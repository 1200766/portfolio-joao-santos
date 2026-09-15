from functools import lru_cache
from pathlib import Path

import joblib
import pandas as pd
import shap


ML_DIR = Path(__file__).resolve().parents[1] / "ml"
ESSENTIAL_PARAMETERS = ["map", "uta_pi", "plgf", "sflt1_plgf_ratio"]
MATERNAL_HISTORY_PARAMETERS = [
    "maternal_age",
    "parity",
    "previous_pe",
    "diabetes",
    "chronic_hypertension",
    "prior_nephropathy_or_proteinuria",
    "bmi",
]


def is_missing(value) -> bool:
    return pd.isna(value)


def safe_float(value, default=None):
    if is_missing(value):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def safe_int(value, default=None):
    if is_missing(value):
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


@lru_cache(maxsize=1)
def load_model_artifacts():
    model = joblib.load(ML_DIR / "xgboost_model.pkl")
    X_reference = joblib.load(ML_DIR / "X_test.pkl")
    config = joblib.load(ML_DIR / "model_config.pkl")
    explainer = shap.TreeExplainer(model)

    return {
        "model": model,
        "explainer": explainer,
        "decision_threshold": config["decision_threshold"],
        "model_features": X_reference.columns.tolist(),
        "fallback_values": X_reference.median(numeric_only=True),
    }


def prepare_case_for_model(features: dict) -> tuple[pd.DataFrame, dict]:
    artifacts = load_model_artifacts()
    model_features = artifacts["model_features"]

    raw_data = pd.DataFrame([features])
    prepared_data = raw_data.reindex(columns=model_features)
    prepared_data = prepared_data.apply(pd.to_numeric, errors="coerce")

    missing_data = detect_missing_data(prepared_data, model_features)
    model_input = prepared_data.fillna(artifacts["fallback_values"])

    return model_input, missing_data


def detect_missing_data(sample_data: pd.DataFrame, model_features: list[str]) -> dict:
    row = sample_data.iloc[0]

    missing_model_features = [
        feature
        for feature in model_features
        if feature not in sample_data.columns or is_missing(row.get(feature))
    ]
    missing_essential = [
        feature
        for feature in ESSENTIAL_PARAMETERS
        if feature not in sample_data.columns or is_missing(row.get(feature))
    ]
    missing_maternal_history = [
        feature
        for feature in MATERNAL_HISTORY_PARAMETERS
        if feature not in sample_data.columns or is_missing(row.get(feature))
    ]

    if missing_essential:
        warning = (
            "Risco calculado com dados incompletos: falta "
            + ", ".join(missing_essential)
            + "."
        )
    else:
        warning = None

    return {
        "missing_model_features": missing_model_features,
        "missing_essential_parameters": missing_essential,
        "missing_maternal_history": missing_maternal_history,
        "has_missing_essential_data": len(missing_essential) > 0,
        "warning": warning,
    }


def get_risk_category(probability: float, decision_threshold: float) -> str:
    if probability < 0.20:
        return "Low"
    if probability < decision_threshold:
        return "Moderate"
    return "High"


def to_frontend_risk_level(risk_category: str) -> str:
    return {
        "Low": "baixo",
        "Moderate": "moderado",
        "High": "alto",
    }[risk_category]


def get_clinical_alert(risk_category: str) -> str:
    if risk_category == "Low":
        return "No immediate alert"
    if risk_category == "Moderate":
        return "Risk reassessment recommended"
    return "High-risk alert"


def get_risk_confidence(missing_data: dict) -> str:
    missing_essential_count = len(missing_data["missing_essential_parameters"])

    if missing_essential_count == 0:
        return "Alta"
    if missing_essential_count == 1:
        return "Moderada"
    return "Baixa"


def get_prediction_mode(missing_data: dict) -> str:
    missing_essential = set(missing_data["missing_essential_parameters"])
    has_map = "map" not in missing_essential
    missing_biomarker_or_doppler = bool(
        missing_essential.intersection({"uta_pi", "plgf", "sflt1_plgf_ratio"})
    )

    if not missing_essential:
        return "Complete risk stratification"

    if has_map and missing_biomarker_or_doppler:
        return "Preliminary risk based on maternal history and blood pressure"

    return "Preliminary risk based on incomplete available clinical data"


