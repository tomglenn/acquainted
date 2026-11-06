#!/usr/bin/env python3
"""Build a deterministic, installable Acquainted ZIP from the addon manifest."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path, PurePosixPath
import re
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

VERSION_PATTERN = r"\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?"


def release_notes(root: Path, version: str) -> str:
    changelog = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(r"^## " + re.escape(version) + r"\s*\n(.*?)(?=^## |\Z)", changelog, re.M | re.S)
    if not match or not match.group(1).strip():
        raise ValueError("A nonempty changelog entry is required for the release version")
    return match.group(1).strip() + "\n"


def package_files(root: Path) -> tuple[str, list[tuple[Path, str]]]:
    addon = root / "Acquainted"
    toc = addon / "Acquainted.toc"
    if toc.is_symlink():
        raise ValueError("Symlinks are not allowed in release packages")
    metadata: dict[str, str] = {}
    files: list[tuple[Path, str]] = [(toc, "Acquainted/Acquainted.toc")]
    seen = {"Acquainted.toc"}
    for raw in toc.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if line.startswith("##"):
            key, separator, value = line[2:].partition(":")
            if separator:
                metadata[key.strip()] = value.strip()
        elif line and not line.startswith("#"):
            relative = PurePosixPath(line.replace("\\", "/"))
            if relative.is_absolute() or ".." in relative.parts or ":" in str(relative):
                raise ValueError("Manifest paths must stay inside the addon folder")
            if str(relative) in seen:
                raise ValueError("Duplicate file in addon manifest")
            seen.add(str(relative))
            source = addon.joinpath(*relative.parts)
            if source.suffix.lower() not in {".lua", ".xml"}:
                raise ValueError("Unexpected file type in addon manifest")
            if source.is_symlink() or not source.is_file() or not source.resolve().is_relative_to(addon.resolve()):
                raise ValueError("Manifest file is missing or leaves the addon folder")
            files.append((source, "Acquainted/" + str(relative)))
    version = metadata.get("Version", "")
    if not re.fullmatch(VERSION_PATTERN, version):
        raise ValueError("Manifest must contain a semantic release version")
    if metadata.get("Title") != "Acquainted" or metadata.get("Group") != "Acquainted":
        raise ValueError("Addon title and group must match Acquainted")
    if metadata.get("Interface") != "16001":
        raise ValueError("This package targets the Forever interface")
    if metadata.get("SavedVariablesPerCharacter") != "AcquaintedDB":
        raise ValueError("Unexpected saved-variable declaration")
    runtime = (addon / "Acquainted.lua").read_text(encoding="utf-8")
    match = re.search(r'^ns\.version\s*=\s*"([^"]+)"', runtime, re.M)
    if not match or match.group(1) != version:
        raise ValueError("Runtime and manifest versions must match")
    for name in ("README.md", "CHANGELOG.md"):
        source = root / name
        if source.is_symlink() or not source.is_file():
            raise ValueError("Release documentation is missing or is a symlink")
        files.append((source, "Acquainted/" + name))
    license_file = root / "LICENSE"
    if license_file.exists():
        if license_file.is_symlink() or not license_file.is_file():
            raise ValueError("License must be a regular file")
        files.append((license_file, "Acquainted/LICENSE"))
    return version, files


def build(root: Path, output: Path, tag: str | None = None) -> Path:
    version, files = package_files(root)
    if tag is not None and tag != "v" + version:
        raise ValueError("Release tag must be v followed by the exact addon version")
    notes = release_notes(root, version)
    output.mkdir(parents=True, exist_ok=True)
    archive = output / f"Acquainted-{version}-Forever.zip"
    with ZipFile(archive, "w", compression=ZIP_DEFLATED) as package:
        for source, name in sorted(files, key=lambda item: item[1]):
            info = ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = ZIP_DEFLATED
            package.writestr(info, source.read_bytes())
    with ZipFile(archive) as package:
        if package.testzip() is not None:
            raise ValueError("ZIP verification failed")
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    (output / "SHA256SUMS").write_text(f"{digest}  {archive.name}\n", encoding="utf-8")
    (output / "RELEASE_NOTES.md").write_text(notes, encoding="utf-8")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Optional version tag, such as v0.3.0")
    parser.add_argument("--output-dir", type=Path, help="Output directory; defaults to dist")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    try:
        archive = build(root, args.output_dir or root / "dist", args.tag)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")
    print(f"Built and verified {archive.name}")


if __name__ == "__main__":
    main()
