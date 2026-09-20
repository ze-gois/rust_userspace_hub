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
SUBMODULE_DIR="$ROOT/$SUBMODULE"
[ -d "$SUBMODULE_DIR" ] || { printf 'Submodule inexistente: %s\n' "$SUBMODULE" >&2; exit 1; }

UNRELATED="$(git status --porcelain --untracked-files=no | awk -v target="$SUBMODULE" 'substr($0, 4) != target')"
if [ -n "$UNRELATED" ]; then
    printf '%s\n' 'O hub possui alterações não relacionadas ao submodule alvo:' >&2
    printf '%s\n' "$UNRELATED" >&2
    exit 1
fi

if [ -n "$(git -C "$SUBMODULE_DIR" status --porcelain)" ]; then
    printf 'O submodule %s possui alterações locais; atualização interrompida.\n' "$SUBMODULE" >&2
    exit 1
fi

git -C "$SUBMODULE_DIR" cat-file -e "$COMMIT^{commit}"
CURRENT="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
BRANCH="$(git -C "$SUBMODULE_DIR" branch --show-current)"
printf 'Submodule: %s\nBranch: %s\nHEAD: %s\nSolicitado: %s\n'     "$SUBMODULE" "${BRANCH:-detached}" "$CURRENT" "$COMMIT"

if [ "$CURRENT" != "$COMMIT" ]; then
    printf '%s\n' 'O commit solicitado não é o HEAD atual do submodule.' >&2
    printf '%s\n' 'Faça switch/merge normalmente dentro da crate e tente novamente; este script não usa detached HEAD.' >&2
    exit 1
fi

if [ -z "$BRANCH" ]; then
    printf '%s\n' 'O submodule está em detached HEAD. Execute scripts/submodules/attach.sh primeiro.' >&2
    exit 1
fi

if [ "$APPLY" = false ]; then
    printf '%s\n' 'Modo dry-run: o gitlink não foi adicionado ao índice.'
    exit 0
fi

git add "$SUBMODULE"
printf '%s\n' 'Gitlink preparado no índice sem alterar branch ou HEAD do submodule.'
printf '%s\n' 'Revise com git diff --cached --submodule e faça o commit do hub.'
