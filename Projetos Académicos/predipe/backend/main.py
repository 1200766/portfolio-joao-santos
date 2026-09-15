import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from auth.router import router as auth_router
from routers.patients import router as patients_router
from routers.pregnancies import router as pregnancies_router
from routers.assessments import router as assessments_router
from routers.admin import router as admin_router
from routers.clinical import router as clinical_router
from routers.fhir import router as fhir_router

# ── App ──────────────────────────────────────────────────
app = FastAPI(
    title="CDSS Pré-eclâmpsia",
    description="Sistema de Apoio à Decisão Clínica para estratificação de risco de pré-eclâmpsia.",
    version="0.1.0",
)

# ── CORS ─────────────────────────────────────────────────
CORS_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ORIGINS",
        "http://127.0.0.1:5500,http://localhost:5500",
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ──────────────────────────────────────────────
app.include_router(auth_router)
app.include_router(patients_router)
app.include_router(pregnancies_router)
app.include_router(assessments_router)
app.include_router(admin_router)
app.include_router(clinical_router)
app.include_router(fhir_router)


# ── Health check ─────────────────────────────────────────
@app.get("/", tags=["health"])
def health():
    return {"status": "ok", "system": "CDSS Pré-eclâmpsia v0.1"}
