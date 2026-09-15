from __future__ import annotations

import unittest

import numpy as np
from scipy import ndimage

from pimed_atlas.core import ImageGeometry, Volume3D
from pimed_atlas.pipelines import (
    SYNTHETIC_BASILAR_LABEL,
    analyse_basilar_volume,
    analyse_landmark_volume,
    generate_synthetic_case,
    parse_landmark_schema,
    synthetic_landmark_schema_payload,
)


def _curved_basilar_case() -> tuple[
    Volume3D,
    np.ndarray,
    np.ndarray,
    float,
    float,
]:
    """Build a non-planar constant-radius tube with known physical anchors."""

    shape_zyx = (84, 96, 96)
    spacing_zyx = (0.6, 0.6, 0.6)
    geometry = ImageGeometry(
        shape_zyx=shape_zyx,
        spacing_zyx=spacing_zyx,
        origin_xyz_mm=(13.0, -11.0, 7.0),
        direction_xyz=np.asarray(
            (
                (0.0, -1.0, 0.0),
                (1.0, 0.0, 0.0),
                (0.0, 0.0, 1.0),
            )
        ),
    )

    parameter = np.linspace(0.0, 1.0, 2001)
    curve_mm_zyx = np.column_stack(
        (
            9.0 + 34.0 * parameter,
            23.0 + 8.0 * np.sin(np.pi * parameter),
            25.0 + 5.0 * np.sin(2.0 * np.pi * parameter),
        )
    )
    centreline_voxels = np.rint(curve_mm_zyx / np.asarray(spacing_zyx)).astype(int)
    centreline_seed = np.zeros(shape_zyx, dtype=bool)
    centreline_seed[tuple(centreline_voxels.T)] = True

    radius_mm = 2.8
    distance_to_curve_mm = ndimage.distance_transform_edt(
        ~centreline_seed,
        sampling=spacing_zyx,
    )
    labels = np.zeros(shape_zyx, dtype=np.uint8)
    labels[distance_to_curve_mm <= radius_mm] = SYNTHETIC_BASILAR_LABEL

    # These are physical XYZ coordinates after applying the non-zero origin
    # and the 90-degree image direction above, not NumPy indices.
    start_anchor_xyz_mm = np.asarray((-10.0, 14.0, 16.0))
    end_anchor_xyz_mm = np.asarray((-10.0, 14.0, 50.0))
    expected_length_mm = float(
        np.linalg.norm(np.diff(curve_mm_zyx, axis=0), axis=1).sum()
    )
    return (
        Volume3D(labels, geometry, case_id="curved-synthetic-case"),
        start_anchor_xyz_mm,
        end_anchor_xyz_mm,
        radius_mm,
        expected_length_mm,
    )


class LandmarkPipelineTests(unittest.TestCase):
    def test_synthetic_schema_drives_all_landmark_operations(self) -> None:
        volume = generate_synthetic_case()
        schema = parse_landmark_schema(synthetic_landmark_schema_payload())

        result = analyse_landmark_volume(volume, schema, source_format="npz")

        self.assertEqual(result["analysis_type"], "landmarks")
        self.assertEqual(len(result["results"]["components"]["labels"]), 2)
        assignments = result["results"]["laterality"][0]["result"]["assignments"]
        self.assertEqual({item["side"] for item in assignments}, {"left", "right"})
        contacts = result["results"]["contacts"][0]["contacts"]
        self.assertEqual(len(contacts), 1)

    def test_schema_rejects_an_implicit_or_unknown_label(self) -> None:
        payload = synthetic_landmark_schema_payload()
        payload["laterality"][0]["label"] = 99

        with self.assertRaisesRegex(ValueError, "não está definida"):
            parse_landmark_schema(payload)

    def test_schema_requires_an_explicit_laterality_midline(self) -> None:
        payload = synthetic_landmark_schema_payload()
        del payload["laterality"][0]["midline_mm"]

        with self.assertRaisesRegex(ValueError, "midline_mm"):
            parse_landmark_schema(payload)

    def test_schema_requires_an_explicit_laterality_tolerance(self) -> None:
        payload = synthetic_landmark_schema_payload()
        del payload["laterality"][0]["tolerance_mm"]

        with self.assertRaisesRegex(ValueError, "tolerance_mm"):
            parse_landmark_schema(payload)

    def test_source_format_cannot_be_used_as_free_text(self) -> None:
        volume = generate_synthetic_case()
        schema = parse_landmark_schema(synthetic_landmark_schema_payload())

        with self.assertRaisesRegex(ValueError, "source_format"):
            analyse_landmark_volume(
                volume,
                schema,
                source_format="identifier-entered-here",
            )


