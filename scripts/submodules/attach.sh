#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
PULL=false

usage() {
    printf 'Uso: %s [--pull]\n' "$0"
    printf '%s\n' 'Sem --pull: anexa cada submodule à branch configurada no SHA fixado pelo hub, quando seguro.'
    printf '%s\n' 'Com --pull: também avança por fast-forward até origin/<branch>.'
}

case "${1:-}" in
    "") ;;
    --pull) PULL=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

cd "$ROOT"
git submodule sync

git config submodule.recurse true
git config status.submoduleSummary true
git config diff.submodule log
git config fetch.recurseSubmodules on-demand

while IFS=' ' read -r key path; do
    [ -n "$path" ] || continue

    section="${key%.path}"
    branch="$(git config --file .gitmodules --get "$section.branch" || true)"
    branch="${branch:-main}"
    repo="$ROOT/$path"

    printf '\n== %s (%s) ==\n' "$path" "$branch"

    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        git submodule update --init --checkout -- "$path"
    fi

    if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        printf 'Submodule possui alterações locais; nenhuma branch será movida: %s\n' "$path" >&2
        exit 1
    fi

    entry="$(git ls-tree HEAD -- "$path")"
    pinned="$(printf '%s\n' "$entry" | awk '$2 == "commit" {print $3}')"
    if [ -z "$pinned" ]; then
        printf 'Não encontrei gitlink para %s no HEAD do hub.\n' "$path" >&2
        exit 1
    fi

    git -C "$repo" fetch --quiet origin "$branch"
    remote_ref="origin/$branch"
    current_branch="$(git -C "$repo" branch --show-current)"

    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        local_tip="$(git -C "$repo" rev-parse "$branch")"

        if [ "$local_tip" != "$pinned" ]; then
            if git -C "$repo" merge-base --is-ancestor "$local_tip" "$remote_ref" &&
               git -C "$repo" merge-base --is-ancestor "$pinned" "$remote_ref"; then
                if [ "$current_branch" = "$branch" ]; then
                    git -C "$repo" switch --detach "$pinned" >/dev/null
                    current_branch=""
                fi
                git -C "$repo" branch -f "$branch" "$pinned" >/dev/null
            else
                printf '%s\n' "Preservando $branch: ela contém história que não pode ser reposicionada com segurança."
            fi
        fi
    else
        git -C "$repo" branch "$branch" "$pinned"
    fi

    git -C "$repo" switch "$branch" >/dev/null
    git -C "$repo" branch --set-upstream-to="$remote_ref" "$branch" >/dev/null

    if [ "$PULL" = true ]; then
        if git -C "$repo" merge-base --is-ancestor HEAD "$remote_ref"; then
            git -C "$repo" merge --ff-only "$remote_ref"
        elif git -C "$repo" merge-base --is-ancestor "$remote_ref" HEAD; then
            printf '%s\n' "Branch local está à frente de $remote_ref; nenhum commit foi descartado."
        else
            printf 'Divergência entre %s e %s; resolva manualmente.\n' "$path" "$remote_ref" >&2
            exit 1
        fi
    fi

    printf 'Pinned: %s\n' "${pinned:0:12}"
    printf 'HEAD:   %s\n' "$(git -C "$repo" rev-parse --short HEAD)"
    printf 'Branch: %s\n' "$(git -C "$repo" branch --show-current)"
    printf 'Track:  %s\n' "$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$')

printf '\n%s\n' 'Submodules anexados. Cada crates/* pode ser usado como repositório Git normal.'
printf '%s\n' 'O hub continua registrando um SHA exato por gitlink.'
