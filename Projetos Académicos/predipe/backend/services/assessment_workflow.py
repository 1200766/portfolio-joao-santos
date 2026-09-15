"""Episódios de avaliação, merge de observações e snapshots de risco."""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any

from core.database import db_clinical
from services.observations import (
    annotate_relevance,
    build_observation_row,
    pick_best_observation,
)
from services.observation_config import DIABETES_LABELS, DIABETES_VALUES
from services.risk_model import evaluate_case_clinically
from utils.clinical import calculate_age, calculate_parity

# Semanas de diferença a partir das quais um lab é considerado "desactualizado"
STALE_LAB_THRESHOLD_WEEKS = 4


def _load_pregnancy_context(pregnancy_id: str) -> dict:
    pregnancy = db_clinical().table("pregnancies") \
        .select("*, patients(date_of_birth, parity_inicial, id)") \
        .eq("id", pregnancy_id) \
        .single() \
        .execute()
    if not pregnancy.data:
        raise ValueError("Gravidez não encontrada.")
    return pregnancy.data


def list_observations_for_pregnancy(pregnancy_id: str) -> list[dict]:
    result = db_clinical().table("clinical_observations") \
        .select("*") \
        .eq("pregnancy_id", pregnancy_id) \
        .order("recorded_at", desc=True) \
        .execute()
    return result.data or []


