"""Modelo explícito para volumes utilizados pelos pipelines."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
from numpy.typing import NDArray

from .geometry import ImageGeometry


@dataclass(frozen=True)
class Volume3D:
    """Array 3D acompanhado da respetiva geometria física."""

    data_zyx: NDArray[np.generic]
    geometry: ImageGeometry
    case_id: str = "synthetic-case"

    def __post_init__(self) -> None:
        data = np.asarray(self.data_zyx)
        if data.ndim != 3:
            raise ValueError("data_zyx deve ser um array tridimensional.")
        if data.shape != self.geometry.shape_zyx:
            raise ValueError(
                "A forma do array não corresponde a geometry.shape_zyx: "
                f"{data.shape} != {self.geometry.shape_zyx}."
            )
        if not self.case_id or any(character.isspace() for character in self.case_id):
            raise ValueError("case_id deve ser não vazio e não pode conter espaços.")
        object.__setattr__(self, "data_zyx", data)

    def mask_for_label(self, label: int) -> NDArray[np.bool_]:
        return np.asarray(self.data_zyx == label, dtype=bool)
