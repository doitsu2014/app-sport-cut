//! Court geometry: homography estimation and court-side calculation.
//!
//! Placeholder boundary. Court calibration is deliberately out of scope for the
//! bootstrap change, but the crate exists so the media and job foundation can
//! reference a stable crate name when calibration work starts.
//!
//! Intended shape of the first implementation:
//!
//! * a four-point (or six-point) manual calibration captured per match,
//! * homography from image coordinates to court coordinates,
//! * court-side assignment for a player position, accounting for the camera's
//!   end of the court.

#![forbid(unsafe_code)]
