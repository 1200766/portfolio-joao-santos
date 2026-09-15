import unittest

import numpy as np

from pimed_atlas.landmarks import (
    ImageGeometry,
    angle_at_point_degrees,
    angle_between_vectors_degrees,
    axis_separation_mm,
    distance_mm,
)


class GeometryTests(unittest.TestCase):
    def test_spatial_transform_round_trip(self) -> None:
        geometry = ImageGeometry(
            shape_zyx=(20, 30, 40),
            origin_xyz_mm=(4.0, -3.0, 8.0),
            spacing_zyx=(3.0, 2.0, 0.5),
            direction_xyz=np.array(
                ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))
            ),
        )
        indices = np.array([[1.0, 2.0, 3.0], [4.5, 1.25, 0.0]])
        physical = geometry.index_zyx_to_physical_xyz(indices)
        restored = geometry.physical_xyz_to_continuous_index_zyx(physical)
        self.assertTrue(np.allclose(restored, indices))

    def test_distance_axis_separation_and_angles(self) -> None:
        self.assertAlmostEqual(distance_mm((0, 0, 0), (3, 4, 0)), 5.0)
        self.assertAlmostEqual(axis_separation_mm((0, -2, 8), (5, 3, 2), "z"), 6.0)
        self.assertAlmostEqual(
            angle_between_vectors_degrees((1, 0, 0), (0, 1, 0)), 90.0
        )
        self.assertAlmostEqual(
            angle_at_point_degrees((1, 0, 0), (0, 0, 0), (0, 1, 0)),
            90.0,
        )

    def test_rejects_undefined_or_invalid_geometry(self) -> None:
        with self.assertRaisesRegex(ValueError, "zero-length"):
            angle_between_vectors_degrees((0, 0, 0), (1, 0, 0))
        with self.assertRaisesRegex(ValueError, "positiv"):
            ImageGeometry((2, 2, 2), spacing_zyx=(1.0, 0.0, 1.0))
        with self.assertRaisesRegex(ValueError, "invertível"):
            ImageGeometry(
                (2, 2, 2),
                (1.0, 1.0, 1.0),
                direction_xyz=np.array(((0, 0, 0), (0, 1, 0), (0, 0, 1))),
            )


if __name__ == "__main__":
    unittest.main()