def clinical_label(feature_name: str, value) -> str:
    labels = {
        "maternal_age": f"Maternal age ({value})",
        "parity": f"Parity ({value})",
        "previous_pe": "Previous preeclampsia",
        "diabetes": "Maternal diabetes",
        "chronic_hypertension": "Chronic hypertension",
        "prior_nephropathy_or_proteinuria": "Previous nephropathy/proteinuria",
        "bmi": f"High BMI ({value})" if safe_float(value, 0) >= 30 else f"BMI ({value})",
        "sbp": f"Systolic BP ({value})",
        "dbp": f"Diastolic BP ({value})",
        "map": f"Elevated MAP ({value})" if safe_float(value, 0) >= 90 else f"MAP ({value})",
        "uta_pi": f"Abnormal UtA-PI ({value})" if safe_float(value, 0) >= 1.6 else f"UtA-PI ({value})",
        "plgf": f"Low PlGF ({value})" if safe_float(value, 999) < 90 else f"PlGF ({value})",
        "sflt1_plgf_ratio": (
            f"High sFlt-1/PlGF ratio ({value})"
            if safe_float(value, 0) >= 30
            else f"sFlt-1/PlGF ratio ({value})"
        ),
    }
    return labels.get(feature_name, f"{feature_name} ({value})")


def get_main_contributing_factors(
    explainer,
    sample_data: pd.DataFrame,
    missing_features: list[str] | None = None,
    top_n: int = 3,
):
    shap_values = explainer.shap_values(sample_data)

    row_shap = shap_values[0]
    row_values = sample_data.iloc[0]

    contribution_df = pd.DataFrame({
        "feature": sample_data.columns,
        "value": row_values.values,
        "shap_value": row_shap,
    }).sort_values(by="shap_value", ascending=False)

    missing_features = missing_features or []
    positive_contributors = contribution_df[
        (contribution_df["shap_value"] > 0)
        & (~contribution_df["feature"].isin(missing_features))
    ].head(top_n)

    readable = [
        clinical_label(row["feature"], row["value"])
        for _, row in positive_contributors.iterrows()
    ]

    shap_values_for_frontend = {
        row["feature"]: round(float(row["shap_value"]), 4)
        for _, row in positive_contributors.iterrows()
    }

    return readable, contribution_df, shap_values_for_frontend


def extract_case_flags(sample_data: pd.DataFrame) -> dict:
    row = sample_data.iloc[0]

    return {
        "has_diabetes": safe_int(row["diabetes"], 0) == 1,
        "has_previous_pe": safe_int(row["previous_pe"], 0) == 1,
        "has_chronic_hypertension": safe_int(row["chronic_hypertension"], 0) == 1,
        "has_nephropathy": safe_int(row["prior_nephropathy_or_proteinuria"], 0) == 1,
        "high_bmi": safe_float(row["bmi"], 0) >= 30,
        "elevated_map": safe_float(row["map"], 0) >= 90,
        "abnormal_uta_pi": safe_float(row["uta_pi"], 0) >= 1.6,
        "low_plgf": safe_float(row["plgf"], 999) < 90,
        "high_sflt1_plgf": safe_float(row["sflt1_plgf_ratio"], 0) >= 30,
    }


def append_missing_data_recommendation(action: str, missing_essential: list[str]) -> str:
    if not missing_essential:
        return action

    missing_text = ", ".join(missing_essential)
    return (
        f"{action} Complete missing measurements ({missing_text}) "
        "before final risk stratification."
    )


def get_contextualized_action(
    risk_category: str,
    flags: dict,
    missing_essential: list[str] | None = None,
) -> str:
    missing_essential = missing_essential or []

    if risk_category == "Low":
        return append_missing_data_recommendation(
            "Maintain routine prenatal follow-up.",
            missing_essential,
        )

    if risk_category == "Moderate":
        if flags["elevated_map"]:
            return append_missing_data_recommendation(
                "Repeat assessment in a shorter interval and reinforce blood pressure monitoring.",
                missing_essential,
            )
        if flags["abnormal_uta_pi"] and flags["low_plgf"]:
            return append_missing_data_recommendation(
                "Repeat assessment and monitor for possible placental dysfunction.",
                missing_essential,
            )
        if flags["has_diabetes"]:
            return append_missing_data_recommendation(
                "Repeat assessment and reinforce metabolic surveillance.",
                missing_essential,
            )
        return append_missing_data_recommendation(
            "Repeat assessment and reinforce surveillance.",
            missing_essential,
        )

    actions = ["Urgent obstetric review and intensified surveillance"]

    if flags["has_diabetes"]:
        actions.append("reinforce metabolic monitoring")

    if flags["elevated_map"]:
        actions.append("tighten blood pressure surveillance")

    if flags["abnormal_uta_pi"] and flags["low_plgf"]:
        actions.append("consider placental dysfunction-oriented follow-up")

    if flags["has_previous_pe"]:
        actions.append("consider closer recurrence-focused surveillance")

    if flags["has_chronic_hypertension"]:
        actions.append("review chronic hypertension-related risk")

    return append_missing_data_recommendation("; ".join(actions) + ".", missing_essential)


