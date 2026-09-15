"""Observações clínicas, alertas e painel de laboratório."""

from fastapi import APIRouter, HTTPException, Depends, Query
from auth.dependencies import require_role
from auth.authorization import require_pregnancy_access
from models.schemas import LabObservationInput
from services import assessment_workflow as workflow
from services.observations import annotate_relevance, pick_best_observation

router = APIRouter(prefix="/clinical", tags=["clinical"])


@router.get("/pregnancies/{pregnancy_id}/observations")
def list_observations(
    pregnancy_id: str,
    gestational_week: int | None = Query(None, ge=4, le=42),
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_pregnancy_access(pregnancy_id, user)
    observations = workflow.list_observations_for_pregnancy(pregnancy_id)
    if gestational_week is not None:
        observations = annotate_relevance(observations, gestational_week)
    return observations


@router.get("/pregnancies/{pregnancy_id}/lab-panel")
def lab_panel(
    pregnancy_id: str,
    gestational_week: int | None = Query(None, ge=4, le=42),
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_pregnancy_access(pregnancy_id, user)
    return workflow.get_recent_lab_panel(pregnancy_id, gestational_week)


@router.post("/lab")
def ingest_lab(
    data: LabObservationInput,
    user: dict = Depends(require_role("doctor", "admin")),
):
    """Simula chegada de resultados de laboratório (sem FHIR)."""
    require_pregnancy_access(data.pregnancy_id, user)
    values = {k: v for k, v in {
        "plgf": data.plgf,
        "uta_pi": data.uta_pi,
        "sflt1_plgf_ratio": data.sflt1_plgf_ratio,
    }.items() if v is not None}
    if not values:
        raise HTTPException(status_code=422, detail="Indique pelo menos um marcador.")

    try:
        created = workflow.create_lab_observations(
            data.pregnancy_id, data.gestational_week, values, source="lab",
        )
        case = workflow.get_or_create_case(data.pregnancy_id, data.gestational_week)
        return {
            "observations": created,
            "assessment_case_id": case["id"],
            "alerts": workflow.get_clinical_alerts(data.pregnancy_id),
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/pregnancies/{pregnancy_id}/alerts")
def clinical_alerts(
    pregnancy_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_pregnancy_access(pregnancy_id, user)
    return workflow.get_clinical_alerts(pregnancy_id)


@router.get("/pregnancies/{pregnancy_id}/merge-preview")
def merge_preview(
    pregnancy_id: str,
    gestational_week: int = Query(..., ge=4, le=42),
    user: dict = Depends(require_role("doctor", "admin")),
):
    """Pré-visualização do merge para o formulário de avaliação."""
    require_pregnancy_access(pregnancy_id, user)
    try:
        features, merge_meta, annotated = workflow.merge_features_for_case(
            pregnancy_id, gestational_week,
        )
        lab_panel = workflow.get_recent_lab_panel(pregnancy_id, gestational_week)
        lab_readonly = {
            f: pick_best_observation(annotated, f, gestational_week)
            for f in ("plgf", "uta_pi", "sflt1_plgf_ratio")
        }
        return {
            "features": features,
            "merge_meta": merge_meta,
            "lab_panel": lab_panel,
            "lab_readonly": lab_readonly,
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/pregnancies/{pregnancy_id}/risk-alerts")
def risk_alerts(
    pregnancy_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    """
    Alertas clínicos baseados no risco: alto/moderado, progressão, dados em falta.
    Inclui SHAP, recomendação e confiança da previsão da última avaliação.
    """
    require_pregnancy_access(pregnancy_id, user)
    try:
        return workflow.get_risk_alerts_for_pregnancy(pregnancy_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
