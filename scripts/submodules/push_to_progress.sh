#!/bin/bash
set -e

# Array com os submódulos
submodules=(ample userspace_build userspace kernelspace)

echo "=== Atualizando e pushando todos os submódulos ==="

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    # Garante estar na branch progress
    git checkout progress

    # Puxa o último commit do progress remoto
    git fetch origin progress
    git merge --ff-only origin/progress

    # Push do submódulo
    git push origin progress

    cd ..
done

echo "=== Atualizando ponteiros no repositório pai ==="
git add "${submodules[@]}"
git commit -m "Atualiza submódulos para os últimos commits de progress e pushados"
git push origin progress

echo "=== Tudo pronto! Submódulos e repositório pai sincronizados ==="
