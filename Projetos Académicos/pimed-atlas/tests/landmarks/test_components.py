import unittest

import numpy as np

from pimed_atlas.landmarks import ImageGeometry, LabelSpec, analyse_landmarks


class LandmarkComponentTests(unittest.TestCase):
    def test_uses_26_connectivity_and_full_physical_geometry(self) -> None:
        labels = np.zeros((5, 5, 5), dtype=np.uint8)
        labels[0, 0, 0] = 17
        labels[1, 1, 1] = 17  # Connected only through a corner.
        labels[4, 4, 4] = 17  # Deliberately filtered as a one-voxel speck.

        geometry = ImageGeometry(
            shape_zyx=labels.shape,
            origin_xyz_mm=(10.0, 20.0, 30.0),
            spacing_zyx=(4.0, 3.0, 2.0),
            direction_xyz=np.array(
                ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))
            ),
        )
        result = analyse_landmarks(
            labels,
            geometry,
            [LabelSpec(17, "configured-landmark", expected_components=1, min_voxels=2)],
        )

        label_result = result.for_label(17)
        self.assertEqual(len(label_result.components), 1)
        component = label_result.components[0]
        self.assertEqual(component.voxel_count, 2)
        self.assertEqual(component.centroid_index_zyx, (0.5, 0.5, 0.5))
        self.assertTrue(
            np.allclose(component.centroid_physical_xyz_mm, (8.5, 21.0, 32.0))
        )
        self.assertEqual(label_result.ignored_component_sizes, (1,))
        self.assertEqual(
            [warning.code for warning in label_result.warnings],
            ["small_components_ignored"],
        )

    def test_orders_components_deterministically_by_size_then_position(self) -> None:
        labels = np.zeros((6, 6, 6), dtype=np.uint8)
        labels[4, 4, 4] = 12
        labels[4, 4, 5] = 12
        labels[1, 1, 1] = 12

        result = analyse_landmarks(
            labels,
            ImageGeometry(labels.shape, (1.0, 1.0, 1.0)),
            [LabelSpec(12, "candidate", expected_components=2)],
        ).for_label(12)

        self.assertEqual([item.voxel_count for item in result.components], [2, 1])
        self.assertEqual(result.components[0].component_id, 1)
        self.assertEqual(result.components[1].component_id, 2)

    def test_returns_warnings_for_absent_and_unexpected_labels(self) -> None:
        result = analyse_landmarks(
            np.zeros((3, 3, 3), dtype=np.uint8),
            ImageGeometry((3, 3, 3), (1.0, 1.0, 1.0)),
            [LabelSpec(9, "not-present", expected_components=2)],
        )

        self.assertEqual(
            [warning.code for warning in result.warnings],
            ["label_absent", "unexpected_component_count"],
        )

    def test_distinguishes_an_absent_label_from_filtered_small_components(self) -> None:
        labels = np.zeros((3, 3, 3), dtype=np.uint8)
        labels[1, 1, 1] = 4
        result = analyse_landmarks(
            labels,
            ImageGeometry(labels.shape, (1.0, 1.0, 1.0)),
            [LabelSpec(4, "small", min_voxels=2)],
        )

        self.assertEqual(
            [warning.code for warning in result.warnings],
            ["no_component_above_minimum_size", "small_components_ignored"],
        )

    def test_requires_integer_volume_and_explicit_non_duplicate_schema(self) -> None:
        with self.assertRaisesRegex(TypeError, "integer or boolean"):
            analyse_landmarks(
                np.zeros((2, 2, 2), dtype=float),
                ImageGeometry((2, 2, 2), (1.0, 1.0, 1.0)),
                [LabelSpec(1, "one")],
            )
        with self.assertRaisesRegex(ValueError, "duplicate"):
            analyse_landmarks(
                np.zeros((2, 2, 2), dtype=np.uint8),
                ImageGeometry((2, 2, 2), (1.0, 1.0, 1.0)),
                [LabelSpec(1, "one"), LabelSpec(1, "duplicate")],
            )


if __name__ == "__main__":
    unittest.main()
