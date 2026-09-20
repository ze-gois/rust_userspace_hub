#!/usr/bin/env python3
from __future__ import annotations

import argparse
import configparser
import re
import shutil
import subprocess
import sys
import time
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_NAMES = {
    "userspace_hub",
    "ample",
    "computers",
    "humans",
    "kernelspace",
    "twins",
    "userspace",
    "userspace_build",
    "webspace",
}
EXPECTED_CHILDREN = EXPECTED_NAMES - {"userspace_hub"}
DEP_SECTIONS = ("dependencies", "build-dependencies", "dev-dependencies")
PUBLISH_DEP_SECTIONS = ("dependencies", "build-dependencies")
SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
CRATES_IO = "https://crates.io"
USER_AGENT = "rust-userspace-hub-publish/2 (+https://github.com/ze-gois/rust_userspace_hub)"
BOOTSTRAP_SOURCE = "userspace"
BOOTSTRAP_TARGET = "userspace_build"
BOOTSTRAP_DIRS = ("src",)
BOOTSTRAP_FILES = ("linker.ld",)


class ReleaseError(RuntimeError):
    pass


@dataclass(frozen=True)
class Submodule:
    section: str
    relpath: Path
    repo: Path
    branch: str


@dataclass(frozen=True)
class Package:
    name: str
    version: str
    manifest: Path
    repo: Path
    submodule: Submodule | None
    document: dict


@dataclass(frozen=True)
class Dependency:
    key: str
    target: str
    version: str | None
    section: str
    path: str | None
    git: str | None
    registry: str | None


@dataclass(frozen=True)
class Model:
    root: Path
    packages: tuple[Package, ...]
    by_name: dict[str, Package]
    submodules: tuple[Submodule, ...]

    @property
    def root_package(self) -> Package:
        return self.by_name["userspace_hub"]


