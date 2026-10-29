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

#[cfg(test)]
mod tests {
    use super::*;

    /// The unit square in image coordinates: the calibration that should be an
    /// identity mapping.
    fn unit_square() -> [ImagePoint; 4] {
        [
            ImagePoint::new(0.0, 0.0),
            ImagePoint::new(1.0, 0.0),
            ImagePoint::new(1.0, 1.0),
            ImagePoint::new(0.0, 1.0),
        ]
    }

    /// A court seen from behind a baseline: the near edge is wider than the far
    /// one, so the mapping has to be genuinely projective.
    fn trapezoid() -> [ImagePoint; 4] {
        [
            ImagePoint::new(0.10, 0.90),
            ImagePoint::new(0.90, 0.90),
            ImagePoint::new(0.70, 0.40),
            ImagePoint::new(0.30, 0.40),
        ]
    }

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-9,
            "expected {expected}, got {actual}"
        );
    }

    /// Where two line segments cross, for the diagonal invariant below.
    fn crossing(a: ImagePoint, b: ImagePoint, c: ImagePoint, d: ImagePoint) -> ImagePoint {
        let determinant = (a.x - b.x) * (c.y - d.y) - (a.y - b.y) * (c.x - d.x);
        assert!(
            determinant.abs() > 1e-12,
            "the lines are parallel, so there is no crossing"
        );
        let first = a.x * b.y - a.y * b.x;
        let second = c.x * d.y - c.y * d.x;
        ImagePoint::new(
            (first * (c.x - d.x) - (a.x - b.x) * second) / determinant,
            (first * (c.y - d.y) - (a.y - b.y) * second) / determinant,
        )
    }

    #[test]
    fn the_unit_square_maps_to_itself_with_the_first_corner_as_the_origin() {
        let mapping = CourtMapping::from_corners(&unit_square()).expect("a square defines a court");

        let origin = mapping
            .to_court(ImagePoint::new(0.0, 0.0))
            .expect("the origin maps");
        assert_close(origin.u, 0.0);
        assert_close(origin.v, 0.0);

        let corner = mapping
            .to_court(ImagePoint::new(0.25, 0.75))
            .expect("an interior point maps");
        assert_close(corner.u, 0.25);
        assert_close(corner.v, 0.75);

        let back = mapping
            .to_image(CourtPoint::new(0.25, 0.75))
            .expect("the court maps back");
        assert_close(back.x, 0.25);
        assert_close(back.y, 0.75);
    }

    #[test]
    fn mapping_a_projected_court_round_trips() {
        let mapping =
            CourtMapping::from_corners(&trapezoid()).expect("a trapezoid defines a court");

        for (u, v) in [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.5, 0.5)] {
            let image = mapping
                .to_image(CourtPoint::new(u, v))
                .unwrap_or_else(|| panic!("court point ({u}, {v}) maps to the image"));
            let court = mapping
                .to_court(image)
                .unwrap_or_else(|| panic!("image point {image:?} maps back to the court"));
            assert!(
                (court.u - u).abs() < 1e-9 && (court.v - v).abs() < 1e-9,
                "({u}, {v}) round-tripped to {court:?}"
            );
        }
    }

    #[test]
    fn the_court_centre_is_where_the_marked_quadrilaterals_diagonals_cross() {
        // A projective map is not affine, so the centre of the court is *not*
        // the middle of the quadrilateral's bounding box. It is the crossing of
        // its diagonals, which is the invariant a wrong homography breaks.
        let corners = trapezoid();
        let mapping = CourtMapping::from_corners(&corners).expect("a trapezoid defines a court");

        let centre = mapping
            .to_image(CourtPoint::new(0.5, 0.5))
            .expect("the court centre maps");
        let expected = crossing(corners[0], corners[2], corners[1], corners[3]);

        assert!(
            (centre.x - expected.x).abs() < 1e-9 && (centre.y - expected.y).abs() < 1e-9,
            "expected {expected:?}, got {centre:?}"
        );
        // And it is genuinely off the bounding box's middle, so the assertion
        // above is not passing by way of an affine mapping.
        assert!(
            (centre.y - 0.65).abs() > 1e-3,
            "the centre should not sit halfway down the image: {centre:?}"
        );
    }

    #[test]
    fn a_parallelogram_is_mapped_without_projective_terms() {
        // The projective terms vanish here, which is the branch the general case
        // divides by; a square sheared into a parallelogram still has to map.
        let sheared = [
            ImagePoint::new(0.20, 0.80),
            ImagePoint::new(0.80, 0.80),
            ImagePoint::new(1.00, 0.30),
            ImagePoint::new(0.40, 0.30),
        ];
        let mapping =
            CourtMapping::from_corners(&sheared).expect("a parallelogram defines a court");

        let court = mapping
            .to_court(ImagePoint::new(0.5, 0.55))
            .expect("the point maps");
        let back = mapping.to_image(court).expect("the point maps back");
        assert!(
            (back.x - 0.5).abs() < 1e-9 && (back.y - 0.55).abs() < 1e-9,
            "{back:?}"
        );
    }
}
