"""Landmark extraction from explicitly configured labels."""

from __future__ import annotations

from collections.abc import Iterable

import numpy as np
from numpy.typing import ArrayLike, NDArray
from scipy import ndimage

from pimed_atlas.core import ImageGeometry

from .models import (
    AnalysisWarning,
    LabelAnalysis,
    LabelSpec,
    LandmarkAnalysis,
    LandmarkComponent,
)

_STRUCTURE_26 = np.ones((3, 3, 3), dtype=bool)


def analyse_landmarks(
    labels_zyx: ArrayLike,
    geometry: ImageGeometry,
    schema: Iterable[LabelSpec],
) -> LandmarkAnalysis:
    """Extract 26-connected components for every label in ``schema``.

    No numeric label receives an anatomical interpretation implicitly.  The
    caller must provide the label value, public name and optional expected
    component count through ``LabelSpec``.
    """

    volume = _validate_label_volume(labels_zyx)
    _validate_geometry_shape(volume, geometry)
    specs = tuple(schema)
    if not specs:
        raise ValueError("schema must contain at least one LabelSpec")
    values = [spec.value for spec in specs]
    if len(values) != len(set(values)):
        raise ValueError("schema contains duplicate label values")

    results = tuple(_analyse_label(volume, geometry, spec) for spec in specs)
    warnings = tuple(warning for result in results for warning in result.warnings)
    return LandmarkAnalysis(labels=results, warnings=warnings)


def extract_label_components(
    labels_zyx: ArrayLike,
    geometry: ImageGeometry,
    spec: LabelSpec,
) -> LabelAnalysis:
    """Convenience wrapper for analysing one configured label."""

    volume = _validate_label_volume(labels_zyx)
    _validate_geometry_shape(volume, geometry)
    return _analyse_label(volume, geometry, spec)


def _analyse_label(
    volume: NDArray[np.generic],
    geometry: ImageGeometry,
    spec: LabelSpec,
) -> LabelAnalysis:
    kept, ignored_sizes = _component_indices(volume, spec.value, spec.min_voxels)
    components: list[LandmarkComponent] = []

    for component_id, indices in enumerate(kept, start=1):
        centroid_index = indices.mean(axis=0, dtype=float)
        centroid_physical = geometry.index_zyx_to_physical_xyz(centroid_index)
        minimum = indices.min(axis=0)
        maximum = indices.max(axis=0)
        components.append(
            LandmarkComponent(
                label=spec.value,
                label_name=spec.name,
                component_id=component_id,
                voxel_count=int(indices.shape[0]),
                centroid_index_zyx=_float_tuple(centroid_index),
                centroid_physical_xyz_mm=_float_tuple(centroid_physical),
                bbox_min_index_zyx=_int_tuple(minimum),
                bbox_max_index_zyx=_int_tuple(maximum),
            )
        )

    warnings: list[AnalysisWarning] = []
    if not kept and ignored_sizes:
        warnings.append(
            AnalysisWarning(
                code="no_component_above_minimum_size",
                message=(
                    f"Label {spec.value} ({spec.name}) is present, but no component "
                    f"contains at least {spec.min_voxels} voxels."
                ),
                label=spec.value,
            )
        )
    elif not kept:
        warnings.append(
            AnalysisWarning(
                code="label_absent",
                message=f"No component was found for label {spec.value} ({spec.name}).",
                label=spec.value,
            )
        )
    if ignored_sizes:
        warnings.append(
            AnalysisWarning(
                code="small_components_ignored",
                message=(
                    f"Ignored {len(ignored_sizes)} component(s) below the "
                    f"minimum size of {spec.min_voxels} voxels."
                ),
                label=spec.value,
            )
        )
    if (
        spec.expected_components is not None
        and len(components) != spec.expected_components
    ):
        warnings.append(
            AnalysisWarning(
                code="unexpected_component_count",
                message=(
                    f"Expected {spec.expected_components} component(s) for label "
                    f"{spec.value}, found {len(components)}."
                ),
                label=spec.value,
                component_ids=tuple(component.component_id for component in components),
            )
        )

    return LabelAnalysis(
        spec=spec,
        components=tuple(components),
        ignored_component_sizes=tuple(ignored_sizes),
        warnings=tuple(warnings),
    )


def _component_indices(
    volume: NDArray[np.generic], label_value: int, min_voxels: int
) -> tuple[list[NDArray[np.int64]], list[int]]:
    labelled, count = ndimage.label(volume == label_value, structure=_STRUCTURE_26)
    components: list[NDArray[np.int64]] = []
    for component_id, region in enumerate(ndimage.find_objects(labelled), start=1):
        if region is None:
            continue
        local = np.argwhere(labelled[region] == component_id)
        offset = np.asarray([axis.start for axis in region], dtype=np.int64)
        components.append((local + offset).astype(np.int64, copy=False))
    if len(components) != count:
        raise RuntimeError("connected-component enumeration was inconsistent")
    components.sort(key=_component_sort_key)
    kept = [indices for indices in components if indices.shape[0] >= min_voxels]
    ignored = sorted(
        (
            int(indices.shape[0])
            for indices in components
            if indices.shape[0] < min_voxels
        ),
        reverse=True,
    )
    return kept, ignored


def _component_sort_key(indices: NDArray[np.int64]) -> tuple[int, int, int, int]:
    minimum = indices.min(axis=0)
    return (-int(indices.shape[0]), int(minimum[0]), int(minimum[1]), int(minimum[2]))


def _validate_label_volume(labels_zyx: ArrayLike) -> NDArray[np.generic]:
    volume = np.asarray(labels_zyx)
    if volume.ndim != 3:
        raise ValueError("labels_zyx must be a three-dimensional NumPy-style volume")
    if volume.dtype.kind not in "biu":
        raise TypeError("labels_zyx must contain integer or boolean labels")
    return volume


def _validate_geometry_shape(
    volume: NDArray[np.generic], geometry: ImageGeometry
) -> None:
    if tuple(volume.shape) != tuple(geometry.shape_zyx):
        raise ValueError(
            "labels_zyx shape must match geometry.shape_zyx: "
            f"{tuple(volume.shape)} != {tuple(geometry.shape_zyx)}"
        )
    if not np.all(np.isfinite(np.asarray(geometry.spacing_zyx, dtype=float))):
        raise ValueError("geometry.spacing_zyx must contain only finite values")
    if not np.all(np.isfinite(np.asarray(geometry.origin_xyz_mm, dtype=float))):
        raise ValueError("geometry.origin_xyz_mm must contain only finite values")


def _float_tuple(values: ArrayLike) -> tuple[float, float, float]:
    array = np.asarray(values, dtype=float)
    return (float(array[0]), float(array[1]), float(array[2]))


def _int_tuple(values: ArrayLike) -> tuple[int, int, int]:
    array = np.asarray(values, dtype=int)
    return (int(array[0]), int(array[1]), int(array[2]))
