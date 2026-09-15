from __future__ import annotations

import unittest

import numpy as np

from pimed_atlas.basilar import (
    CrossSection,
    measure_section,
    sample_cross_section,
    signed_distance_field,
)


def synthetic_tube(
    shape: tuple[int, int, int],
    spacing_zyx: tuple[float, float, float],
    center_zyx: tuple[float, float, float],
    direction_mm_zyx: tuple[float, float, float],
    radius_mm: float,
    half_length_mm: float,
) -> np.ndarray:
    indices = np.indices(shape, dtype=float)
    points_mm = np.moveaxis(indices, 0, -1) * np.asarray(spacing_zyx)
    center_mm = np.asarray(center_zyx) * np.asarray(spacing_zyx)
    relative = points_mm - center_mm
    direction = np.asarray(direction_mm_zyx, dtype=float)
    direction /= np.linalg.norm(direction)
    axial = np.einsum("...i,i->...", relative, direction)
    radial = relative - axial[..., np.newaxis] * direction
    radial_distance = np.linalg.norm(radial, axis=-1)
    return (np.abs(axial) <= half_length_mm) & (radial_distance <= radius_mm)


class SignedDistanceTests(unittest.TestCase):
    def test_field_is_in_physical_units_and_inside_positive(self) -> None:
        mask = np.zeros((9, 9, 9), dtype=bool)
        mask[2:7, 2:7, 2:7] = True
        field = signed_distance_field(mask, spacing_zyx=(2.0, 1.0, 0.5))

        self.assertGreater(field[4, 4, 4], 0.0)
        self.assertLess(field[0, 0, 0], 0.0)
        self.assertAlmostEqual(field[4, 4, 4], 1.5)

    def test_rejects_a_mask_truncated_by_the_volume_border(self) -> None:
        mask = np.zeros((7, 7, 7), dtype=bool)
        mask[0:3, 2:5, 2:5] = True

        with self.assertRaisesRegex(ValueError, "border"):
            signed_distance_field(mask, spacing_zyx=(1.0, 1.0, 1.0))


