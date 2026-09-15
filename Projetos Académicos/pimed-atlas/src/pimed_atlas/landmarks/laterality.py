"""Explicit, convention-driven assignment of left and right."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import numpy as np

from .models import (
    AnalysisWarning,
    LandmarkComponent,
    LateralityAssignment,
    LateralityResult,
)

Axis = Literal["x", "y", "z"]
AnatomicalSide = Literal["left", "right"]
_AXIS_INDEX: dict[Axis, int] = {"x": 0, "y": 1, "z": 2}


@dataclass(frozen=True)
class LateralityConvention:
    """Semantics required before a coordinate may be called left or right.

    For example, an LPS image would normally use ``axis="x"`` and
    ``positive_side="left"``.  The implementation deliberately does not infer
    either value from the string ``coordinate_system``.
    """

    coordinate_system: str
    axis: Axis
    positive_side: AnatomicalSide
    midline_mm: float
    tolerance_mm: float

    def __post_init__(self) -> None:
        if (
            not isinstance(self.coordinate_system, str)
            or not self.coordinate_system.strip()
        ):
            raise ValueError("coordinate_system must be stated explicitly")
        if self.axis not in _AXIS_INDEX:
            raise ValueError("axis must be one of: x, y, z")
        if self.positive_side not in ("left", "right"):
            raise ValueError("positive_side must be either 'left' or 'right'")
        if (
            isinstance(self.midline_mm, bool)
            or not isinstance(self.midline_mm, (int, float, np.integer, np.floating))
            or not np.isfinite(self.midline_mm)
        ):
            raise ValueError("midline_mm must be finite")
        if (
            isinstance(self.tolerance_mm, bool)
            or not isinstance(self.tolerance_mm, (int, float, np.integer, np.floating))
            or not np.isfinite(self.tolerance_mm)
            or self.tolerance_mm < 0.0
        ):
            raise ValueError("tolerance_mm must be finite and non-negative")


def assign_laterality(
    components: tuple[LandmarkComponent, ...] | list[LandmarkComponent],
    convention: LateralityConvention,
    *,
    require_bilateral: bool = False,
) -> LateralityResult:
    """Assign sides without embedding a dataset-specific anatomical heuristic."""

    axis_index = _AXIS_INDEX[convention.axis]
    negative_side: AnatomicalSide = (
        "right" if convention.positive_side == "left" else "left"
    )
    assignments: list[LateralityAssignment] = []
    warnings: list[AnalysisWarning] = []

    for component in components:
        coordinate = component.centroid_physical_xyz_mm[axis_index]
        offset = float(coordinate - convention.midline_mm)
        if abs(offset) <= convention.tolerance_mm:
            side = "indeterminate"
            warnings.append(
                AnalysisWarning(
                    code="laterality_within_midline_tolerance",
                    message=(
                        f"Component {component.component_id} of label {component.label} "
                        "lies within the configured midline tolerance."
                    ),
                    label=component.label,
                    component_ids=(component.component_id,),
                )
            )
        elif offset > 0.0:
            side = convention.positive_side
        else:
            side = negative_side

        assignments.append(
            LateralityAssignment(
                label=component.label,
                component_id=component.component_id,
                side=side,
                signed_offset_from_midline_mm=offset,
            )
        )

    if require_bilateral:
        for expected_side in ("left", "right"):
            matches = [item for item in assignments if item.side == expected_side]
            if not matches:
                warnings.append(
                    AnalysisWarning(
                        code="missing_lateral_side",
                        message=f"No component was assigned to the {expected_side} side.",
                    )
                )
            elif len(matches) > 1:
                warnings.append(
                    AnalysisWarning(
                        code="multiple_components_on_side",
                        message=(
                            f"{len(matches)} components were assigned to the "
                            f"{expected_side} side."
                        ),
                        component_ids=tuple(item.component_id for item in matches),
                    )
                )

    return LateralityResult(
        coordinate_system=convention.coordinate_system,
        axis=convention.axis,
        positive_side=convention.positive_side,
        midline_mm=float(convention.midline_mm),
        tolerance_mm=float(convention.tolerance_mm),
        assignments=tuple(assignments),
        warnings=tuple(warnings),
    )
