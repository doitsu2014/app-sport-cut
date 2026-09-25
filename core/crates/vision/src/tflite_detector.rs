//! macOS-only trial backend for the EfficientDet-Lite0 Task Library model.
//!
//! This feature is disabled by default. The caller supplies local runtime and
//! weight paths; neither is downloaded or selected for distribution here.

use std::path::Path;
use std::sync::Mutex;

use image::{imageops, RgbImage};
use sportcut_common::{Result, SportcutError};
use tflite_c::{Interpreter, InterpreterOptions, Model, TfLiteLibrary, TfLiteType};

use crate::{BoundingBox, Detection, FrameView, PersonDetector};

const INPUT_SIDE: u32 = 320;
const INPUT_CHANNELS: usize = 3;

/// A local EfficientDet-Lite0 candidate backed by a TFLite C interpreter.
pub struct TflitePersonDetector {
    interpreter: Mutex<Interpreter>,
    min_score: f32,
}

impl std::fmt::Debug for TflitePersonDetector {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TflitePersonDetector")
            .field("min_score", &self.min_score)
            .finish_non_exhaustive()
    }
}

impl TflitePersonDetector {
    /// Load an explicitly supplied local runtime and Task Library weight file.
    pub fn open(runtime_path: &Path, model_path: &Path, min_score: f32) -> Result<Self> {
        if !runtime_path.is_file() {
            return Err(invalid(format!(
                "TFLite runtime is missing at {}; supply the local macOS runtime",
                runtime_path.display()
            )));
        }
        if !model_path.is_file() {
            return Err(invalid(format!(
                "person model weights are missing at {}; supply the local model file",
                model_path.display()
            )));
        }
        if !min_score.is_finite() || !(0.0..=1.0).contains(&min_score) {
            return Err(invalid("minimum person score must be between zero and one"));
        }
        let library = TfLiteLibrary::load_from_path(runtime_path)
            .map_err(|error| invalid(format!("TFLite runtime cannot be loaded: {error}")))?;
        let model = Model::from_file(model_path, library.clone())
            .map_err(|error| invalid(format!("person model cannot be loaded: {error}")))?;
        let mut options = InterpreterOptions::new(library);
        options.num_threads(4);
        let interpreter = Interpreter::new(model, options)
            .map_err(|error| invalid(format!("person model cannot be initialized: {error}")))?;
        if interpreter.input_count() != 1 || interpreter.output_count() != 4 {
            return Err(SportcutError::unsupported(
                "person model tensor layout",
                "expected one RGB input and four DetectionPostProcess outputs",
            ));
        }
        let input = interpreter
            .input(0)
            .map_err(|error| invalid(format!("person model input is unreadable: {error}")))?;
        if input.dtype() != TfLiteType::UInt8
            || input.dims()
                != [
                    1,
                    INPUT_SIDE as i32,
                    INPUT_SIDE as i32,
                    INPUT_CHANNELS as i32,
                ]
        {
            return Err(SportcutError::unsupported(
                "person model input",
                "expected a 1×320×320×3 UInt8 RGB tensor",
            ));
        }
        Ok(Self {
            interpreter: Mutex::new(interpreter),
            min_score,
        })
    }
}

impl PersonDetector for TflitePersonDetector {
    fn detect(&self, frame: &FrameView<'_>) -> Result<Vec<Detection>> {
        let (input, placement) = prepare_input(frame)?;
        let mut interpreter = self
            .interpreter
            .lock()
            .map_err(|_| invalid("TFLite interpreter is unavailable after a worker failure"))?;
        let mut tensor = interpreter
            .input_mut(0)
            .map_err(|error| invalid(format!("person model input is unavailable: {error}")))?;
        let buffer = tensor
            .data_mut()
            .map_err(|error| invalid(format!("person model input cannot be written: {error}")))?;
        if buffer.len() != input.len() {
            return Err(invalid("person model input byte size changed unexpectedly"));
        }
        buffer.copy_from_slice(&input);
        drop(tensor);
        interpreter
            .invoke()
            .map_err(|error| invalid(format!("person inference failed: {error}")))?;
        let outputs = (0..4)
            .map(|index| {
                interpreter
                    .output(index)
                    .and_then(|tensor| tensor.to_vec_f32())
                    .map_err(|error| invalid(format!("person model output is unreadable: {error}")))
            })
            .collect::<Result<Vec<_>>>()?;
        decode_people(
            &outputs,
            placement,
            frame.width,
            frame.height,
            self.min_score,
        )
    }
}

