#!/bin/bash
set -e

# Uso: ./cleanup_branch.sh <branch_name> [--auto] [--force]

if [ $# -lt 1 ]; then
    echo "Uso: $0 <branch_name> [--auto] [--force]"
    exit 1
fi

branch_to_delete="$1"
shift

auto_mode=false
force_mode=false

# Processa flags
for arg in "$@"; do
    case "$arg" in
        --auto) auto_mode=true ;;
        --force) force_mode=true ;;
    esac
done

submodules=(ample userspace_build userspace kernelspace)

prompt() {
    if $auto_mode || $force_mode; then
        return 0
    fi
    read -p "$1 [y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]]
}

delete_named_branch() {
    local repo_path="$1"
    cd "$repo_path"

    current_branch=$(git symbolic-ref --short HEAD)

    # Remove branch local se não for o atual
    if [ "$branch_to_delete" != "$current_branch" ]; then
        if git rev-parse --verify "$branch_to_delete" >/dev/null 2>&1; then
            if prompt "Remover branch local '$branch_to_delete' em $repo_path?"; then
                git branch -D "$branch_to_delete"
                echo "Branch local '$branch_to_delete' removida."
            fi
        fi
    else
        echo "Não é possível deletar o branch atual '$current_branch' localmente em $repo_path."
    fi

    # Remove branch remota
    if git ls-remote --exit-code --heads origin "$branch_to_delete" >/dev/null 2>&1; then
        if prompt "Remover branch remota '$branch_to_delete' em $repo_path?"; then
            git push origin --delete "$branch_to_delete"
            echo "Branch remota '$branch_to_delete' removida."
        fi
    fi

    cd - >/dev/null
}

echo "=== Iniciando remoção do branch '$branch_to_delete' ==="

# Limpa submódulos
for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    delete_named_branch "$sub"
done

# Limpa repositório pai
echo ">>> Repositório pai"
delete_named_branch "."

echo "=== Remoção do branch '$branch_to_delete' concluída ==="
