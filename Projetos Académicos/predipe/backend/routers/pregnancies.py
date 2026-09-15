from fastapi import APIRouter, HTTPException, Depends
from models.schemas import PregnancyInput
from auth.dependencies import require_role
from auth.authorization import require_patient_access, require_pregnancy_access
from core.database import db_clinical
from utils.clinical import calculate_prior_flags, calculate_pregnancy_number

router = APIRouter(prefix="/pregnancies", tags=["pregnancies"])


@router.post("")
def create_pregnancy(
    data: PregnancyInput,
    user: dict = Depends(require_role("doctor", "admin")),
):
    require_patient_access(data.patient_id, user)
    database = db_clinical()

    # Calcula antecedentes automaticamente
    prior = calculate_prior_flags(data.patient_id, database)

    result = database.table("pregnancies").insert({
        "patient_id":                       data.patient_id,
        "bmi":                              data.bmi,
        "prior_pe":                         prior["prior_pe"],
        "prior_nephropathy_or_proteinuria": prior["prior_nephropathy_or_proteinuria"],
        "started_at":                       str(data.started_at),
    }).execute()

    if not result.data:
        raise HTTPException(status_code=400, detail="Erro ao registar gravidez.")

    return result.data[0]


@router.get("/{patient_id}")
def list_pregnancies(
    patient_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    patient = require_patient_access(patient_id, user)
    parity_inicial = patient["parity_inicial"]
    database = db_clinical()

    result = database.table("pregnancies") \
        .select("*") \
        .eq("patient_id", patient_id) \
        .order("started_at", desc=True) \
        .execute()

    pregnancies = []
    for preg in result.data:
        pregnancies.append({
            **preg,
            "pregnancy_number": calculate_pregnancy_number(
                patient_id,
                parity_inicial,
                preg["started_at"],
                database,
            ),
        })

    return pregnancies


@router.patch("/{pregnancy_id}/close")
def close_pregnancy(
    pregnancy_id: str,
    body: dict,
    user: dict = Depends(require_role("doctor", "admin")),
):
    """Regista o fim de uma gravidez e o outcome (PE ou não)."""
    require_pregnancy_access(pregnancy_id, user)
    result = db_clinical().table("pregnancies").update({
        "ended_at":   body.get("ended_at"),
        "pe_outcome": body.get("pe_outcome"),
        "pe_subtype": body.get("pe_subtype"),
    }).eq("id", pregnancy_id).execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="Gravidez não encontrada.")

    return result.data[0]
