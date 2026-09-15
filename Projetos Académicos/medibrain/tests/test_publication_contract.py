import ast
import hashlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
ORIGINAL_REPORT = ROOT / ("1200" + "766_JoaoPedro_PREST-B_Relatorio.pdf")
ORIGINAL_REPORT_SHA256 = (
    "13ec2973363a3182b907a46ac861e09869989eff4f831f18322bec29d0e06a7b"
)


class PublicationContractTests(unittest.TestCase):
    def test_no_signal_files_are_packaged(self):
        forbidden_endings = (".edf", ".edf.part", ".eeg", ".fif", ".vhdr", ".vmrk")
        packaged = [
            path
            for path in ROOT.rglob("*")
            if path.is_file() and path.name.lower().endswith(forbidden_endings)
        ]
        self.assertEqual(packaged, [])

    def test_partial_edf_downloads_are_ignored(self):
        ignore_rules = (ROOT / ".gitignore").read_text().splitlines()
        self.assertIn("*.edf.part", ignore_rules)

    def test_original_report_is_present_and_unchanged(self):
        self.assertTrue(ORIGINAL_REPORT.is_file())
        digest = hashlib.sha256(ORIGINAL_REPORT.read_bytes()).hexdigest()
        self.assertEqual(digest, ORIGINAL_REPORT_SHA256)

    def test_source_only_references_approved_public_edf_examples(self):
        source = "\n".join(path.read_text() for path in SRC.glob("*.py"))
        edf_paths = re.findall(r"['\"]([^'\"]+\.edf)['\"]", source)
        self.assertTrue(edf_paths)
        self.assertTrue(
            all(re.fullmatch(r"data/PN00-[1-5]\.edf", path) for path in edf_paths)
        )

    def test_empty_prototype_was_excluded(self):
        self.assertFalse((SRC / "app.py").exists())

    def test_rights_are_reserved_until_explicit_decision(self):
        self.assertTrue((ROOT / "AUTHORS.md").is_file())
        rights = (ROOT / "RIGHTS.md").read_text()
        self.assertIn("Todos os direitos reservados", rights)
        self.assertFalse((ROOT / "LICENSE").exists())

    def test_autoreject_uses_pn00_1_instead_of_mne_sample(self):
        source = (SRC / "AutoReject.py").read_text()
        tree = ast.parse(source)
        file_paths = [
            node.value.value
            for node in ast.walk(tree)
            if isinstance(node, ast.Assign)
            and any(
                isinstance(target, ast.Name) and target.id == "file_path"
                for target in node.targets
            )
            and isinstance(node.value, ast.Constant)
            and isinstance(node.value.value, str)
        ]
        self.assertEqual(file_paths, ["data/PN00-1.edf"])
        self.assertNotIn("sample_data_folder =", source)

    def test_ica_then_autoreject_uses_pn00_4_interval(self):
        source = (SRC / "ICA_ICLabel_AutoReject.py").read_text()
        tree = ast.parse(source)
        intervals = []
        for node in ast.walk(tree):
            if not (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "compute_bsi_pre_ictal"
                and len(node.args) == 7
            ):
                continue
            interval = tuple(
                arg.value
                for arg in node.args[3:]
                if isinstance(arg, ast.Constant) and isinstance(arg.value, int)
            )
            intervals.append(interval)
        self.assertEqual(intervals, [(0, 1005, 1006, 1080)] * 2)

    def test_autoreject_then_ica_saves_pn00_2(self):
        source = (SRC / "AutoReject_ICA_ICLabel.py").read_text()
        self.assertIn("PN00-2_corrigido.fif", source)
        self.assertNotIn("PN00-4_corrigido.fif", source)


if __name__ == "__main__":
    unittest.main()
