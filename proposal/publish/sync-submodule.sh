#!/usr/bin/env bash
set -euo pipefail

PUBLISH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PUBLISH_DIR/../.." && pwd)"
SUBMODULE=""
BRANCH="main"
APPLY=false

usage() {
    printf 'Uso: %s --submodule crates/NOME [--branch BRANCH] [--dry-run|--apply]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --submodule)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            SUBMODULE="$2"
            shift 2
            ;;
        --branch)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            BRANCH="$2"
            shift 2
            ;;
        --apply)
            APPLY=true
            shift
            ;;
        --dry-run)
            APPLY=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$SUBMODULE" ] || { usage >&2; exit 2; }
case "$SUBMODULE" in
    crates/*) ;;
    *) printf '%s\n' '--submodule deve apontar para crates/NOME.' >&2; exit 2 ;;
esac

cd "$ROOT"
SUBMODULE_DIR="$ROOT/$SUBMODULE"
[ -d "$SUBMODULE_DIR" ] || {
    printf 'Submodule inexistente: %s\n' "$SUBMODULE" >&2
    exit 1
}

if [ -n "$(git status --short)" ]; then
    printf '%s\n' 'O hub possui alterações locais; sincronização interrompida.' >&2
    git status --short
    exit 1
fi
if [ -n "$(git -C "$SUBMODULE_DIR" status --short)" ]; then
    printf 'O submodule %s possui alterações locais; sincronização interrompida.\n' "$SUBMODULE" >&2
    git -C "$SUBMODULE_DIR" status --short
    exit 1
fi

REMOTE="$(git -C "$SUBMODULE_DIR" remote get-url origin)"
printf 'Submodule: %s\nRemoto: %s\nBranch remota: %s\n' "$SUBMODULE" "$REMOTE" "$BRANCH"
printf '%s\n' 'Buscando o commit remoto; nenhuma alteração de checkout será feita no modo dry-run.'
git -C "$SUBMODULE_DIR" fetch --quiet origin "$BRANCH"
TARGET="$(git -C "$SUBMODULE_DIR" rev-parse "origin/$BRANCH")"
CURRENT="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
printf 'Commit atual: %s\nCommit remoto: %s\n' "$CURRENT" "$TARGET"

if [ "$CURRENT" = "$TARGET" ]; then
    printf '%s\n' 'O submodule já aponta para o commit remoto.'
    exit 0
fi

if [ "$APPLY" = false ]; then
    printf '%s\n' 'Modo dry-run: nenhum checkout ou gitlink foi alterado.'
    printf 'Para aplicar: %s --submodule %s --branch %s --apply\n' "$0" "$SUBMODULE" "$BRANCH"
    exit 0
fi

git -C "$SUBMODULE_DIR" checkout --detach "$TARGET"
git add "$SUBMODULE"
printf '%s\n' 'Gitlink preparado no índice. Revise com git diff --cached --submodule e faça o commit manualmente.'
