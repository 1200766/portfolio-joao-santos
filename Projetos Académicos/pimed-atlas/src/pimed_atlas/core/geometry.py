"""Transformações explícitas entre índices NumPy e coordenadas físicas."""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from numpy.typing import ArrayLike, NDArray


def _identity_direction() -> NDArray[np.float64]:
    return np.eye(3, dtype=float)


@dataclass(frozen=True, eq=False)
class ImageGeometry:
    """Geometria de um volume 3D.

    Os arrays usam ordem ``z, y, x``. A origem, a matriz de direção e os pontos
    físicos usam ordem ``x, y, z`` e unidades de milímetros.
    """

    shape_zyx: tuple[int, int, int]
    spacing_zyx: tuple[float, float, float]
    origin_xyz_mm: tuple[float, float, float] = (0.0, 0.0, 0.0)
    direction_xyz: NDArray[np.float64] = field(default_factory=_identity_direction)

    def __post_init__(self) -> None:
        if (
            len(self.shape_zyx) != 3
            or any(
                isinstance(value, bool) or not isinstance(value, int)
                for value in self.shape_zyx
            )
            or any(value <= 0 for value in self.shape_zyx)
        ):
            raise ValueError("shape_zyx deve conter três dimensões positivas.")
        spacing = np.asarray(self.spacing_zyx, dtype=float)
        if (
            spacing.shape != (3,)
            or not np.isfinite(spacing).all()
            or np.any(spacing <= 0)
        ):
            raise ValueError("spacing_zyx deve conter três valores positivos.")

        origin = np.asarray(self.origin_xyz_mm, dtype=float)
        if origin.shape != (3,) or not np.isfinite(origin).all():
            raise ValueError("origin_xyz_mm deve conter três valores finitos.")

        direction = np.asarray(self.direction_xyz, dtype=float)
        if direction.shape != (3, 3):
            raise ValueError("direction_xyz deve ser uma matriz 3 × 3.")
        if not np.isfinite(direction).all() or abs(np.linalg.det(direction)) < 1e-12:
            raise ValueError("direction_xyz deve ser finita e invertível.")
        if not np.allclose(direction.T @ direction, np.eye(3), atol=1e-6):
            raise ValueError(
                "direction_xyz deve ser ortonormal para representar eixos físicos."
            )
        object.__setattr__(
            self, "spacing_zyx", tuple(float(value) for value in spacing)
        )
        object.__setattr__(
            self, "origin_xyz_mm", tuple(float(value) for value in origin)
        )
        immutable_direction = direction.copy()
        immutable_direction.setflags(write=False)
        object.__setattr__(self, "direction_xyz", immutable_direction)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, ImageGeometry):
            return NotImplemented
        return (
            self.shape_zyx == other.shape_zyx
            and self.spacing_zyx == other.spacing_zyx
            and self.origin_xyz_mm == other.origin_xyz_mm
            and np.array_equal(self.direction_xyz, other.direction_xyz)
        )

    def __hash__(self) -> int:
        return hash(
            (
                self.shape_zyx,
                self.spacing_zyx,
                self.origin_xyz_mm,
                self.direction_xyz.tobytes(),
            )
        )

    @property
    def spacing_xyz(self) -> NDArray[np.float64]:
        return np.asarray(self.spacing_zyx[::-1], dtype=float)

    @property
    def origin_xyz(self) -> NDArray[np.float64]:
        return np.asarray(self.origin_xyz_mm, dtype=float)

    def index_zyx_to_physical_xyz(self, index_zyx: ArrayLike) -> NDArray[np.float64]:
        """Converte um ou vários índices contínuos ``zyx`` para pontos ``xyz``."""

        indices = np.asarray(index_zyx, dtype=float)
        if indices.shape[-1:] != (3,):
            raise ValueError("O último eixo de index_zyx deve ter comprimento 3.")
        indices_xyz = indices[..., ::-1]
        scaled = indices_xyz * self.spacing_xyz
        return self.origin_xyz + scaled @ self.direction_xyz.T

    def physical_xyz_to_continuous_index_zyx(
        self,
        point_xyz_mm: ArrayLike,
    ) -> NDArray[np.float64]:
        """Converte pontos físicos ``xyz`` para índices contínuos NumPy ``zyx``."""

        points = np.asarray(point_xyz_mm, dtype=float)
        if points.shape[-1:] != (3,):
            raise ValueError("O último eixo de point_xyz_mm deve ter comprimento 3.")
        local_xyz = (points - self.origin_xyz) @ np.linalg.inv(self.direction_xyz).T
        indices_xyz = local_xyz / self.spacing_xyz
        return indices_xyz[..., ::-1]

    def contains_continuous_index(self, index_zyx: ArrayLike) -> NDArray[np.bool_]:
        indices = np.asarray(index_zyx, dtype=float)
        if indices.shape[-1:] != (3,):
            raise ValueError("O último eixo de index_zyx deve ter comprimento 3.")
        upper = np.asarray(self.shape_zyx, dtype=float) - 1.0
        return np.logical_and(indices >= 0.0, indices <= upper).all(axis=-1)
