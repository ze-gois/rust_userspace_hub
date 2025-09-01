#!/bin/bash
set -e

# Array com os submódulos
submodules=(ample build crate hub kernel)

echo "=== Atualizando e pushando todos os submódulos ==="

for sub in "${submodules[@]}"; do
    echo ">>> Submódulo: $sub"
    cd "$sub"

    # Garante estar na branch main
    git checkout dev

    # Puxa o último commit do main remoto
    git fetch origin dev
    git merge --ff-only origin/dev

    # Push do submódulo
    git push origin dev

    cd ..
done

echo "=== Atualizando ponteiros no repositório pai ==="
git add "${submodules[@]}"
git commit -m "Atualiza submódulos para os últimos commits de dev e pushados"
git push origin dev

echo "=== Tudo pronto! Submódulos e repositório pai sincronizados ==="
