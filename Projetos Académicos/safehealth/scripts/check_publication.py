#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {
    ".h",
    ".ino",
    ".php",
    ".sql",
    ".md",
    ".env",
    ".js",
    ".css",
    ".html",
    ".json",
    ".py",
    ".txt",
    ".yaml",
    ".yml",
}
FORBIDDEN_NAMES = {
    ".DS_Store",
    ".Rhistory",
    ".env",
    "config.h",
    "passwords.local.sql",
}
FORBIDDEN_SUFFIXES = {".zip", ".pcap", ".pcapng", ".key", ".pem", ".p12"}
MAX_FILE_SIZE = 10 * 1024 * 1024
RESERVED_EMAIL_DOMAINS = {
    "example.com",
    "example.net",
    "example.org",
    "example.invalid",
    "example.test",
}
PERSONAL_PATH_PATTERN = re.compile(
    r"(?:/" + "Users/" + r"[^\s`\"']+|/" + "home/" +
    r"[^\s`\"']+|[A-Za-z]:\\" + "Users\\" + r"[^\s`\"']+)",
    re.IGNORECASE,
)
PATTERNS = {
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "JWT-like token": re.compile(r"\beyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}"),
    "private IPv4 host": re.compile(
        r"(?<![\d.])(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|"
        r"192\.168\.\d{1,3}\.\d{1,3}|"
        r"172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3})(?![\d.])"
    ),
    "caminho pessoal absoluto": PERSONAL_PATH_PATTERN,
    "número académico": re.compile(r"(?<!\d)\d{7}(?!\d)"),
}
EMAIL_PATTERN = re.compile(
    r"(?i)\b[A-Z0-9._%+-]+@([A-Z0-9.-]+\.[A-Z]{2,})\b"
)
SECRET_ASSIGNMENT = re.compile(
    r"(?ix)\b(?:password|passwd|pwd|secret|token|api[_-]?key|device[_-]?key|"
    r"wifi[_-]?(?:password|pass)|ssid)\b\s*[:=]\s*[\"']([^\"']+)[\"']"
)
SECRET_DEFINE = re.compile(
    r"(?ix)^\s*\#define\s+\w*(?:password|passwd|secret|token|key|ssid)\w*\s+"
    r"[\"']([^\"']+)[\"']"
)
SECRET_ENV_ASSIGNMENT = re.compile(
    r"(?ix)^\s*[A-Z0-9_]*(?:PASSWORD|PASS|SECRET|TOKEN|KEY|SSID)[A-Z0-9_]*"
    r"\s*=\s*[\"']?([^\"'\s#]+)"
)
PLACEHOLDER_MARKERS = (
    "YOUR_",
    "CHANGE_ME",
    "REPLACE_ME",
    "PLACEHOLDER",
    "EXAMPLE",
    "DEMO_",
)


def is_placeholder(value: str) -> bool:
    upper = value.strip().upper()
    return not upper or any(marker in upper for marker in PLACEHOLDER_MARKERS)


def add_problem(problems: list[str], label: str, relative: Path, line: int | None = None) -> None:
    location = f"{relative}:{line}" if line is not None else str(relative)
    # Nunca incluir no output o valor que originou a ocorrência.
    problems.append(f"{label}: {location}")


def scan_tree(root: Path) -> list[str]:
    """Devolve apenas categorias e localizações; nunca inclui o valor detetado."""
    problems: list[str] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(root)
        if path.stat().st_size > MAX_FILE_SIZE:
            add_problem(problems, "ficheiro superior a 10 MiB", relative)
        if (
            path.name in FORBIDDEN_NAMES
            or (path.name.startswith(".env.") and path.name != ".env.example")
            or path.suffix.lower() in FORBIDDEN_SUFFIXES
        ):
            add_problem(problems, "artefacto excluído presente", relative)
            continue
        if PATTERNS["número académico"].search(str(relative)):
            add_problem(problems, "número académico no nome", relative)
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name != ".env.example":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for line_number, line in enumerate(text.splitlines(), 1):
            for label, pattern in PATTERNS.items():
                if pattern.search(line):
                    add_problem(problems, label, relative, line_number)

            for email_match in EMAIL_PATTERN.finditer(line):
                domain = email_match.group(1).lower()
                if domain not in RESERVED_EMAIL_DOMAINS:
                    add_problem(
                        problems,
                        "email fora de domínio reservado",
                        relative,
                        line_number,
                    )

            for assignment in SECRET_ASSIGNMENT.finditer(line):
                if not is_placeholder(assignment.group(1)):
                    add_problem(
                        problems,
                        "segredo literal não-placeholder",
                        relative,
                        line_number,
                    )

            define = SECRET_DEFINE.search(line)
            if define and not is_placeholder(define.group(1)):
                add_problem(
                    problems,
                    "segredo literal não-placeholder",
                    relative,
                    line_number,
                )

            env_assignment = (
                SECRET_ENV_ASSIGNMENT.search(line)
                if path.suffix.lower() == ".env" or path.name.startswith(".env")
                else None
            )
            if env_assignment and not is_placeholder(env_assignment.group(1)):
                add_problem(
                    problems,
                    "segredo literal não-placeholder",
                    relative,
                    line_number,
                )

    return problems


def main() -> int:
    problems = scan_tree(ROOT)

    if problems:
        print("Falha na verificação:")
        for problem in problems:
            print(f"- {problem}")
        return 1

    required = [
        ROOT / ".env.example",
        ROOT / "firmware" / "config.example.h",
        ROOT / "AUTHORS.md",
        ROOT / "CONTRIBUTIONS.md",
        ROOT / "RIGHTS.md",
    ]
    missing = [str(path.relative_to(ROOT)) for path in required if not path.exists()]
    if missing:
        print("Ficheiros obrigatórios em falta: " + ", ".join(missing))
        return 1

    print("Verificação estática concluída sem ocorrências.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
