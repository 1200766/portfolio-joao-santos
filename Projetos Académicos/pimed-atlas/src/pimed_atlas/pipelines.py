"""Pipelines públicos da reconstrução individual de João Santos.

Este módulo liga a leitura dos volumes aos algoritmos de landmarks e da
artéria basilar sem introduzir convenções anatómicas implícitas. Os resultados
não acrescentam automaticamente caminhos de origem, identificadores dos casos
nem voxels brutos; texto definido pelo utilizador continua a exigir revisão.
"""

from __future__ import annotations

import json
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from .basilar import (
    build_skeleton_graph,
    estimate_tangents,
    geodesic_centerline,
    measure_section,
    sample_cross_section,
    select_component_26,
    signed_distance_field,
    skeletonize_3d,
)
from .core import ImageGeometry, Volume3D, read_legacy_vtk, read_npz_volume
from .core.serialization import to_jsonable
from .landmarks import (
    LabelSpec,
    LateralityConvention,
    analyse_landmarks,
    analyse_surface_contacts,
    assign_laterality,
)

LANDMARK_SCHEMA_VERSION = 1
RESULT_SCHEMA_VERSION = 1
SYNTHETIC_CASE_ID = "synthetic-public-example"
SYNTHETIC_BASILAR_LABEL = 8


@dataclass(frozen=True)
class LateralityTask:
    """Uma atribuição de lateralidade totalmente definida pelo utilizador."""

    label: int
    convention: LateralityConvention
    require_bilateral: bool = False


@dataclass(frozen=True)
class ContactTask:
    """Uma medição de proximidade entre superfícies etiquetadas."""

    source_label: int
    target_label: int
    threshold_mm: float
    source_min_voxels: int
    target_min_voxels: int


@dataclass(frozen=True)
class LandmarkSchema:
    """Esquema explícito e validado para o pipeline de landmarks."""

    labels: tuple[LabelSpec, ...]
    laterality: tuple[LateralityTask, ...] = ()
    contacts: tuple[ContactTask, ...] = ()
    schema_version: int = LANDMARK_SCHEMA_VERSION


def read_volume(path: str | Path) -> tuple[Volume3D, str]:
    """Lê NPZ ou VTK sem expor o caminho nos resultados produzidos."""

    source = Path(path)
    suffix = source.suffix.lower()
    if suffix == ".npz":
        return read_npz_volume(source), "npz"
    if suffix == ".vtk":
        return read_legacy_vtk(source), "vtk-legacy"
    raise ValueError("O volume deve usar a extensão .npz ou .vtk.")


