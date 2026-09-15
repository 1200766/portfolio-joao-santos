"""
Adaptador FHIR (esqueleto).
Autenticação: API key em header X-FHIR-API-Key (configurar FHIR_API_KEY no .env).
"""

import os
import secrets
from fastapi import APIRouter, HTTPException, Header, Depends
from pydantic import BaseModel, Field
from typing import Any, Optional

from services import assessment_workflow as workflow

router = APIRouter(prefix="/fhir", tags=["fhir"])

# Chave do adaptador LIS/FHIR — NÃO é a SUPABASE_PUBLISHABLE_KEY.
# Não existe valor por omissão: a integração fica indisponível até ser configurada.
FHIR_API_KEY = (os.getenv("FHIR_API_KEY") or "").strip()
FHIR_INGEST_ENABLED = (os.getenv("FHIR_INGEST_ENABLED") or "false").strip().lower() \
    in {"1", "true", "yes"}


def verify_fhir_key(x_fhir_api_key: str = Header(..., alias="X-FHIR-API-Key")):
    if not FHIR_INGEST_ENABLED:
        raise HTTPException(
            status_code=503,
            detail="Integração FHIR desativada.",
        )
    if not FHIR_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Integração FHIR não configurada.",
        )
    if not secrets.compare_digest(x_fhir_api_key, FHIR_API_KEY):
        raise HTTPException(
            status_code=401,
            detail="API key FHIR inválida.",
        )
    return True


class FhirObservationIn(BaseModel):
    pregnancy_id: str
    gestational_week: int = Field(..., ge=4, le=42)
    plgf: Optional[float] = None
    uta_pi: Optional[float] = Field(None, ge=0.5, le=4.0)
    sflt1_plgf_ratio: Optional[float] = None
    fhir_id: Optional[str] = None
    fhir_provenance: Optional[dict[str, Any]] = None
    loinc_codes: Optional[dict[str, str]] = None
    auto_compute_partial: bool = False


@router.post("/Observation", dependencies=[Depends(verify_fhir_key)])
def ingest_observation(body: FhirObservationIn):
    """
    Entrada simplificada de Observation FHIR já mapeada.
    Fase seguinte: parser completo de recurso FHIR R4.
    """
    values = {}
    if body.plgf is not None:
        values["plgf"] = body.plgf
    if body.uta_pi is not None:
        values["uta_pi"] = body.uta_pi
    if body.sflt1_plgf_ratio is not None:
        values["sflt1_plgf_ratio"] = body.sflt1_plgf_ratio

    if not values:
        raise HTTPException(status_code=422, detail="Nenhum marcador laboratorial fornecido.")

    try:
        created = workflow.create_lab_observations(
            body.pregnancy_id,
            body.gestational_week,
            values,
            source="fhir",
            fhir_id=body.fhir_id,
            fhir_provenance=body.fhir_provenance,
            loinc_codes=body.loinc_codes,
        )
        case = workflow.get_or_create_case(body.pregnancy_id, body.gestational_week)

        snapshot = None
        if body.auto_compute_partial:
            try:
                snapshot = workflow.run_assessment_snapshot(
                    body.pregnancy_id,
                    body.gestational_week,
                    "partial_auto",
                    assessment_case_id=case["id"],
                )
            except ValueError:
                snapshot = None

        return {
            "observations": created,
            "assessment_case_id": case["id"],
            "snapshot": snapshot,
            "alerts": workflow.get_clinical_alerts(body.pregnancy_id),
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/Observation/recalculate", dependencies=[Depends(verify_fhir_key)])
def fhir_trigger_recalc(body: FhirObservationIn):
    """Após chegada de lab — o médico confirma via UI; endpoint para integração automática."""
    try:
        workflow.create_lab_observations(
            body.pregnancy_id,
            body.gestational_week,
            {k: v for k, v in {
                "plgf": body.plgf,
                "uta_pi": body.uta_pi,
                "sflt1_plgf_ratio": body.sflt1_plgf_ratio,
            }.items() if v is not None},
            source="fhir",
            fhir_id=body.fhir_id,
            fhir_provenance=body.fhir_provenance,
        )
        case = workflow.get_or_create_case(body.pregnancy_id, body.gestational_week)
        snapshot = workflow.run_assessment_snapshot(
            body.pregnancy_id,
            body.gestational_week,
            "lab_arrival",
            assessment_case_id=case["id"],
        )
        return snapshot
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