class SectionMetricTests(unittest.TestCase):
    def assert_circular_metrics(self, metrics, radius_mm: float) -> None:
        expected_area = np.pi * radius_mm**2
        expected_diameter = 2.0 * radius_mm
        self.assertTrue(metrics.valid)
        self.assertFalse(metrics.touches_sampling_border)
        self.assertAlmostEqual(
            metrics.area_mm2, expected_area, delta=expected_area * 0.12
        )
        self.assertAlmostEqual(
            metrics.equivalent_diameter_mm,
            expected_diameter,
            delta=0.5,
        )
        self.assertAlmostEqual(metrics.feret_max_mm, expected_diameter, delta=0.8)
        self.assertAlmostEqual(
            metrics.moment_major_axis_mm, expected_diameter, delta=0.7
        )
        self.assertAlmostEqual(
            metrics.moment_minor_axis_mm, expected_diameter, delta=0.7
        )

    def test_straight_tube_with_anisotropic_voxels(self) -> None:
        spacing = (2.0, 0.6, 0.4)
        center = (12.0, 30.0, 40.0)
        radius = 4.0
        mask = synthetic_tube(
            shape=(25, 61, 81),
            spacing_zyx=spacing,
            center_zyx=center,
            direction_mm_zyx=(1.0, 0.0, 0.0),
            radius_mm=radius,
            half_length_mm=18.0,
        )
        field = signed_distance_field(mask, spacing)
        section = sample_cross_section(
            field,
            spacing,
            center_zyx=center,
            normal_mm_zyx=(1.0, 0.0, 0.0),
            sampling_mm=0.2,
            half_extent_mm=6.0,
        )

        self.assert_circular_metrics(measure_section(section), radius)

    def test_ellipse_recovers_distinct_moment_axes(self) -> None:
        sampling = 0.1
        coordinates = np.arange(-6.0, 6.0 + sampling / 2.0, sampling)
        u_grid, v_grid = np.meshgrid(coordinates, coordinates, indexing="xy")
        mask = (u_grid / 4.0) ** 2 + (v_grid / 2.0) ** 2 <= 1.0
        section = CrossSection(
            signed_distance_mm=np.where(mask, 1.0, -1.0),
            mask=mask,
            u_mm=coordinates,
            v_mm=coordinates,
            sampling_mm=sampling,
            center_zyx=(0.0, 0.0, 0.0),
            normal_mm_zyx=(1.0, 0.0, 0.0),
            basis_u_mm_zyx=(0.0, 1.0, 0.0),
            basis_v_mm_zyx=(0.0, 0.0, 1.0),
        )

        metrics = measure_section(section)

        self.assertAlmostEqual(metrics.area_mm2, 8.0 * np.pi, delta=0.35)
        self.assertAlmostEqual(
            metrics.equivalent_diameter_mm, 2.0 * np.sqrt(8.0), delta=0.08
        )
        self.assertAlmostEqual(metrics.feret_max_mm, 8.0, delta=0.2)
        self.assertAlmostEqual(metrics.moment_major_axis_mm, 8.0, delta=0.15)
        self.assertAlmostEqual(metrics.moment_minor_axis_mm, 4.0, delta=0.15)

    def test_quality_rejects_tiny_or_multi_component_sections(self) -> None:
        coordinates = np.arange(-2.0, 2.5, 0.5)
        mask = np.zeros((len(coordinates), len(coordinates)), dtype=bool)
        mask[4, 4] = True
        section = CrossSection(
            signed_distance_mm=np.where(mask, 1.0, -1.0),
            mask=mask,
            u_mm=coordinates,
            v_mm=coordinates,
            sampling_mm=0.5,
            center_zyx=(0.0, 0.0, 0.0),
            normal_mm_zyx=(1.0, 0.0, 0.0),
            basis_u_mm_zyx=(0.0, 1.0, 0.0),
            basis_v_mm_zyx=(0.0, 0.0, 1.0),
            foreground_component_count=2,
        )

        metrics = measure_section(section)

        self.assertFalse(metrics.valid)
        self.assertEqual(
            set(metrics.invalid_reasons),
            {"too_few_pixels", "multiple_foreground_components"},
        )

    def test_measurement_rejects_non_uniform_axes(self) -> None:
        mask = np.ones((3, 3), dtype=bool)
        section = CrossSection(
            signed_distance_mm=np.ones((3, 3)),
            mask=mask,
            u_mm=np.asarray((-1.0, 0.0, 1.5)),
            v_mm=np.asarray((-1.0, 0.0, 1.0)),
            sampling_mm=1.0,
            center_zyx=(0.0, 0.0, 0.0),
            normal_mm_zyx=(1.0, 0.0, 0.0),
            basis_u_mm_zyx=(0.0, 1.0, 0.0),
            basis_v_mm_zyx=(0.0, 0.0, 1.0),
        )

        with self.assertRaisesRegex(ValueError, "uniform"):
            measure_section(section)

    def test_inclined_tube_uses_an_orthogonal_physical_plane(self) -> None:
        spacing = (1.4, 0.7, 0.5)
        center = (25.0, 36.0, 44.0)
        direction = (1.0, 0.35, 0.8)
        radius = 3.5
        mask = synthetic_tube(
            shape=(51, 73, 89),
            spacing_zyx=spacing,
            center_zyx=center,
            direction_mm_zyx=direction,
            radius_mm=radius,
            half_length_mm=25.0,
        )
        field = signed_distance_field(mask, spacing)
        section = sample_cross_section(
            field,
            spacing,
            center_zyx=center,
            normal_mm_zyx=direction,
            sampling_mm=0.2,
            half_extent_mm=5.5,
        )

        metrics = measure_section(section)
        self.assert_circular_metrics(metrics, radius)
        self.assertAlmostEqual(metrics.centroid_uv_mm[0], 0.0, delta=0.25)
        self.assertAlmostEqual(metrics.centroid_uv_mm[1], 0.0, delta=0.25)

    def test_sampling_rejects_a_centre_outside_the_object(self) -> None:
        mask = np.zeros((11, 11, 11), dtype=bool)
        mask[4:7, 4:7, 4:7] = True
        field = signed_distance_field(mask, (1.0, 1.0, 1.0))

        with self.assertRaisesRegex(ValueError, "centre"):
            sample_cross_section(
                field,
                spacing_zyx=(1.0, 1.0, 1.0),
                center_zyx=(1.0, 1.0, 1.0),
                normal_mm_zyx=(1.0, 0.0, 0.0),
                sampling_mm=0.5,
                half_extent_mm=3.0,
            )


if __name__ == "__main__":
    unittest.main()
