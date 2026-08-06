#!/usr/bin/env bash
set -euo pipefail

PUBLISH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PUBLISH_DIR/../.." && pwd)"
SUBMODULE=""
COMMIT=""
APPLY=false

usage() {
    printf 'Uso: %s --submodule crates/NOME --commit SHA [--dry-run|--apply]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --submodule)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            SUBMODULE="$2"
            shift 2
            ;;
        --commit)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            COMMIT="$2"
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

[ -n "$SUBMODULE" ] && [ -n "$COMMIT" ] || { usage >&2; exit 2; }
case "$SUBMODULE" in
    crates/*) ;;
    *) printf '%s\n' '--submodule deve apontar para crates/NOME.' >&2; exit 2 ;;
esac

cd "$ROOT"
[ -d "$ROOT/$SUBMODULE" ] || { printf 'Submodule inexistente: %s\n' "$SUBMODULE" >&2; exit 1; }

if [ -n "$(git status --short)" ]; then
    printf '%s\n' 'O hub possui alterações locais; atualização interrompida.' >&2
    exit 1
fi
if [ -n "$(git -C "$ROOT/$SUBMODULE" status --short)" ]; then
    printf 'O submodule %s possui alterações locais; atualização interrompida.\n' "$SUBMODULE" >&2
    exit 1
fi

git -C "$ROOT/$SUBMODULE" cat-file -e "$COMMIT^{commit}"
CURRENT="$(git -C "$ROOT/$SUBMODULE" rev-parse HEAD)"
printf 'Submodule: %s\nAtual: %s\nNovo: %s\n' "$SUBMODULE" "$CURRENT" "$COMMIT"

if [ "$APPLY" = false ]; then
    printf '%s\n' 'Modo dry-run: nenhum gitlink foi alterado.'
    exit 0
fi

git -C "$ROOT/$SUBMODULE" checkout --detach "$COMMIT"
git add "$SUBMODULE"
printf 'Gitlink preparado no índice. Revise com git diff --cached e faça o commit manualmente.\n'
