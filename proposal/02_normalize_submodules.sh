#!/usr/bin/env bash
set -euo pipefail

PROPOSAL_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PROPOSAL_DIR/.." && pwd)"
APPLY=false

if [ "${1:-}" = "--apply" ]; then
    APPLY=true
elif [ "${1:-}" != "" ]; then
    printf 'Uso: %s [--apply]\n' "$0" >&2
    exit 2
fi

cd "$ROOT"
printf 'Raiz: %s\n' "$ROOT"

if [ "$APPLY" = true ]; then
    printf '%s\n' 'Inicializando os submodules de gestão nos commits registrados pelo hub...'
    git submodule update --init --recursive
else
    printf '%s\n' 'Modo inspeção: nenhum submodule será alterado.'
fi

printf '\n%s\n' 'Estado dos submodules:'
git submodule status --recursive

printf '\n%s\n' 'Branches e worktrees:'
while IFS= read -r path; do
    [ -z "$path" ] && continue
    printf '\n[%s]\n' "$path"
    git -C "$ROOT/$path" status --short --branch
    git -C "$ROOT/$path" log -1 --format='%h %D %s'
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

printf '\n%s\n' 'Observação: este script não faz checkout de main, não faz pull e não faz push.'
printf '%s\n' 'A branch main no .gitmodules não altera automaticamente o commit fixado pelo hub.'
