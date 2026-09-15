import pandas as pd
import numpy as np
import joblib

from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    roc_auc_score
)

from xgboost import XGBClassifier
import shap
import matplotlib.pyplot as plt


DECISION_THRESHOLD = 0.35


# =========================
# 1. Load dataset
# =========================
file_path = "synthetic_preeclampsia_dataset.csv"
df = pd.read_csv(file_path)

print("Dataset loaded successfully.")
print(df.head())
print("\nColumns:")
print(df.columns.tolist())


# =========================
# 2. Define features and target
# =========================
columns_to_drop = [
    "pe_outcome",
    "pe_subtype",
    "synthetic_risk_score",
    "synthetic_pe_probability"
]

X = df.drop(columns=columns_to_drop, errors="ignore")
y = df["pe_outcome"]

print("\nFeature matrix shape:", X.shape)
print("Target shape:", y.shape)


# =========================
# 3. Train/test split
# =========================
X_train, X_test, y_train, y_test = train_test_split(
    X, y,
    test_size=0.2,
    random_state=42,
    stratify=y
)

print("\nTraining samples:", len(X_train))
print("Testing samples:", len(X_test))


# =========================
# 4. Compute class weight
# =========================
n_negative = (y_train == 0).sum()
n_positive = (y_train == 1).sum()
scale_pos_weight = n_negative / n_positive

print("\nClass balance in training set:")
print(f"Negative cases: {n_negative}")
print(f"Positive cases: {n_positive}")
print(f"scale_pos_weight: {scale_pos_weight:.3f}")


# =========================
# 5. Train XGBoost model
# =========================
model = XGBClassifier(
    n_estimators=150,
    max_depth=4,
    learning_rate=0.08,
    subsample=0.9,
    colsample_bytree=0.9,
    objective="binary:logistic",
    eval_metric="logloss",
    scale_pos_weight=scale_pos_weight,
    random_state=42
)

model.fit(X_train, y_train)

print("\nModel trained successfully.")


# =========================
# 6. Predictions
# =========================
y_prob = model.predict_proba(X_test)[:, 1]
y_pred = (y_prob >= DECISION_THRESHOLD).astype(int)

print("\n=== Model Evaluation ===")
print(f"Decision threshold: {DECISION_THRESHOLD}")
print("Accuracy:", round(accuracy_score(y_test, y_pred), 4))
print("ROC AUC:", round(roc_auc_score(y_test, y_prob), 4))

print("\nConfusion Matrix:")
print(confusion_matrix(y_test, y_pred))

print("\nClassification Report:")
print(classification_report(y_test, y_pred))


# =========================
# 7. Feature importance
# =========================
feature_importance = pd.DataFrame({
    "Feature": X.columns,
    "Importance": model.feature_importances_
}).sort_values(by="Importance", ascending=False)

print("\n=== XGBoost Feature Importance ===")
print(feature_importance)


# =========================
# 8. SHAP explanation
# =========================
explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)

print("\nSHAP values calculated successfully.")


# =========================
# 9. Save plots
# =========================
plt.figure()
shap.summary_plot(shap_values, X_test, show=False)
plt.tight_layout()
plt.savefig("shap_summary_plot.png", dpi=300, bbox_inches="tight")
plt.close()

print("\nGlobal SHAP summary plot saved as: shap_summary_plot.png")


sample_index = 0
sample_data = X_test.iloc[[sample_index]]
sample_pred_prob = model.predict_proba(sample_data)[0, 1]
sample_pred_class = int(sample_pred_prob >= DECISION_THRESHOLD)

print("\n=== Individual Case Explanation ===")
print("Predicted probability of PE:", round(float(sample_pred_prob), 4))
print("Predicted class:", sample_pred_class)
print(f"Threshold used: {DECISION_THRESHOLD}")
print("\nInput values:")
print(sample_data)

sample_shap_values = explainer.shap_values(sample_data)

try:
    shap_explanation = shap.Explanation(
        values=sample_shap_values[0],
        base_values=explainer.expected_value,
        data=sample_data.iloc[0].values,
        feature_names=sample_data.columns.tolist()
    )

    plt.figure()
    shap.plots.waterfall(shap_explanation, show=False)
    plt.tight_layout()
    plt.savefig("shap_waterfall_case_0.png", dpi=300, bbox_inches="tight")
    plt.close()

    print("Individual SHAP waterfall plot saved as: shap_waterfall_case_0.png")

except Exception as e:
    print("Could not generate waterfall plot:", e)


# =========================
# 10. Save artifacts
# =========================
feature_importance.to_csv("xgboost_feature_importance.csv", index=False)
print("\nFeature importance saved as: xgboost_feature_importance.csv")

joblib.dump(model, "xgboost_model.pkl")
joblib.dump(X_test, "X_test.pkl")
joblib.dump({"decision_threshold": DECISION_THRESHOLD}, "model_config.pkl")

print("\nArtifacts saved:")
print("- xgboost_model.pkl")
print("- X_test.pkl")
print("- model_config.pkl")