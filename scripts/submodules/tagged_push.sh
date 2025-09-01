#!/bin/bash
set -e

# Verifica argumentos
if [ $# -lt 1 ]; then
    echo "Uso: $0 <branch_name> [--auto]"
    exit 1
fi

branch_name="$1"
auto_mode=false
if [ "$2" == "--auto" ]; then
    auto_mode=true
fi

submodules=(ample build crate hub kernel)

prompt() {
    # Se auto_mode está ativado, retorna true
    if $auto_mode; then
        return 0
    fi
    read -p "$1 [y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]]
}

echo "=== Iniciando sincronização na branch '$branch_name' ==="
echo "Auto mode: $auto_mode"

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    git switch -C "$branch_name"

    tag="${branch_name}-$(whoami)-backup-$(date +%Y%m%d%H%M%S)"
    if prompt "Criar tag de backup '$tag' e enviar para o remoto?"; then
        git tag "$tag"
        git push origin "$tag"
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
        git push --set-upstream origin "$branch_name"
        echo "Branch pushada."
    fi

    cd ..
done

echo "=== Atualizando repositório pai ==="
git switch -C "$branch_name"

tag="${branch_name}-$(whoami)-backup-$(date +%Y%m%d%H%M%S)"
if prompt "Criar tag de backup '$tag' no pai e enviar?"; then
    git tag "$tag"
    git push origin "$tag"
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
    git push --set-upstream origin "$branch_name"
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
