#!/bin/bash
set -e

# Verifica argumentos
if [ $# -lt 1 ]; then
    echo "Uso: $0 <branch_name> [--auto] [--force]"
    exit 1
fi

date_stamp=$(date +%Y%m%d%H%M%S)
branch_name="$1"
auto_mode=false
force_mode=false

shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) auto_mode=true ;;
        --force) force_mode=true ;;
    esac
    shift
done

submodules=(ample userspace_build userspace kernelspace)

prompt() {
    # Se auto_mode ou force_mode estão ativados, retorna true
    if $auto_mode || $force_mode; then
        return 0
    fi
    read -p "$1 [y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]]
}

echo "=== Iniciando sincronização na branch '$branch_name' ==="
echo "Auto mode: $auto_mode"
echo "Force mode: $force_mode"

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    git switch -C "$branch_name"

    tag="$sub-${branch_name}-$(whoami)-backup-$date_stamp"
    if prompt "Criar tag de backup '$tag' e enviar para o remoto?"; then
        if git rev-parse "$tag" >/dev/null 2>&1; then
            echo "Tag $tag já existe."
            if $force_mode; then
                git tag -d "$tag"
                git push origin ":refs/tags/$tag"
                echo "Tag antiga removida (force mode)."
            fi
        fi
        git tag "$tag"
        git push origin "$tag" $($force_mode && echo "--force")
        echo "Tag enviada."
    fi

    if ! git diff-index --quiet HEAD --; then
        if prompt "Há mudanças locais em $sub. Comitar?"; then
            git add .
            git commit -m "initing $branch_name"
            echo "Commit realizado."
        fi
    fi

    if prompt "Push do branch '$branch_name' para origin?"; then
        git push --set-upstream origin "$branch_name" $($force_mode && echo "--force")
        echo "Branch pushada."
    fi

    cd ..
done

echo "=== Atualizando repositório pai ==="
git switch -C "$branch_name"

tag="userspace-hub-${branch_name}-$(whoami)-backup-$date_stamp"
if prompt "Criar tag de backup '$tag' no pai e enviar?"; then
    if git rev-parse "$tag" >/dev/null 2>&1; then
        echo "Tag $tag já existe."
        if $force_mode; then
            git tag -d "$tag"
            git push origin ":refs/tags/$tag"
            echo "Tag antiga removida (force mode)."
        fi
    fi
    git tag "$tag"
    git push origin "$tag" $($force_mode && echo "--force")
    echo "Tag enviada."
fi

git add "${submodules[@]}"

if ! git diff-index --quiet HEAD --; then
    if prompt "Há mudanças no repositório pai. Comitar?"; then
        git add .
        git commit -m "initing $branch_name"
        echo "Commit realizado."
    fi
fi

if prompt "Push do branch '$branch_name' do pai para origin?"; then
    git push --set-upstream origin "$branch_name" $($force_mode && echo "--force")
    echo "Branch do pai pushada."
fi

# ==== Status final resumido ====
echo "=== Status final dos submódulos e do repositório pai ==="

for sub in "${submodules[@]}"; do
    cd "$sub"
    echo ">>> Submódulo: $sub"
    echo "Branch: $(git symbolic-ref --short HEAD)"
    echo "Commit: $(git rev-parse --short HEAD) - $(git log -1 --pretty=%B)"
    cd ..
done

echo ">>> Repositório pai"
echo "Branch: $(git symbolic-ref --short HEAD)"
echo "Commit: $(git rev-parse --short HEAD) - $(git log -1 --pretty=%B)"

echo "=== Sincronização completa ==="
