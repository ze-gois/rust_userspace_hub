#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
PULL=false

usage() {
    printf 'Uso: %s [--pull]\n' "$0"
    printf '%s\n' 'Sem --pull: anexa cada submodule à branch configurada preservando o SHA fixado pelo hub.'
    printf '%s\n' 'Com --pull: depois de anexar, faz fast-forward até origin/<branch> quando possível.'
}

case "${1:-}" in
    "") ;;
    --pull) PULL=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

cd "$ROOT"

git submodule sync
git submodule update --init

# Torna o comportamento cotidiano do superproject mais informativo.
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

    if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        printf 'Submodule possui alterações locais; não vou trocar branches: %s\n' "$path" >&2
        exit 1
    fi

    pinned="$(git -C "$repo" rev-parse HEAD)"
    git -C "$repo" fetch --quiet origin "$branch"
    remote_ref="origin/$branch"

    if ! git -C "$repo" rev-parse --verify --quiet "$remote_ref^{commit}" >/dev/null; then
        printf 'Branch remota inexistente: %s em %s\n' "$remote_ref" "$path" >&2
        exit 1
    fi

    if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
        local_tip="$(git -C "$repo" rev-parse "$branch")"

        if [ "$local_tip" != "$pinned" ]; then
            if git -C "$repo" merge-base --is-ancestor "$local_tip" "$remote_ref" &&
               git -C "$repo" merge-base --is-ancestor "$pinned" "$remote_ref"; then
                # A branch local não contém trabalho exclusivo; reposicioná-la no gitlink
                # mantém o superproject limpo e ainda permite um pull normal depois.
                git -C "$repo" branch -f "$branch" "$pinned" >/dev/null
            else
                printf '%s\n' "A branch local $branch contém história não representada pelo remoto; preservando-a."
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

    printf 'HEAD:   %s\n' "$(git -C "$repo" rev-parse --short HEAD)"
    printf 'Branch: %s\n' "$(git -C "$repo" branch --show-current)"
    printf 'Track:  %s\n' "$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}')"
done < <(git config --file .gitmodules --get-regexp '^submodule\..*\.path$')

printf '\n%s\n' 'Submodules anexados. Agora cada crates/* pode ser usado como um repositório Git normal.'
printf '%s\n' 'O hub continua registrando o SHA exato de cada submodule no próximo commit do superproject.'
