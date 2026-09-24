/// Translation between the stored calibration and the bridge's form of it.
///
/// The two shapes carry the same information; keeping the domain model separate
/// means a change to the bridge contract is one file's worth of work rather than
/// a change that reaches the catalog and the screens.
library;

import '../../../bridge/sportcut_engine.dart';
import '../domain/court_calibration.dart';

/// The bridge form of a segment.
CalibrationSegmentDto toSegmentDto(CalibrationSegment segment) =>
    CalibrationSegmentDto(
      fromMs: segment.fromMs,
      corners: <CourtCornerDto>[
        for (final corner in segment.corners)
          CourtCornerDto(x: corner.x, y: corner.y),
      ],
      orientation: switch (segment.orientation) {
        CourtOrientation.away => CourtOrientationDto.away,
        CourtOrientation.across => CourtOrientationDto.across,
      },
    );

/// The bridge form of a whole calibration.
CourtCalibrationDto toCalibrationDto(CourtCalibration calibration) =>
    CourtCalibrationDto(
      schemaVersion: calibration.schemaVersion,
      segments: <CalibrationSegmentDto>[
        for (final segment in calibration.segments) toSegmentDto(segment),
      ],
    );

/// A segment the engine reported, as the application stores it.
CalibrationSegment fromSegmentDto(CalibrationSegmentDto dto) =>
    CalibrationSegment(
      fromMs: dto.fromMs,
      corners: <CourtCorner>[
        for (final corner in dto.corners) CourtCorner(x: corner.x, y: corner.y),
      ],
      orientation: switch (dto.orientation) {
        CourtOrientationDto.away => CourtOrientation.away,
        CourtOrientationDto.across => CourtOrientation.across,
      },
    );

/// A calibration the engine reported, as the application stores it.
CourtCalibration fromCalibrationDto(CourtCalibrationDto dto) => CourtCalibration(
      schemaVersion: dto.schemaVersion,
      segments: <CalibrationSegment>[
        for (final segment in dto.segments) fromSegmentDto(segment),
      ],
    );
