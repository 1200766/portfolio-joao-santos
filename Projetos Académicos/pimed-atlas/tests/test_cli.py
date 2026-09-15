from __future__ import annotations

import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

from pimed_atlas.cli import main


class CommandLineTests(unittest.TestCase):
    def test_complete_synthetic_workflow(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            volume = directory / "case.npz"
            schema = directory / "schema.json"
            landmarks = directory / "landmarks.json"
            basilar = directory / "basilar.json"

            with redirect_stdout(io.StringIO()):
                self.assertEqual(
                    main(
                        [
                            "generate-synthetic",
                            "--volume-output",
                            str(volume),
                            "--schema-output",
                            str(schema),
                        ]
                    ),
                    0,
                )
                self.assertEqual(
                    main(
                        [
                            "analyse-landmarks",
                            "--input",
                            str(volume),
                            "--schema",
                            str(schema),
                            "--output",
                            str(landmarks),
                        ]
                    ),
                    0,
                )
                self.assertEqual(
                    main(
                        [
                            "analyse-basilar",
                            "--input",
                            str(volume),
                            "--label",
                            "8",
                            "--allow-automatic-exploratory",
                            "--section-stride",
                            "4",
                            "--output",
                            str(basilar),
                        ]
                    ),
                    0,
                )

            landmark_payload = json.loads(landmarks.read_text(encoding="utf-8"))
            basilar_payload = json.loads(basilar.read_text(encoding="utf-8"))
            rendered = landmarks.read_text(encoding="utf-8") + basilar.read_text(
                encoding="utf-8"
            )
            self.assertEqual(landmark_payload["analysis_type"], "landmarks")
            self.assertGreater(basilar_payload["results"]["section_count"], 2)
            self.assertNotIn(str(directory), rendered)
            self.assertNotIn("synthetic-public-example", rendered)

    def test_existing_output_is_not_replaced_without_flag(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            volume = directory / "case.npz"
            schema = directory / "schema.json"
            volume.write_text("preservar", encoding="utf-8")

            errors = io.StringIO()
            with redirect_stderr(errors):
                status = main(
                    [
                        "generate-synthetic",
                        "--volume-output",
                        str(volume),
                        "--schema-output",
                        str(schema),
                    ]
                )

            self.assertEqual(status, 2)
            self.assertEqual(volume.read_text(encoding="utf-8"), "preservar")
            self.assertIn("--overwrite", errors.getvalue())


if __name__ == "__main__":
    unittest.main()
