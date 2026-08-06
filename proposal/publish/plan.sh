#!/usr/bin/env bash
set -euo pipefail

PUBLISH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PUBLISH_DIR/../.." && pwd)"
cd "$ROOT"

CRATE="${1:-}"

printf 'Workspace: %s\n' "$ROOT"
printf '%s\n' '== Estado Git do hub =='
git --no-optional-locks status --short --branch

printf '\n%s\n' '== Submodules fixados =='
git submodule status --recursive

printf '\n%s\n' '== Plano de pacotes =='
if [ -n "$CRATE" ]; then
    cargo metadata --format-version 1 --no-deps | python3 -c '
import json
import sys
wanted = sys.argv[1]
data = json.load(sys.stdin)
found = [p for p in data["packages"] if p["name"] == wanted]
if not found:
    raise SystemExit(f"crate não encontrada no workspace: {wanted}")
for package in found:
    name = package["name"]
    version = package["version"]
    manifest = package["manifest_path"]
    print(f"crate={name}")
    print(f"version={version}")
    print(f"manifest={manifest}")
' "$CRATE"
else
    cargo metadata --format-version 1 --no-deps | python3 -c '
import json
import sys
data = json.load(sys.stdin)
for package in sorted(data["packages"], key=lambda p: p["name"]):
    name = package["name"]
    version = package["version"]
    manifest = package["manifest_path"]
    print(f"{name} {version} {manifest}")
'
fi

printf '\n%s\n' 'Nenhuma versão foi incrementada e nada será publicado por este comando.'
printf '%s\n' 'Use publish.sh somente depois de revisar este plano.'
