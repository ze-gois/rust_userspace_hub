#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "crates" / "userspace"
TARGET = ROOT / "crates" / "userspace_build"
PROJECTED_DIRS = ("src",)
PROJECTED_FILES = ("linker.ld",)


class SyncError(RuntimeError):
    pass


def transform(data: bytes) -> bytes:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data

    return (
        text.replace("userspace::", "userspace_build::")
        .replace("use userspace;", "use userspace_build;")
    ).encode("utf-8")


def projection(source: Path = SOURCE) -> dict[Path, bytes]:
    projected: dict[Path, bytes] = {}

    for dirname in PROJECTED_DIRS:
        root = source / dirname
        if not root.is_dir():
            raise SyncError(f"source directory missing: {root}")
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            projected[path.relative_to(source)] = transform(path.read_bytes())

    for filename in PROJECTED_FILES:
        path = source / filename
        if not path.is_file():
            raise SyncError(f"source file missing: {path}")
        projected[Path(filename)] = transform(path.read_bytes())

    return projected


def actual(target: Path = TARGET) -> dict[Path, bytes]:
    observed: dict[Path, bytes] = {}

    for dirname in PROJECTED_DIRS:
        root = target / dirname
        if root.is_dir():
            for path in sorted(item for item in root.rglob("*") if item.is_file()):
                observed[path.relative_to(target)] = path.read_bytes()

    for filename in PROJECTED_FILES:
        path = target / filename
        if path.is_file():
            observed[Path(filename)] = path.read_bytes()

    return observed


def drift(source: Path = SOURCE, target: Path = TARGET) -> tuple[list[str], list[str], list[str]]:
    expected = projection(source)
    observed = actual(target)

    expected_paths = set(expected)
    observed_paths = set(observed)

    missing = sorted(str(path) for path in expected_paths - observed_paths)
    extra = sorted(str(path) for path in observed_paths - expected_paths)
    changed = sorted(
        str(path)
        for path in expected_paths & observed_paths
        if expected[path] != observed[path]
    )
    return missing, extra, changed


def sync(source: Path = SOURCE, target: Path = TARGET) -> None:
    expected = projection(source)

    for dirname in PROJECTED_DIRS:
        root = target / dirname
        if root.exists():
            shutil.rmtree(root)

    for filename in PROJECTED_FILES:
        path = target / filename
        if path.exists():
            path.unlink()

    for relpath, data in expected.items():
        path = target / relpath
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def check(source: Path = SOURCE, target: Path = TARGET) -> None:
    missing, extra, changed = drift(source, target)
    if not (missing or extra or changed):
        return

    details: list[str] = []
    if missing:
        details.append(f"missing={missing}")
    if extra:
        details.append(f"extra={extra}")
    if changed:
        details.append(f"changed={changed}")
    raise SyncError("userspace_build differs from userspace projection; " + " ".join(details))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Synchronize userspace into userspace_build without publishing."
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("sync", help="replace the projected userspace_build files")
    sub.add_parser("check", help="verify that userspace_build matches userspace")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "sync":
            sync()
            check()
            print("userspace -> userspace_build synchronized")
        elif args.command == "check":
            check()
            print("userspace_build matches userspace")
        return 0
    except SyncError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
