#!/usr/bin/env python3
"""Descarrega registos PN00 diretamente da fonte pública do PhysioNet."""

from __future__ import annotations

import argparse
import shutil
import sys
import urllib.request
from pathlib import Path


BASE_URL = "https://physionet.org/files/siena-scalp-eeg/1.0.0/PN00"
AVAILABLE_RECORDS = {f"PN00-{number}" for number in range(1, 6)}
DEFAULT_RECORDS = ("PN00-1", "PN00-2", "PN00-4")


def normalise_record(value: str) -> str:
    record = value.removesuffix(".edf")
    if record not in AVAILABLE_RECORDS:
        allowed = ", ".join(sorted(AVAILABLE_RECORDS))
        raise argparse.ArgumentTypeError(
            f"Registo desconhecido: {value}. Valores permitidos: {allowed}."
        )
    return record


def download(record: str, output_dir: Path, force: bool) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    destination = output_dir / f"{record}.edf"
    temporary = destination.with_suffix(".edf.part")

    if destination.exists() and not force:
        print(f"A manter {destination}; use --force para substituir.")
        return destination

    url = f"{BASE_URL}/{record}.edf"
    request = urllib.request.Request(url, headers={"User-Agent": "medibrain-eeg-study/1.0"})
    print(f"A descarregar {url}")

    try:
        with urllib.request.urlopen(request) as response, temporary.open("wb") as stream:
            shutil.copyfileobj(response, stream)
        temporary.replace(destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    print(f"Guardado em {destination}")
    return destination


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Descarrega ficheiros PN00 da Siena Scalp EEG Database."
    )
    parser.add_argument(
        "records",
        nargs="*",
        type=normalise_record,
        default=list(DEFAULT_RECORDS),
        help="PN00-1 a PN00-5; predefinição: PN00-1 PN00-2 PN00-4",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("data"),
        help="Pasta de destino (predefinição: data).",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Substitui ficheiros que já existam.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    print("Fonte: Siena Scalp EEG Database v1.0.0 (PhysioNet)")
    print("Licença dos dados: CC BY 4.0")
    print("DOI: https://doi.org/10.13026/5d4a-j060")
    try:
        for record in args.records:
            download(record, args.output_dir, args.force)
    except Exception as exc:
        print(f"Erro na descarga: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
