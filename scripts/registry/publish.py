#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys
import re

USERSPACE_DIR = os.getcwd()
CRATE_DIR = os.path.join(USERSPACE_DIR, "crate")
BUILD_DIR = os.path.join(USERSPACE_DIR, "build")
PUBLISH_CARGO = os.path.join(USERSPACE_DIR, "scripts", "registry", "publish", "build", "Cargo.toml")
PUBLISH_BUILD_RS = os.path.join(USERSPACE_DIR, "scripts", "registry", "publish", "build", "build.rs")

def prepare_build_staging(version_build):
    # Limpa build dir
    # if os.path.exists(BUILD_DIR):
    #     shutil.rmtree(BUILD_DIR)
    # shutil.copytree(CRATE_DIR, BUILD_DIR)

    # Sobrescreve arquivos
    if os.path.exists(PUBLISH_CARGO):
        shutil.copy(PUBLISH_CARGO, os.path.join(BUILD_DIR, "Cargo.toml"))
    if os.path.exists(PUBLISH_BUILD_RS):
        shutil.copy(PUBLISH_BUILD_RS, os.path.join(BUILD_DIR, "build.rs"))

    # Atualiza a versão do userspace_build na crate principal
    crate_cargo_toml = os.path.join(CRATE_DIR, "Cargo.toml")
    with open(crate_cargo_toml, "r") as f:
        content = f.read()

    pattern = r'(version\s*=\s*")[^"]*(")'

    def replace_build_cersion(match):
        return match.group(1) + version_build + match.group(2)

    if re.search(pattern, content):
        content = re.sub(pattern, replace_build_cersion, content)


    pattern = r'(userspace_build\s*=\s*\{[^}]*version\s*=\s*")[^"]*(".*\})'

    def replace_version(match):
        return match.group(1) + version_build + match.group(2)

    if re.search(pattern, content):
        content = re.sub(pattern, replace_version, content)

    with open(crate_cargo_toml, "w") as f:
        f.write(content)

def git_commit_and_push(dir_path, message):
    if not os.path.exists(os.path.join(dir_path, ".git")):
        subprocess.run(["git", "init"], cwd=dir_path, check=True)
    subprocess.run(["git", "add", "."], cwd=dir_path, check=True)
    subprocess.run(["git", "commit", "-m", message], cwd=dir_path, check=True)
    # opcional: adicionar branch e remote correto
    subprocess.run(["git", "push", "-u", "origin", "main"], cwd=dir_path, check=True)

def cargo_publish(dir_path):
    subprocess.run(["cargo", "publish"], cwd=dir_path, check=True)

def publish_build_and_crate(version_build):

    build_cargo_toml = "publish_Cargo.toml"
    with open(build_cargo_toml, "r") as f:
        content = f.read()

    pattern = r'(version\s*=\s*")[^"]*(")'

    def replace_build_ersion(match):
        return match.group(1) + version_build + match.group(2)

    if re.search(pattern, content):
        content = re.sub(pattern, replace_build_ersion, content)

    with open(build_cargo_toml, "w") as f:
        f.write(content)

    print(f"Publishing build crate userspace_build version {version_build}")
    prepare_build_staging(version_build)
    git_commit_and_push(BUILD_DIR, f"Prepare build crate userspace_build {version_build}")
    cargo_publish(BUILD_DIR)
    print("Build crate published.")

    print("Now publishing main crate userspace...")
    git_commit_and_push(CRATE_DIR, f"Update userspace to depend on userspace_build {version_build}")
    cargo_publish(CRATE_DIR)
    print("Main crate published successfully.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: publish.py <userspace_build_version>")
        sys.exit(1)

    version_build = sys.argv[1]
    publish_build_and_crate(version_build)
