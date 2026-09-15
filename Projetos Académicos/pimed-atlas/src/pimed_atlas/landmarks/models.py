"""Structured results for landmark and surface-contact analysis.

The public reconstruction intentionally keeps anatomical names outside the
algorithms.  Labels only acquire a meaning through an explicit ``LabelSpec``
provided by the caller.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

Point3D = tuple[float, float, float]
Index3D = tuple[float, float, float]
Side = Literal["left", "right", "indeterminate"]


@dataclass(frozen=True)
class AnalysisWarning:
    """A non-fatal condition that may affect interpretation of a result."""

    code: str
    message: str
    label: int | None = None
    component_ids: tuple[int, ...] = ()


@dataclass(frozen=True)
class LabelSpec:
    """Caller-supplied semantics and validation rules for one numeric label."""

    value: int
    name: str
    expected_components: int | None = None
    min_voxels: int = 1

    def __post_init__(self) -> None:
        if isinstance(self.value, bool) or not isinstance(self.value, int):
            raise TypeError("label value must be an integer")
        if not isinstance(self.name, str) or not self.name.strip():
            raise ValueError("label name must not be empty")
        if self.expected_components is not None and (
            isinstance(self.expected_components, bool)
            or not isinstance(self.expected_components, int)
            or self.expected_components < 0
        ):
            raise ValueError("expected_components must be a non-negative integer")
        if (
            isinstance(self.min_voxels, bool)
            or not isinstance(self.min_voxels, int)
            or self.min_voxels < 1
        ):
            raise ValueError("min_voxels must be an integer of at least 1")


@dataclass(frozen=True)
class LandmarkComponent:
    """One 26-connected component of a configured label."""

    label: int
    label_name: str
    component_id: int
    voxel_count: int
    centroid_index_zyx: Index3D
    centroid_physical_xyz_mm: Point3D
    bbox_min_index_zyx: tuple[int, int, int]
    bbox_max_index_zyx: tuple[int, int, int]


@dataclass(frozen=True)
class LabelAnalysis:
    """Connected components and warnings for one configured label."""

    spec: LabelSpec
    components: tuple[LandmarkComponent, ...]
    ignored_component_sizes: tuple[int, ...] = ()
    warnings: tuple[AnalysisWarning, ...] = ()


@dataclass(frozen=True)
class LandmarkAnalysis:
    """Results for all labels requested in a schema."""

    labels: tuple[LabelAnalysis, ...]
    warnings: tuple[AnalysisWarning, ...] = ()

    def for_label(self, value: int) -> LabelAnalysis:
        """Return the result for ``value`` or raise a precise lookup error."""

        for result in self.labels:
            if result.spec.value == value:
                return result
        raise KeyError(f"label {value} was not part of this analysis")


@dataclass(frozen=True)
class LateralityAssignment:
    """A side assigned under a caller-provided coordinate convention."""

    label: int
    component_id: int
    side: Side
    signed_offset_from_midline_mm: float


@dataclass(frozen=True)
class LateralityResult:
    """Assignments plus the explicit convention used to create them."""

    coordinate_system: str
    axis: Literal["x", "y", "z"]
    positive_side: Literal["left", "right"]
    midline_mm: float
    tolerance_mm: float
    assignments: tuple[LateralityAssignment, ...]
    warnings: tuple[AnalysisWarning, ...] = ()


@dataclass(frozen=True)
class ComponentSurfacePair:
    """Minimum proximity between two surface-voxel centre sets.

    This is a resolution-dependent discrete measurement, not the distance
    between continuous reconstructed surfaces and not a contact area.
    """

    source_label: int
    source_component_id: int
    target_label: int
    target_component_id: int
    source_surface_voxels: int
    target_surface_voxels: int
    minimum_distance_mm: float
    closest_source_point_xyz_mm: Point3D
    closest_target_point_xyz_mm: Point3D
    pairs_within_threshold: int
    within_threshold: bool


@dataclass(frozen=True)
class ContactAnalysis:
    """All evaluated component pairs for two labels.

    Distances are Euclidean distances between surface voxel centres in physical
    space. Adjacent voxels therefore remain one voxel spacing apart. ``contacts``
    filters the evaluated pairs using the explicit threshold supplied by the
    caller; it does not prove continuous-surface contact.
    """

    source_label: int
    target_label: int
    threshold_mm: float
    distance_definition: str
    pairs: tuple[ComponentSurfacePair, ...]
    warnings: tuple[AnalysisWarning, ...] = ()

    @property
    def contacts(self) -> tuple[ComponentSurfacePair, ...]:
        return tuple(pair for pair in self.pairs if pair.within_threshold)