def get_or_create_case(pregnancy_id: str, gestational_week: int) -> dict:
    existing = db_clinical().table("assessment_cases") \
        .select("*") \
        .eq("pregnancy_id", pregnancy_id) \
        .eq("gestational_week", gestational_week) \
        .order("created_at", desc=True) \
        .limit(1) \
        .execute()

    if existing.data:
        return existing.data[0]

    created = db_clinical().table("assessment_cases").insert({
        "pregnancy_id": pregnancy_id,
        "gestational_week": gestational_week,
        "status": "pending_lab",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).execute()

    if not created.data:
        raise RuntimeError("Erro ao criar assessment_case.")
    return created.data[0]


def insert_observations(rows: list[dict]) -> list[dict]:
    """UPSERT por (pregnancy_id, field, source, gestational_week) — evita duplicados."""
    if not rows:
        return []
    result = db_clinical().table("clinical_observations") \
        .upsert(rows, on_conflict="pregnancy_id,field,source,gestational_week") \
        .execute()
    return result.data or []


def create_clinician_observations_from_form(
    pregnancy_id: str,
    gestational_week: int,
    *,
    sbp: int | None = None,
    dbp: int | None = None,
    diabetes: str = "none",
    chronic_hypertension: bool = False,
    uta_pi: float | None = None,
    plgf: float | None = None,
    sflt1_plgf_ratio: float | None = None,
    manual_lab_fields: dict[str, bool] | None = None,
) -> list[dict]:
    manual = manual_lab_fields or {}
    rows: list[dict] = []

    if sbp is not None:
        rows.append(build_observation_row(
            pregnancy_id, "sbp", float(sbp), "clinician", gestational_week, unit="mmHg",
        ))
    if dbp is not None:
        rows.append(build_observation_row(
            pregnancy_id, "dbp", float(dbp), "clinician", gestational_week, unit="mmHg",
        ))

    rows.append(build_observation_row(
        pregnancy_id, "diabetes", float(DIABETES_VALUES.get(diabetes, 0)),
        "clinician", gestational_week, unit="enum",
    ))
    rows.append(build_observation_row(
        pregnancy_id, "chronic_hypertension", float(int(chronic_hypertension)),
        "clinician", gestational_week, unit="bool",
    ))

    if uta_pi is not None:
        rows.append(build_observation_row(
            pregnancy_id, "uta_pi", uta_pi, "clinician", gestational_week,
            unit="ratio", manual_lab_entry=manual.get("uta_pi", False),
        ))
    if plgf is not None:
        rows.append(build_observation_row(
            pregnancy_id, "plgf", plgf, "clinician", gestational_week,
            unit="pg/mL", manual_lab_entry=manual.get("plgf", False),
        ))
    if sflt1_plgf_ratio is not None:
        rows.append(build_observation_row(
            pregnancy_id, "sflt1_plgf_ratio", sflt1_plgf_ratio, "clinician",
            gestational_week, unit="ratio",
            manual_lab_entry=manual.get("sflt1_plgf_ratio", False),
        ))

    return insert_observations(rows)


def create_lab_observations(
    pregnancy_id: str,
    gestational_week: int,
    values: dict[str, float],
    *,
    source: str = "lab",
    fhir_id: str | None = None,
    fhir_provenance: dict | None = None,
    loinc_codes: dict[str, str] | None = None,
) -> list[dict]:
    units = {
        "plgf": "pg/mL",
        "uta_pi": "ratio",
        "sflt1_plgf_ratio": "ratio",
    }
    loinc_codes = loinc_codes or {}
    rows = [
        build_observation_row(
            pregnancy_id, field, value, source, gestational_week,
            unit=units.get(field),
            fhir_id=fhir_id,
            fhir_provenance=fhir_provenance,
            loinc_code=loinc_codes.get(field),
        )
        for field, value in values.items()
        if field in ("plgf", "uta_pi", "sflt1_plgf_ratio") and value is not None
    ]
    return insert_observations(rows)


def merge_features_for_case(
    pregnancy_id: str,
    gestational_week: int,
    observations: list[dict] | None = None,
) -> tuple[dict, dict, list[dict]]:
    """Devolve (features para modelo, metadados de merge, observações anotadas)."""
    preg = _load_pregnancy_context(pregnancy_id)
    patient = preg["patients"]
    observations = observations or list_observations_for_pregnancy(pregnancy_id)
    annotated = annotate_relevance(observations, gestational_week)

    maternal_age = calculate_age(
        date.fromisoformat(patient["date_of_birth"]), date.today()
    )
    parity = calculate_parity(patient["id"], patient["parity_inicial"], db_clinical())

    sbp_obs = pick_best_observation(annotated, "sbp", gestational_week)
    dbp_obs = pick_best_observation(annotated, "dbp", gestational_week)
    sbp = int(sbp_obs["value"]) if sbp_obs else None
    dbp = int(dbp_obs["value"]) if dbp_obs else None
    computed_map = None
    if sbp is not None and dbp is not None:
        computed_map = round((sbp + 2 * dbp) / 3, 2)

    diabetes_obs = pick_best_observation(annotated, "diabetes", gestational_week)
    diabetes_val = int(diabetes_obs["value"]) if diabetes_obs else 0
    diabetes_label = DIABETES_LABELS.get(diabetes_val, "none")

    ht_obs = pick_best_observation(annotated, "chronic_hypertension", gestational_week)
    chronic_ht = bool(int(ht_obs["value"])) if ht_obs else False

    def _lab_val(field: str):
        o = pick_best_observation(annotated, field, gestational_week)
        return float(o["value"]) if o else None

    features = {
        "maternal_age": maternal_age,
        "parity": parity,
        "previous_pe": int(bool(preg["prior_pe"])),
        "prior_nephropathy_or_proteinuria": int(bool(preg["prior_nephropathy_or_proteinuria"])),
        "bmi": preg["bmi"],
        "diabetes": 0 if diabetes_label == "none" else 1,
        "chronic_hypertension": int(chronic_ht),
        "sbp": sbp,
        "dbp": dbp,
        "map": computed_map,
        "uta_pi": _lab_val("uta_pi"),
        "plgf": _lab_val("plgf"),
        "sflt1_plgf_ratio": _lab_val("sflt1_plgf_ratio"),
    }

    merge_meta = {
        "sources_used": {
            k: (pick_best_observation(annotated, k, gestational_week) or {}).get("source")
            for k in ("plgf", "uta_pi", "sflt1_plgf_ratio", "sbp", "dbp")
        },
        "observation_ids_used": {
            k: (pick_best_observation(annotated, k, gestational_week) or {}).get("id")
            for k in ("plgf", "uta_pi", "sflt1_plgf_ratio", "sbp", "dbp", "diabetes", "chronic_hypertension")
        },
    }

    return features, merge_meta, annotated


def infer_case_status(features: dict, has_snapshot: bool) -> str:
    has_bp = features.get("sbp") is not None and features.get("dbp") is not None
    has_lab = any(features.get(f) is not None for f in ("plgf", "uta_pi", "sflt1_plgf_ratio"))
    if has_snapshot and has_lab and has_bp:
        return "computed"
    if has_bp:
        # FIX: se tem PA (com ou sem lab), o caso está ready — não pending_lab
        return "ready"
    if has_lab:
        return "pending_lab"
    return "pending_lab"


def run_assessment_snapshot(
    pregnancy_id: str,
    gestational_week: int,
    triggered_by: str,
    *,
    assessment_case_id: str | None = None,
) -> dict[str, Any]:
    case = get_or_create_case(pregnancy_id, gestational_week)
    case_id = assessment_case_id or case["id"]

    features, merge_meta, annotated = merge_features_for_case(
        pregnancy_id, gestational_week,
    )

    if features.get("sbp") and features.get("dbp") and features["dbp"] >= features["sbp"]:
        raise ValueError("A pressão diastólica deve ser inferior à sistólica.")

    clinical_output = evaluate_case_clinically(features)
    risk_probability = clinical_output["predicted_probability"]
    risk_level = clinical_output["risk_level"]
    risk_score = round(risk_probability * 100, 1)

    missing_fields = clinical_output.get("missing_data") or {}
    features_used = {k: v for k, v in features.items() if v is not None}

    diabetes_obs = pick_best_observation(annotated, "diabetes", gestational_week)
    diabetes_label = (
        DIABETES_LABELS.get(int(diabetes_obs["value"]), "none")
        if diabetes_obs else "none"
    )

    row = {
        "pregnancy_id": pregnancy_id,
        "gestational_week": gestational_week,
        "assessment_case_id": case_id,
        "features_used": features_used,
        "missing_fields": missing_fields,
        "triggered_by": triggered_by,
        "computed_at": datetime.now(timezone.utc).isoformat(),
        "risk_probability": risk_probability,
        "risk_score": risk_score,
        "risk_level": risk_level,
        "shap_values": clinical_output["shap_values"],
        "diabetes": diabetes_label,
        "chronic_hypertension": bool(features.get("chronic_hypertension")),
        "sbp": features.get("sbp"),
        "dbp": features.get("dbp"),
        "map": features.get("map"),
        "uta_pi": features.get("uta_pi"),
        "plgf": features.get("plgf"),
        "sflt1_plgf_ratio": features.get("sflt1_plgf_ratio"),
        # Campos clínicos persistidos para o histórico e alertas
        "risk_confidence":           clinical_output["risk_confidence"],
        "prediction_mode":           clinical_output["prediction_mode"],
        "suggested_action":          clinical_output["suggested_action"],
        "main_contributing_factors": clinical_output["main_contributing_factors"],
    }

    # assessments são sempre INSERT (histórico imutável — nunca upsert)
    result = db_clinical().table("assessments").insert(row).execute()
    if not result.data:
        raise RuntimeError("Erro ao guardar snapshot de avaliação.")

    new_status = infer_case_status(features, True)
    db_clinical().table("assessment_cases").update({
        "status": new_status,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", case_id).execute()

    snapshot = result.data[0]
    return {
        **snapshot,
        "risk_probability": risk_probability,
        "risk_score": risk_score,
        "risk_level": risk_level,
        "shap_values": clinical_output["shap_values"],
        "features_used": features_used,
        "merge_meta": merge_meta,
        "risk_confidence": clinical_output["risk_confidence"],
        "prediction_mode": clinical_output["prediction_mode"],
        "clinical_alert": clinical_output["clinical_alert"],
        "suggested_action": clinical_output["suggested_action"],
        "clinical_summary": clinical_output["clinical_summary"],
        "missing_data": missing_fields,
        "main_contributing_factors": clinical_output["main_contributing_factors"],
        "assessment_case_id": case_id,
        "triggered_by": triggered_by,
    }


def get_clinical_alerts(pregnancy_id: str) -> list[dict]:
    """Alertas contextuais para a ficha da paciente."""
    alerts: list[dict] = []
    observations = list_observations_for_pregnancy(pregnancy_id)
    cases = db_clinical().table("assessment_cases") \
        .select("*") \
        .eq("pregnancy_id", pregnancy_id) \
        .order("updated_at", desc=True) \
        .execute()
    cases_data = cases.data or []

    lab_recent = [o for o in observations if o["source"] in ("lab", "fhir")]
    if not lab_recent:
        return alerts

    latest_lab = max(lab_recent, key=lambda o: o["recorded_at"])
    gw = latest_lab["gestational_week"]
    case_for_week = next((c for c in cases_data if c["gestational_week"] == gw), None)

    snapshots = db_clinical().table("assessments") \
        .select("id, gestational_week, triggered_by, computed_at") \
        .eq("pregnancy_id", pregnancy_id) \
        .eq("gestational_week", gw) \
        .execute()
    snap_list = snapshots.data or []

    # FIX stale_lab: só dispara se a observação for de mais de N semanas atrás
    annotated = annotate_relevance(observations, gw)
    stale = [
        o for o in annotated
        if o["source"] in ("lab", "fhir")
        and not o["is_relevant"]
        and (gw - o["gestational_week"]) > STALE_LAB_THRESHOLD_WEEKS
    ]
    if stale:
        alerts.append({
            "type": "stale_lab",
            "severity": "info",
            "message": (
                f"Existem análises de laboratório com mais de {STALE_LAB_THRESHOLD_WEEKS} semanas. "
                "Solicite nova análise."
            ),
            "gestational_week": gw,
        })

    if not snap_list:
        # Caso A: lab chegou mas ainda não há consulta
        alerts.append({
            "type": "lab_without_consultation",
            "severity": "warning",
            "message": (
                f"Novos resultados de laboratório recebidos (semana {gw}). "
                "Complete a avaliação com os dados da consulta para calcular o risco."
            ),
            "gestational_week": gw,
        })
    elif case_for_week and any(s.get("triggered_by") == "clinician" for s in snap_list):
        # Caso C: já existe snapshot de consulta, mas lab chegou depois e não há recálculo
        has_lab_snapshot = any(
            s.get("triggered_by") in ("lab_arrival", "recalc_request") for s in snap_list
        )
        if not has_lab_snapshot:
            alerts.append({
                "type": "lab_after_assessment",
                "severity": "warning",
                "message": (
                    f"Novos resultados de laboratório disponíveis para a semana {gw}. "
                    "Recalcule o risco com os novos dados."
                ),
                "gestational_week": gw,
                "case_id": case_for_week["id"],
            })

    return alerts


def get_recent_lab_panel(pregnancy_id: str, reference_week: int | None = None) -> list[dict]:
    observations = list_observations_for_pregnancy(pregnancy_id)
    lab_obs = [o for o in observations if o["source"] in ("lab", "fhir")]
    if not lab_obs:
        return []

    if reference_week is None:
        reference_week = max(o["gestational_week"] for o in lab_obs)

    annotated = annotate_relevance(lab_obs, reference_week)
    by_field: dict[str, dict] = {}
    for o in annotated:
        f = o["field"]
        if f not in ("plgf", "uta_pi", "sflt1_plgf_ratio"):
            continue
        prev = by_field.get(f)
        if not prev or o["recorded_at"] > prev["recorded_at"]:
            by_field[f] = o

    return list(by_field.values())


def get_risk_timeline(pregnancy_id: str) -> list[dict]:
    """
    Devolve 1 ponto por semana gestacional (o snapshot mais recente),
    mais a lista completa de snapshots dessa semana como histórico.
    Usado pelo gráfico da ficha da paciente.
    """
    result = db_clinical().table("assessments") \
        .select("*") \
        .eq("pregnancy_id", pregnancy_id) \
        .order("gestational_week", desc=False) \
        .order("computed_at", desc=True) \
        .execute()

    all_snapshots = result.data or []
    if not all_snapshots:
        return []

    # Agrupa por semana gestacional
    by_week: dict[int, list[dict]] = {}
    for s in all_snapshots:
        gw = s["gestational_week"]
        by_week.setdefault(gw, []).append(s)

    timeline = []
    for gw in sorted(by_week.keys()):
        week_snapshots = by_week[gw]
        # O mais recente é o primeiro (já ordenado por computed_at desc)
        latest = week_snapshots[0]
        timeline.append({
            **latest,
            "history": week_snapshots[1:],  # versões anteriores desta semana
            "version_count": len(week_snapshots),
        })

    return timeline
