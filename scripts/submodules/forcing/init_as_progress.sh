#!/bin/bash
set -e

# Array com os submódulos
submodules=(ample userspace_build userspace kernelspace)

echo "=== Atualizando e pushando todos os submódulos ==="

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    # Garante estar na branch progress
    git checkout -b progress
    git add .
    git commit -m "initing progress"
    git push --set-upstream origin progress

    cd ..
done

echo "=== Atualizando ponteiros no repositório pai ==="
git checkout -b progress
git add "${submodules[@]}"
git add .
git commit -m "initing progress"
git push --set-upstream origin progress

echo "=== Tudo pronto! Submódulos e repositório pai sincronizados ==="
