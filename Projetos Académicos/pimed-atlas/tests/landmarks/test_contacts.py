import unittest

import numpy as np

from pimed_atlas.landmarks import ImageGeometry, analyse_surface_contacts


class SurfaceContactTests(unittest.TestCase):
    def test_measures_component_surfaces_in_physical_space(self) -> None:
        labels = np.zeros((5, 5, 7), dtype=np.uint8)
        labels[1, 1, 1] = 8
        labels[1, 1, 3] = 12
        labels[4, 4, 6] = 12

        result = analyse_surface_contacts(
            labels,
            ImageGeometry(labels.shape, spacing_zyx=(3.0, 1.0, 2.0)),
            8,
            12,
            threshold_mm=4.0,
        )

        self.assertEqual(len(result.pairs), 2)
        self.assertEqual(len(result.contacts), 1)
        contact = result.contacts[0]
        self.assertAlmostEqual(contact.minimum_distance_mm, 4.0)
        self.assertEqual(contact.pairs_within_threshold, 1)
        self.assertEqual(contact.closest_source_point_xyz_mm, (2.0, 1.0, 3.0))
        self.assertEqual(contact.closest_target_point_xyz_mm, (6.0, 1.0, 3.0))
        self.assertEqual(
            result.distance_definition,
            "euclidean_distance_between_surface_voxel_centres",
        )

    def test_direction_rotation_preserves_physical_distance(self) -> None:
        labels = np.zeros((3, 3, 4), dtype=np.uint8)
        labels[1, 1, 1] = 1
        labels[1, 1, 2] = 2
        geometry = ImageGeometry(
            labels.shape,
            spacing_zyx=(1.0, 1.0, 2.5),
            direction_xyz=np.array(
                ((0.0, -1.0, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0))
            ),
        )

        pair = analyse_surface_contacts(
            labels, geometry, 1, 2, threshold_mm=2.5
        ).contacts[0]
        self.assertAlmostEqual(pair.minimum_distance_mm, 2.5)

    def test_warns_when_labels_or_contacts_are_missing(self) -> None:
        labels = np.zeros((3, 3, 5), dtype=np.uint8)
        labels[1, 1, 0] = 1
        labels[1, 1, 4] = 2

        no_contact = analyse_surface_contacts(
            labels, ImageGeometry(labels.shape, (1.0, 1.0, 1.0)), 1, 2, threshold_mm=1.0
        )
        self.assertEqual(len(no_contact.contacts), 0)
        self.assertEqual(
            [warning.code for warning in no_contact.warnings],
            ["no_surface_contacts_within_threshold"],
        )

        absent = analyse_surface_contacts(
            labels, ImageGeometry(labels.shape, (1.0, 1.0, 1.0)), 1, 9, threshold_mm=1.0
        )
        self.assertEqual(
            [warning.code for warning in absent.warnings],
            ["contact_target_label_absent"],
        )

    def test_evaluates_unique_pairs_when_labels_are_the_same(self) -> None:
        labels = np.zeros((3, 3, 5), dtype=np.uint8)
        labels[1, 1, 0] = 5
        labels[1, 1, 2] = 5
        labels[1, 1, 4] = 5

        result = analyse_surface_contacts(
            labels, ImageGeometry(labels.shape, (1.0, 1.0, 1.0)), 5, 5, threshold_mm=2.0
        )
        self.assertEqual(len(result.pairs), 3)
        self.assertEqual(len(result.contacts), 2)

    def test_adjacent_voxels_are_one_spacing_apart_under_the_declared_metric(
        self,
    ) -> None:
        labels = np.zeros((3, 3, 4), dtype=np.uint8)
        labels[1, 1, 1] = 1
        labels[1, 1, 2] = 2

        result = analyse_surface_contacts(
            labels,
            ImageGeometry(labels.shape, (1.0, 1.0, 2.0)),
            1,
            2,
            threshold_mm=0.0,
        )

        self.assertEqual(result.pairs[0].minimum_distance_mm, 2.0)
        self.assertFalse(result.pairs[0].within_threshold)
        self.assertEqual(
            result.distance_definition,
            "euclidean_distance_between_surface_voxel_centres",
        )


if __name__ == "__main__":
    unittest.main()