class BasilarPipelineTests(unittest.TestCase):
    def test_automatic_mode_requires_explicit_acceptance(self) -> None:
        volume = generate_synthetic_case()

        with self.assertRaisesRegex(ValueError, "confirme explicitamente"):
            analyse_basilar_volume(
                volume,
                source_format="npz",
                label=SYNTHETIC_BASILAR_LABEL,
            )

    def test_automatic_mode_does_not_treat_case_id_as_proof(self) -> None:
        source = generate_synthetic_case()
        volume = Volume3D(
            source.data_zyx,
            source.geometry,
            case_id="authorized-but-not-synthetic",
        )

        result = analyse_basilar_volume(
            volume,
            source_format="npz",
            label=SYNTHETIC_BASILAR_LABEL,
            allow_automatic_exploratory=True,
            section_stride=5,
        )

        self.assertNotIn(volume.case_id, str(result))
        self.assertFalse(
            result["configuration"]["synthetic_origin_verified_by_software"]
        )
        self.assertTrue(result["configuration"]["automatic_mode_acknowledged_by_user"])
        self.assertIn(
            "synthetic_origin_not_verified_by_software",
            result["results"]["quality_warnings"],
        )
        self.assertIn(
            "automatic_endpoint_selection_is_exploratory",
            result["results"]["quality_warnings"],
        )

    def test_synthetic_case_produces_structured_sections(self) -> None:
        volume = generate_synthetic_case()

        result = analyse_basilar_volume(
            volume,
            source_format="npz",
            label=SYNTHETIC_BASILAR_LABEL,
            allow_automatic_exploratory=True,
            section_stride=4,
        )

        self.assertEqual(result["analysis_type"], "basilar_cross_sections")
        self.assertTrue(result["results"]["centerline"]["automatic_endpoints"])
        self.assertGreater(result["results"]["section_count"], 2)
        self.assertEqual(
            result["results"]["valid_section_count"],
            result["results"]["section_count"],
        )
        self.assertNotIn("synthetic-public-example", str(result))
        self.assertNotIn("source_path", str(result["results"]))

    def test_physical_anchors_respect_origin_and_rotation(self) -> None:
        source = generate_synthetic_case()
        direction = np.asarray(
            (
                (0.0, -1.0, 0.0),
                (1.0, 0.0, 0.0),
                (0.0, 0.0, 1.0),
            )
        )
        geometry = ImageGeometry(
            shape_zyx=source.geometry.shape_zyx,
            spacing_zyx=source.geometry.spacing_zyx,
            origin_xyz_mm=(13.0, -17.0, 29.0),
            direction_xyz=direction,
        )
        volume = Volume3D(source.data_zyx, geometry, case_id="authorized-test")
        start_anchor = geometry.index_zyx_to_physical_xyz((12.2, 39.1, 27.1))
        end_anchor = geometry.index_zyx_to_physical_xyz((30.8, 44.9, 36.9))

        result = analyse_basilar_volume(
            volume,
            source_format="npz",
            label=SYNTHETIC_BASILAR_LABEL,
            start_anchor_xyz_mm=start_anchor,
            end_anchor_xyz_mm=end_anchor,
            maximum_anchor_distance_mm=2.0,
            section_stride=5,
        )

        anchors = result["configuration"]["anchors"]
        self.assertLessEqual(anchors["start"]["snapping_distance_mm"], 2.0)
        self.assertLessEqual(anchors["end"]["snapping_distance_mm"], 2.0)
        self.assertFalse(result["results"]["centerline"]["automatic_endpoints"])

    def test_curved_tube_recovers_stable_sections_and_plausible_geometry(
        self,
    ) -> None:
        (
            volume,
            start_anchor_xyz_mm,
            end_anchor_xyz_mm,
            radius_mm,
            expected_length_mm,
        ) = _curved_basilar_case()

        result = analyse_basilar_volume(
            volume,
            source_format="npz",
            label=SYNTHETIC_BASILAR_LABEL,
            start_anchor_xyz_mm=start_anchor_xyz_mm,
            end_anchor_xyz_mm=end_anchor_xyz_mm,
            maximum_anchor_distance_mm=2.0,
            sampling_mm=0.3,
            half_extent_mm=5.5,
            section_stride=4,
            endpoint_margin=4,
            tangent_window=3,
        )

        analysis = result["results"]
        self.assertEqual(
            result["configuration"]["endpoint_selection"], "physical_anchors"
        )
        self.assertFalse(analysis["centerline"]["automatic_endpoints"])
        self.assertGreaterEqual(analysis["section_count"], 10)
        self.assertEqual(analysis["valid_section_count"], analysis["section_count"])
        self.assertEqual(analysis["quality_warnings"], [])

        diameters_mm = np.asarray(
            [
                section["metrics"]["equivalent_diameter_mm"]
                for section in analysis["sections"]
            ]
        )
        expected_diameter_mm = 2.0 * radius_mm
        self.assertAlmostEqual(
            float(np.median(diameters_mm)),
            expected_diameter_mm,
            delta=0.12 * expected_diameter_mm,
        )
        self.assertLess(float(np.std(diameters_mm) / np.mean(diameters_mm)), 0.08)

        recovered_length_mm = analysis["centerline"]["length_mm"]
        self.assertAlmostEqual(
            recovered_length_mm,
            expected_length_mm,
            delta=0.15 * expected_length_mm,
        )

        anchors = result["configuration"]["anchors"]
        snapped_start = np.asarray(anchors["start"]["snapped_point_xyz_mm"])
        snapped_end = np.asarray(anchors["end"]["snapped_point_xyz_mm"])
        recovered_chord_mm = float(np.linalg.norm(snapped_end - snapped_start))
        recovered_tortuosity = recovered_length_mm / recovered_chord_mm
        expected_chord_mm = float(
            np.linalg.norm(end_anchor_xyz_mm - start_anchor_xyz_mm)
        )
        expected_tortuosity = expected_length_mm / expected_chord_mm
        self.assertGreater(recovered_tortuosity, 1.1)
        self.assertAlmostEqual(
            recovered_tortuosity,
            expected_tortuosity,
            delta=0.20 * expected_tortuosity,
        )

    def test_rejects_distant_or_collapsed_physical_anchors(self) -> None:
        volume = generate_synthetic_case()
        distant = volume.geometry.index_zyx_to_physical_xyz((0, 0, 0))
        near = volume.geometry.index_zyx_to_physical_xyz((22, 42, 32))

        with self.assertRaisesRegex(ValueError, "acima do limite"):
            analyse_basilar_volume(
                volume,
                source_format="npz",
                label=SYNTHETIC_BASILAR_LABEL,
                start_anchor_xyz_mm=distant,
                end_anchor_xyz_mm=near,
                maximum_anchor_distance_mm=1.0,
            )

        with self.assertRaisesRegex(ValueError, "mesmo nó"):
            analyse_basilar_volume(
                volume,
                source_format="npz",
                label=SYNTHETIC_BASILAR_LABEL,
                start_anchor_xyz_mm=near,
                end_anchor_xyz_mm=near,
                maximum_anchor_distance_mm=2.0,
            )

    def test_high_anisotropy_requires_an_explicit_override(self) -> None:
        source = generate_synthetic_case()
        geometry = ImageGeometry(
            shape_zyx=source.geometry.shape_zyx,
            spacing_zyx=(2.4, 0.8, 0.6),
            origin_xyz_mm=source.geometry.origin_xyz_mm,
            direction_xyz=source.geometry.direction_xyz,
        )
        volume = Volume3D(source.data_zyx, geometry, source.case_id)

        with self.assertRaisesRegex(ValueError, "anisotropia"):
            analyse_basilar_volume(
                volume,
                source_format="npz",
                label=SYNTHETIC_BASILAR_LABEL,
                allow_automatic_exploratory=True,
            )

        result = analyse_basilar_volume(
            volume,
            source_format="npz",
            label=SYNTHETIC_BASILAR_LABEL,
            allow_automatic_exploratory=True,
            allow_high_anisotropy=True,
            section_stride=5,
        )
        self.assertTrue(result["configuration"]["high_anisotropy_override"])
        self.assertIn(
            "voxel_anisotropy_above_configured_limit",
            result["results"]["quality_warnings"],
        )


if __name__ == "__main__":
    unittest.main()
