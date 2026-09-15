"""Regras de relevância temporal e prioridade de fontes por campo."""

from typing import Literal

ObservationSource = Literal["lab", "clinician", "context", "fhir"]

# Janela em semanas gestacionais: |obs_week - case_week| <= window
RELEVANCE_WINDOW_WEEKS: dict[str, int] = {
    "plgf": 2,
    "sflt1_plgf_ratio": 2,
    "uta_pi": 3,
    "sbp": 0,
    "dbp": 0,
    "bmi": 42,
    "diabetes": 42,
    "chronic_hypertension": 42,
}

# Campos que só aceitam laboratório (ou entrada manual em papel pelo clínico)
LAB_ONLY_FIELDS = frozenset({"plgf", "uta_pi", "sflt1_plgf_ratio"})

# Campos só do clínico na consulta
CLINICIAN_ONLY_FIELDS = frozenset({
    "sbp", "dbp", "diabetes", "chronic_hypertension",
})

# Campos de contexto (gravidez / registo)
CONTEXT_FIELDS = frozenset({"bmi"})

DIABETES_LABELS = {
    0: "none",
    1: "type1",
    2: "type2",
    3: "gestational",
}
DIABETES_VALUES = {v: k for k, v in DIABETES_LABELS.items()}
