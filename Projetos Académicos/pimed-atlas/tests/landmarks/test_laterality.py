import unittest

from pimed_atlas.landmarks import (
    LandmarkComponent,
    LateralityConvention,
    assign_laterality,
)


def component(component_id: int, x_mm: float) -> LandmarkComponent:
    return LandmarkComponent(
        label=12,
        label_name="configured-paired-structure",
        component_id=component_id,
        voxel_count=3,
        centroid_index_zyx=(0.0, 0.0, 0.0),
        centroid_physical_xyz_mm=(x_mm, 0.0, 0.0),
        bbox_min_index_zyx=(0, 0, 0),
        bbox_max_index_zyx=(0, 0, 0),
    )


class LateralityTests(unittest.TestCase):
    def test_assigns_sides_only_under_explicit_semantics(self) -> None:
        result = assign_laterality(
            [component(1, -2.0), component(2, 3.0), component(3, 0.1)],
            LateralityConvention(
                coordinate_system="declared-LPS",
                axis="x",
                positive_side="left",
                midline_mm=0.0,
                tolerance_mm=0.2,
            ),
            require_bilateral=True,
        )

        self.assertEqual(
            [assignment.side for assignment in result.assignments],
            ["right", "left", "indeterminate"],
        )
        self.assertEqual(
            [warning.code for warning in result.warnings],
            ["laterality_within_midline_tolerance"],
        )
        self.assertEqual(result.coordinate_system, "declared-LPS")
        self.assertEqual(result.positive_side, "left")

    def test_warns_instead_of_inventing_a_missing_bilateral_component(self) -> None:
        result = assign_laterality(
            [component(1, 2.0), component(2, 4.0)],
            LateralityConvention(
                "caller-defined",
                "x",
                "right",
                midline_mm=0.0,
                tolerance_mm=0.0,
            ),
            require_bilateral=True,
        )

        self.assertEqual(
            [warning.code for warning in result.warnings],
            ["missing_lateral_side", "multiple_components_on_side"],
        )

    def test_rejects_an_unnamed_coordinate_system(self) -> None:
        with self.assertRaisesRegex(ValueError, "coordinate_system"):
            LateralityConvention("", "x", "left", midline_mm=0.0, tolerance_mm=0.0)

    def test_result_preserves_the_complete_numeric_convention(self) -> None:
        result = assign_laterality(
            [component(1, 2.0)],
            LateralityConvention(
                "declared", "x", "left", midline_mm=1.0, tolerance_mm=0.25
            ),
        )

        self.assertEqual(result.midline_mm, 1.0)
        self.assertEqual(result.tolerance_mm, 0.25)

    def test_rejects_boolean_numeric_parameters(self) -> None:
        with self.assertRaisesRegex(ValueError, "midline_mm"):
            LateralityConvention(
                "declared", "x", "left", midline_mm=True, tolerance_mm=0.0
            )


if __name__ == "__main__":
    unittest.main()
