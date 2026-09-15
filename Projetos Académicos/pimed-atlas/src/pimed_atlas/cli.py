"""CLI da reconstrução pública individual de João Santos.

Os comandos apenas criam ficheiros locais e não enviam dados nem resultados
para serviços externos. Não acrescentam automaticamente caminhos de origem,
identificadores de casos ou voxels aos JSON; texto fornecido pelo utilizador
continua a exigir revisão antes de ser partilhado.
"""

from __future__ import annotations

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

from .core import save_npz_volume, write_json
from .pipelines import (
    analyse_basilar_volume,
    analyse_landmark_volume,
    generate_synthetic_case,
    load_landmark_schema,
    read_volume,
    synthetic_landmark_schema_payload,
)


def build_parser() -> argparse.ArgumentParser:
    """Constrói o parser sem executar operações no sistema de ficheiros."""

    parser = argparse.ArgumentParser(
        prog="pimed-atlas",
        description=(
            "Reconstrução individual do protótipo académico ATLAS; "
            "não validada para uso clínico."
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    synthetic = subparsers.add_parser(
        "generate-synthetic",
        help="gera um volume e um esquema sem dados reais",
    )
    synthetic.add_argument("--volume-output", type=Path, required=True)
    synthetic.add_argument("--schema-output", type=Path, required=True)
    synthetic.add_argument(
        "--overwrite",
        action="store_true",
        help="permite substituir os dois ficheiros de saída",
    )
    synthetic.set_defaults(handler=_generate_synthetic)

    landmarks = subparsers.add_parser(
        "analyse-landmarks",
        help="analisa apenas as labels definidas num esquema JSON explícito",
    )
    _add_common_analysis_arguments(landmarks)
    landmarks.add_argument("--schema", type=Path, required=True)
    landmarks.set_defaults(handler=_analyse_landmarks)

    basilar = subparsers.add_parser(
        "analyse-basilar",
        help="analisa secções ortogonais de uma label vascular",
    )
    _add_common_analysis_arguments(basilar)
    basilar.add_argument("--label", type=int, required=True)
    basilar.add_argument(
        "--component-seed",
        nargs=3,
        type=int,
        metavar=("Z", "Y", "X"),
        help="voxel da componente pretendida, em índices ZYX",
    )
    basilar.add_argument(
        "--start-anchor-mm", nargs=3, type=float, metavar=("X", "Y", "Z")
    )
    basilar.add_argument(
        "--end-anchor-mm", nargs=3, type=float, metavar=("X", "Y", "Z")
    )
    basilar.add_argument(
        "--maximum-anchor-distance-mm",
        type=float,
        default=5.0,
        help="distância máxima entre cada anchor XYZ e o esqueleto",
    )
    basilar.add_argument(
        "--allow-automatic-exploratory",
        action="store_true",
        help=(
            "declara o input como sintético e aceita extremos automáticos "
            "não autenticados"
        ),
    )
    basilar.add_argument("--sampling-mm", type=float)
    basilar.add_argument("--half-extent-mm", type=float)
    basilar.add_argument("--section-stride", type=int, default=2)
    basilar.add_argument("--endpoint-margin", type=int, default=2)
    basilar.add_argument("--tangent-window", type=int, default=2)
    basilar.add_argument("--maximum-anisotropy-ratio", type=float, default=3.0)
    basilar.add_argument(
        "--allow-high-anisotropy",
        action="store_true",
        help="aceita explicitamente voxels acima do limite de anisotropia",
    )
    basilar.set_defaults(handler=_analyse_basilar)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Executa a CLI e devolve um código adequado a scripts de automação."""

    parser = build_parser()
    arguments = parser.parse_args(argv)
    try:
        return int(arguments.handler(arguments))
    except (FileNotFoundError, TypeError, ValueError, RuntimeError) as error:
        print(f"Erro: {error}", file=sys.stderr)
        return 2


def _add_common_analysis_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--input", type=Path, required=True, help="volume .npz ou .vtk")
    parser.add_argument("--output", type=Path, required=True, help="resultado JSON")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="permite substituir o resultado existente",
    )


def _generate_synthetic(arguments: argparse.Namespace) -> int:
    _ensure_available(
        (arguments.volume_output, arguments.schema_output), arguments.overwrite
    )
    volume = generate_synthetic_case()
    save_npz_volume(arguments.volume_output, volume)
    write_json(arguments.schema_output, synthetic_landmark_schema_payload())
    print(f"Volume sintético criado: {arguments.volume_output}")
    print(f"Esquema explícito criado: {arguments.schema_output}")
    return 0


def _analyse_landmarks(arguments: argparse.Namespace) -> int:
    _ensure_available((arguments.output,), arguments.overwrite)
    volume, source_format = read_volume(arguments.input)
    schema = load_landmark_schema(arguments.schema)
    result = analyse_landmark_volume(volume, schema, source_format=source_format)
    write_json(arguments.output, result)
    print(f"Análise de landmarks concluída: {arguments.output}")
    return 0


def _analyse_basilar(arguments: argparse.Namespace) -> int:
    _ensure_available((arguments.output,), arguments.overwrite)
    volume, source_format = read_volume(arguments.input)
    result = analyse_basilar_volume(
        volume,
        source_format=source_format,
        label=arguments.label,
        component_seed_zyx=arguments.component_seed,
        start_anchor_xyz_mm=arguments.start_anchor_mm,
        end_anchor_xyz_mm=arguments.end_anchor_mm,
        maximum_anchor_distance_mm=arguments.maximum_anchor_distance_mm,
        allow_automatic_exploratory=arguments.allow_automatic_exploratory,
        maximum_anisotropy_ratio=arguments.maximum_anisotropy_ratio,
        allow_high_anisotropy=arguments.allow_high_anisotropy,
        sampling_mm=arguments.sampling_mm,
        half_extent_mm=arguments.half_extent_mm,
        section_stride=arguments.section_stride,
        endpoint_margin=arguments.endpoint_margin,
        tangent_window=arguments.tangent_window,
    )
    write_json(arguments.output, result)
    print(f"Análise da basilar concluída: {arguments.output}")
    return 0


def _ensure_available(paths: Sequence[Path], overwrite: bool) -> None:
    duplicates = len(set(paths)) != len(paths)
    if duplicates:
        raise ValueError("Os caminhos de saída devem ser diferentes.")
    existing = [path for path in paths if path.exists()]
    if existing and not overwrite:
        rendered = ", ".join(str(path) for path in existing)
        raise ValueError(
            f"A saída já existe ({rendered}); use --overwrite para a substituir."
        )


if __name__ == "__main__":
    raise SystemExit(main())
