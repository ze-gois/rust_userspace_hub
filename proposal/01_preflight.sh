#!/usr/bin/env bash
set -euo pipefail

PROPOSAL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PROPOSAL_DIR/.." && pwd)"
cd "$ROOT"

failures=0
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        printf 'ok   %-18s %s\n' "$1" "$(command -v "$1")"
    else
        printf 'FAIL %-18s não encontrado\n' "$1"
        failures=$((failures + 1))
    fi
}

printf 'Workspace: %s\n\n' "$ROOT"
printf '%s\n' '== Ferramentas =='
for command in git cargo rustc python3; do
    check_command "$command"
done

printf '\n%s\n' '== Git do hub =='
git --no-optional-locks status --short --branch

printf '\n%s\n' '== Submodules =='
git submodule status --recursive

while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ ! -d "$ROOT/$path" ]; then
        printf 'FAIL submodule ausente: %s\n' "$path"
        failures=$((failures + 1))
        continue
    fi

    if [ -n "$(git -C "$ROOT/$path" status --short 2>/dev/null)" ]; then
        printf 'WARN submodule modificado: %s\n' "$path"
    else
        printf 'ok   submodule limpo: %s\n' "$path"
    fi
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

printf '\n%s\n' '== Cargo metadata =='
if cargo metadata --format-version 1 --no-deps >/dev/null; then
    printf '%s\n' 'ok   cargo metadata'
else
    printf '%s\n' 'FAIL cargo metadata'
    failures=$((failures + 1))
fi

printf '\n%s\n' '== Dependências duplicadas =='
if cargo tree --workspace --duplicates; then
    printf '%s\n' 'Aviso: revise cada duplicação acima; nem toda duplicação é necessariamente inválida.'
else
    printf '%s\n' 'FAIL cargo tree --duplicates'
    failures=$((failures + 1))
fi

printf '\n%s\n' '== Resultado =='
if [ "$failures" -eq 0 ]; then
    printf '%s\n' 'Preflight concluído sem falhas. Este script não altera arquivos.'
else
    printf 'Preflight encontrou %s falha(s). Nenhuma alteração foi feita.\n' "$failures"
    exit 1
fi
