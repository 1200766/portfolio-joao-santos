from fastapi import APIRouter, HTTPException, Depends
from models.schemas import AssessmentInput, RecalcInput
from auth.dependencies import require_role
from auth.authorization import require_pregnancy_access
from core.database import db_clinical
from services import assessment_workflow as workflow

import traceback

router = APIRouter(prefix="/assessments", tags=["assessments"])


def _tables_ready() -> bool:
    try:
        db_clinical().table("clinical_observations").select("id").limit(1).execute()
        return True
    except Exception:
        return False


@router.post("")
def create_assessment(
    data: AssessmentInput,
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_pregnancy_access(data.pregnancy_id, user)
    if data.dbp >= data.sbp:
        raise HTTPException(
            status_code=422,
            detail="A pressão diastólica deve ser inferior à sistólica.",
        )

    if not _tables_ready():
        raise HTTPException(
            status_code=503,
            detail=(
                "Configure SUPABASE_SECRET_KEY no .env e execute "
                "001_clinical_data_model.sql e 002_rls_clinical_tables.sql no Supabase."
            ),
        )

    try:
        workflow.get_or_create_case(data.pregnancy_id, data.gestational_week)
        workflow.create_clinician_observations_from_form(
            data.pregnancy_id,
            data.gestational_week,
            sbp=data.sbp,
            dbp=data.dbp,
            diabetes=data.diabetes,
            chronic_hypertension=data.chronic_hypertension,
            uta_pi=data.uta_pi,
            plgf=data.plgf,
            sflt1_plgf_ratio=data.sflt1_plgf_ratio,
            manual_lab_fields=data.manual_lab_fields,
        )
        return workflow.run_assessment_snapshot(
            data.pregnancy_id,
            data.gestational_week,
            "clinician",
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/recalculate")
def recalculate_assessment(
    data: RecalcInput,
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_pregnancy_access(data.pregnancy_id, user)
    if not _tables_ready():
        raise HTTPException(status_code=503, detail="Migração SQL em falta.")

    try:
        return workflow.run_assessment_snapshot(
            data.pregnancy_id,
            data.gestational_week,
            "recalc_request",
            assessment_case_id=data.assessment_case_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{pregnancy_id}/timeline")
def get_risk_timeline(
    pregnancy_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    """
    1 ponto por semana gestacional (snapshot mais recente),
    com campo 'history' contendo versões anteriores da mesma semana.
    Usado pelo gráfico e pelo histórico com dropdown.
    """
    require_pregnancy_access(pregnancy_id, user)
    try:
        return workflow.get_risk_timeline(pregnancy_id)
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/{pregnancy_id}")
def list_assessments(
    pregnancy_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    """Todos os snapshots (imutáveis), ordenados por semana e data de cálculo."""
    require_pregnancy_access(pregnancy_id, user)
    result = db_clinical().table("assessments") \
        .select("*") \
        .eq("pregnancy_id", pregnancy_id) \
        .order("gestational_week", desc=True) \
        .order("computed_at", desc=True) \
        .execute()
    return result.data
