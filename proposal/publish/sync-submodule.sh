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

UNRELATED="$(git status --porcelain --untracked-files=no | awk -v target="$SUBMODULE" 'substr($0, 4) != target')"
if [ -n "$UNRELATED" ]; then
    printf '%s\n' 'O hub possui alterações não relacionadas ao submodule alvo:' >&2
    printf '%s\n' "$UNRELATED" >&2
    exit 1
fi

if [ -n "$(git -C "$SUBMODULE_DIR" status --porcelain)" ]; then
    printf 'O submodule %s possui alterações locais; sincronização interrompida.\n' "$SUBMODULE" >&2
    git -C "$SUBMODULE_DIR" status --short
    exit 1
fi

REMOTE="$(git -C "$SUBMODULE_DIR" remote get-url origin)"
printf 'Submodule: %s\nRemoto: %s\nBranch: %s\n' "$SUBMODULE" "$REMOTE" "$BRANCH"

git -C "$SUBMODULE_DIR" fetch --quiet origin "$BRANCH"
TARGET="$(git -C "$SUBMODULE_DIR" rev-parse "origin/$BRANCH")"
CURRENT="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
CURRENT_BRANCH="$(git -C "$SUBMODULE_DIR" branch --show-current)"
printf 'HEAD atual: %s (%s)\nHEAD remoto: %s\n' "$CURRENT" "${CURRENT_BRANCH:-detached}" "$TARGET"

if [ "$APPLY" = false ]; then
    printf '%s\n' 'Modo dry-run: nenhum checkout, merge ou gitlink foi alterado.'
    exit 0
fi

if ! git -C "$SUBMODULE_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git -C "$SUBMODULE_DIR" switch -c "$BRANCH" --track "origin/$BRANCH"
else
    git -C "$SUBMODULE_DIR" switch "$BRANCH"
    git -C "$SUBMODULE_DIR" branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null
fi

if git -C "$SUBMODULE_DIR" merge-base --is-ancestor HEAD "origin/$BRANCH"; then
    git -C "$SUBMODULE_DIR" merge --ff-only "origin/$BRANCH"
elif git -C "$SUBMODULE_DIR" merge-base --is-ancestor "origin/$BRANCH" HEAD; then
    printf '%s\n' 'A branch local está à frente do remoto; nenhum commit local será descartado.'
else
    printf '%s\n' 'Branch local e remota divergiram; resolva manualmente antes de atualizar o hub.' >&2
    exit 1
fi

git add "$SUBMODULE"
printf '%s\n' 'Gitlink preparado no índice; o submodule permanece em uma branch normal.'
printf '%s\n' 'Revise com git diff --cached --submodule antes do commit do hub.'
