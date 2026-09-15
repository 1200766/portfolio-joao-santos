"""Adaptadores de entrada; o núcleo matemático não depende de VTK."""

from __future__ import annotations

from pathlib import Path

import numpy as np

from .geometry import ImageGeometry
from .volume import Volume3D


def save_npz_volume(path: str | Path, volume: Volume3D) -> None:
    """Guarda um caso sintético ou autorizado num contentor NumPy portátil."""

    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(
        destination,
        data_zyx=volume.data_zyx,
        spacing_zyx=np.asarray(volume.geometry.spacing_zyx, dtype=float),
        origin_xyz_mm=np.asarray(volume.geometry.origin_xyz_mm, dtype=float),
        direction_xyz=volume.geometry.direction_xyz,
        case_id=np.asarray(volume.case_id),
    )


def read_npz_volume(path: str | Path) -> Volume3D:
    """Lê o formato NPZ explícito utilizado nos exemplos sintéticos."""

    source = Path(path)
    if not source.is_file():
        raise FileNotFoundError(source)
    with np.load(source, allow_pickle=False) as archive:
        required = {
            "data_zyx",
            "spacing_zyx",
            "origin_xyz_mm",
            "direction_xyz",
            "case_id",
        }
        missing = required.difference(archive.files)
        if missing:
            raise ValueError(f"Campos em falta no NPZ: {', '.join(sorted(missing))}.")
        data = np.asarray(archive["data_zyx"])
        geometry = ImageGeometry(
            shape_zyx=data.shape,
            spacing_zyx=tuple(float(value) for value in archive["spacing_zyx"]),
            origin_xyz_mm=tuple(float(value) for value in archive["origin_xyz_mm"]),
            direction_xyz=np.asarray(archive["direction_xyz"], dtype=float),
        )
        case_id = str(np.asarray(archive["case_id"]).item())
    return Volume3D(data, geometry, case_id)


def read_legacy_vtk(path: str | Path, *, case_id: str | None = None) -> Volume3D:
    """Lê um volume VTK legado e devolve um array ``zyx`` com geometria.

    O import de VTK é adiado para que os testes do núcleo possam correr sem a
    dependência opcional. Ficheiros legados sem matriz de direção são tratados
    com direção identidade e essa limitação deve acompanhar qualquer resultado.
    """

    try:
        from vtkmodules.util.numpy_support import vtk_to_numpy
        from vtkmodules.vtkIOLegacy import vtkDataSetReader
    except ImportError as exc:
        raise RuntimeError(
            "A leitura de VTK requer a dependência opcional: pip install '.[vtk]'."
        ) from exc

    source = Path(path)
    if not source.is_file():
        raise FileNotFoundError(source)

    reader = vtkDataSetReader()
    reader.SetFileName(str(source))
    reader.ReadAllScalarsOn()
    reader.Update()
    image = reader.GetOutput()

    dimensions_xyz = tuple(int(value) for value in image.GetDimensions())
    if len(dimensions_xyz) != 3 or any(value <= 0 for value in dimensions_xyz):
        raise ValueError(f"O ficheiro não contém um volume 3D válido: {source}")

    scalars = image.GetPointData().GetScalars()
    if scalars is None:
        raise ValueError(f"O ficheiro não contém escalares de voxel: {source}")

    data = vtk_to_numpy(scalars).reshape(dimensions_xyz[::-1])
    spacing_xyz = tuple(float(value) for value in image.GetSpacing())
    origin_xyz = tuple(float(value) for value in image.GetOrigin())

    geometry = ImageGeometry(
        shape_zyx=data.shape,
        spacing_zyx=spacing_xyz[::-1],
        origin_xyz_mm=origin_xyz,
        # O formato VTK legado não codifica a orientação dos eixos.
        direction_xyz=np.eye(3, dtype=float),
    )
    return Volume3D(data, geometry, case_id or source.stem)
