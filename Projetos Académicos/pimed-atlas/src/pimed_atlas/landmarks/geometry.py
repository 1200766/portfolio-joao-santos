"""Small, defensive geometry functions used by the landmark workflow."""

from __future__ import annotations

from typing import Literal

import numpy as np
from numpy.typing import ArrayLike


def distance_mm(first_xyz_mm: ArrayLike, second_xyz_mm: ArrayLike) -> float:
    """Return finite Euclidean distance between two physical 3D points."""

    first = _vector3(first_xyz_mm, "first_xyz_mm")
    second = _vector3(second_xyz_mm, "second_xyz_mm")
    return float(np.linalg.norm(second - first))


def axis_separation_mm(
    first_xyz_mm: ArrayLike,
    second_xyz_mm: ArrayLike,
    axis: Literal["x", "y", "z"],
) -> float:
    """Return absolute separation along a caller-selected physical axis."""

    if axis not in ("x", "y", "z"):
        raise ValueError("axis must be one of: x, y, z")
    first = _vector3(first_xyz_mm, "first_xyz_mm")
    second = _vector3(second_xyz_mm, "second_xyz_mm")
    axis_index = ("x", "y", "z").index(axis)
    return float(abs(second[axis_index] - first[axis_index]))


def angle_between_vectors_degrees(first: ArrayLike, second: ArrayLike) -> float:
    """Return the smaller angle in degrees and reject undefined zero vectors."""

    first_vector = _vector3(first, "first")
    second_vector = _vector3(second, "second")
    first_norm = float(np.linalg.norm(first_vector))
    second_norm = float(np.linalg.norm(second_vector))
    if first_norm <= np.finfo(float).eps or second_norm <= np.finfo(float).eps:
        raise ValueError("angle is undefined for a zero-length vector")
    cosine = float(np.dot(first_vector, second_vector) / (first_norm * second_norm))
    return float(np.degrees(np.arccos(np.clip(cosine, -1.0, 1.0))))


def angle_at_point_degrees(
    first_xyz_mm: ArrayLike,
    vertex_xyz_mm: ArrayLike,
    second_xyz_mm: ArrayLike,
) -> float:
    """Return the angle ``first -> vertex -> second`` in physical space."""

    first = _vector3(first_xyz_mm, "first_xyz_mm")
    vertex = _vector3(vertex_xyz_mm, "vertex_xyz_mm")
    second = _vector3(second_xyz_mm, "second_xyz_mm")
    return angle_between_vectors_degrees(first - vertex, second - vertex)


def _vector3(values: ArrayLike, name: str) -> np.ndarray:
    vector = np.asarray(values, dtype=float)
    if vector.shape != (3,):
        raise ValueError(f"{name} must contain exactly three coordinates")
    if not np.all(np.isfinite(vector)):
        raise ValueError(f"{name} must contain only finite coordinates")
    return vector
