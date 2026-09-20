#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
import tomllib
from pathlib import Path

from lockstep import (
    ROOT,
    dependency_tables,
    dependency_violations,
    ensure_clean_and_attached,
    packages,
    run_git,
    submodules,
    version_key,
)


def internal_dependencies(pkg, internal_names: set[str]) -> set[str]:
    with pkg.manifest.open("rb") as handle:
        doc = tomllib.load(handle)

    deps: set[str] = set()
    for section, table in dependency_tables(doc):
        if section.endswith("dev-dependencies"):
            continue
        for name in table:
            if name in internal_names and name != pkg.name:
                deps.add(name)
    return deps


def topological_order(pkgs) -> list:
    by_name = {pkg.name: pkg for pkg in pkgs}
    internal_names = set(by_name)
    pending = {
        pkg.name: internal_dependencies(pkg, internal_names)
        for pkg in pkgs
    }

    result = []
    done: set[str] = set()

    while len(result) < len(pkgs):
        ready = sorted(
            name for name, deps in pending.items()
            if name not in done and deps <= done
        )
        if not ready:
            remaining = {
                name: sorted(deps - done)
                for name, deps in pending.items()
                if name not in done
            }
            raise SystemExit(f"ciclo no grafo interno de publicação: {remaining}")

        for name in ready:
            result.append(by_name[name])
            done.add(name)

    return result


def run(*args: str, cwd: Path = ROOT, check: bool = True) -> subprocess.CompletedProcess:
    print("+", " ".join(args))
    return subprocess.run(args, cwd=cwd, check=check)


def ensure_pushed_heads() -> None:
    root_branch = run_git(ROOT, "branch", "--show-current")
    if not root_branch:
        raise SystemExit("hub está em detached HEAD")

    run_git(ROOT, "fetch", "origin", root_branch)
    root_head = run_git(ROOT, "rev-parse", "HEAD")
    root_remote = run_git(ROOT, "rev-parse", f"origin/{root_branch}")
    if root_head != root_remote:
        raise SystemExit(
            f"hub não coincide com origin/{root_branch}; commit/push antes de publicar"
        )

    for _, repo, branch in submodules():
        run_git(repo, "fetch", "origin", branch)
        head = run_git(repo, "rev-parse", "HEAD")
        remote = run_git(repo, "rev-parse", f"origin/{branch}")
        if head != remote:
            raise SystemExit(
                f"{repo.relative_to(ROOT)} não coincide com origin/{branch}; "
                "commit/push ou pull --ff-only antes de publicar"
            )


def cargo_sees(crate: str, version: str) -> bool:
    result = subprocess.run(
        ["cargo", "info", f"{crate}@{version}"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def wait_until_visible(crate: str, version: str, timeout: int) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if cargo_sees(crate, version):
            print(f"registry visível: {crate}@{version}")
            return
        time.sleep(5)
    raise SystemExit(
        f"timeout aguardando {crate}@{version} ficar visível ao Cargo; "
        "reexecute com --resume quando o registry propagar a versão"
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Publica os nove crates do rust_userspace_hub como uma release lockstep."
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        help="faz cargo publish; sem esta opção apenas valida/empacota",
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="em modo --execute, pula crates da versão que já estejam visíveis no registry",
    )
    parser.add_argument(
        "--visibility-timeout",
        type=int,
        default=180,
        help="segundos para aguardar cada publicação aparecer para o Cargo (default: 180)",
    )
    args = parser.parse_args()

    pkgs = packages()
    versions = {pkg.version for pkg in pkgs}
    if len(versions) != 1:
        raise SystemExit(
            "release bloqueado: os nove package.version não são iguais: "
            + ", ".join(sorted(versions, key=version_key))
        )

    version = next(iter(versions))
    version_key(version)

    violations = dependency_violations(pkgs, version)
    if violations:
        print("release bloqueado: grafo interno fora do lockstep", file=sys.stderr)
        for violation in violations:
            print(f"  - {violation}", file=sys.stderr)
        return 1

    ensure_clean_and_attached()
    ensure_pushed_heads()
    order = topological_order(pkgs)

    print(f"Release lockstep: {version}")
    print("Ordem de publicação:")
    for index, pkg in enumerate(order, start=1):
        print(f"  {index}. {pkg.name} ({pkg.manifest.relative_to(ROOT)})")

    print("\n== Validação do workspace ==")
    run("cargo", "check", "--workspace")

    print("\n== Empacotamento local ==")
    for pkg in order:
        run(
            "cargo",
            "package",
            "--manifest-path",
            str(pkg.manifest),
            "--no-verify",
        )

    if not args.execute:
        print("\nDRY RUN concluído. Nenhuma crate foi publicada.")
        print("Use --execute somente depois de revisar commits, gitlinks e versão.")
        return 0

    if not os.environ.get("CARGO_REGISTRY_TOKEN"):
        raise SystemExit("CARGO_REGISTRY_TOKEN não está definido")

    print("\n== Publicação coordenada ==")
    for pkg in order:
        if cargo_sees(pkg.name, version):
            if args.resume:
                print(f"skip: {pkg.name}@{version} já está visível no registry")
                continue
            raise SystemExit(
                f"{pkg.name}@{version} já existe no registry; "
                "use --resume apenas se estiver retomando esta mesma release"
            )

        run("cargo", "publish", "--manifest-path", str(pkg.manifest))
        wait_until_visible(pkg.name, version, args.visibility_timeout)

    print(f"\nRelease {version} publicada para os {len(order)} crates.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
