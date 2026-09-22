from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "userspace_build.py"
SPEC = importlib.util.spec_from_file_location("userspace_build_sync", SCRIPT)
assert SPEC and SPEC.loader
sync_module = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = sync_module
SPEC.loader.exec_module(sync_module)


class UserspaceBuildSyncTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "userspace"
        self.target = self.root / "userspace_build"
        (self.source / "src").mkdir(parents=True)
        (self.target / "src").mkdir(parents=True)

        (self.source / "src" / "library.rs").write_text(
            "use userspace;\npub fn f() { userspace::info!(\"x\"); }\n"
        )
        (self.source / "linker.ld").write_text("SECTIONS {}\n")

        (self.target / "Cargo.toml").write_text("[package]\nname=\"userspace_build\"\n")
        (self.target / "build.rs").write_text("fn main() {}\n")
        (self.target / "src" / "stale.rs").write_text("stale\n")

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_sync_projects_source_and_preserves_boundary_files(self) -> None:
        sync_module.sync(self.source, self.target)
        sync_module.check(self.source, self.target)

        self.assertEqual(
            (self.target / "src" / "library.rs").read_text(),
            "use userspace_build;\n"
            "pub fn f() { userspace_build::info!(\"x\"); }\n",
        )
        self.assertEqual((self.target / "linker.ld").read_text(), "SECTIONS {}\n")
        self.assertFalse((self.target / "src" / "stale.rs").exists())
        self.assertTrue((self.target / "Cargo.toml").exists())
        self.assertTrue((self.target / "build.rs").exists())

    def test_check_reports_drift_without_modifying_target(self) -> None:
        (self.target / "src" / "library.rs").write_text("different\n")
        before = (self.target / "src" / "library.rs").read_bytes()

        with self.assertRaises(sync_module.SyncError):
            sync_module.check(self.source, self.target)

        self.assertEqual((self.target / "src" / "library.rs").read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
