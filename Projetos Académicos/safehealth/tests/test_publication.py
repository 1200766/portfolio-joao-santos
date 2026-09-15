from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import check_publication  # noqa: E402


class PublicationSafetyTests(unittest.TestCase):
    def test_publication_tree_is_clean(self) -> None:
        self.assertEqual(check_publication.scan_tree(ROOT), [])

    def test_checker_covers_required_sensitive_patterns_without_echoing_values(self) -> None:
        sample_credential = "real" + "-test-credential"
        student_number = "123" + "4567"
        email = "person" + "@" + "university" + ".pt"
        personal_path = "/" + "Users" + "/sample/private.txt"

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "sample.env").write_text(
                "API" + "_KEY=" + sample_credential + "\n", encoding="utf-8"
            )
            (root / "notes.txt").write_text(
                "\n".join((student_number, email, personal_path)),
                encoding="utf-8",
            )
            with (root / "large.bin").open("wb") as handle:
                handle.truncate(check_publication.MAX_FILE_SIZE + 1)

            problems = check_publication.scan_tree(root)

        report = "\n".join(problems)
        for expected_label in (
            "segredo literal não-placeholder",
            "número académico",
            "email fora de domínio reservado",
            "caminho pessoal absoluto",
            "ficheiro superior a 10 MiB",
        ):
            self.assertIn(expected_label, report)
        for sensitive_value in (sample_credential, student_number, email, personal_path):
            self.assertNotIn(sensitive_value, report)

    def test_portal_handlers_enforce_roles_ownership_and_csrf(self) -> None:
        backend = ROOT / "portal" / "Portal" / "backend"
        mutations = (
            "add_paciente.php",
            "delete_dispositivo.php",
            "delete_medico.php",
            "delete_paciente.php",
            "logout.php",
            "save_dispositivo.php",
            "save_medico.php",
            "save_paciente.php",
        )
        for name in mutations:
            source = (backend / name).read_text(encoding="utf-8")
            self.assertIn("safehealth_require_roles", source, name)
            self.assertIn("safehealth_require_csrf", source, name)

        for name in ("get_paciente.php", "get_medicoes.php", "get_temperaturas.php"):
            source = (backend / name).read_text(encoding="utf-8")
            self.assertIn("safehealth_require_roles", source, name)
            self.assertIn("safehealth_patient_is_accessible", source, name)

        for path in backend.glob("*.php"):
            if path.name == "conn.php":
                continue
            self.assertNotIn("->query(", path.read_text(encoding="utf-8"), path.name)

    def test_device_credentials_are_not_returned_or_logged(self) -> None:
        backend = ROOT / "portal" / "Portal" / "backend"
        device_read = (backend / "get_dispositivo.php").read_text(encoding="utf-8")
        ingest = (backend / "inserir_medicao.php").read_text(encoding="utf-8")
        portal_javascript = (ROOT / "portal" / "Portal" / "app.js").read_text(
            encoding="utf-8"
        )
        firmware = (ROOT / "firmware" / "SafeHealth_ESP32.ino").read_text(
            encoding="utf-8"
        )

        self.assertNotIn("dispositivos.device_key,", device_read)
        success_payload = ingest.split("$stmt->execute();", 1)[-1]
        self.assertNotIn('"device_key" =>', success_payload)
        self.assertNotIn('"id_paciente" =>', success_payload)
        self.assertNotIn("Serial.println(DEVICE_KEY)", firmware)
        self.assertNotIn("Serial.println(json)", firmware)
        self.assertNotIn('console.log("PACIENTE:"', portal_javascript)


if __name__ == "__main__":
    unittest.main()
