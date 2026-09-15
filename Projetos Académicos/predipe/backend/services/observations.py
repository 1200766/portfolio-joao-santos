"""Observações clínicas, relevância temporal e merge para o modelo."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from services.observation_config import (
    CLINICIAN_ONLY_FIELDS,
    CONTEXT_FIELDS,
    DIABETES_LABELS,
    DIABETES_VALUES,
    LAB_ONLY_FIELDS,
    RELEVANCE_WINDOW_WEEKS,
)


def is_relevant(field: str, obs_gestational_week: int, case_gestational_week: int) -> bool:
    window = RELEVANCE_WINDOW_WEEKS.get(field, 2)
    if field in ("sbp", "dbp"):
        return obs_gestational_week == case_gestational_week
    return abs(obs_gestational_week - case_gestational_week) <= window


def annotate_relevance(
    observations: list[dict],
    case_gestational_week: int,
) -> list[dict]:
    out = []
    for obs in observations:
        field = obs["field"]
        gw = obs["gestational_week"]
        out.append({
            **obs,
            "is_relevant": is_relevant(field, gw, case_gestational_week),
        })
    return out


def _accepts_source_for_field(field: str, obs: dict) -> bool:
    source = obs["source"]
    if field in LAB_ONLY_FIELDS:
        if source in ("lab", "fhir"):
            return True
        if source == "clinician" and obs.get("manual_lab_entry"):
            return True
        return False
    if field in CLINICIAN_ONLY_FIELDS:
        return source == "clinician"
    if field in CONTEXT_FIELDS:
        return source in ("clinician", "context", "fhir")
    return False


def pick_best_observation(
    observations: list[dict],
    field: str,
    case_gestational_week: int,
) -> dict | None:
    candidates = [
        o for o in observations
        if o["field"] == field
        and _accepts_source_for_field(field, o)
        and is_relevant(field, o["gestational_week"], case_gestational_week)
    ]
    if not candidates:
        return None
    return max(candidates, key=lambda o: o.get("recorded_at") or o.get("created_at", ""))


def build_observation_row(
    pregnancy_id: str,
    field: str,
    value: float,
    source: str,
    gestational_week: int,
    *,
    unit: str | None = None,
    manual_lab_entry: bool = False,
    notes: str | None = None,
    fhir_id: str | None = None,
    fhir_provenance: dict | None = None,
    loinc_code: str | None = None,
) -> dict:
    return {
        "pregnancy_id": pregnancy_id,
        "field": field,
        "value": value,
        "unit": unit,
        "source": source,
        "gestational_week": gestational_week,
        "recorded_at": datetime.now(timezone.utc).isoformat(),
        "manual_lab_entry": manual_lab_entry,
        "notes": notes,
        "fhir_id": fhir_id,
        "fhir_provenance": fhir_provenance,
        "loinc_code": loinc_code,
    }
