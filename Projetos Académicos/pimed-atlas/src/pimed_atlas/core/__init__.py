"""Tipos e operações comuns aos módulos de análise."""

from .geometry import ImageGeometry
from .io import read_legacy_vtk, read_npz_volume, save_npz_volume
from .serialization import to_jsonable, write_json
from .volume import Volume3D

__all__ = [
    "ImageGeometry",
    "Volume3D",
    "read_legacy_vtk",
    "read_npz_volume",
    "save_npz_volume",
    "to_jsonable",
    "write_json",
]
