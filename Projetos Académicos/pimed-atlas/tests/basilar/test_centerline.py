from __future__ import annotations

import unittest

import numpy as np

from pimed_atlas.basilar import (
    build_skeleton_graph,
    estimate_tangents,
    geodesic_centerline,
    select_component_26,
    skeletonize_3d,
)


class ComponentTests(unittest.TestCase):
    def test_selects_largest_or_seeded_26_connected_component(self) -> None:
        mask = np.zeros((12, 12, 12), dtype=bool)
        mask[1:4, 1:4, 1:4] = True
        mask[8, 8, 8] = True
        mask[9, 9, 9] = True  # A corner touch belongs to the same 26-component.

        largest = select_component_26(mask)
        seeded = select_component_26(mask, seed_zyx=(9, 9, 9))

        self.assertEqual(int(largest.sum()), 27)
        self.assertEqual(int(seeded.sum()), 2)
        self.assertTrue(seeded[8, 8, 8])

    def test_seed_must_be_foreground(self) -> None:
        mask = np.zeros((3, 3, 3), dtype=bool)
        mask[1, 1, 1] = True
        with self.assertRaisesRegex(ValueError, "foreground"):
            select_component_26(mask, seed_zyx=(0, 0, 0))


class CentrelineTests(unittest.TestCase):
    def test_seeded_geodesic_uses_physical_edge_weights(self) -> None:
        skeleton = np.zeros((7, 7, 7), dtype=bool)
        skeleton[1:6, 3, 3] = True
        graph = build_skeleton_graph(skeleton, spacing_zyx=(2.0, 1.0, 0.5))

        path = geodesic_centerline(
            graph,
            start_seed_zyx=(1, 3, 3),
            end_seed_zyx=(5, 3, 3),
        )

        np.testing.assert_array_equal(path.points_zyx[:, 0], np.arange(1, 6))
        self.assertAlmostEqual(path.length_mm, 8.0)
        self.assertFalse(path.automatic_endpoints)

    def test_automatic_mode_finds_full_synthetic_line(self) -> None:
        skeleton = np.zeros((8, 8, 8), dtype=bool)
        skeleton[2, 1:7, 4] = True
        graph = build_skeleton_graph(skeleton, spacing_zyx=(2.0, 0.75, 1.0))

        path = geodesic_centerline(graph)

        self.assertEqual(len(path.points_zyx), 6)
        self.assertAlmostEqual(path.length_mm, 3.75)
        self.assertTrue(path.automatic_endpoints)

    def test_automatic_mode_rejects_a_cycle(self) -> None:
        skeleton = np.zeros((3, 5, 5), dtype=bool)
        skeleton[1, 1, 1:4] = True
        skeleton[1, 3, 1:4] = True
        skeleton[1, 1:4, 1] = True
        skeleton[1, 1:4, 3] = True
        graph = build_skeleton_graph(skeleton, spacing_zyx=(1.0, 1.0, 1.0))

        with self.assertRaisesRegex(ValueError, "acyclic"):
            geodesic_centerline(graph)

    def test_seeded_path_excludes_a_lateral_skeleton_branch(self) -> None:
        skeleton = np.zeros((9, 9, 9), dtype=bool)
        skeleton[1:8, 4, 4] = True
        skeleton[4, 4, 5:8] = True
        graph = build_skeleton_graph(skeleton, spacing_zyx=(1.0, 1.0, 1.0))

        path = geodesic_centerline(
            graph,
            start_seed_zyx=(1, 4, 4),
            end_seed_zyx=(7, 4, 4),
        )

        np.testing.assert_array_equal(path.points_zyx[:, 2], 4)
        self.assertAlmostEqual(path.length_mm, 6.0)

    def test_seeded_path_rejects_disconnected_skeletons(self) -> None:
        skeleton = np.zeros((9, 9, 9), dtype=bool)
        skeleton[1:4, 2, 2] = True
        skeleton[5:8, 6, 6] = True
        graph = build_skeleton_graph(skeleton, spacing_zyx=(1.0, 1.0, 1.0))

        with self.assertRaisesRegex(ValueError, "disconnected"):
            geodesic_centerline(
                graph,
                start_seed_zyx=(1, 2, 2),
                end_seed_zyx=(7, 6, 6),
            )

    def test_tangents_are_computed_in_physical_coordinates(self) -> None:
        points = np.asarray(
            [
                (1, 3, 2),
                (2, 3, 4),
                (3, 3, 6),
                (4, 3, 8),
            ],
            dtype=float,
        )
        tangents = estimate_tangents(points, spacing_zyx=(2.0, 1.0, 0.5), window=1)
        expected = np.asarray((2.0, 0.0, 1.0)) / np.sqrt(5.0)

        np.testing.assert_allclose(tangents, np.tile(expected, (4, 1)))
        np.testing.assert_allclose(np.linalg.norm(tangents, axis=1), 1.0)

    def test_skeletonizes_a_synthetic_straight_tube(self) -> None:
        z, y, x = np.indices((17, 17, 17))
        tube = ((y - 8) ** 2 + (x - 8) ** 2 <= 9) & (z >= 2) & (z <= 14)

        skeleton = skeletonize_3d(tube)
        graph = build_skeleton_graph(skeleton, spacing_zyx=(1.0, 1.0, 1.0))
        path = geodesic_centerline(graph)

        self.assertEqual(skeleton.dtype, np.bool_)
        self.assertGreaterEqual(len(path.points_zyx), 9)
        self.assertGreater(path.length_mm, 8.0)


if __name__ == "__main__":
    unittest.main()
