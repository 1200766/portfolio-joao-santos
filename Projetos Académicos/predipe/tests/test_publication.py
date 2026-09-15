from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

import joblib
import pandas as pd
from sklearn.metrics import f1_score, recall_score, roc_auc_score
from sklearn.model_selection import train_test_split


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "modelo"
BACKEND_MODEL_DIR = ROOT / "backend" / "ml"


def load_generator_module():
    path = MODEL_DIR / "GerarDados.py"
    spec = importlib.util.spec_from_file_location("predipe_data_generator", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class PublicationTests(unittest.TestCase):
    def test_synthetic_generator_is_deterministic(self):
        generator = load_generator_module()
        with tempfile.TemporaryDirectory() as directory:
            first = generator.generate_synthetic_pe_dataset(
                n_samples=64,
                random_state=42,
                save_path=str(Path(directory) / "first.csv"),
            )
            second = generator.generate_synthetic_pe_dataset(
                n_samples=64,
                random_state=42,
                save_path=str(Path(directory) / "second.csv"),
            )
        pd.testing.assert_frame_equal(first, second)
        self.assertEqual(len(first), 64)
        self.assertTrue(set(first["pe_outcome"]).issubset({0, 1}))

    def test_published_model_reproduces_documented_metrics(self):
        frame = pd.read_csv(MODEL_DIR / "synthetic_preeclampsia_dataset.csv")
        features = frame.drop(
            columns=[
                "pe_outcome",
                "pe_subtype",
                "synthetic_risk_score",
                "synthetic_pe_probability",
            ],
            errors="ignore",
        )
        target = frame["pe_outcome"]
        _, test_features, _, test_target = train_test_split(
            features,
            target,
            test_size=0.2,
            random_state=42,
            stratify=target,
        )
        model = joblib.load(BACKEND_MODEL_DIR / "xgboost_model.pkl")
        config = joblib.load(BACKEND_MODEL_DIR / "model_config.pkl")
        probabilities = model.predict_proba(test_features)[:, 1]
        predictions = (probabilities >= config["decision_threshold"]).astype(int)

        self.assertAlmostEqual(roc_auc_score(test_target, probabilities), 0.8813, places=4)
        self.assertAlmostEqual(recall_score(test_target, predictions), 0.82, places=2)
        self.assertAlmostEqual(f1_score(test_target, predictions), 0.69, places=2)

    def test_publication_security_contract(self):
        lab_simulator = (ROOT / "frontend" / "lab_simulator.html").read_text()
        login = (ROOT / "frontend" / "login.html").read_text()
        dashboard = (ROOT / "frontend" / "dashboard_doctor.html").read_text()
        env_example = (ROOT / "backend" / ".env.example").read_text()
        database = (ROOT / "backend" / "core" / "database.py").read_text()
        fhir_router = (ROOT / "backend" / "routers" / "fhir.py").read_text()
        rls_sql = (ROOT / "backend" / "sql" / "002_rls_clinical_tables.sql").read_text()

        self.assertNotIn("predipe-lab-dev", lab_simulator)
        self.assertNotIn('localStorage.setItem("fhir_api_key"', lab_simulator)
        self.assertIn('type="password" id="api_key"', lab_simulator)
        self.assertIn("@example.invalid", login)
        self.assertIn("escapeHtml(displayName)", dashboard)
        self.assertIn("FHIR_INGEST_ENABLED=false", env_example)
        self.assertIn("SUPABASE_PUBLISHABLE_KEY", env_example)
        self.assertIn("SUPABASE_SECRET_KEY", env_example)
        self.assertNotIn("SUPABASE_ANON_KEY", env_example)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", env_example)
        self.assertIn('os.getenv("SUPABASE_PUBLISHABLE_KEY")', database)
        self.assertIn('os.getenv("SUPABASE_SECRET_KEY")', database)
        self.assertNotIn("SUPABASE_ANON_KEY", database)
        self.assertNotIn("SUPABASE_SERVICE_ROLE_KEY", database)
        self.assertIn('os.getenv("FHIR_API_KEY") or ""', fhir_router)
        self.assertIn("if not FHIR_INGEST_ENABLED", fhir_router)
        self.assertIn("if not FHIR_API_KEY", fhir_router)
        self.assertIn("secrets.compare_digest", fhir_router)
        self.assertNotIn("predipe-lab-dev", fhir_router)
        self.assertIn(
            "ALTER TABLE clinical_observations ENABLE ROW LEVEL SECURITY",
            rls_sql,
        )

        protected_routes = {
            "pregnancies.py": ("require_patient_access", "require_pregnancy_access"),
            "clinical.py": ("require_pregnancy_access",),
            "assessments.py": ("require_pregnancy_access",),
        }
        for filename, guards in protected_routes.items():
            source = (ROOT / "backend" / "routers" / filename).read_text()
            for guard in guards:
                self.assertIn(guard, source, f"{filename} sem {guard}")

        admin_router = (ROOT / "backend" / "routers" / "admin.py").read_text()
        auth_dependencies = (ROOT / "backend" / "auth" / "dependencies.py").read_text()
        self.assertNotIn('supabase.table("', admin_router)
        self.assertIn('db_clinical().table("users")', auth_dependencies)


if __name__ == "__main__":
    unittest.main()
