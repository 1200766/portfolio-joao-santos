from pydantic import BaseModel, Field
from typing import Optional, Literal
from datetime import date


# ── Auth ──────────────────────────────────────────────────
class LoginInput(BaseModel):
    email: str
    password: str
    role: Literal["doctor", "admin"] = "doctor"


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    name: str
    id: str


# ── Pacientes ─────────────────────────────────────────────
class PatientInput(BaseModel):
    doctor_id: str
    patient_code: str
    date_of_birth: date
    parity_inicial: int = Field(0, ge=0)


class AdminPatientInput(BaseModel):
    doctor_id: str
    patient_code: str
    date_of_birth: date
    parity_inicial: int = Field(0, ge=0)


class DoctorInput(BaseModel):
    email: str
    password: str = Field(..., min_length=6)
    name: str


class ActiveToggle(BaseModel):
    active: bool


# ── Gravidezes ────────────────────────────────────────────
class PregnancyInput(BaseModel):
    patient_id: str
    bmi: float = Field(..., ge=12, le=70)
    started_at: date


# ── Avaliações ────────────────────────────────────────────
class AssessmentInput(BaseModel):
    pregnancy_id: str
    gestational_week: int = Field(..., ge=4, le=42)
    diabetes: Literal["none", "type1", "type2", "gestational"] = "none"
    chronic_hypertension: bool = False
    sbp: int = Field(..., ge=70, le=250)
    dbp: int = Field(..., ge=40, le=150)
    uta_pi: Optional[float] = Field(None, ge=0.5, le=4.0)
    plgf: Optional[float] = Field(None, ge=0)
    sflt1_plgf_ratio: Optional[float] = Field(None, ge=0)
    # Valores de lab introduzidos manualmente em papel (source=clinician, manual_lab_entry=true)
    manual_lab_fields: Optional[dict[str, bool]] = None


class RecalcInput(BaseModel):
    pregnancy_id: str
    gestational_week: int = Field(..., ge=4, le=42)
    assessment_case_id: Optional[str] = None


class LabObservationInput(BaseModel):
    pregnancy_id: str
    gestational_week: int = Field(..., ge=4, le=42)
    plgf: Optional[float] = None
    uta_pi: Optional[float] = Field(None, ge=0.5, le=4.0)
    sflt1_plgf_ratio: Optional[float] = None
