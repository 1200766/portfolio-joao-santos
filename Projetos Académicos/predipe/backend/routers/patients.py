from fastapi import APIRouter, HTTPException, Depends
from models.schemas import PatientInput
from auth.dependencies import require_role
from core.database import db_clinical
from utils.clinical import calculate_age, calculate_parity
from datetime import date

router = APIRouter(prefix="/patients", tags=["patients"])


@router.post("")
def create_patient(
    data: PatientInput,
    user: dict = Depends(require_role("doctor", "admin")),
):
    doctor_id = user["id"] if user["role"] == "doctor" else data.doctor_id
    row = {
        "doctor_id":      doctor_id,
        "patient_code":   data.patient_code,
        "date_of_birth":  str(data.date_of_birth),
        "parity_inicial": data.parity_inicial,
    }
    row["active"] = True

    database = db_clinical()
    result = database.table("patients").insert(row).execute()

    if not result.data:
        raise HTTPException(status_code=400, detail="Erro ao registar paciente.")

    return result.data[0]


@router.get("")
def list_patients(user: dict = Depends(require_role("doctor", "admin"))):
    """Lista todos os pacientes do médico autenticado."""
    database = db_clinical()
    query = database.table("patients") \
        .select("*, pregnancies(id, pe_outcome, assessments(risk_level, created_at))")

    if user["role"] == "doctor":
        query = query.eq("doctor_id", user["id"]).eq("active", True)

    result = query.order("created_at", desc=True).execute()

    patients = []
    for p in result.data:
        # Calcula última avaliação e risco actual
        all_assessments = [
            a
            for preg in (p.get("pregnancies") or [])
            for a in (preg.get("assessments") or [])
        ]
        all_assessments.sort(key=lambda a: a["created_at"], reverse=True)

        last_risk    = all_assessments[0]["risk_level"]   if all_assessments else None
        last_date    = all_assessments[0]["created_at"]   if all_assessments else None
        parity       = calculate_parity(p["id"], p["parity_inicial"], database)
        maternal_age = calculate_age(
            date.fromisoformat(p["date_of_birth"]), date.today()
        )
        full_name = p.get("full_name") or p.get("patient_code")

        patients.append({
            **p,
            "full_name":           full_name,
            "parity":              parity,
            "maternal_age":        maternal_age,
            "last_risk_level":     last_risk,
            "last_assessment_date": last_date,
        })

    return patients


@router.get("/{patient_id}")
def get_patient(
    patient_id: str,
    user: dict = Depends(require_role("doctor", "admin")),
):
    database = db_clinical()
    result = database.table("patients") \
        .select("*") \
        .eq("id", patient_id) \
        .single() \
        .execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="Paciente não encontrada.")

    p = result.data
    if user["role"] == "doctor":
        if p.get("doctor_id") != user["id"] or p.get("active") is False:
            raise HTTPException(status_code=404, detail="Paciente não encontrada.")

    parity       = calculate_parity(patient_id, p["parity_inicial"], database)
    maternal_age = calculate_age(
        date.fromisoformat(p["date_of_birth"]), date.today()
    )
    full_name = p.get("full_name") or p.get("patient_code")

    return {**p, "full_name": full_name, "parity": parity, "maternal_age": maternal_age}
