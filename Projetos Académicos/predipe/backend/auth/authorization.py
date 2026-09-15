"""Verificações de pertença para recursos clínicos.

Estas verificações são deliberadamente feitas no backend antes de qualquer
leitura ou mutação. O cliente ``service_role`` ignora RLS, pelo que nunca deve
ser usado sem uma verificação equivalente na fronteira da API.
"""

from fastapi import HTTPException

from core.database import db_clinical


def _not_found(resource: str) -> HTTPException:
    # Uma resposta 404 evita confirmar a existência de registos de outro médico.
    return HTTPException(status_code=404, detail=f"{resource} não encontrado.")


def _authorization_db():
    try:
        return db_clinical()
    except RuntimeError as error:
        raise HTTPException(
            status_code=503,
            detail="Backend clínico não configurado.",
        ) from error


def require_patient_access(patient_id: str, user: dict) -> dict:
    result = _authorization_db().table("patients") \
        .select("id, doctor_id, active, parity_inicial") \
        .eq("id", patient_id) \
        .limit(1) \
        .execute()

    if not result.data:
        raise _not_found("Paciente")

    patient = result.data[0]
    if user["role"] == "doctor" and (
        patient.get("doctor_id") != user["id"]
        or patient.get("active") is False
    ):
        raise _not_found("Paciente")

    return patient


def require_pregnancy_access(pregnancy_id: str, user: dict) -> dict:
    result = _authorization_db().table("pregnancies") \
        .select("id, patient_id") \
        .eq("id", pregnancy_id) \
        .limit(1) \
        .execute()

    if not result.data:
        raise _not_found("Gravidez")

    pregnancy = result.data[0]
    require_patient_access(pregnancy["patient_id"], user)
    return pregnancy