def run(
    *args: str,
    cwd: Path,
    check: bool = True,
    capture: bool = False,
) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(args))
    return subprocess.run(
        args,
        cwd=cwd,
        check=check,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def git(repo: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def load_toml(path: Path) -> dict:
    with path.open("rb") as handle:
        return tomllib.load(handle)


def parse_version(version: str) -> tuple[int, int, int]:
    match = SEMVER.fullmatch(version)
    if not match:
        raise ReleaseError(f"versão fora do formato X.Y.Z: {version}")
    return tuple(int(part) for part in match.groups())


def parse_submodules(root: Path) -> tuple[Submodule, ...]:
    path = root / ".gitmodules"
    if not path.is_file():
        raise ReleaseError(f".gitmodules ausente: {path}")

    parser = configparser.ConfigParser(interpolation=None)
    parser.read(path)
    items: list[Submodule] = []
    for section in parser.sections():
        if not section.startswith('submodule "'):
            continue
        relpath = Path(parser[section]["path"])
        branch_name = parser[section].get("branch", "main")
        items.append(Submodule(section, relpath, root / relpath, branch_name))
    return tuple(sorted(items, key=lambda item: str(item.relpath)))


def load_package(manifest: Path, repo: Path, submodule: Submodule | None) -> Package:
    if not manifest.is_file():
        raise ReleaseError(f"manifest ausente: {manifest}")
    doc = load_toml(manifest)
    package = doc.get("package")
    if not isinstance(package, dict):
        raise ReleaseError(f"[package] ausente: {manifest}")
    name = package.get("name")
    version = package.get("version")
    if not isinstance(name, str) or not isinstance(version, str):
        raise ReleaseError(f"package.name/version inválidos: {manifest}")
    parse_version(version)

    publish = package.get("publish", True)
    if publish is False:
        raise ReleaseError(f"{name}: publish=false")
    if isinstance(publish, list) and "crates-io" not in publish:
        raise ReleaseError(f"{name}: package.publish não permite crates-io")
    if not isinstance(publish, (bool, list)):
        raise ReleaseError(f"{name}: package.publish inválido: {publish!r}")

    return Package(name, version, manifest, repo, submodule, doc)


def load_model(root: Path = ROOT) -> Model:
    subs = parse_submodules(root)
    packages: list[Package] = [load_package(root / "Cargo.toml", root, None)]
    for sub in subs:
        packages.append(load_package(sub.repo / "Cargo.toml", sub.repo, sub))

    names = [pkg.name for pkg in packages]
    if len(names) != len(set(names)):
        raise ReleaseError(f"nomes de package duplicados: {names}")

    actual = set(names)
    if actual != EXPECTED_NAMES:
        missing = sorted(EXPECTED_NAMES - actual)
        extra = sorted(actual - EXPECTED_NAMES)
        raise ReleaseError(
            "unidade de publicação deve conter exatamente os nove crates; "
            f"ausentes={missing or '-'} extras={extra or '-'}"
        )
    if len(subs) != 8:
        raise ReleaseError(f"esperados 8 submodules diretos, encontrados {len(subs)}")

    by_name = {pkg.name: pkg for pkg in packages}
    model = Model(root, tuple(packages), by_name, subs)
    validate_structure(model)
    return model


def iter_dependency_tables(doc: dict) -> Iterable[tuple[str, dict]]:
    for section in DEP_SECTIONS:
        table = doc.get(section)
        if isinstance(table, dict):
            yield section, table

    target = doc.get("target")
    if isinstance(target, dict):
        for target_name, cfg in target.items():
            if not isinstance(cfg, dict):
                continue
            for section in DEP_SECTIONS:
                table = cfg.get(section)
                if isinstance(table, dict):
                    yield f"target.{target_name}.{section}", table


def dependency_from(key: str, spec: object, section: str) -> Dependency:
    if isinstance(spec, str):
        return Dependency(key, key, spec, section, None, None, None)
    if isinstance(spec, dict):
        target = spec.get("package", key)
        return Dependency(
            key=key,
            target=target if isinstance(target, str) else key,
            version=spec.get("version") if isinstance(spec.get("version"), str) else None,
            section=section,
            path=spec.get("path") if isinstance(spec.get("path"), str) else None,
            git=spec.get("git") if isinstance(spec.get("git"), str) else None,
            registry=spec.get("registry") if isinstance(spec.get("registry"), str) else None,
        )
    return Dependency(key, key, None, section, None, None, None)


def internal_dependencies(pkg: Package, publish_only: bool = False) -> tuple[Dependency, ...]:
    allowed = PUBLISH_DEP_SECTIONS if publish_only else DEP_SECTIONS
    result: list[Dependency] = []
    for section, table in iter_dependency_tables(pkg.document):
        base = section.rsplit(".", 1)[-1]
        if base not in allowed:
            continue
        for key, spec in table.items():
            dep = dependency_from(key, spec, section)
            if dep.target in EXPECTED_NAMES and dep.target != pkg.name:
                result.append(dep)
    return tuple(result)


def validate_structure(model: Model) -> None:
    root_doc = model.root_package.document
    workspace = root_doc.get("workspace")
    if not isinstance(workspace, dict):
        raise ReleaseError("Cargo.toml raiz sem [workspace]")

    members = workspace.get("members")
    if not isinstance(members, list) or not all(isinstance(item, str) for item in members):
        raise ReleaseError("[workspace].members inválido")
    member_paths = {Path(item) for item in members}
    sub_paths = {sub.relpath for sub in model.submodules}
    if member_paths != sub_paths:
        raise ReleaseError(
            "workspace.members deve coincidir com os oito submodules; "
            f"workspace={sorted(map(str, member_paths))} submodules={sorted(map(str, sub_paths))}"
        )

    for pkg in model.packages:
        if pkg.submodule is None:
            continue
        expected = Path("crates") / pkg.name
        if pkg.submodule.relpath != expected:
            raise ReleaseError(
                f"{pkg.name}: path canônico esperado {expected}, encontrado {pkg.submodule.relpath}"
            )

    patch = root_doc.get("patch")
    crates_patch = patch.get("crates-io") if isinstance(patch, dict) else None
    if not isinstance(crates_patch, dict):
        raise ReleaseError("Cargo.toml raiz deve possuir [patch.crates-io]")

    for name in sorted(EXPECTED_CHILDREN):
        spec = crates_patch.get(name)
        if not isinstance(spec, dict) or not isinstance(spec.get("path"), str):
            raise ReleaseError(f"[patch.crates-io].{name} deve apontar para crates/{name}")
        resolved = (model.root / spec["path"]).resolve()
        expected = model.by_name[name].repo.resolve()
        if resolved != expected:
            raise ReleaseError(
                f"[patch.crates-io].{name} resolve para {resolved}, esperado {expected}"
            )

    root_targets = {
        dep.target for dep in internal_dependencies(model.root_package, publish_only=True)
    }
    if root_targets != EXPECTED_CHILDREN:
        raise ReleaseError(
            "userspace_hub deve depender diretamente dos oito crates; "
            f"faltam={sorted(EXPECTED_CHILDREN - root_targets)} "
            f"extras={sorted(root_targets - EXPECTED_CHILDREN)}"
        )

    for pkg in model.packages:
        for dep in internal_dependencies(pkg):
            if dep.path:
                raise ReleaseError(
                    f"{pkg.name}: {dep.section}.{dep.key} usa path={dep.path!r}; "
                    "dependências internas devem ser registry-first"
                )
            if dep.git:
                raise ReleaseError(
                    f"{pkg.name}: {dep.section}.{dep.key} usa git=; "
                    "dependências internas devem vir do crates.io"
                )
            if dep.registry and dep.registry != "crates-io":
                raise ReleaseError(
                    f"{pkg.name}: {dep.section}.{dep.key} usa registry={dep.registry!r}"
                )
            if dep.version is None:
                raise ReleaseError(
                    f"{pkg.name}: {dep.section}.{dep.key} não declara version"
                )

        if pkg.submodule is not None:
            patch_doc = pkg.document.get("patch")
            child_patch = patch_doc.get("crates-io") if isinstance(patch_doc, dict) else None
            if isinstance(child_patch, dict):
                overlap = sorted(set(child_patch) & EXPECTED_NAMES)
                if overlap:
                    raise ReleaseError(
                        f"{pkg.name}: [patch.crates-io] interno referencia {overlap}; "
                        "o patch local pertence somente ao hub"
                    )


def version_requirement_matches(requirement: str, version: str) -> bool:
    return requirement.strip() in {version, f"={version}"}


def validate_lockstep(model: Model, expected: str | None = None) -> str:
    versions = {pkg.version for pkg in model.packages}
    if expected is None:
        if len(versions) != 1:
            raise ReleaseError(
                "package.version fora de lockstep: "
                + ", ".join(sorted(versions, key=parse_version))
            )
        expected = next(iter(versions))
    parse_version(expected)

    for pkg in model.packages:
        if pkg.version != expected:
            raise ReleaseError(
                f"{pkg.name}: package.version={pkg.version}, esperado {expected}"
            )
        for dep in internal_dependencies(pkg):
            assert dep.version is not None
            if not version_requirement_matches(dep.version, expected):
                raise ReleaseError(
                    f"{pkg.name}: {dep.section}.{dep.key} usa {dep.version!r}, "
                    f"esperado {expected!r}"
                )
    return expected


def graph(model: Model) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for pkg in model.packages:
        result[pkg.name] = {
            dep.target for dep in internal_dependencies(pkg, publish_only=True)
        }
    return result


def topological_order(model: Model) -> list[Package]:
    deps = graph(model)
    done: set[str] = set()
    result: list[Package] = []

    while len(result) < len(model.packages):
        ready = sorted(
            name
            for name, required in deps.items()
            if name not in done and required <= done
        )
        if not ready:
            remaining = {
                name: sorted(required - done)
                for name, required in deps.items()
                if name not in done
            }
            raise ReleaseError(f"ciclo no grafo interno: {remaining}")
        for name in ready:
            result.append(model.by_name[name])
            done.add(name)
    return result


def next_patch(model: Model) -> str:
    major, minor, patch = max(parse_version(pkg.version) for pkg in model.packages)
    return f"{major}.{minor}.{patch + 1}"


def status_lines(model: Model) -> list[str]:
    order = topological_order(model)
    width = max(len(pkg.name) for pkg in model.packages)
    lines = ["Pacotes:"]
    for pkg in sorted(model.packages, key=lambda item: item.name):
        rel = pkg.manifest.relative_to(model.root)
        lines.append(f"  {pkg.name:<{width}}  {pkg.version:<10}  {rel}")
    lines.append("")
    lines.append("Grafo de publicação:")
    deps = graph(model)
    for index, pkg in enumerate(order, start=1):
        required = ", ".join(sorted(deps[pkg.name])) or "-"
        lines.append(f"  {index:>2}. {pkg.name:<{width}}  <- {required}")
    return lines


def ensure_initialized(model: Model) -> None:
    for sub in model.submodules:
        try:
            git(sub.repo, "rev-parse", "--git-dir")
        except subprocess.CalledProcessError as exc:
            raise ReleaseError(
                f"submodule não inicializado: {sub.relpath}; "
                "execute scripts/submodules/attach.sh"
            ) from exc


def ensure_clean_attached(model: Model, root_branch: str | None = None) -> None:
    ensure_initialized(model)

    if git(model.root, "status", "--porcelain"):
        raise ReleaseError("hub possui alterações locais")

    current_root = git(model.root, "branch", "--show-current")
    if not current_root:
        raise ReleaseError("hub está em detached HEAD")
    if root_branch and current_root != root_branch:
        raise ReleaseError(f"hub está em {current_root}; esperado {root_branch}")

    for sub in model.submodules:
        if git(sub.repo, "status", "--porcelain"):
            raise ReleaseError(f"{sub.relpath} possui alterações locais")
        current = git(sub.repo, "branch", "--show-current")
        if current != sub.branch:
            raise ReleaseError(
                f"{sub.relpath} está em {current or '<detached HEAD>'}; "
                f"esperado {sub.branch}"
            )


def ensure_pushed_and_pinned(model: Model) -> None:
    ensure_clean_attached(model, root_branch="main")

    git(model.root, "fetch", "--quiet", "origin", "main")
    if git(model.root, "rev-parse", "HEAD") != git(model.root, "rev-parse", "origin/main"):
        raise ReleaseError("hub HEAD não coincide com origin/main")

    for sub in model.submodules:
        git(sub.repo, "fetch", "--quiet", "origin", sub.branch)
        head = git(sub.repo, "rev-parse", "HEAD")
        remote = git(sub.repo, "rev-parse", f"origin/{sub.branch}")
        if head != remote:
            raise ReleaseError(
                f"{sub.relpath}: HEAD não coincide com origin/{sub.branch}"
            )

        entry = git(model.root, "ls-tree", "HEAD", str(sub.relpath))
        fields = entry.split()
        if len(fields) < 3 or fields[1] != "commit":
            raise ReleaseError(f"gitlink inválido para {sub.relpath}: {entry!r}")
        pinned = fields[2]
        if pinned != head:
            raise ReleaseError(
                f"{sub.relpath}: hub fixa {pinned[:12]}, checkout está em {head[:12]}"
            )



def transform_bootstrap_bytes(data: bytes) -> bytes:
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return data
    return (
        text.replace("userspace::", "userspace_build::")
        .replace("use userspace;", "use userspace_build;")
    ).encode("utf-8")


def bootstrap_projection(model: Model) -> dict[Path, bytes]:
    source = model.by_name[BOOTSTRAP_SOURCE].repo
    projected: dict[Path, bytes] = {}

    for dirname in BOOTSTRAP_DIRS:
        root = source / dirname
        if not root.is_dir():
            raise ReleaseError(f"bootstrap source ausente: {root}")
        for path in sorted(item for item in root.rglob("*") if item.is_file()):
            rel = path.relative_to(source)
            projected[rel] = transform_bootstrap_bytes(path.read_bytes())

    for filename in BOOTSTRAP_FILES:
        path = source / filename
        if not path.is_file():
            raise ReleaseError(f"bootstrap source ausente: {path}")
        projected[Path(filename)] = transform_bootstrap_bytes(path.read_bytes())

    return projected


def bootstrap_actual(model: Model) -> dict[Path, bytes]:
    target = model.by_name[BOOTSTRAP_TARGET].repo
    actual: dict[Path, bytes] = {}

    for dirname in BOOTSTRAP_DIRS:
        root = target / dirname
        if root.is_dir():
            for path in sorted(item for item in root.rglob("*") if item.is_file()):
                actual[path.relative_to(target)] = path.read_bytes()

    for filename in BOOTSTRAP_FILES:
        path = target / filename
        if path.is_file():
            actual[Path(filename)] = path.read_bytes()

    return actual


def bootstrap_drift(model: Model) -> tuple[list[str], list[str], list[str]]:
    expected = bootstrap_projection(model)
    actual = bootstrap_actual(model)
    expected_paths = set(expected)
    actual_paths = set(actual)

    missing = sorted(str(path) for path in expected_paths - actual_paths)
    extra = sorted(str(path) for path in actual_paths - expected_paths)
    changed = sorted(
        str(path)
        for path in expected_paths & actual_paths
        if expected[path] != actual[path]
    )
    return missing, extra, changed


def validate_bootstrap_copy(model: Model) -> None:
    missing, extra, changed = bootstrap_drift(model)
    if not (missing or extra or changed):
        return

    details: list[str] = []
    if missing:
        details.append(f"ausentes={missing}")
    if extra:
        details.append(f"extras={extra}")
    if changed:
        details.append(f"divergentes={changed}")
    raise ReleaseError(
        "userspace_build divergiu da projeção de userspace; "
        + " ".join(details)
        + "; execute 'python3 scripts/publish.py prepare <versão>'"
    )


def sync_bootstrap_copy(model: Model) -> None:
    target = model.by_name[BOOTSTRAP_TARGET].repo
    projection = bootstrap_projection(model)

    for dirname in BOOTSTRAP_DIRS:
        root = target / dirname
        if root.exists():
            shutil.rmtree(root)

    for filename in BOOTSTRAP_FILES:
        path = target / filename
        if path.exists():
            path.unlink()

    for rel, data in projection.items():
        path = target / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*(?:#.*)?$")
PACKAGE_VERSION_RE = re.compile(r'^(\s*version\s*=\s*")[^"]+(".*)$')


def rewrite_manifest(pkg: Package, internal_names: set[str], version: str) -> str:
    text = pkg.manifest.read_text()
    output: list[str] = []
    section = ""
    package_version_done = False

    keys = {
        dep.key
        for dep in internal_dependencies(pkg)
        if dep.target in internal_names
    }

    for line in text.splitlines(keepends=True):
        stripped = line.rstrip("\n")
        header = SECTION_RE.match(stripped)
        if header:
            section = header.group(1).strip()
            output.append(line)
            continue

        if section == "package" and not package_version_done:
            body = line[:-1] if line.endswith("\n") else line
            match = PACKAGE_VERSION_RE.match(body)
            if match:
                ending = "\n" if line.endswith("\n") else ""
                output.append(f'{match.group(1)}{version}{match.group(2)}{ending}')
                package_version_done = True
                continue

        base = section.rsplit(".", 1)[-1]
        if base in DEP_SECTIONS:
            replaced = False
            for key in keys:
                dep_re = re.compile(rf'^(\s*{re.escape(key)}\s*=\s*)(.*)$')
                dep_match = dep_re.match(stripped)
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
                        spec = (
                            spec[: brace + 1]
                            + f' version = "{version}",'
                            + spec[brace + 1 :]
                        )
                    output.append(prefix + spec + ending)
                elif re.fullmatch(r'\s*"[^"]+"\s*(?:#.*)?', spec):
                    comment = ""
                    if "#" in spec:
                        _, comment_text = spec.split("#", 1)
                        comment = " #" + comment_text
                    output.append(f'{prefix}"{version}"{comment}{ending}')
                else:
                    raise ReleaseError(
                        f"{pkg.name}: não sei reescrever {section}.{key}: {spec}"
                    )
                replaced = True
                break
            if replaced:
                continue

        output.append(line)

    if not package_version_done:
        raise ReleaseError(f"{pkg.name}: package.version não encontrado")
    return "".join(output)


def prepare(model: Model, version: str) -> None:
    parse_version(version)
    ensure_clean_attached(model)

    bootstrap_original = bootstrap_actual(model)
    originals = {
        pkg.manifest: pkg.manifest.read_bytes()
        for pkg in model.packages
    }
    lock = model.root / "Cargo.lock"
    lock_existed = lock.exists()
    lock_original = lock.read_bytes() if lock_existed else b""

    try:
        sync_bootstrap_copy(model)
        validate_bootstrap_copy(model)

        for pkg in model.packages:
            updated = rewrite_manifest(pkg, EXPECTED_NAMES, version)
            pkg.manifest.write_text(updated)

        refreshed = load_model(model.root)
        validate_lockstep(refreshed, version)

        run("cargo", "generate-lockfile", cwd=model.root)
        print(f"\nBootstrap userspace -> userspace_build sincronizado.")
        print(f"Versão {version} preparada nos nove manifests e no Cargo.lock.")
        print("Nenhum commit, tag, push ou publish foi executado.")
    except Exception:
        target = model.by_name[BOOTSTRAP_TARGET].repo
        for dirname in BOOTSTRAP_DIRS:
            root = target / dirname
            if root.exists():
                shutil.rmtree(root)
        for filename in BOOTSTRAP_FILES:
            path = target / filename
            if path.exists():
                path.unlink()
        for rel, original in bootstrap_original.items():
            path = target / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(original)

        for path, original in originals.items():
            path.write_bytes(original)
        if lock_existed:
            lock.write_bytes(lock_original)
        elif lock.exists():
            lock.unlink()
        raise


def run_checks(model: Model, allow_dirty: bool) -> None:
    version = validate_lockstep(model)
    order = topological_order(model)
    print(f"Lockstep: {version}")
    validate_bootstrap_copy(model)
    print("Bootstrap: userspace_build sincronizado com userspace")

    run("cargo", "fmt", "--all", "--", "--check", cwd=model.root)
    run("cargo", "check", "--workspace", cwd=model.root)

    for pkg in order:
        args = [
            "cargo",
            "package",
            "--manifest-path",
            str(pkg.manifest),
            "--registry",
            "crates-io",
            "--no-verify",
        ]
        if allow_dirty:
            args.append("--allow-dirty")
        run(*args, cwd=model.root)


def api_version_exists(crate: str, version: str) -> bool:
    crate_q = urllib.parse.quote(crate, safe="")
    version_q = urllib.parse.quote(version, safe="")
    request = urllib.request.Request(
        f"{CRATES_IO}/api/v1/crates/{crate_q}/{version_q}",
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            if response.status == 200:
                return True
            raise ReleaseError(
                f"crates.io respondeu HTTP {response.status} para {crate}@{version}"
            )
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return False
        raise ReleaseError(
            f"crates.io respondeu HTTP {exc.code} para {crate}@{version}"
        ) from exc
    except urllib.error.URLError as exc:
        raise ReleaseError(
            f"não foi possível consultar crates.io para {crate}@{version}: {exc.reason}"
        ) from exc


def cargo_index_sees(crate: str, version: str) -> bool:
    result = subprocess.run(
        ["cargo", "info", f"{crate}@{version}", "--registry", "crates-io"],
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def wait_visible(crate: str, version: str, timeout: int) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if api_version_exists(crate, version) and cargo_index_sees(crate, version):
            print(f"registry visível: {crate}@{version}")
            return
        time.sleep(5)
    raise ReleaseError(
        f"timeout aguardando {crate}@{version}; "
        "reexecute publish --execute --resume quando o registry propagar"
    )


def registry_state(order: list[Package], version: str) -> list[bool]:
    state: list[bool] = []
    for pkg in order:
        exists = api_version_exists(pkg.name, version)
        state.append(exists)
        print(f"  {pkg.name:<18} {'EXISTS' if exists else 'absent'}")
    return state


def ensure_prefix_state(order: list[Package], state: list[bool]) -> int:
    first_absent = next(
        (index for index, present in enumerate(state) if not present),
        len(state),
    )
    if any(state[first_absent:]):
        bad = [
            order[index].name
            for index in range(first_absent, len(order))
            if state[index]
        ]
        raise ReleaseError(
            "estado parcial do registry não é um prefixo da ordem desta unidade; "
            f"publicações fora de ordem detectadas: {bad}"
        )
    return first_absent


def publish(model: Model, execute: bool, resume: bool, timeout: int) -> None:
    if resume and not execute:
        raise ReleaseError("--resume exige --execute")

    version = validate_lockstep(model)
    order = topological_order(model)
    ensure_pushed_and_pinned(model)
    run_checks(model, allow_dirty=False)

    print("\nOrdem de publicação:")
    for index, pkg in enumerate(order, start=1):
        print(f"  {index}. {pkg.name}@{version}")

    print("\nEstado no crates.io:")
    state = registry_state(order, version)
    if any(state) and not resume:
        existing = [
            pkg.name
            for pkg, present in zip(order, state)
            if present
        ]
        raise ReleaseError(
            f"a versão {version} já existe para {existing}; "
            "use --resume somente para retomar esta mesma unidade"
        )

    start = ensure_prefix_state(order, state) if resume else 0

    if not execute:
        print("\nDRY RUN concluído. Nenhum upload foi feito.")
        print("Use 'publish --execute' somente depois de revisar este plano.")
        return

    if resume and start:
        print("\nConfirmando visibilidade do prefixo já publicado:")
        for pkg in order[:start]:
            wait_visible(pkg.name, version, timeout)

    if start == len(order):
        print(f"\nNada a fazer: os nove crates de {version} já estão publicados.")
        return

    for pkg in order[start:]:
        run(
            "cargo",
            "publish",
            "--manifest-path",
            str(pkg.manifest),
            "--registry",
            "crates-io",
            cwd=model.root,
        )
        wait_visible(pkg.name, version, timeout)

    print(
        f"\nUnidade {version} publicada: "
        f"{len(order)} crates em ordem topológica."
    )


def command_plan(model: Model) -> None:
    print("\n".join(status_lines(model)))
    print()
    try:
        version = validate_lockstep(model)
        print(f"LOCKSTEP: YES ({version})")
    except ReleaseError as exc:
        print(f"LOCKSTEP: NO ({exc})")
    print(f"Próximo patch sugerido: {next_patch(model)}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Unidade coordenada de publicação dos nove crates no crates.io."
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("plan", help="mostra versões, grafo e ordem topológica")
    sub.add_parser(
        "next-patch",
        help="calcula o próximo patch a partir da maior versão atual",
    )

    prepare_parser = sub.add_parser(
        "prepare",
        help="alinha os nove manifests e o Cargo.lock para uma versão",
    )
    prepare_parser.add_argument("version")

    sub.add_parser(
        "check",
        help="valida lockstep, formatação, workspace e empacotamento local",
    )

    publish_parser = sub.add_parser(
        "publish",
        help="valida e publica os nove crates na ordem do grafo",
    )
    publish_parser.add_argument(
        "--execute",
        action="store_true",
        help="faz uploads reais; sem esta opção é dry-run",
    )
    publish_parser.add_argument(
        "--resume",
        action="store_true",
        help="retoma um prefixo já publicado desta mesma versão",
    )
    publish_parser.add_argument(
        "--visibility-timeout",
        type=int,
        default=300,
        help="segundos para cada crate ficar visível no API/index (default: 300)",
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        model = load_model(ROOT)
        if args.command == "plan":
            command_plan(model)
        elif args.command == "next-patch":
            print(next_patch(model))
        elif args.command == "prepare":
            prepare(model, args.version)
        elif args.command == "check":
            run_checks(model, allow_dirty=True)
        elif args.command == "publish":
            publish(
                model,
                args.execute,
                args.resume,
                args.visibility_timeout,
            )
        else:
            parser.error(f"comando desconhecido: {args.command}")
        return 0
    except ReleaseError as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        return 2
    except subprocess.CalledProcessError as exc:
        print(
            f"ERRO: comando falhou com status {exc.returncode}",
            file=sys.stderr,
        )
        return exc.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
