#!/bin/bash
set -e

# Verifica argumento
if [ $# -ne 1 ]; then
    echo "Uso: $0 <branch_name>"
    exit 1
fi

branch_name="$1"
submodules=(ample build crate hub kernel)

echo "=== Iniciando sincronização interativa na branch '$branch_name' ==="

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    # Cria ou muda para a branch
    git switch -C "$branch_name"

    # Cria tag de backup
    tag="${branch_name}-$(whoami)-backup-$(date +%Y%m%d%H%M%S)"

    read -p "Criar tag de backup '$tag' e enviar para o remoto? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        git tag "$tag"
        git push origin "$tag"
        echo "Tag enviada."
    else
        echo "Tag ignorada."
    fi

    # Comita mudanças locais, se houver
    if ! git diff-index --quiet HEAD --; then
        read -p "Há mudanças locais em $sub. Comitar e pushar para '$branch_name'? [y/N] " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "initing $branch_name"
            git push --set-upstream origin "$branch_name"
            echo "Alterações enviadas."
        else
            echo "Alterações locais não commitadas."
        fi
    fi

    cd ..
done

echo "=== Atualizando repositório pai ==="

# Cria ou muda para branch no pai
git switch -C "$branch_name"

# Tag de backup no pai
tag="${branch_name}-$(whoami)-backup-$(date +%Y%m%d%H%M%S)"
read -p "Criar tag de backup '$tag' no pai e enviar? [y/N] " yn
if [[ "$yn" =~ ^[Yy]$ ]]; then
    git tag "$tag"
    git push origin "$tag"
    echo "Tag enviada."
else
    echo "Tag ignorada."
fi

# Adiciona submódulos atualizados
git add "${submodules[@]}"

# Comita mudanças no pai se houver
if ! git diff-index --quiet HEAD --; then
    read -p "Há mudanças no repositório pai. Comitar e pushar para '$branch_name'? [y/N] " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        git add .
        git commit -m "initing $branch_name"
        git push --set-upstream origin "$branch_name"
        echo "Alterações enviadas."
    else
        echo "Alterações locais do pai não commitadas."
    fi
fi

echo "=== Sincronização interativa completa ==="