#[derive(Debug, Clone, Copy)]
struct Placement {
    width: u32,
    height: u32,
    left: u32,
    top: u32,
}

fn prepare_input(frame: &FrameView<'_>) -> Result<(Vec<u8>, Placement)> {
    let expected_len = (frame.width as usize)
        .checked_mul(frame.height as usize)
        .and_then(|pixels| pixels.checked_mul(INPUT_CHANNELS))
        .ok_or_else(|| invalid("decoded frame dimensions overflow the RGB buffer"))?;
    if frame.width == 0 || frame.height == 0 || frame.pixels.len() != expected_len {
        return Err(invalid(
            "decoded frame is not a positive-size packed RGB8 image",
        ));
    }
    let source = RgbImage::from_raw(frame.width, frame.height, frame.pixels.to_vec())
        .ok_or_else(|| invalid("decoded frame cannot be interpreted as RGB8"))?;
    let scale = (f64::from(INPUT_SIDE) / f64::from(frame.width))
        .min(f64::from(INPUT_SIDE) / f64::from(frame.height));
    let width = (f64::from(frame.width) * scale)
        .round()
        .clamp(1.0, f64::from(INPUT_SIDE)) as u32;
    let height = (f64::from(frame.height) * scale)
        .round()
        .clamp(1.0, f64::from(INPUT_SIDE)) as u32;
    let left = (INPUT_SIDE - width) / 2;
    let top = (INPUT_SIDE - height) / 2;
    let resized = imageops::resize(&source, width, height, imageops::FilterType::Triangle);
    let mut input = vec![0_u8; INPUT_SIDE as usize * INPUT_SIDE as usize * INPUT_CHANNELS];
    for y in 0..height as usize {
        let source_start = y * width as usize * INPUT_CHANNELS;
        let destination_start =
            ((top as usize + y) * INPUT_SIDE as usize + left as usize) * INPUT_CHANNELS;
        let length = width as usize * INPUT_CHANNELS;
        input[destination_start..destination_start + length]
            .copy_from_slice(&resized.as_raw()[source_start..source_start + length]);
    }
    Ok((
        input,
        Placement {
            width,
            height,
            left,
            top,
        },
    ))
}

fn decode_people(
    outputs: &[Vec<f32>],
    placement: Placement,
    frame_width: u32,
    frame_height: u32,
    min_score: f32,
) -> Result<Vec<Detection>> {
    if outputs.len() != 4 || outputs[3].len() != 1 {
        return Err(invalid(
            "person model returned an unsupported output layout",
        ));
    }
    let count_value = outputs[3][0];
    if !count_value.is_finite() || count_value < 0.0 {
        return Err(invalid("person model returned an invalid detection count"));
    }
    let count = (count_value as usize)
        .min(outputs[0].len() / 4)
        .min(outputs[1].len())
        .min(outputs[2].len());
    let mut people = Vec::new();
    for index in 0..count {
        let class = outputs[1][index];
        let score = outputs[2][index];
        if !class.is_finite() || class.round() != 0.0 || !score.is_finite() || score < min_score {
            continue;
        }
        let box_values = &outputs[0][index * 4..index * 4 + 4];
        if box_values.iter().any(|value| !value.is_finite()) {
            continue;
        }
        let x1 = unletterbox(box_values[1], placement.left, placement.width).clamp(0.0, 1.0)
            * frame_width as f32;
        let y1 = unletterbox(box_values[0], placement.top, placement.height).clamp(0.0, 1.0)
            * frame_height as f32;
        let x2 = unletterbox(box_values[3], placement.left, placement.width).clamp(0.0, 1.0)
            * frame_width as f32;
        let y2 = unletterbox(box_values[2], placement.top, placement.height).clamp(0.0, 1.0)
            * frame_height as f32;
        if x2 > x1 && y2 > y1 {
            people.push(Detection {
                bbox: BoundingBox {
                    x: x1,
                    y: y1,
                    width: x2 - x1,
                    height: y2 - y1,
                },
                confidence: score,
            });
        }
    }
    Ok(people)
}

fn unletterbox(value: f32, offset: u32, extent: u32) -> f32 {
    (value * INPUT_SIDE as f32 - offset as f32) / extent as f32
}

fn invalid(message: impl Into<String>) -> SportcutError {
    SportcutError::InvalidInput(format!("person detection: {}", message.into()))
}
