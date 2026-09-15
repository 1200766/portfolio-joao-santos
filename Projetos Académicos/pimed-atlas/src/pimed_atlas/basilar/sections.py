"""Orthogonal cross-section sampling and two-dimensional vessel metrics."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass

import numpy as np
from scipy import ndimage
from scipy.spatial import ConvexHull, QhullError
from scipy.spatial.distance import pdist


@dataclass(frozen=True)
class CrossSection:
    """A signed-distance plane and its centre-connected foreground region."""

    signed_distance_mm: np.ndarray
    mask: np.ndarray
    u_mm: np.ndarray
    v_mm: np.ndarray
    sampling_mm: float
    center_zyx: tuple[float, float, float]
    normal_mm_zyx: tuple[float, float, float]
    basis_u_mm_zyx: tuple[float, float, float]
    basis_v_mm_zyx: tuple[float, float, float]
    foreground_component_count: int = 1


@dataclass(frozen=True)
class SectionMetrics:
    """Physical metrics for a rasterised vessel cross-section."""

    area_mm2: float
    equivalent_diameter_mm: float
    feret_max_mm: float
    moment_major_axis_mm: float
    moment_minor_axis_mm: float
    centroid_uv_mm: tuple[float, float]
    pixel_count: int
    touches_sampling_border: bool
    foreground_component_count: int
    center_to_centroid_mm: float
    invalid_reasons: tuple[str, ...]
    valid: bool


def _validate_spacing(spacing_zyx: Sequence[float]) -> np.ndarray:
    spacing = np.asarray(spacing_zyx, dtype=float)
    if spacing.shape != (3,):
        raise ValueError("spacing_zyx must contain exactly three values")
    if not np.all(np.isfinite(spacing)) or np.any(spacing <= 0):
        raise ValueError("spacing_zyx values must be finite and positive")
    return spacing


def signed_distance_field(
    mask: np.ndarray,
    spacing_zyx: Sequence[float],
) -> np.ndarray:
    """Return an inside-positive signed distance field in millimetres."""

    foreground = np.asarray(mask, dtype=bool)
    spacing = _validate_spacing(spacing_zyx)
    if foreground.ndim != 3:
        raise ValueError("mask must be a three-dimensional array")
    if not np.any(foreground):
        raise ValueError("mask contains no foreground voxels")
    if np.all(foreground):
        raise ValueError("mask must contain background around the object")
    if (
        np.any(foreground[0, :, :])
        or np.any(foreground[-1, :, :])
        or np.any(foreground[:, 0, :])
        or np.any(foreground[:, -1, :])
        or np.any(foreground[:, :, 0])
        or np.any(foreground[:, :, -1])
    ):
        raise ValueError(
            "mask touches the volume border; add background padding before "
            "computing the signed-distance field"
        )

    inside = ndimage.distance_transform_edt(foreground, sampling=spacing)
    outside = ndimage.distance_transform_edt(~foreground, sampling=spacing)
    return inside - outside


def _plane_basis(
    normal_mm_zyx: Sequence[float],
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    normal = np.asarray(normal_mm_zyx, dtype=float)
    if normal.shape != (3,) or not np.all(np.isfinite(normal)):
        raise ValueError("normal_mm_zyx must contain three finite values")
    norm = float(np.linalg.norm(normal))
    if norm == 0:
        raise ValueError("normal_mm_zyx cannot be the zero vector")
    normal = normal / norm

    reference = np.zeros(3, dtype=float)
    reference[int(np.argmin(np.abs(normal)))] = 1.0
    basis_u = np.cross(normal, reference)
    basis_u /= np.linalg.norm(basis_u)
    basis_v = np.cross(normal, basis_u)
    basis_v /= np.linalg.norm(basis_v)
    return normal, basis_u, basis_v


def sample_cross_section(
    signed_distance_mm: np.ndarray,
    spacing_zyx: Sequence[float],
    center_zyx: Sequence[float],
    normal_mm_zyx: Sequence[float],
    sampling_mm: float,
    half_extent_mm: float,
    interpolation_order: int = 1,
) -> CrossSection:
    """Resample a signed-distance field on a physical orthogonal plane.

    The returned binary mask contains only the 8-connected positive region
    that includes the plane centre. This prevents a nearby disconnected object
    from contaminating the section metrics.
    """

    field = np.asarray(signed_distance_mm, dtype=float)
    spacing = _validate_spacing(spacing_zyx)
    if field.ndim != 3:
        raise ValueError("signed_distance_mm must be a three-dimensional array")
    if not np.all(np.isfinite(field)):
        raise ValueError("signed_distance_mm must contain only finite values")

    center = np.asarray(center_zyx, dtype=float)
    if center.shape != (3,) or not np.all(np.isfinite(center)):
        raise ValueError("center_zyx must contain three finite values")
    if np.any(center < 0) or np.any(center > np.asarray(field.shape) - 1):
        raise ValueError("center_zyx lies outside the signed-distance volume")
    if not np.isfinite(sampling_mm) or sampling_mm <= 0:
        raise ValueError("sampling_mm must be finite and positive")
    if not np.isfinite(half_extent_mm) or half_extent_mm <= 0:
        raise ValueError("half_extent_mm must be finite and positive")
    if interpolation_order not in (0, 1):
        raise ValueError("interpolation_order must be 0 or 1")

    normal, basis_u, basis_v = _plane_basis(normal_mm_zyx)
    radius_samples = int(np.ceil(half_extent_mm / sampling_mm))
    coordinates_mm = np.arange(-radius_samples, radius_samples + 1) * sampling_mm
    u_grid, v_grid = np.meshgrid(coordinates_mm, coordinates_mm, indexing="xy")

    center_mm = center * spacing
    physical_points = (
        center_mm[:, np.newaxis, np.newaxis]
        + basis_u[:, np.newaxis, np.newaxis] * u_grid
        + basis_v[:, np.newaxis, np.newaxis] * v_grid
    )
    index_points = physical_points / spacing[:, np.newaxis, np.newaxis]
    outside_value = min(float(np.min(field)), -float(np.max(spacing)))
    sampled = ndimage.map_coordinates(
        field,
        index_points,
        order=interpolation_order,
        mode="constant",
        cval=outside_value,
        prefilter=interpolation_order > 1,
    )

    foreground = sampled >= 0.0
    labels, component_count = ndimage.label(
        foreground,
        structure=np.ones((3, 3), dtype=np.uint8),
    )
    centre_index = (radius_samples, radius_samples)
    centre_label = int(labels[centre_index])
    if centre_label == 0:
        raise ValueError("the plane centre does not lie inside the sampled object")
    selected = labels == centre_label

    return CrossSection(
        signed_distance_mm=sampled,
        mask=selected,
        u_mm=coordinates_mm.copy(),
        v_mm=coordinates_mm.copy(),
        sampling_mm=float(sampling_mm),
        center_zyx=tuple(float(value) for value in center),
        normal_mm_zyx=tuple(float(value) for value in normal),
        basis_u_mm_zyx=tuple(float(value) for value in basis_u),
        basis_v_mm_zyx=tuple(float(value) for value in basis_v),
        foreground_component_count=int(component_count),
    )


def _maximum_feret_mm(
    rows: np.ndarray,
    columns: np.ndarray,
    section: CrossSection,
) -> float:
    half_pixel = section.sampling_mm / 2.0
    centres = np.column_stack((section.u_mm[columns], section.v_mm[rows]))
    offsets = np.asarray(
        [
            (-half_pixel, -half_pixel),
            (-half_pixel, half_pixel),
            (half_pixel, -half_pixel),
            (half_pixel, half_pixel),
        ]
    )
    corners = np.unique(
        (centres[:, np.newaxis, :] + offsets[np.newaxis, :, :]).reshape(-1, 2),
        axis=0,
    )
    if len(corners) < 2:
        return 0.0
    if len(corners) <= 3:
        return float(np.max(pdist(corners)))

    try:
        hull = ConvexHull(corners)
        boundary = corners[hull.vertices]
    except QhullError:
        boundary = corners
    return float(np.max(pdist(boundary)))


def measure_section(
    section: CrossSection,
    *,
    min_pixel_count: int = 4,
    max_centroid_offset_mm: float | None = None,
) -> SectionMetrics:
    """Measure area and diameters from one sampled cross-section.

    ``moment_major_axis_mm`` and ``moment_minor_axis_mm`` are the full axes of
    the uniform ellipse with the same second central moments as the rasterised
    region. They are deliberately not labelled as anatomical ellipsoid axes.
    """

    if not isinstance(section, CrossSection):
        raise TypeError("section must be a CrossSection")
    if not isinstance(min_pixel_count, int) or isinstance(min_pixel_count, bool):
        raise TypeError("min_pixel_count must be an integer")
    if min_pixel_count < 1:
        raise ValueError("min_pixel_count must be at least 1")
    if max_centroid_offset_mm is not None and (
        not np.isfinite(max_centroid_offset_mm) or max_centroid_offset_mm < 0
    ):
        raise ValueError("max_centroid_offset_mm must be finite and non-negative")
    if not np.isfinite(section.sampling_mm) or section.sampling_mm <= 0:
        raise ValueError("section sampling_mm must be finite and positive")
    if section.foreground_component_count < 0:
        raise ValueError("foreground_component_count cannot be negative")
    mask = np.asarray(section.mask, dtype=bool)
    signed_distance = np.asarray(section.signed_distance_mm, dtype=float)
    if mask.ndim != 2 or mask.shape != (
        len(section.v_mm),
        len(section.u_mm),
    ):
        raise ValueError("section mask and coordinate axes have incompatible shapes")
    if signed_distance.shape != mask.shape or not np.all(np.isfinite(signed_distance)):
        raise ValueError("signed-distance samples must be finite and match the mask")

    for name, values in (("u_mm", section.u_mm), ("v_mm", section.v_mm)):
        axis = np.asarray(values, dtype=float)
        if axis.ndim != 1 or len(axis) == 0 or not np.all(np.isfinite(axis)):
            raise ValueError(f"section {name} must be a finite one-dimensional axis")
        if len(axis) > 1 and not np.allclose(
            np.diff(axis), section.sampling_mm, rtol=1e-9, atol=1e-12
        ):
            raise ValueError(f"section {name} must use the declared uniform sampling")

    frame = np.asarray(
        (
            section.normal_mm_zyx,
            section.basis_u_mm_zyx,
            section.basis_v_mm_zyx,
        ),
        dtype=float,
    )
    if frame.shape != (3, 3) or not np.all(np.isfinite(frame)):
        raise ValueError("section plane frame must contain three finite 3D vectors")
    if not np.allclose(frame @ frame.T, np.eye(3), atol=1e-6):
        raise ValueError("section plane frame must be orthonormal")

    rows, columns = np.nonzero(mask)
    pixel_count = len(rows)
    if pixel_count == 0:
        return SectionMetrics(
            area_mm2=0.0,
            equivalent_diameter_mm=0.0,
            feret_max_mm=0.0,
            moment_major_axis_mm=0.0,
            moment_minor_axis_mm=0.0,
            centroid_uv_mm=(float("nan"), float("nan")),
            pixel_count=0,
            touches_sampling_border=False,
            foreground_component_count=section.foreground_component_count,
            center_to_centroid_mm=float("nan"),
            invalid_reasons=("empty_section",),
            valid=False,
        )

    u = section.u_mm[columns]
    v = section.v_mm[rows]
    coordinates = np.column_stack((u, v))
    centroid = np.mean(coordinates, axis=0)
    centered = coordinates - centroid
    covariance = centered.T @ centered / pixel_count
    covariance += np.eye(2) * (section.sampling_mm**2 / 12.0)
    eigenvalues = np.linalg.eigvalsh(covariance)
    eigenvalues = np.maximum(eigenvalues, 0.0)
    minor_axis, major_axis = 4.0 * np.sqrt(eigenvalues)

    area = pixel_count * section.sampling_mm**2
    equivalent_diameter = 2.0 * np.sqrt(area / np.pi)
    touches_border = bool(
        np.any(mask[0, :])
        or np.any(mask[-1, :])
        or np.any(mask[:, 0])
        or np.any(mask[:, -1])
    )
    center_to_centroid = float(np.linalg.norm(centroid))
    invalid_reasons: list[str] = []
    if pixel_count < min_pixel_count:
        invalid_reasons.append("too_few_pixels")
    if touches_border:
        invalid_reasons.append("touches_sampling_border")
    if section.foreground_component_count > 1:
        invalid_reasons.append("multiple_foreground_components")
    if (
        max_centroid_offset_mm is not None
        and center_to_centroid > max_centroid_offset_mm
    ):
        invalid_reasons.append("centroid_too_far_from_plane_center")

    return SectionMetrics(
        area_mm2=float(area),
        equivalent_diameter_mm=float(equivalent_diameter),
        feret_max_mm=_maximum_feret_mm(rows, columns, section),
        moment_major_axis_mm=float(major_axis),
        moment_minor_axis_mm=float(minor_axis),
        centroid_uv_mm=(float(centroid[0]), float(centroid[1])),
        pixel_count=pixel_count,
        touches_sampling_border=touches_border,
        foreground_component_count=section.foreground_component_count,
        center_to_centroid_mm=center_to_centroid,
        invalid_reasons=tuple(invalid_reasons),
        valid=not invalid_reasons,
    )
