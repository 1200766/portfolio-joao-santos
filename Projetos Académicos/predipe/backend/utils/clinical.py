from datetime import date


def calculate_age(date_of_birth: date, reference_date: date) -> int:
    """Calcula a idade em anos completos a partir da data de nascimento."""
    age = reference_date.year - date_of_birth.year
    if (reference_date.month, reference_date.day) < (date_of_birth.month, date_of_birth.day):
        age -= 1
    return age


def calculate_parity(patient_id: str, parity_inicial: int, supabase) -> int:
    """
    Soma parity_inicial com o número de gravidezes já terminadas
    no sistema para esta paciente.
    """
    result = supabase.table("pregnancies") \
        .select("id") \
        .eq("patient_id", patient_id) \
        .not_.is_("ended_at", "null") \
        .execute()
    return parity_inicial + len(result.data)


def calculate_parity_at_registration(
    patient_id: str,
    parity_inicial: int,
    started_at: str,
    supabase,
) -> int:
    """Paridade no momento do registo de uma gravidez (gravidezes anteriores já terminadas)."""
    result = supabase.table("pregnancies") \
        .select("id") \
        .eq("patient_id", patient_id) \
        .not_.is_("ended_at", "null") \
        .lt("started_at", started_at) \
        .execute()
    return parity_inicial + len(result.data)


def calculate_pregnancy_number(
    patient_id: str,
    parity_inicial: int,
    started_at: str,
    supabase,
) -> int:
    """Número da gravidez = paridade no registo + 1."""
    return calculate_parity_at_registration(
        patient_id, parity_inicial, started_at, supabase
    ) + 1


def calculate_prior_flags(patient_id: str, supabase) -> dict:
    """
    Verifica gravidezes anteriores terminadas e devolve:
    - prior_pe: se alguma gravidez teve PE confirmada
    - prior_nephropathy_or_proteinuria: se alguma gravidez tinha este antecedente
    """
    result = supabase.table("pregnancies") \
        .select("pe_outcome, prior_nephropathy_or_proteinuria") \
        .eq("patient_id", patient_id) \
        .not_.is_("ended_at", "null") \
        .execute()

    prior_pe = any(
        p["pe_outcome"] for p in result.data if p["pe_outcome"]
    )
    prior_nephropathy = any(
        p["prior_nephropathy_or_proteinuria"]
        for p in result.data
        if p["prior_nephropathy_or_proteinuria"]
    )
    return {
        "prior_pe": prior_pe,
        "prior_nephropathy_or_proteinuria": prior_nephropathy,
    }


def stratify_risk(probability: float) -> tuple[str, float]:
    """Converte probabilidade [0,1] em nível de risco e score 0–100."""
    score = round(probability * 100, 1)
    if probability < 0.2:
        level = "baixo"
    elif probability < 0.5:
        level = "moderado"
    else:
        level = "alto"
    return level, score