//! The projective mapping a marked quadrilateral defines.
//!
//! The court plane and the image plane are related by a homography, so four
//! point correspondences determine it exactly. The four corners the user marks
//! are the image side; the unit square is the court side.

use sportcut_common::{Result, SportcutError};

use crate::{CourtPoint, ImagePoint};

/// Smallest magnitude a projective denominator may have before the mapping is
/// treated as undefined at that point.
const PROJECTIVE_EPSILON: f64 = 1e-12;

/// A projective mapping between normalized image coordinates and court
/// coordinates, in both directions.
///
/// Both matrices are row-major and act on the column vector `(x, y, 1)`. The
/// result is divided through by its third component, so each matrix is only
/// defined up to scale.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CourtMapping {
    /// Maps an image position to a court position.
    pub image_to_court: [[f64; 3]; 3],
    /// Maps a court position back to an image position.
    pub court_to_image: [[f64; 3]; 3],
}

impl CourtMapping {
    /// Derive the mapping from four corners in the order they were marked.
    ///
    /// The corners are taken as the image of the unit square's corners in the
    /// same order, so the first corner becomes the court origin and the walk
    /// through them fixes which court axes the two edges run along.
    pub fn from_corners(corners: &[ImagePoint; 4]) -> Result<Self> {
        let court_to_image = square_to_quad(corners)?;
        let image_to_court = invert(&court_to_image).ok_or_else(|| {
            SportcutError::InvalidInput(
                "court calibration: the marked corners do not define a court".to_string(),
            )
        })?;
        Ok(Self {
            image_to_court,
            court_to_image,
        })
    }

    /// The court position an image position maps to.
    ///
    /// `None` on the mapping's vanishing line, where the projection is
    /// undefined because the two planes meet.
    pub fn to_court(&self, point: ImagePoint) -> Option<CourtPoint> {
        let (u, v) = apply(&self.image_to_court, point.x, point.y)?;
        Some(CourtPoint::new(u, v))
    }

    /// The image position a court position maps to.
    pub fn to_image(&self, point: CourtPoint) -> Option<ImagePoint> {
        let (x, y) = apply(&self.court_to_image, point.u, point.v)?;
        Some(ImagePoint::new(x, y))
    }
}

/// The court's outline and net, in image coordinates.
///
/// This is what the application draws over the recording so the user can check
/// the calibration against the painted lines.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CourtOutline {
    /// The four court corners, in the order they were marked.
    pub corners: [ImagePoint; 4],
    /// The two ends of the net line.
    pub net: [ImagePoint; 2],
}

/// Apply a projective matrix to a point and divide through.
fn apply(matrix: &[[f64; 3]; 3], x: f64, y: f64) -> Option<(f64, f64)> {
    let w = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2];
    if !w.is_finite() || w.abs() <= PROJECTIVE_EPSILON {
        return None;
    }
    let mapped_x = (matrix[0][0] * x + matrix[0][1] * y + matrix[0][2]) / w;
    let mapped_y = (matrix[1][0] * x + matrix[1][1] * y + matrix[1][2]) / w;
    if !mapped_x.is_finite() || !mapped_y.is_finite() {
        return None;
    }
    Some((mapped_x, mapped_y))
}

/// The homography mapping the unit square onto the marked quadrilateral.
///
/// Squares map to quadrilaterals through a single projective transform, so the
/// matrix is written directly from the corners rather than solved for. The
/// degenerate case is affine — the quadrilateral is a parallelogram — and is
/// taken separately, because the projective terms both vanish there.
fn square_to_quad(corners: &[ImagePoint; 4]) -> Result<[[f64; 3]; 3]> {
    let [p0, p1, p2, p3] = *corners;

    let projective_u = p0.x - p1.x + p2.x - p3.x;
    let projective_v = p0.y - p1.y + p2.y - p3.y;

    if projective_u.abs() <= PROJECTIVE_EPSILON && projective_v.abs() <= PROJECTIVE_EPSILON {
        return Ok([
            [p1.x - p0.x, p2.x - p1.x, p0.x],
            [p1.y - p0.y, p2.y - p1.y, p0.y],
            [0.0, 0.0, 1.0],
        ]);
    }

    let edge_u = p1.x - p2.x;
    let edge_v = p3.x - p2.x;
    let edge_u_y = p1.y - p2.y;
    let edge_v_y = p3.y - p2.y;

    let denominator = edge_u * edge_v_y - edge_v * edge_u_y;
    if denominator.abs() <= PROJECTIVE_EPSILON || !denominator.is_finite() {
        return Err(SportcutError::InvalidInput(
            "court calibration: the marked corners do not define a court".to_string(),
        ));
    }

    let g = (projective_u * edge_v_y - edge_v * projective_v) / denominator;
    let h = (edge_u * projective_v - projective_u * edge_u_y) / denominator;

    let matrix = [
        [p1.x - p0.x + g * p1.x, p3.x - p0.x + h * p3.x, p0.x],
        [p1.y - p0.y + g * p1.y, p3.y - p0.y + h * p3.y, p0.y],
        [g, h, 1.0],
    ];

    if matrix
        .iter()
        .flatten()
        .any(|component| !component.is_finite())
    {
        return Err(SportcutError::InvalidInput(
            "court calibration: the marked corners do not define a court".to_string(),
        ));
    }

    Ok(matrix)
}

/// Invert a 3x3 matrix, or `None` when it is singular.
fn invert(matrix: &[[f64; 3]; 3]) -> Option<[[f64; 3]; 3]> {
    let determinant = matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
        - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
        + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]);

    if !determinant.is_finite() || determinant.abs() <= PROJECTIVE_EPSILON {
        return None;
    }

    let inverse = [
        [
            (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1]) / determinant,
            (matrix[0][2] * matrix[2][1] - matrix[0][1] * matrix[2][2]) / determinant,
            (matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1]) / determinant,
        ],
        [
            (matrix[1][2] * matrix[2][0] - matrix[1][0] * matrix[2][2]) / determinant,
            (matrix[0][0] * matrix[2][2] - matrix[0][2] * matrix[2][0]) / determinant,
            (matrix[0][2] * matrix[1][0] - matrix[0][0] * matrix[1][2]) / determinant,
        ],
        [
            (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0]) / determinant,
            (matrix[0][1] * matrix[2][0] - matrix[0][0] * matrix[2][1]) / determinant,
            (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]) / determinant,
        ],
    ];

    if inverse
        .iter()
        .flatten()
        .any(|component| !component.is_finite())
    {
        return None;
    }

    Some(inverse)
}
