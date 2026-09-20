#!/usr/bin/env python3
from __future__ import annotations

import argparse
import configparser
import re
import subprocess
import sys
import tomllib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GITMODULES = ROOT / ".gitmodules"
DEP_SECTIONS = {"dependencies", "dev-dependencies", "build-dependencies"}
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


@dataclass(frozen=True)
class Package:
    name: str
    version: str
    manifest: Path
    repo: Path


def run_git(repo: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout.strip()


def submodules() -> list[tuple[str, Path, str]]:
    parser = configparser.ConfigParser()
    parser.read(GITMODULES)
    result: list[tuple[str, Path, str]] = []
    for section in parser.sections():
        if not section.startswith('submodule "'):
            continue
        path = Path(parser[section]["path"])
        branch = parser[section].get("branch", "main")
        name = section[len('submodule "'):-1]
        result.append((name, ROOT / path, branch))
    return result


def load_package(manifest: Path, repo: Path) -> Package:
    with manifest.open("rb") as handle:
        doc = tomllib.load(handle)
    pkg = doc["package"]
    return Package(pkg["name"], pkg["version"], manifest, repo)


def packages() -> list[Package]:
    result = [load_package(ROOT / "Cargo.toml", ROOT)]
    for _, repo, _ in submodules():
        manifest = repo / "Cargo.toml"
        if not manifest.is_file():
            raise SystemExit(f"manifest ausente: {manifest}")
        result.append(load_package(manifest, repo))
    return result


def dependency_tables(doc: dict) -> list[tuple[str, dict]]:
    tables: list[tuple[str, dict]] = []
    for section in DEP_SECTIONS:
        table = doc.get(section)
        if isinstance(table, dict):
            tables.append((section, table))
    target = doc.get("target")
    if isinstance(target, dict):
        for target_name, target_cfg in target.items():
            if not isinstance(target_cfg, dict):
                continue
            for section in DEP_SECTIONS:
                table = target_cfg.get(section)
                if isinstance(table, dict):
                    tables.append((f"target.{target_name}.{section}", table))
    return tables


def dependency_violations(pkgs: list[Package], expected: str | None) -> list[str]:
    by_name = {pkg.name: pkg for pkg in pkgs}
    canonical = {pkg.name: pkg.repo.resolve() for pkg in pkgs}
    violations: list[str] = []

    for pkg in pkgs:
        with pkg.manifest.open("rb") as handle:
            doc = tomllib.load(handle)

        for section, table in dependency_tables(doc):
            for dep_name, spec in table.items():
                if dep_name not in by_name or dep_name == pkg.name:
                    continue

                if isinstance(spec, str):
                    if expected is not None and spec != expected:
                        violations.append(
                            f"{pkg.name}: {section}.{dep_name} usa {spec!r}, esperado {expected!r}"
                        )
                    if pkg.repo != ROOT:
                        violations.append(
                            f"{pkg.name}: {section}.{dep_name} não possui path local para o workspace"
                        )
                    continue

                if not isinstance(spec, dict):
                    violations.append(f"{pkg.name}: formato não suportado em {section}.{dep_name}")
                    continue

                version = spec.get("version")
                if expected is not None and version != expected:
                    violations.append(
                        f"{pkg.name}: {section}.{dep_name}.version={version!r}, esperado {expected!r}"
                    )

                path_value = spec.get("path")
                if pkg.repo != ROOT:
                    if not path_value:
                        violations.append(
                            f"{pkg.name}: {section}.{dep_name} não possui path local para o workspace"
                        )
                    else:
                        resolved = (pkg.manifest.parent / path_value).resolve()
                        if resolved != canonical[dep_name]:
                            violations.append(
                                f"{pkg.name}: {section}.{dep_name}.path resolve para {resolved}, "
                                f"esperado {canonical[dep_name]}"
                            )

    return violations


def version_key(version: str) -> tuple[int, int, int]:
    match = SEMVER.fullmatch(version)
    if not match:
        raise SystemExit(f"versão fora do formato X.Y.Z: {version}")
    return tuple(int(part) for part in match.groups())


def render_status(pkgs: list[Package]) -> int:
    width = max(len(pkg.name) for pkg in pkgs)
    for pkg in sorted(pkgs, key=lambda item: item.name):
        rel = pkg.manifest.relative_to(ROOT)
        print(f"{pkg.name:<{width}}  {pkg.version:<12}  {rel}")

    versions = {pkg.version for pkg in pkgs}
    expected = next(iter(versions)) if len(versions) == 1 else None
    violations = dependency_violations(pkgs, expected)

    print()
    if expected is None:
        print("LOCKSTEP: NO")
        print("Versões presentes:", ", ".join(sorted(versions, key=version_key)))
    elif violations:
        print(f"LOCKSTEP: NO (versão comum {expected}, grafo interno inconsistente)")
    else:
        print(f"LOCKSTEP: YES ({expected})")

    if violations:
        print("\nViolações:")
        for item in violations:
            print(f"  - {item}")

    return 0 if expected is not None and not violations else 1


def next_patch(pkgs: list[Package]) -> str:
    major, minor, patch = max(version_key(pkg.version) for pkg in pkgs)
    return f"{major}.{minor}.{patch + 1}"


def ensure_clean_and_attached() -> None:
    if run_git(ROOT, "status", "--porcelain", "--untracked-files=no"):
        raise SystemExit("hub possui alterações rastreadas; prepare o release a partir de uma árvore limpa")

    for _, repo, branch in submodules():
        if run_git(repo, "status", "--porcelain", "--untracked-files=no"):
            raise SystemExit(f"{repo.relative_to(ROOT)} possui alterações rastreadas")
        current = run_git(repo, "branch", "--show-current")
        if current != branch:
            shown = current or "<detached HEAD>"
            raise SystemExit(
                f"{repo.relative_to(ROOT)} está em {shown}; execute scripts/submodules/attach.sh"
            )


def replace_manifest(text: str, internal_names: set[str], version: str) -> str:
    section = ""
    output: list[str] = []
    package_version_seen = False

    section_re = re.compile(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$")
    package_version_re = re.compile(r'^(\s*version\s*=\s*")[^"]+(".*)$')

    for line in text.splitlines(keepends=True):
        match = section_re.match(line.rstrip("\n"))
        if match:
            section = match.group(1).strip()
            output.append(line)
            continue

        if section == "package":
            match = package_version_re.match(line)
            if match and not package_version_seen:
                ending = "\n" if line.endswith("\n") else ""
                body = line[:-1] if ending else line
                match = package_version_re.match(body)
                assert match
                output.append(f'{match.group(1)}{version}{match.group(2)}{ending}')
                package_version_seen = True
                continue

        is_dep_section = (
            section in DEP_SECTIONS
            or section.endswith(".dependencies")
            or section.endswith(".dev-dependencies")
            or section.endswith(".build-dependencies")
        )

        if is_dep_section:
            replaced = False
            for name in internal_names:
                dep_re = re.compile(rf'^(\s*{re.escape(name)}\s*=\s*)(.*)$')
                dep_match = dep_re.match(line.rstrip("\n"))
                if not dep_match:
                    continue

                prefix, spec = dep_match.groups()
                ending = "\n" if line.endswith("\n") else ""

                if spec.lstrip().startswith("{"):
                    if re.search(r'\bversion\s*=\s*"[^"]+"', spec):
                        spec = re.sub(
                            r'(\bversion\s*=\s*")[^"]+(")',
                            rf'\g<1>{version}\2',
                            spec,
                            count=1,
                        )
                    else:
                        brace = spec.find("{")
                        spec = spec[: brace + 1] + f' version = "{version}",' + spec[brace + 1 :]
                    output.append(prefix + spec + ending)
                elif re.fullmatch(r'\s*"[^"]+"\s*(?:#.*)?', spec):
                    comment = ""
                    if "#" in spec:
                        _, comment = spec.split("#", 1)
                        comment = " #" + comment
                    output.append(f'{prefix}"{version}"{comment}{ending}')
                else:
                    output.append(line)

                replaced = True
                break

            if replaced:
                continue

        output.append(line)

    if not package_version_seen:
        raise SystemExit("manifest sem package.version editável")

    return "".join(output)


def set_version(pkgs: list[Package], version: str) -> None:
    version_key(version)
    ensure_clean_and_attached()
    internal_names = {pkg.name for pkg in pkgs}

    for pkg in pkgs:
        original = pkg.manifest.read_text()
        updated = replace_manifest(original, internal_names, version)
        if updated != original:
            pkg.manifest.write_text(updated)
            print(f"updated {pkg.manifest.relative_to(ROOT)}")

    refreshed = packages()
    violations = dependency_violations(refreshed, version)
    versions = {pkg.version for pkg in refreshed}
    if versions != {version}:
        raise SystemExit(f"falha ao alinhar package.version: {sorted(versions)}")
    if violations:
        print("\nVersões foram alinhadas, mas o grafo local ainda precisa de correções:", file=sys.stderr)
        for item in violations:
            print(f"  - {item}", file=sys.stderr)
        raise SystemExit(3)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Coordena a versão lockstep dos nove repositórios do rust_userspace_hub."
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status")
    sub.add_parser("check")
    sub.add_parser("next-patch")
    set_parser = sub.add_parser("set-version")
    set_parser.add_argument("version")

    args = parser.parse_args()
    pkgs = packages()

    if args.command in {"status", "check"}:
        return render_status(pkgs)
    if args.command == "next-patch":
        print(next_patch(pkgs))
        return 0
    if args.command == "set-version":
        set_version(pkgs, args.version)
        return render_status(packages())
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
