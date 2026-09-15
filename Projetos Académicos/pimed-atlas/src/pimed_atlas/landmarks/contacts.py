"""Physical surface-distance analysis between labelled components."""

from __future__ import annotations

from itertools import combinations, product

import numpy as np
from numpy.typing import ArrayLike, NDArray
from scipy import ndimage
from scipy.spatial import cKDTree

from pimed_atlas.core import ImageGeometry

from .components import (
    _component_indices,
    _validate_geometry_shape,
    _validate_label_volume,
)
from .models import AnalysisWarning, ComponentSurfacePair, ContactAnalysis

_SURFACE_NEIGHBOURHOOD_26 = np.ones((3, 3, 3), dtype=bool)
_DISTANCE_DEFINITION = "euclidean_distance_between_surface_voxel_centres"


def analyse_surface_contacts(
    labels_zyx: ArrayLike,
    geometry: ImageGeometry,
    source_label: int,
    target_label: int,
    *,
    threshold_mm: float,
    source_min_voxels: int = 1,
    target_min_voxels: int = 1,
) -> ContactAnalysis:
    """Measure every relevant pair of 26-connected labelled components.

    A pair is a contact when the minimum Euclidean distance between its surface
    voxel centres is no greater than ``threshold_mm``.  The threshold therefore
    has an explicit physical meaning and should be selected for the image
    resolution and the intended experiment.
    """

    volume = _validate_label_volume(labels_zyx)
    _validate_geometry_shape(volume, geometry)
    _validate_label(source_label, "source_label")
    _validate_label(target_label, "target_label")
    _validate_min_voxels(source_min_voxels, "source_min_voxels")
    _validate_min_voxels(target_min_voxels, "target_min_voxels")
    if (
        isinstance(threshold_mm, bool)
        or not isinstance(threshold_mm, (int, float, np.integer, np.floating))
        or not np.isfinite(threshold_mm)
        or threshold_mm < 0.0
    ):
        raise ValueError("threshold_mm must be finite and non-negative")
    if source_label == target_label and source_min_voxels != target_min_voxels:
        raise ValueError(
            "source_min_voxels and target_min_voxels must match when both labels "
            "are the same"
        )

    source_components, source_ignored = _component_indices(
        volume, source_label, source_min_voxels
    )
    if source_label == target_label:
        target_components = source_components
        target_ignored = source_ignored
        component_pairs = combinations(enumerate(source_components, start=1), 2)
    else:
        target_components, target_ignored = _component_indices(
            volume, target_label, target_min_voxels
        )
        component_pairs = product(
            enumerate(source_components, start=1),
            enumerate(target_components, start=1),
        )

    warnings: list[AnalysisWarning] = []
    if not source_components:
        warnings.append(
            AnalysisWarning(
                code=(
                    "contact_source_no_component_above_minimum_size"
                    if source_ignored
                    else "contact_source_label_absent"
                ),
                message=(
                    f"No component of source label {source_label} met the minimum size."
                    if source_ignored
                    else f"Source label {source_label} is absent."
                ),
                label=source_label,
            )
        )
    if source_label != target_label and not target_components:
        warnings.append(
            AnalysisWarning(
                code=(
                    "contact_target_no_component_above_minimum_size"
                    if target_ignored
                    else "contact_target_label_absent"
                ),
                message=(
                    f"No component of target label {target_label} met the minimum size."
                    if target_ignored
                    else f"Target label {target_label} is absent."
                ),
                label=target_label,
            )
        )
    if source_label == target_label and len(source_components) == 1:
        warnings.append(
            AnalysisWarning(
                code="insufficient_components_for_same_label_comparison",
                message=(
                    f"Label {source_label} has only one eligible component; "
                    "at least two are required for a within-label comparison."
                ),
                label=source_label,
            )
        )
    if source_ignored:
        warnings.append(
            AnalysisWarning(
                code="contact_source_components_ignored",
                message=(
                    f"Ignored {len(source_ignored)} source component(s) below "
                    f"{source_min_voxels} voxels."
                ),
                label=source_label,
            )
        )
    if target_ignored and source_label != target_label:
        warnings.append(
            AnalysisWarning(
                code="contact_target_components_ignored",
                message=(
                    f"Ignored {len(target_ignored)} target component(s) below "
                    f"{target_min_voxels} voxels."
                ),
                label=target_label,
            )
        )

    evaluated: list[ComponentSurfacePair] = []
    for (source_id, source_indices), (target_id, target_indices) in component_pairs:
        source_surface = _surface_indices(source_indices)
        target_surface = _surface_indices(target_indices)
        source_physical = geometry.index_zyx_to_physical_xyz(source_surface)
        target_physical = geometry.index_zyx_to_physical_xyz(target_surface)
        evaluated.append(
            _measure_pair(
                source_label=source_label,
                source_id=source_id,
                source_points=source_physical,
                target_label=target_label,
                target_id=target_id,
                target_points=target_physical,
                threshold_mm=float(threshold_mm),
            )
        )

    if evaluated and not any(pair.within_threshold for pair in evaluated):
        warnings.append(
            AnalysisWarning(
                code="no_surface_contacts_within_threshold",
                message=(
                    "All component pairs were farther apart than the configured "
                    f"threshold of {threshold_mm:g} mm."
                ),
            )
        )

    return ContactAnalysis(
        source_label=source_label,
        target_label=target_label,
        threshold_mm=float(threshold_mm),
        distance_definition=_DISTANCE_DEFINITION,
        pairs=tuple(evaluated),
        warnings=tuple(warnings),
    )


