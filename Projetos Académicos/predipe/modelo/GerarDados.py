import numpy as np
import pandas as pd


def sigmoid(x):
    return 1 / (1 + np.exp(-x))


def generate_synthetic_pe_dataset(
    n_samples: int = 500,
    random_state: int = 42,
    save_path: str = "synthetic_preeclampsia_dataset.csv"
) -> pd.DataFrame:
    """
    Generate a synthetic dataset for early preeclampsia decision support prototyping.

    Notes:
    - This is NOT a clinically validated dataset.
    - It is designed for prototyping an XGBoost + SHAP pipeline.
    - The outcome is generated from a synthetic risk logic based on plausible
      combinations of maternal risk factors, hemodynamic variables, Doppler findings,
      and biomarkers.
    """

    rng = np.random.default_rng(random_state)

    rows = []

    for _ in range(n_samples):
        # ----------------------------
        # 1) Maternal / clinical history
        # ----------------------------
        maternal_age = np.clip(rng.normal(30, 5), 18, 45)
        bmi = np.clip(rng.normal(26, 5), 18, 42)

        # Parity: 0 = nulliparous, 1+ = multiparous
        parity = rng.choice([0, 1, 2, 3], p=[0.45, 0.30, 0.18, 0.07])

        # Previous PE only makes sense if parity > 0
        if parity == 0:
            previous_pe = 0
        else:
            previous_pe = rng.choice([0, 1], p=[0.88, 0.12])

        diabetes = rng.choice([0, 1], p=[0.85, 0.15])
        chronic_hypertension = rng.choice([0, 1], p=[0.90, 0.10])
        prior_nephropathy_or_proteinuria = rng.choice([0, 1], p=[0.94, 0.06])

        # ----------------------------
        # 2) Hemodynamic data
        # ----------------------------
        # Baseline MAP influenced by age, BMI, HTN, diabetes
        map_value = (
            rng.normal(85, 8)
            + 0.20 * (maternal_age - 30)
            + 0.35 * (bmi - 25)
            + 8.0 * chronic_hypertension
            + 3.5 * diabetes
        )
        map_value = float(np.clip(map_value, 65, 120))

        # Optional SBP / DBP derived approximately from MAP
        dbp = np.clip(map_value - rng.normal(8, 4), 45, 100)
        sbp = np.clip(dbp + 3 * (map_value - dbp), 80, 180)

        # ----------------------------
        # 3) Doppler / Ultrasound data
        # ----------------------------
        # Higher risk factors tend to push UtA-PI upward
        uta_pi = (
            rng.normal(1.35, 0.30)
            + 0.20 * previous_pe
            + 0.18 * diabetes
            + 0.20 * chronic_hypertension
            + 0.015 * max(map_value - 90, 0)
        )
        uta_pi = float(np.clip(uta_pi, 0.7, 3.0))

        # ----------------------------
        # 4) Biomarkers
        # ----------------------------
        # PlGF tends to be lower in higher-risk cases
        plgf = (
            rng.normal(120, 30)
            - 18 * previous_pe
            - 15 * diabetes
            - 18 * chronic_hypertension
            - 0.9 * max(map_value - 90, 0)
            - 16 * max(uta_pi - 1.5, 0)
        )
        plgf = float(np.clip(plgf, 15, 250))

        # sFlt-1/PlGF ratio tends to be higher in higher-risk cases
        sflt1_plgf_ratio = (
            rng.normal(20, 8)
            + 8 * previous_pe
            + 7 * diabetes
            + 8 * chronic_hypertension
            + 0.5 * max(map_value - 90, 0)
            + 10 * max(uta_pi - 1.5, 0)
            + 0.10 * max(80 - plgf, 0)
        )
        sflt1_plgf_ratio = float(np.clip(sflt1_plgf_ratio, 3, 150))

        # ----------------------------
        # 5) Synthetic risk logic (structured in blocks)
        # ----------------------------
        maternal_risk = 0.0
        hemodynamic_risk = 0.0
        placental_risk = 0.0
        angiogenic_risk = 0.0
        interaction_risk = 0.0

        # Maternal block
        if maternal_age >= 35:
            maternal_risk += 0.5
        if bmi >= 30:
            maternal_risk += 0.8
        if parity == 0:  # nulliparity as a risk factor
            maternal_risk += 0.4
        if previous_pe == 1:
            maternal_risk += 1.6
        if diabetes == 1:
            maternal_risk += 1.2
        if chronic_hypertension == 1:
            maternal_risk += 1.4
        if prior_nephropathy_or_proteinuria == 1:
            maternal_risk += 1.0

        # Hemodynamic block
        if map_value >= 95:
            hemodynamic_risk += 1.7
        elif map_value >= 90:
            hemodynamic_risk += 0.8

        # Placental (Doppler) block
        if uta_pi >= 1.9:
            placental_risk += 1.7
        elif uta_pi >= 1.6:
            placental_risk += 0.8

        # Angiogenic block
        if plgf < 60:
            angiogenic_risk += 1.8
        elif plgf < 90:
            angiogenic_risk += 0.9
        if sflt1_plgf_ratio >= 50:
            angiogenic_risk += 1.4
        elif sflt1_plgf_ratio >= 30:
            angiogenic_risk += 0.7

        # Interaction block (as in Phase 1 additions)
        # Maternal-metabolic profile
        if diabetes == 1 and bmi >= 30:
            interaction_risk += 0.4
        if chronic_hypertension == 1 and bmi >= 30:
            interaction_risk += 0.4
        if diabetes == 1 and prior_nephropathy_or_proteinuria == 1:
            interaction_risk += 0.6
        if chronic_hypertension == 1 and prior_nephropathy_or_proteinuria == 1:
            interaction_risk += 0.7

        # Hemodynamic expression
        if diabetes == 1 and map_value >= 95:
            interaction_risk += 0.5
        if chronic_hypertension == 1 and map_value >= 95:
            interaction_risk += 0.7
        if prior_nephropathy_or_proteinuria == 1 and map_value >= 95:
            interaction_risk += 0.6
        if maternal_age >= 35 and map_value >= 95:
            interaction_risk += 0.3

        # Placental dysfunction pattern
        if uta_pi >= 1.8 and plgf < 90:
            interaction_risk += 0.8
        if uta_pi >= 1.9 and plgf < 60:
            interaction_risk += 1.2
        if uta_pi >= 1.8 and sflt1_plgf_ratio >= 30:
            interaction_risk += 0.8
        if map_value >= 95 and plgf < 90:
            interaction_risk += 0.7
        if map_value >= 95 and uta_pi >= 1.8:
            interaction_risk += 0.7

        # Recurrence profile
        if previous_pe == 1 and plgf < 80:
            interaction_risk += 0.5
        if previous_pe == 1 and map_value >= 95:
            interaction_risk += 0.6
        if previous_pe == 1 and uta_pi >= 1.8:
            interaction_risk += 0.7
        if previous_pe == 1 and sflt1_plgf_ratio >= 30:
            interaction_risk += 0.6

        # Existing interacção HTA + UtA-PI
        if chronic_hypertension == 1 and uta_pi >= 1.8:
            interaction_risk += 0.5

        # Combine blocks and add random noise
        risk_score = (
            maternal_risk
            + hemodynamic_risk
            + placental_risk
            + angiogenic_risk
            + interaction_risk
            + rng.normal(0, 0.6)
        )

        # Convert to probability
        pe_probability = sigmoid(risk_score - 3.6)

        # Final binary outcome
        pe_outcome = int(rng.random() < pe_probability)

        # Optional subtype label for richer prototyping
        if pe_outcome == 0:
            pe_subtype = "No PE"
        else:
            if (plgf < 55 and uta_pi > 1.9 and map_value > 95):
                pe_subtype = "Early/Evolving PE"
            else:
                pe_subtype = "Late/Moderate PE"

        rows.append({
            "maternal_age": round(maternal_age, 1),
            "parity": parity,
            "previous_pe": previous_pe,
            "diabetes": diabetes,
            "chronic_hypertension": chronic_hypertension,
            "prior_nephropathy_or_proteinuria": prior_nephropathy_or_proteinuria,
            "bmi": round(bmi, 1),
            "sbp": round(float(sbp), 1),
            "dbp": round(float(dbp), 1),
            "map": round(map_value, 1),
            "uta_pi": round(uta_pi, 2),
            "plgf": round(plgf, 1),
            "sflt1_plgf_ratio": round(sflt1_plgf_ratio, 1),
            "synthetic_risk_score": round(float(risk_score), 3),
            "synthetic_pe_probability": round(float(pe_probability), 4),
            "pe_outcome": pe_outcome,
            "pe_subtype": pe_subtype
        })

    df = pd.DataFrame(rows)

    # Save to CSV
    df.to_csv(save_path, index=False)

    return df


if __name__ == "__main__":
    df = generate_synthetic_pe_dataset(
        n_samples=10000,
        random_state=42,
        save_path="synthetic_preeclampsia_dataset.csv"
    )

    print("Dataset generated successfully.")
    print(df.head())
    print("\nClass distribution:")
    print(df["pe_outcome"].value_counts(normalize=True).rename("proportion"))