def generate_clinical_summary(
    probability: float,
    risk_category: str,
    main_factors: list[str],
    action: str,
    risk_confidence: str,
    prediction_mode: str,
    missing_warning: str | None,
) -> str:
    if len(main_factors) == 0:
        factor_text = "non-specific model-derived factors"
    elif len(main_factors) == 1:
        factor_text = main_factors[0]
    elif len(main_factors) == 2:
        factor_text = f"{main_factors[0]} and {main_factors[1]}"
    else:
        factor_text = f"{main_factors[0]}, {main_factors[1]} and {main_factors[2]}"

    summary = (
        f"This patient was classified as {risk_category.lower()} risk for preeclampsia "
        f"(predicted probability: {probability:.4f}; risk confidence: {risk_confidence}; "
        f"mode: {prediction_mode}) mainly due to {factor_text}. "
        f"Recommended action: {action}"
    )

    if missing_warning:
        summary = f"{missing_warning} {summary}"

    return summary


def evaluate_case_clinically(features: dict) -> dict:
    artifacts = load_model_artifacts()
    model = artifacts["model"]
    explainer = artifacts["explainer"]
    decision_threshold = artifacts["decision_threshold"]

    model_input, missing_data = prepare_case_for_model(features)
    risk_confidence = get_risk_confidence(missing_data)
    prediction_mode = get_prediction_mode(missing_data)

    probability = float(model.predict_proba(model_input)[0, 1])
    predicted_class = int(probability >= decision_threshold)
    risk_category = get_risk_category(probability, decision_threshold)
    risk_level = to_frontend_risk_level(risk_category)
    alert = get_clinical_alert(risk_category)

    main_factors, contribution_df, shap_values = get_main_contributing_factors(
        explainer,
        model_input,
        missing_data["missing_model_features"],
        top_n=5,
    )
    flags = extract_case_flags(model_input)
    action = get_contextualized_action(
        risk_category,
        flags,
        missing_data["missing_essential_parameters"],
    )
    summary = generate_clinical_summary(
        probability,
        risk_category,
        main_factors,
        action,
        risk_confidence,
        prediction_mode,
        missing_data["warning"],
    )

    return {
        "predicted_probability": round(probability, 4),
        "predicted_class": predicted_class,
        "decision_threshold": decision_threshold,
        "risk_category": risk_category,
        "risk_level": risk_level,
        "risk_confidence": risk_confidence,
        "prediction_mode": prediction_mode,
        "clinical_alert": alert,
        "suggested_action": action,
        "main_contributing_factors": main_factors,
        "clinical_summary": summary,
        "missing_data": missing_data,
        "shap_values": shap_values,
        "full_contributions": contribution_df,
    }


def evaluate_risk_evolution(
    longitudinal_measurements: pd.DataFrame,
    week_column: str = "gestational_week",
) -> pd.DataFrame:
    if not isinstance(longitudinal_measurements, pd.DataFrame):
        longitudinal_measurements = pd.DataFrame(longitudinal_measurements)

    trajectory_rows = []

    for position, (_, measurement) in enumerate(longitudinal_measurements.iterrows(), start=1):
        clinical_output = evaluate_case_clinically(measurement.to_dict())

        week = measurement.get(week_column)
        if is_missing(week):
            week = position

        trajectory_rows.append({
            "assessment": position,
            "gestational_week": week,
            "predicted_probability": clinical_output["predicted_probability"],
            "predicted_class": clinical_output["predicted_class"],
            "risk_level": clinical_output["risk_level"],
            "risk_confidence": clinical_output["risk_confidence"],
            "prediction_mode": clinical_output["prediction_mode"],
            "clinical_alert": clinical_output["clinical_alert"],
            "missing_essential_parameters": ", ".join(
                clinical_output["missing_data"]["missing_essential_parameters"]
            ),
            "missing_data_warning": clinical_output["missing_data"]["warning"],
            "main_contributing_factors": "; ".join(
                clinical_output["main_contributing_factors"]
            ),
            "suggested_action": clinical_output["suggested_action"],
            "clinical_summary": clinical_output["clinical_summary"],
        })

    trajectory_df = pd.DataFrame(trajectory_rows)

    if not trajectory_df.empty:
        trajectory_df["risk_delta_from_previous"] = (
            trajectory_df["predicted_probability"].diff().round(4)
        )
        trajectory_df["risk_trend"] = trajectory_df["risk_delta_from_previous"].apply(
            classify_risk_trend
        )

    return trajectory_df


def classify_risk_trend(delta) -> str:
    if is_missing(delta):
        return "Baseline"
    if delta >= 0.05:
        return "Increasing"
    if delta <= -0.05:
        return "Decreasing"
    return "Stable"
