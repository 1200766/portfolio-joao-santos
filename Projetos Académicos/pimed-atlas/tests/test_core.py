from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

from pimed_atlas.core import (
    ImageGeometry,
    Volume3D,
    read_npz_volume,
    save_npz_volume,
    write_json,
)


class GeometryTests(unittest.TestCase):
    def test_index_physical_round_trip_with_rotation(self):
        direction = np.array(
            [
                [0.0, -1.0, 0.0],
                [1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0],
            ]
        )
        geometry = ImageGeometry(
            shape_zyx=(20, 30, 40),
            spacing_zyx=(1.5, 0.8, 0.5),
            origin_xyz_mm=(12.0, -4.0, 3.0),
            direction_xyz=direction,
        )
        indices = np.array([[2.5, 7.0, 11.25], [19.0, 0.0, 39.0]])

        physical = geometry.index_zyx_to_physical_xyz(indices)
        recovered = geometry.physical_xyz_to_continuous_index_zyx(physical)

        np.testing.assert_allclose(recovered, indices, atol=1e-12)

    def test_volume_rejects_mismatched_shape(self):
        geometry = ImageGeometry((4, 5, 6), (1.0, 1.0, 1.0))
        with self.assertRaisesRegex(ValueError, "não corresponde"):
            Volume3D(np.zeros((4, 5, 5)), geometry)

    def test_geometry_rejects_non_finite_or_non_orthonormal_axes(self):
        with self.assertRaisesRegex(ValueError, "positivos"):
            ImageGeometry((4, 5, 6), (1.0, float("nan"), 1.0))
        with self.assertRaisesRegex(ValueError, "ortonormal"):
            ImageGeometry(
                (4, 5, 6),
                (1.0, 1.0, 1.0),
                direction_xyz=np.array(
                    [[1.0, 0.2, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
                ),
            )

    def test_geometry_direction_is_immutable_and_equality_is_boolean(self):
        first = ImageGeometry((4, 5, 6), (1.0, 2.0, 3.0))
        second = ImageGeometry((4, 5, 6), (1.0, 2.0, 3.0))

        self.assertTrue(first == second)
        self.assertEqual(hash(first), hash(second))
        with self.assertRaises(ValueError):
            first.direction_xyz[0, 0] = 0.0

    def test_label_mask_is_boolean(self):
        labels = np.zeros((4, 5, 6), dtype=np.uint8)
        labels[1:3, 2:4, 3:5] = 8
        volume = Volume3D(labels, ImageGeometry(labels.shape, (1.0, 1.0, 1.0)))

        mask = volume.mask_for_label(8)

        self.assertEqual(mask.dtype, np.bool_)
        self.assertEqual(int(mask.sum()), 8)

    def test_npz_round_trip_preserves_geometry(self):
        labels = np.arange(4 * 5 * 6, dtype=np.uint16).reshape((4, 5, 6))
        geometry = ImageGeometry(
            labels.shape,
            (1.5, 0.8, 0.5),
            (12.0, -4.0, 3.0),
            np.diag([-1.0, -1.0, 1.0]),
        )
        original = Volume3D(labels, geometry, "synthetic-roundtrip")

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "case.npz"
            save_npz_volume(path, original)
            recovered = read_npz_volume(path)

        np.testing.assert_array_equal(recovered.data_zyx, original.data_zyx)
        np.testing.assert_allclose(
            recovered.geometry.direction_xyz,
            original.geometry.direction_xyz,
        )
        self.assertEqual(recovered.geometry.spacing_zyx, (1.5, 0.8, 0.5))
        self.assertEqual(recovered.case_id, "synthetic-roundtrip")

    def test_json_writer_replaces_non_finite_values_with_null(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "result.json"
            write_json(path, {"values": np.asarray([1.0, np.nan, np.inf])})
            raw = path.read_text(encoding="utf-8")
            recovered = json.loads(raw)

        self.assertNotIn("NaN", raw)
        self.assertNotIn("Infinity", raw)
        self.assertEqual(recovered, {"values": [1.0, None, None]})


if __name__ == "__main__":
    unittest.main()
