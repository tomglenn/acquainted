"""Install Acquainted into a chosen AddOns folder, preserving a local backup."""
from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path
import shutil

ADDON_ID = "Acquainted"
FILES = ("Policy.lua", "GameSettings.lua", "Settings.lua", "ContextMenus.lua", "Acquainted.lua", "Acquainted.toc")


def install(source: Path, destination: Path, backups: Path) -> Path | None:
    if destination.is_symlink():
        raise RuntimeError("Refusing to replace an addon symlink")
    for name in FILES:
        if (source / name).is_symlink() or not (source / name).is_file():
            raise RuntimeError(f"Missing or invalid source file: {name}")
    backup = None
    if destination.exists():
        backup = backups / ("installed-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        shutil.copytree(destination, backup)
    shutil.copytree(source, destination, dirs_exist_ok=True)
    for name in ("README.md", "CHANGELOG.md", "LICENSE"):
        document = source.parent / name
        if document.is_file():
            shutil.copy2(document, destination / name)
    for name in FILES:
        if (source / name).read_bytes() != (destination / name).read_bytes():
            raise RuntimeError(f"Verification failed: {name}")
    return backup


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--addons-dir", type=Path, help="Forever's Interface/AddOns directory")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent
    addons = args.addons_dir or Path("/Applications/World of Warcraft/_forever_/Interface/AddOns")
    if not addons.is_dir():
        parser.error("AddOns folder not found; specify --addons-dir")
    try:
        backup = install(root / ADDON_ID, addons / ADDON_ID, root / ".local-backups")
    except (OSError, RuntimeError) as error:
        parser.exit(1, f"Installation failed: {error}\n")
    if backup:
        print("Previous addon files were backed up locally.")
    print("Installed and verified Acquainted.")
    print("Use /reload for Lua updates; new folders or metadata may need a game restart.")
    print("Open Options > AddOns > Acquainted, or use /acq.")


if __name__ == "__main__":
    main()
