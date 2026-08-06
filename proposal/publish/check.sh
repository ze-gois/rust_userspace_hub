#!/usr/bin/env bash
set -euo pipefail

PUBLISH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PUBLISH_DIR/../.." && pwd)"
cd "$ROOT"

if [ -n "$(git status --short)" ]; then
    printf '%s\n' 'O hub possui alterações locais. Resolva-as antes do check de release.' >&2
    git status --short
    exit 1
fi

while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ -n "$(git -C "$ROOT/$path" status --short)" ]; then
        printf 'Submodule modificado: %s\n' "$path" >&2
        git -C "$ROOT/$path" status --short
        exit 1
    fi
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

printf '%s\n' '== Formatação =='
cargo fmt --all -- --check

printf '\n%s\n' '== Check =='
cargo check --workspace

printf '\n%s\n' '== Testes =='
cargo test --workspace

printf '\n%s\n' '== Clippy =='
cargo clippy --workspace --all-targets -- -D warnings

printf '\n%s\n' '== Duplicações =='
cargo tree --workspace --duplicates

printf '\n%s\n' 'Checks de release concluídos. Nenhuma crate foi publicada.'
