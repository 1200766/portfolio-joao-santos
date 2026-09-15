from fastapi import APIRouter, HTTPException, Depends
from models.schemas import DoctorInput, AdminPatientInput, ActiveToggle
from auth.dependencies import require_role
from core.database import db_clinical, supabase_admin

router = APIRouter(prefix="/admin", tags=["admin"])


def _require_admin(user: dict = Depends(require_role("admin"))):
    return user


@router.get("/doctors")
def list_doctors(_: dict = Depends(_require_admin)):
    result = db_clinical().table("users") \
        .select("id, name, role, active, created_at") \
        .eq("role", "doctor") \
        .order("created_at", desc=True) \
        .execute()
    return result.data


@router.post("/doctors")
def create_doctor(data: DoctorInput, _: dict = Depends(_require_admin)):
    if not supabase_admin:
        raise HTTPException(
            status_code=503,
            detail="SUPABASE_SECRET_KEY não configurada. Não é possível criar médicos pela API.",
        )

    try:
        auth = supabase_admin.auth.admin.create_user({
            "email": data.email,
            "password": data.password,
            "email_confirm": True,
        })
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Erro ao criar conta Auth: {e}")

    user_id = auth.user.id
    profile = db_clinical().table("users").insert({
        "id": user_id,
        "name": data.name,
        "role": "doctor",
        "active": True,
    }).execute()

    if not profile.data:
        raise HTTPException(status_code=400, detail="Conta Auth criada mas falhou o perfil em users.")

    return profile.data[0]


@router.patch("/doctors/{user_id}/active")
def set_doctor_active(
    user_id: str,
    body: ActiveToggle,
    _: dict = Depends(_require_admin),
):
    result = db_clinical().table("users") \
        .update({"active": body.active}) \
        .eq("id", user_id) \
        .eq("role", "doctor") \
        .execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="Médico não encontrado.")

    return result.data[0]


@router.get("/patients")
def list_all_patients(_: dict = Depends(_require_admin)):
    database = db_clinical()
    result = database.table("patients") \
        .select("*") \
        .order("created_at", desc=True) \
        .execute()

    doctors = database.table("users") \
        .select("id, name") \
        .eq("role", "doctor") \
        .execute()
    by_id = {d["id"]: d["name"] for d in (doctors.data or [])}

    return [
        {**p, "doctor_name": by_id.get(p.get("doctor_id"))}
        for p in (result.data or [])
    ]


@router.post("/patients")
def create_patient_admin(data: AdminPatientInput, _: dict = Depends(_require_admin)):
    database = db_clinical()
    doctor = database.table("users") \
        .select("id") \
        .eq("id", data.doctor_id) \
        .eq("role", "doctor") \
        .single() \
        .execute()

    if not doctor.data:
        raise HTTPException(status_code=404, detail="Médico não encontrado.")

    result = database.table("patients").insert({
        "doctor_id":      data.doctor_id,
        "patient_code":   data.patient_code,
        "date_of_birth":  str(data.date_of_birth),
        "parity_inicial": data.parity_inicial,
        "active":         True,
    }).execute()

    if not result.data:
        raise HTTPException(status_code=400, detail="Erro ao registar paciente.")

    return result.data[0]


@router.patch("/patients/{patient_id}/active")
def set_patient_active(
    patient_id: str,
    body: ActiveToggle,
    _: dict = Depends(_require_admin),
):
    result = db_clinical().table("patients") \
        .update({"active": body.active}) \
        .eq("id", patient_id) \
        .execute()

    if not result.data:
        raise HTTPException(status_code=404, detail="Paciente não encontrada.")

    return result.data[0]
