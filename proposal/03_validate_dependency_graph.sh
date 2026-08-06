#!/usr/bin/env bash
set -euo pipefail

PROPOSAL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PROPOSAL_DIR/.." && pwd)"
cd "$ROOT"

printf '%s\n' '== Pacotes do workspace =='
cargo metadata --format-version 1 --no-deps | python3 -c '
import json
import sys

data = json.load(sys.stdin)
for package in sorted(data["packages"], key=lambda item: item["name"]):
    print(f"{package[\"name\"]} {package[\"version\"]} {package[\"manifest_path\"]}")
'

printf '\n%s\n' '== Dependências do workspace =='
cargo tree --workspace --depth 1 --prefix depth

printf '\n%s\n' '== Duplicações =='
DUPLICATES="$(cargo tree --workspace --duplicates || true)"
if [ -n "$DUPLICATES" ]; then
    printf '%s\n' "$DUPLICATES"
    printf '\n%s\n' 'As duplicações acima devem ser revisadas antes da publicação.'
else
    printf '%s\n' 'Nenhuma duplicação encontrada.'
fi

printf '\n%s\n' '== Validação sem publicação =='
cargo check --workspace
printf '%s\n' 'Grafo validado. Este script não altera arquivos nem publica crates.'