def load_landmark_schema(path: str | Path) -> LandmarkSchema:
    """Lê e valida um esquema JSON; não interpreta labels por convenção."""

    source = Path(path)
    if not source.is_file():
        raise FileNotFoundError(source)
    try:
        payload = json.loads(source.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(
            f"O esquema JSON é inválido na linha {error.lineno}, coluna {error.colno}."
        ) from error
    return parse_landmark_schema(payload)


def parse_landmark_schema(payload: Any) -> LandmarkSchema:
    """Converte um objeto JSON no esquema estrito utilizado pelo pipeline."""

    root = _mapping(payload, "raiz")
    _reject_unknown(
        root, {"schema_version", "labels", "laterality", "contacts"}, "raiz"
    )

    schema_version = _integer(
        _required(root, "schema_version", "raiz"), "schema_version"
    )
    if schema_version != LANDMARK_SCHEMA_VERSION:
        raise ValueError(
            "schema_version não suportada: "
            f"{schema_version}; utilize {LANDMARK_SCHEMA_VERSION}."
        )

    raw_labels = _list(_required(root, "labels", "raiz"), "labels")
    if not raw_labels:
        raise ValueError("labels deve conter pelo menos uma definição.")

    label_specs: list[LabelSpec] = []
    for index, raw_label in enumerate(raw_labels):
        location = f"labels[{index}]"
        item = _mapping(raw_label, location)
        _reject_unknown(
            item,
            {"value", "name", "expected_components", "min_voxels"},
            location,
        )
        value = _integer(_required(item, "value", location), f"{location}.value")
        name = _text(_required(item, "name", location), f"{location}.name")
        expected_raw = item.get("expected_components")
        expected = (
            None
            if expected_raw is None
            else _integer(expected_raw, f"{location}.expected_components")
        )
        min_voxels = _integer(item.get("min_voxels", 1), f"{location}.min_voxels")
        try:
            label_specs.append(
                LabelSpec(
                    value=value,
                    name=name,
                    expected_components=expected,
                    min_voxels=min_voxels,
                )
            )
        except (TypeError, ValueError) as error:
            raise ValueError(f"{location} é inválido: {error}") from error

    labels_by_value = {spec.value: spec for spec in label_specs}
    if len(labels_by_value) != len(label_specs):
        raise ValueError("labels contém valores de label repetidos.")

    laterality_tasks: list[LateralityTask] = []
    seen_laterality_labels: set[int] = set()
    for index, raw_task in enumerate(_list(root.get("laterality", []), "laterality")):
        location = f"laterality[{index}]"
        item = _mapping(raw_task, location)
        _reject_unknown(
            item,
            {
                "label",
                "coordinate_system",
                "axis",
                "positive_side",
                "midline_mm",
                "tolerance_mm",
                "require_bilateral",
            },
            location,
        )
        label = _integer(_required(item, "label", location), f"{location}.label")
        _require_configured_label(label, labels_by_value, location)
        if label in seen_laterality_labels:
            raise ValueError(f"{location} repete a lateralidade para a label {label}.")
        seen_laterality_labels.add(label)
        try:
            convention = LateralityConvention(
                coordinate_system=_text(
                    _required(item, "coordinate_system", location),
                    f"{location}.coordinate_system",
                ),
                axis=_text(_required(item, "axis", location), f"{location}.axis"),
                positive_side=_text(
                    _required(item, "positive_side", location),
                    f"{location}.positive_side",
                ),
                midline_mm=_number(
                    _required(item, "midline_mm", location),
                    f"{location}.midline_mm",
                ),
                tolerance_mm=_number(
                    _required(item, "tolerance_mm", location),
                    f"{location}.tolerance_mm",
                ),
            )
        except (TypeError, ValueError) as error:
            raise ValueError(f"{location} é inválido: {error}") from error
        laterality_tasks.append(
            LateralityTask(
                label=label,
                convention=convention,
                require_bilateral=_boolean(
                    item.get("require_bilateral", False),
                    f"{location}.require_bilateral",
                ),
            )
        )

    contact_tasks: list[ContactTask] = []
    for index, raw_task in enumerate(_list(root.get("contacts", []), "contacts")):
        location = f"contacts[{index}]"
        item = _mapping(raw_task, location)
        _reject_unknown(
            item,
            {
                "source_label",
                "target_label",
                "threshold_mm",
                "source_min_voxels",
                "target_min_voxels",
            },
            location,
        )
        source_label = _integer(
            _required(item, "source_label", location), f"{location}.source_label"
        )
        target_label = _integer(
            _required(item, "target_label", location), f"{location}.target_label"
        )
        _require_configured_label(source_label, labels_by_value, location)
        _require_configured_label(target_label, labels_by_value, location)
        source_min = _integer(
            item.get("source_min_voxels", labels_by_value[source_label].min_voxels),
            f"{location}.source_min_voxels",
        )
        target_min = _integer(
            item.get("target_min_voxels", labels_by_value[target_label].min_voxels),
            f"{location}.target_min_voxels",
        )
        threshold = _number(
            _required(item, "threshold_mm", location), f"{location}.threshold_mm"
        )
        if threshold < 0.0:
            raise ValueError(f"{location}.threshold_mm não pode ser negativo.")
        if source_min < 1 or target_min < 1:
            raise ValueError(f"{location}: os limites de voxels devem ser positivos.")
        if source_label == target_label and source_min != target_min:
            raise ValueError(
                f"{location}: os limites devem coincidir quando as labels são iguais."
            )
        contact_tasks.append(
            ContactTask(
                source_label=source_label,
                target_label=target_label,
                threshold_mm=threshold,
                source_min_voxels=source_min,
                target_min_voxels=target_min,
            )
        )

    return LandmarkSchema(
        labels=tuple(label_specs),
        laterality=tuple(laterality_tasks),
        contacts=tuple(contact_tasks),
        schema_version=schema_version,
    )


def analyse_landmark_volume(
    volume: Volume3D,
    schema: LandmarkSchema,
    *,
    source_format: str,
) -> dict[str, Any]:
    """Executa componentes, lateralidade e contactos definidos no esquema."""

    _validate_source_format(source_format)
    landmark_result = analyse_landmarks(volume.data_zyx, volume.geometry, schema.labels)

    laterality_results: list[dict[str, Any]] = []
    for task in schema.laterality:
        label_result = landmark_result.for_label(task.label)
        result = assign_laterality(
            label_result.components,
            task.convention,
            require_bilateral=task.require_bilateral,
        )
        laterality_results.append({"label": task.label, "result": result})

    contact_results: list[dict[str, Any]] = []
    for task in schema.contacts:
        contact_result = analyse_surface_contacts(
            volume.data_zyx,
            volume.geometry,
            task.source_label,
            task.target_label,
            threshold_mm=task.threshold_mm,
            source_min_voxels=task.source_min_voxels,
            target_min_voxels=task.target_min_voxels,
        )
        contact_results.append(
            {
                "analysis": contact_result,
                "contacts": contact_result.contacts,
            }
        )

    return to_jsonable(
        {
            "result_schema_version": RESULT_SCHEMA_VERSION,
            "analysis_type": "landmarks",
            "authorship": "reconstrucao_individual_de_joao_santos",
            "input_summary": _input_summary(volume, source_format),
            "configuration": _public_landmark_schema(schema),
            "results": {
                "components": landmark_result,
                "laterality": laterality_results,
                "contacts": contact_results,
            },
            "privacy": _privacy_statement(user_schema_text_included=True),
            "clinical_status": "prova_de_conceito_nao_validada_para_uso_clinico",
        }
    )


def analyse_basilar_volume(
    volume: Volume3D,
    *,
    source_format: str,
    label: int,
    component_seed_zyx: Sequence[int] | None = None,
    start_anchor_xyz_mm: Sequence[float] | None = None,
    end_anchor_xyz_mm: Sequence[float] | None = None,
    maximum_anchor_distance_mm: float = 5.0,
    allow_automatic_exploratory: bool = False,
    maximum_anisotropy_ratio: float = 3.0,
    allow_high_anisotropy: bool = False,
    sampling_mm: float | None = None,
    half_extent_mm: float | None = None,
    section_stride: int = 2,
    endpoint_margin: int = 2,
    tangent_window: int = 2,
) -> dict[str, Any]:
    """Analisa secções ortogonais da label vascular selecionada.

    A deteção automática dos extremos é apenas um modo exploratório para
    dados sintéticos e exige aceitação explícita. O software não tenta deduzir
    nem autenticar a origem do volume através de metadados controlados pelo
    utilizador. A análise normal requer dois anchors físicos em XYZ.
    """

    if isinstance(label, bool) or not isinstance(label, int):
        raise TypeError("label deve ser um número inteiro.")
    _validate_source_format(source_format)
    spacing = np.asarray(volume.geometry.spacing_zyx, dtype=float)
    anisotropy_ratio = float(np.max(spacing) / np.min(spacing))
    if (
        isinstance(maximum_anisotropy_ratio, bool)
        or not isinstance(maximum_anisotropy_ratio, (int, float))
        or not np.isfinite(maximum_anisotropy_ratio)
        or maximum_anisotropy_ratio < 1.0
    ):
        raise ValueError("maximum_anisotropy_ratio deve ser finito e pelo menos 1.")
    if anisotropy_ratio > maximum_anisotropy_ratio and not allow_high_anisotropy:
        raise ValueError(
            "A anisotropia dos voxels "
            f"({anisotropy_ratio:.3f}) excede o limite configurado "
            f"({maximum_anisotropy_ratio:.3f}); reveja os dados ou use "
            "--allow-high-anisotropy de forma explícita."
        )
    direction = np.asarray(volume.geometry.direction_xyz, dtype=float)
    if not np.allclose(direction.T @ direction, np.eye(3), atol=1e-8):
        raise ValueError(
            "A análise da basilar requer uma matriz de direção ortonormal."
        )
    if (start_anchor_xyz_mm is None) != (end_anchor_xyz_mm is None):
        raise ValueError("Forneça simultaneamente --start-anchor-mm e --end-anchor-mm.")
    if (
        isinstance(maximum_anchor_distance_mm, bool)
        or not isinstance(maximum_anchor_distance_mm, (int, float))
        or not np.isfinite(maximum_anchor_distance_mm)
        or maximum_anchor_distance_mm < 0.0
    ):
        raise ValueError("maximum_anchor_distance_mm deve ser finito e não negativo.")

    automatic = start_anchor_xyz_mm is None
    if automatic:
        if not allow_automatic_exploratory:
            raise ValueError(
                "Sem anchors, confirme explicitamente o modo exploratório para "
                "dados sintéticos com --allow-automatic-exploratory."
            )
    elif allow_automatic_exploratory:
        raise ValueError(
            "Não combine anchors explícitos com --allow-automatic-exploratory."
        )

    if (
        isinstance(section_stride, bool)
        or not isinstance(section_stride, int)
        or section_stride < 1
    ):
        raise ValueError("section_stride deve ser um inteiro positivo.")
    if (
        isinstance(endpoint_margin, bool)
        or not isinstance(endpoint_margin, int)
        or endpoint_margin < 0
    ):
        raise ValueError("endpoint_margin deve ser um inteiro não negativo.")
    if (
        isinstance(tangent_window, bool)
        or not isinstance(tangent_window, int)
        or tangent_window < 1
    ):
        raise ValueError("tangent_window deve ser um inteiro positivo.")

    mask = volume.mask_for_label(label)
    if not np.any(mask):
        raise ValueError(f"A label {label} não existe no volume.")
    selected = select_component_26(mask, seed_zyx=component_seed_zyx)
    skeleton = skeletonize_3d(selected)
    graph = build_skeleton_graph(skeleton, volume.geometry.spacing_zyx)

    anchor_report: dict[str, Any] | None = None
    start_seed_zyx: Sequence[float] | None = None
    end_seed_zyx: Sequence[float] | None = None
    if not automatic:
        start_anchor = _snap_physical_anchor(
            "inicial",
            start_anchor_xyz_mm,
            graph.nodes_zyx,
            volume.geometry,
            maximum_anchor_distance_mm,
        )
        end_anchor = _snap_physical_anchor(
            "final",
            end_anchor_xyz_mm,
            graph.nodes_zyx,
            volume.geometry,
            maximum_anchor_distance_mm,
        )
        if start_anchor["graph_node_index"] == end_anchor["graph_node_index"]:
            raise ValueError(
                "Os dois anchors foram associados ao mesmo nó do esqueleto; "
                "selecione pontos distintos."
            )
        start_seed_zyx = start_anchor["snapped_index_zyx"]
        end_seed_zyx = end_anchor["snapped_index_zyx"]
        anchor_report = {
            "coordinate_order": "xyz",
            "units": "mm",
            "maximum_snapping_distance_mm": float(maximum_anchor_distance_mm),
            "start": start_anchor,
            "end": end_anchor,
        }

    path = geodesic_centerline(
        graph,
        start_seed_zyx=start_seed_zyx,
        end_seed_zyx=end_seed_zyx,
    )
    if len(path.points_zyx) < 2:
        raise ValueError("A linha central selecionada tem menos de dois pontos.")

    section_indices = _section_indices(
        len(path.points_zyx), section_stride, endpoint_margin
    )
    tangents = estimate_tangents(
        path.points_zyx,
        volume.geometry.spacing_zyx,
        window=tangent_window,
    )
    distance_field = signed_distance_field(selected, volume.geometry.spacing_zyx)

    if isinstance(sampling_mm, bool):
        raise TypeError("sampling_mm deve ser finito e positivo.")
    selected_sampling = (
        float(sampling_mm)
        if sampling_mm is not None
        else float(min(volume.geometry.spacing_zyx) / 2.0)
    )
    if not np.isfinite(selected_sampling) or selected_sampling <= 0.0:
        raise ValueError("sampling_mm deve ser finito e positivo.")

    maximum_inside_radius = float(np.max(distance_field[selected]))
    if isinstance(half_extent_mm, bool):
        raise TypeError("half_extent_mm deve ser finito e positivo.")
    selected_extent = (
        float(half_extent_mm)
        if half_extent_mm is not None
        else max(4.0 * selected_sampling, 1.75 * maximum_inside_radius)
    )
    if not np.isfinite(selected_extent) or selected_extent <= 0.0:
        raise ValueError("half_extent_mm deve ser finito e positivo.")

    cumulative_distance = np.concatenate(
        (
            np.asarray([0.0]),
            np.cumsum(np.linalg.norm(np.diff(path.points_mm_zyx, axis=0), axis=1)),
        )
    )
    sections: list[dict[str, Any]] = []
    for node_index in section_indices:
        section = sample_cross_section(
            distance_field,
            volume.geometry.spacing_zyx,
            center_zyx=path.points_zyx[node_index],
            normal_mm_zyx=tangents[node_index],
            sampling_mm=selected_sampling,
            half_extent_mm=selected_extent,
        )
        metrics = measure_section(
            section,
            max_centroid_offset_mm=float(np.max(spacing)),
        )
        sections.append(
            {
                "centerline_node_index": node_index,
                "distance_from_start_mm": float(cumulative_distance[node_index]),
                "metrics": metrics,
            }
        )

    valid_sections = sum(bool(item["metrics"].valid) for item in sections)
    quality_warnings: list[str] = []
    if anisotropy_ratio > maximum_anisotropy_ratio:
        quality_warnings.append("voxel_anisotropy_above_configured_limit")
    if automatic:
        quality_warnings.append("synthetic_origin_not_verified_by_software")
        quality_warnings.append("automatic_endpoint_selection_is_exploratory")
    if valid_sections < len(sections):
        quality_warnings.append("invalid_cross_sections_present")
    return to_jsonable(
        {
            "result_schema_version": RESULT_SCHEMA_VERSION,
            "analysis_type": "basilar_cross_sections",
            "authorship": "reconstrucao_individual_de_joao_santos",
            "input_summary": _input_summary(volume, source_format),
            "configuration": {
                "label": label,
                "component_selection": (
                    "seeded"
                    if component_seed_zyx is not None
                    else "largest_26_component"
                ),
                "component_seed_zyx": component_seed_zyx,
                "endpoint_selection": (
                    "automatic_exploratory" if automatic else "physical_anchors"
                ),
                "automatic_mode_acknowledged_by_user": bool(automatic),
                "synthetic_origin_verified_by_software": False,
                "anchors": anchor_report,
                "sampling_mm": selected_sampling,
                "half_extent_mm": selected_extent,
                "section_stride_nodes": section_stride,
                "endpoint_margin_nodes": endpoint_margin,
                "tangent_window_nodes": tangent_window,
                "voxel_anisotropy_ratio": anisotropy_ratio,
                "maximum_anisotropy_ratio": float(maximum_anisotropy_ratio),
                "high_anisotropy_override": bool(
                    anisotropy_ratio > maximum_anisotropy_ratio
                    and allow_high_anisotropy
                ),
                "maximum_section_centroid_offset_mm": float(np.max(spacing)),
            },
            "results": {
                "selected_component_voxels": int(np.count_nonzero(selected)),
                "skeleton_nodes": len(graph.nodes_zyx),
                "centerline": {
                    "node_count": len(path.points_zyx),
                    "length_mm": float(path.length_mm),
                    "automatic_endpoints": bool(path.automatic_endpoints),
                },
                "section_count": len(sections),
                "valid_section_count": valid_sections,
                "invalid_section_count": len(sections) - valid_sections,
                "sections": sections,
                "quality_warnings": quality_warnings,
            },
            "privacy": _privacy_statement(user_schema_text_included=False),
            "clinical_status": "prova_de_conceito_nao_validada_para_uso_clinico",
            "method_limitations": [
                "skeletonization_occurs_on_the_voxel_grid",
                "uv_coordinates_are_local_and_not_comparable_between_sections",
            ],
        }
    )


def generate_synthetic_case() -> Volume3D:
    """Cria um volume público sem origem em pessoas ou exames reais."""

    geometry = ImageGeometry(
        shape_zyx=(45, 65, 65),
        spacing_zyx=(1.0, 0.8, 0.6),
        origin_xyz_mm=(-19.2, -25.6, -22.0),
        direction_xyz=np.eye(3, dtype=float),
    )
    indices = np.moveaxis(np.indices(geometry.shape_zyx, dtype=float), 0, -1)
    local_mm_zyx = indices * np.asarray(geometry.spacing_zyx)
    labels = np.zeros(geometry.shape_zyx, dtype=np.uint8)

    center_zyx = np.asarray((22.0, 42.0, 32.0))
    center_mm_zyx = center_zyx * np.asarray(geometry.spacing_zyx)
    direction_mm_zyx = np.asarray((1.0, 0.25, 0.35), dtype=float)
    direction_mm_zyx /= np.linalg.norm(direction_mm_zyx)
    relative = local_mm_zyx - center_mm_zyx
    axial = np.einsum("...i,i->...", relative, direction_mm_zyx)
    radial = relative - axial[..., np.newaxis] * direction_mm_zyx
    tube = (np.abs(axial) <= 15.0) & (np.linalg.norm(radial, axis=-1) <= 3.0)
    labels[tube] = SYNTHETIC_BASILAR_LABEL

    for centre, radius_mm, label in (
        ((10.0, 12.0, 12.0), 1.6, 1),
        ((10.0, 12.0, 52.0), 1.6, 1),
        ((10.0, 12.0, 19.0), 1.2, 2),
    ):
        sphere_center = np.asarray(centre) * np.asarray(geometry.spacing_zyx)
        sphere = np.linalg.norm(local_mm_zyx - sphere_center, axis=-1) <= radius_mm
        labels[sphere] = label

    return Volume3D(labels, geometry, SYNTHETIC_CASE_ID)


def synthetic_landmark_schema_payload() -> dict[str, Any]:
    """Devolve o esquema explícito associado apenas ao exemplo sintético."""

    return {
        "schema_version": LANDMARK_SCHEMA_VERSION,
        "labels": [
            {
                "value": 1,
                "name": "marcador_bilateral_sintetico",
                "expected_components": 2,
                "min_voxels": 5,
            },
            {
                "value": 2,
                "name": "marcador_referencia_sintetico",
                "expected_components": 1,
                "min_voxels": 5,
            },
        ],
        "laterality": [
            {
                "label": 1,
                "coordinate_system": "LPS_sintetico_declarado",
                "axis": "x",
                "positive_side": "left",
                "midline_mm": 0.0,
                "tolerance_mm": 0.5,
                "require_bilateral": True,
            }
        ],
        "contacts": [
            {
                "source_label": 1,
                "target_label": 2,
                "threshold_mm": 2.5,
            }
        ],
    }


def _section_indices(length: int, stride: int, margin: int) -> tuple[int, ...]:
    if length <= 2 * margin:
        raise ValueError(
            "A linha central é demasiado curta para a margem de extremos escolhida."
        )
    return tuple(range(margin, length - margin, stride))


def _snap_physical_anchor(
    name: str,
    anchor_xyz_mm: Sequence[float] | None,
    skeleton_nodes_zyx: np.ndarray,
    geometry: ImageGeometry,
    maximum_distance_mm: float,
) -> dict[str, Any]:
    if anchor_xyz_mm is None:
        raise ValueError(f"O anchor {name} não foi fornecido.")
    anchor = np.asarray(anchor_xyz_mm, dtype=float)
    if anchor.shape != (3,) or not np.all(np.isfinite(anchor)):
        raise ValueError(f"O anchor {name} deve conter três coordenadas XYZ finitas.")

    continuous_index = geometry.physical_xyz_to_continuous_index_zyx(anchor)
    if not bool(geometry.contains_continuous_index(continuous_index)):
        raise ValueError(f"O anchor {name} fica fora dos limites físicos do volume.")

    node_points_xyz_mm = geometry.index_zyx_to_physical_xyz(skeleton_nodes_zyx)
    distances = np.linalg.norm(node_points_xyz_mm - anchor, axis=1)
    graph_node_index = int(np.argmin(distances))
    snapping_distance = float(distances[graph_node_index])
    if snapping_distance > maximum_distance_mm + 1e-12:
        raise ValueError(
            f"O anchor {name} está a {snapping_distance:.3f} mm do esqueleto, "
            f"acima do limite de {maximum_distance_mm:.3f} mm."
        )

    snapped_index = skeleton_nodes_zyx[graph_node_index]
    snapped_point = node_points_xyz_mm[graph_node_index]
    return {
        "requested_point_xyz_mm": tuple(float(value) for value in anchor),
        "continuous_index_zyx": tuple(float(value) for value in continuous_index),
        "snapped_index_zyx": tuple(int(value) for value in snapped_index),
        "snapped_point_xyz_mm": tuple(float(value) for value in snapped_point),
        "snapping_distance_mm": snapping_distance,
        "graph_node_index": graph_node_index,
    }


def _input_summary(volume: Volume3D, source_format: str) -> dict[str, Any]:
    return {
        "format": source_format,
        "shape_zyx": list(volume.geometry.shape_zyx),
        "spacing_zyx_mm": list(volume.geometry.spacing_zyx),
        "direction_xyz": np.asarray(
            volume.geometry.direction_xyz, dtype=float
        ).tolist(),
        "source_path_included": False,
        "case_identifier_included": False,
        "raw_voxels_included": False,
        "direction_status": (
            "identity_assumed_because_legacy_vtk_has_no_direction_metadata"
            if source_format == "vtk-legacy"
            else "provided_by_npz_metadata"
        ),
    }


def _validate_source_format(source_format: str) -> None:
    if source_format not in {"npz", "vtk-legacy"}:
        raise ValueError("source_format deve ser 'npz' ou 'vtk-legacy'.")


def _privacy_statement(*, user_schema_text_included: bool) -> dict[str, Any]:
    return {
        "source_path_included": False,
        "case_identifier_included": False,
        "raw_voxels_included": False,
        "user_schema_text_included": user_schema_text_included,
        "notice": (
            "Os resultados derivados e, nos landmarks, os nomes fornecidos no "
            "esquema podem continuar sujeitos a regras de privacidade; reveja-os "
            "antes de qualquer publicação."
        ),
    }


def _public_landmark_schema(schema: LandmarkSchema) -> dict[str, Any]:
    return {
        "schema_version": schema.schema_version,
        "labels": list(schema.labels),
        "laterality": [
            {
                "label": task.label,
                "convention": task.convention,
                "require_bilateral": task.require_bilateral,
            }
            for task in schema.laterality
        ],
        "contacts": list(schema.contacts),
    }


def _mapping(value: Any, location: str) -> Mapping[str, Any]:
    if not isinstance(value, dict):
        raise TypeError(f"{location} deve ser um objeto JSON.")
    return value


def _list(value: Any, location: str) -> list[Any]:
    if not isinstance(value, list):
        raise TypeError(f"{location} deve ser uma lista JSON.")
    return value


def _required(mapping: Mapping[str, Any], key: str, location: str) -> Any:
    if key not in mapping:
        raise ValueError(f"Falta o campo obrigatório {location}.{key}.")
    return mapping[key]


def _reject_unknown(
    mapping: Mapping[str, Any], allowed: set[str], location: str
) -> None:
    unknown = sorted(set(mapping).difference(allowed))
    if unknown:
        raise ValueError(f"Campos desconhecidos em {location}: {', '.join(unknown)}.")


def _integer(value: Any, location: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"{location} deve ser um número inteiro.")
    return value


def _number(value: Any, location: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise TypeError(f"{location} deve ser um número.")
    result = float(value)
    if not np.isfinite(result):
        raise ValueError(f"{location} deve ser finito.")
    return result


def _text(value: Any, location: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{location} deve ser texto não vazio.")
    return value


def _boolean(value: Any, location: str) -> bool:
    if not isinstance(value, bool):
        raise TypeError(f"{location} deve ser true ou false.")
    return value


def _require_configured_label(
    label: int, labels_by_value: Mapping[int, LabelSpec], location: str
) -> None:
    if label not in labels_by_value:
        raise ValueError(
            f"{location} refere a label {label}, que não está definida em labels."
        )
