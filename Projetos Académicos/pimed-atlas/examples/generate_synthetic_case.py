"""Gera o exemplo público da reconstrução individual de João Santos.

Execução a partir de `Projetos Académicos/pimed-atlas/` no repositório público
de portefólio, depois da instalação:

    python examples/generate_synthetic_case.py DIRETORIO_DE_SAIDA
"""

from __future__ import annotations

import argparse
from pathlib import Path

from pimed_atlas.core import save_npz_volume, write_json
from pimed_atlas.pipelines import (
    generate_synthetic_case,
    synthetic_landmark_schema_payload,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Cria um volume e um esquema inteiramente sintéticos."
    )
    parser.add_argument("output_directory", type=Path)
    arguments = parser.parse_args()

    directory = arguments.output_directory
    volume_path = directory / "synthetic_case.npz"
    schema_path = directory / "landmark_schema.json"
    if volume_path.exists() or schema_path.exists():
        parser.error("a saída já existe; escolha outro diretório")

    save_npz_volume(volume_path, generate_synthetic_case())
    write_json(schema_path, synthetic_landmark_schema_payload())
    print(f"Exemplo criado em {directory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