def _surface_indices(indices: NDArray[np.int64]) -> NDArray[np.int64]:
    """Return 26-neighbourhood boundary voxels without allocating full volume."""

    minimum = indices.min(axis=0)
    maximum = indices.max(axis=0)
    shape = maximum - minimum + 3
    local_mask = np.zeros(tuple(int(value) for value in shape), dtype=bool)
    local_indices = indices - minimum + 1
    local_mask[tuple(local_indices.T)] = True
    interior = ndimage.binary_erosion(
        local_mask,
        structure=_SURFACE_NEIGHBOURHOOD_26,
        border_value=0,
    )
    surface_local = np.argwhere(local_mask & ~interior)
    return (surface_local + minimum - 1).astype(np.int64, copy=False)


def _measure_pair(
    *,
    source_label: int,
    source_id: int,
    source_points: NDArray[np.float64],
    target_label: int,
    target_id: int,
    target_points: NDArray[np.float64],
    threshold_mm: float,
) -> ComponentSurfacePair:
    target_tree = cKDTree(target_points)
    nearest_distances, nearest_indices = target_tree.query(source_points, k=1)
    source_index = int(np.argmin(nearest_distances))
    target_index = int(nearest_indices[source_index])
    minimum_distance = float(nearest_distances[source_index])
    pair_count = int(cKDTree(source_points).count_neighbors(target_tree, threshold_mm))

    return ComponentSurfacePair(
        source_label=source_label,
        source_component_id=source_id,
        target_label=target_label,
        target_component_id=target_id,
        source_surface_voxels=int(source_points.shape[0]),
        target_surface_voxels=int(target_points.shape[0]),
        minimum_distance_mm=minimum_distance,
        closest_source_point_xyz_mm=_point_tuple(source_points[source_index]),
        closest_target_point_xyz_mm=_point_tuple(target_points[target_index]),
        pairs_within_threshold=pair_count,
        within_threshold=minimum_distance <= threshold_mm + 1e-12,
    )


def _validate_label(value: int, name: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{name} must be an integer")


def _validate_min_voxels(value: int, name: str) -> None:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ValueError(f"{name} must be an integer greater than or equal to 1")


def _point_tuple(values: NDArray[np.float64]) -> tuple[float, float, float]:
    return (float(values[0]), float(values[1]), float(values[2]))
