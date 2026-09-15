import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIRMWARE = ROOT / "firmware" / "plathink_scale" / "plathink_scale.ino"


class PublicationContractTests(unittest.TestCase):
    def test_only_one_curated_sketch_is_packaged(self):
        self.assertEqual(list(ROOT.rglob("*.ino")), [FIRMWARE])

    def test_firmware_has_single_weight_reading_block(self):
        source = FIRMWARE.read_text()
        self.assertEqual(source.count("if (reading)"), 1)
        self.assertEqual(source.count("if (LoadCell.getTareStatus())"), 1)

    def test_expected_hardware_contract_is_present(self):
        source = FIRMWARE.read_text()
        self.assertIn("Serial.begin(57600)", source)
        self.assertIn("const int HX711_dout = 7", source)
        self.assertIn("const int HX711_sck = 6", source)

    def test_rights_are_reserved_until_collective_agreement(self):
        rights = (ROOT / "RIGHTS.md").read_text()
        self.assertIn("Todos os direitos reservados", rights)
        self.assertIn("Bibliotecas de terceiros", rights)
        self.assertFalse((ROOT / "LICENSE").exists())

    def test_no_large_or_identifying_artifacts_are_packaged(self):
        forbidden = {".pdf", ".ppt", ".pptx", ".doc", ".docx", ".mp4", ".mov", ".zip"}
        packaged = [path for path in ROOT.rglob("*") if path.suffix.lower() in forbidden]
        self.assertEqual(packaged, [])

    def test_publication_uses_confirmed_project_name(self):
        text_files = [
            path for path in ROOT.rglob("*")
            if path.is_file()
            and "tests" not in path.parts
            and path.suffix.lower() in {".md", ".ino"}
        ]
        combined = "\n".join(path.read_text() for path in text_files)
        legacy_spelling = "Plati" + "nk"
        self.assertNotIn(legacy_spelling, combined)

    def test_authors_are_named_in_the_documented_order(self):
        authors = (ROOT / "AUTHORS.md").read_text()
        ordered_names = [
            "João Melo",
            "João Pedro Santos",
            "Rita Portugal",
            "Pedro Guimarães",
        ]
        positions = [authors.index(name) for name in ordered_names]
        self.assertEqual(positions, sorted(positions))
        self.assertNotIn("dois coautores", authors)


if __name__ == "__main__":
    unittest.main()
