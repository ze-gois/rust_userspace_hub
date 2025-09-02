#!/bin/bash
set -e

# Verifica argumentos
if [ $# -lt 1 ]; then
    echo "Uso: $0 <branch_name>"
    exit 1
fi

branch_name=$1
submodules=(ample userspace_build userspace kernelspace)

echo "=== Iniciando checkout na branch '$branch_name' ==="

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    git switch -C "$branch_name"
    # git pull origin "$branch_name"
    cd ..
done

echo "=== Atualizando repositório pai ==="
git switch -C "$branch_name"
# git pull origin "$branch_name"

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
