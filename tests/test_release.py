"""Checks for release contents and non-destructive local installation."""
from __future__ import annotations

import hashlib
from pathlib import Path
import shutil
import tempfile
import unittest
from zipfile import ZipFile

import sys
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from scripts.package import build, package_files
from install import install

ROOT = Path(__file__).resolve().parent.parent


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="acquainted-check-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "project"
        self.root.mkdir()
        shutil.copytree(ROOT / "Acquainted", self.root / "Acquainted")
        for name in ("README.md", "CHANGELOG.md"):
            shutil.copy2(ROOT / name, self.root / name)
        self.version, _ = package_files(self.root)
        self.output = self.root / "dist"

    def test_installable_layout_and_whitelist(self):
        (self.root / "Acquainted" / "unlisted.lua").write_text("-- local data")
        (self.root / "account-data").mkdir()
        (self.root / "account-data" / "settings.lua").write_text("-- private")
        archive = build(self.root, self.output, "v" + self.version)
        with ZipFile(archive) as package:
            names = set(package.namelist())
            self.assertIn("Acquainted/Acquainted.toc", names)
            self.assertIn("Acquainted/Acquainted.lua", names)
            self.assertIn("Acquainted/README.md", names)
            self.assertIn("Acquainted/CHANGELOG.md", names)
            self.assertTrue(all(name.startswith("Acquainted/") for name in names))
            self.assertFalse(any("unlisted" in name or "account" in name or "install.py" in name for name in names))

    def test_archive_is_reproducible_and_checksum_matches(self):
        archive = build(self.root, self.output)
        original = archive.read_bytes()
        build(self.root, self.output)
        self.assertEqual(original, archive.read_bytes())
        checksum, filename = (self.output / "SHA256SUMS").read_text().strip().split("  ")
        self.assertEqual(hashlib.sha256(original).hexdigest(), checksum)
        self.assertEqual(archive.name, filename)
        self.assertTrue((self.output / "RELEASE_NOTES.md").read_text().strip())

    def test_tag_must_match_source(self):
        with self.assertRaisesRegex(ValueError, "tag"):
            build(self.root, self.output, "v999.0.0")
        self.assertFalse(self.output.exists())

    def test_runtime_version_must_match_manifest(self):
        main = self.root / "Acquainted" / "Acquainted.lua"
        main.write_text(main.read_text().replace('ns.version = "' + self.version + '"', 'ns.version = "999.0.0"'))
        with self.assertRaisesRegex(ValueError, "versions"):
            build(self.root, self.output)

    def test_changelog_entry_is_required(self):
        (self.root / "CHANGELOG.md").write_text("# Changelog\n")
        with self.assertRaisesRegex(ValueError, "changelog"):
            build(self.root, self.output)

    def test_manifest_must_not_escape_addon(self):
        toc = self.root / "Acquainted" / "Acquainted.toc"
        toc.write_text(toc.read_text() + "\n../outside.lua\n")
        with self.assertRaisesRegex(ValueError, "inside"):
            build(self.root, self.output)

    def test_missing_manifest_file_fails(self):
        (self.root / "Acquainted" / "Policy.lua").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            build(self.root, self.output)

    def test_symlink_is_not_packaged(self):
        source = self.root / "Acquainted" / "Policy.lua"
        source.unlink()
        source.symlink_to(self.root / "README.md")
        with self.assertRaisesRegex(ValueError, "Manifest"):
            build(self.root, self.output)

    def test_optional_license_is_bundled(self):
        (self.root / "LICENSE").write_text("Example license text for this test.\n")
        archive = build(self.root, self.output)
        with ZipFile(archive) as package:
            self.assertEqual(b"Example license text for this test.\n", package.read("Acquainted/LICENSE"))

    def test_fresh_install_and_backed_up_update(self):
        destination = self.root / "game" / "Interface" / "AddOns" / "Acquainted"
        backups = self.root / "backups"
        self.assertIsNone(install(self.root / "Acquainted", destination, backups))
        main = destination / "Acquainted.lua"
        main.write_text("-- previous installation")
        backup = install(self.root / "Acquainted", destination, backups)
        self.assertEqual("-- previous installation", (backup / "Acquainted.lua").read_text())
        self.assertEqual((self.root / "Acquainted" / "Acquainted.lua").read_bytes(), main.read_bytes())

    def test_installer_does_not_touch_game_saves(self):
        destination = self.root / "game" / "Interface" / "AddOns" / "Acquainted"
        save = self.root / "game" / "WTF" / "Account" / "sample" / "SavedVariables" / "Acquainted.lua"
        save.parent.mkdir(parents=True)
        save.write_text("AcquaintedDB = { known = {} }\n")
        before = save.read_bytes()
        install(self.root / "Acquainted", destination, self.root / "backups")
        self.assertEqual(before, save.read_bytes())

    def test_installer_refuses_destination_symlink(self):
        destination = self.root / "linked-addon"
        destination.symlink_to(self.root / "Acquainted", target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "symlink"):
            install(self.root / "Acquainted", destination, self.root / "backups")


if __name__ == "__main__":
    unittest.main()
