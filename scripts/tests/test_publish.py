from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "publish.py"
SPEC = importlib.util.spec_from_file_location("publish_unit", SCRIPT)
assert SPEC and SPEC.loader
publish_unit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = publish_unit
SPEC.loader.exec_module(publish_unit)

CHILDREN = [
    "ample",
    "computers",
    "humans",
    "kernelspace",
    "twins",
    "userspace",
    "userspace_build",
    "webspace",
]

DEPS = {
    "ample": {},
    "computers": {},
    "humans": {"ample": "0.2.2"},
    "userspace_build": {"ample": "0.2.2"},
    "userspace": {"ample": "0.2.2", "userspace_build": "0.2.2"},
    "webspace": {"ample": "0.2.2", "humans": "0.2.2"},
    "kernelspace": {
        "ample": "0.2.2",
        "userspace": "0.2.2",
        "userspace_build": "0.2.2",
    },
    "twins": {
        "ample": "0.2.2",
        "userspace": "0.2.2",
        "userspace_build": "0.2.2",
    },
}


def child_manifest(name: str, version: str = "0.2.2") -> str:
    deps = DEPS[name]
    body = [
        "[package]\n",
        f'name = "{name}"\n',
        f'version = "{version}"\n',
        "publish = true\n\n",
        "[dependencies]\n",
    ]
    for dep, dep_version in deps.items():
        body.append(f'{dep} = "{dep_version}"\n')
    body.append("\n[build-dependencies]\n")
    return "".join(body)


def make_fixture(root: Path) -> None:
    sections = []
    for name in CHILDREN:
        sections.append(
            f'[submodule "crates/{name}"]\n'
            f"\tpath = crates/{name}\n"
            f"\turl = git@github.com:ze-gois/rust_{name}.git\n"
            "\tbranch = main\n"
        )
        repo = root / "crates" / name
        repo.mkdir(parents=True)
        (repo / "Cargo.toml").write_text(child_manifest(name))

    (root / ".gitmodules").write_text("\n".join(sections))

    cargo = [
        "[package]\n",
        'name = "userspace_hub"\n',
        'version = "0.2.2"\n',
        "publish = true\n\n",
        "[workspace]\n",
        "members = [\n",
    ]
    cargo.extend(f'    "crates/{name}",\n' for name in CHILDREN)
    cargo.append("]\n\n[patch.crates-io]\n")
    cargo.extend(
        f'{name} = {{ path = "crates/{name}" }}\n'
        for name in CHILDREN
    )
    cargo.append("\n[dependencies]\n")
    cargo.extend(
        f'{name} = "0.2.2"\n'
        for name in CHILDREN
        if name != "userspace_build"
    )
    cargo.append(
        '\n[build-dependencies]\nuserspace_build = "0.2.2"\n'
    )
    (root / "Cargo.toml").write_text("".join(cargo))


class PublishUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        make_fixture(self.root)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_topological_order(self) -> None:
        model = publish_unit.load_model(self.root)
        self.assertEqual(
            [pkg.name for pkg in publish_unit.topological_order(model)],
            [
                "ample",
                "computers",
                "humans",
                "userspace_build",
                "userspace",
                "webspace",
                "kernelspace",
                "twins",
                "userspace_hub",
            ],
        )

    def test_exact_nine_packages_are_required(self) -> None:
        text = (self.root / ".gitmodules").read_text()
        marker = '[submodule "crates/webspace"]'
        text = text[: text.index(marker)]
        (self.root / ".gitmodules").write_text(text)
        with self.assertRaises(publish_unit.ReleaseError):
            publish_unit.load_model(self.root)

    def test_internal_path_is_rejected(self) -> None:
        manifest = self.root / "crates" / "userspace" / "Cargo.toml"
        text = manifest.read_text().replace(
            'ample = "0.2.2"',
            'ample = { version = "0.2.2", path = "../ample" }',
        )
        manifest.write_text(text)
        with self.assertRaises(publish_unit.ReleaseError):
            publish_unit.load_model(self.root)

    def test_manifest_rewrite_aligns_package_and_dependencies(self) -> None:
        model = publish_unit.load_model(self.root)
        pkg = model.by_name["userspace"]
        rewritten = publish_unit.rewrite_manifest(
            pkg,
            publish_unit.EXPECTED_NAMES,
            "0.2.3",
        )
        self.assertIn('version = "0.2.3"', rewritten)
        self.assertIn('ample = "0.2.3"', rewritten)
        self.assertIn('userspace_build = "0.2.3"', rewritten)

    def test_patch_must_cover_canonical_child(self) -> None:
        manifest = self.root / "Cargo.toml"
        text = manifest.read_text().replace(
            'ample = { path = "crates/ample" }',
            'ample = { path = "crates/computers" }',
        )
        manifest.write_text(text)
        with self.assertRaises(publish_unit.ReleaseError):
            publish_unit.load_model(self.root)


if __name__ == "__main__":
    unittest.main()
