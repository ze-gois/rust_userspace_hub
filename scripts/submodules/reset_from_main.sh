#!/bin/bash
set -e

# Array com os submódulos
submodules=(ample userspace_build userspace kernelspace)

echo "=== Atualizando submódulos para o último commit de main ==="

for sub in "${submodules[@]}"; do
    echo ">>> Atualizando $sub..."
    cd "$sub"

    # Pega a última versão da branch main
    git fetch origin main
    git reset --hard origin/main

    cd ..
done

echo "=== Comitando novos ponteiros no repositório pai ==="
git add "${submodules[@]}"
git commit -m "Atualiza todos os submódulos para o último commit de main"
git push

echo "=== Feito! Todos os submódulos atualizados e commit no pai enviado ==="
