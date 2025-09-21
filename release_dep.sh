#!/usr/bin/env bash
set -euo pipefail

MAX_VERSION="${1:?Informe a versão máxima}"

# Lista de todas as crates do nosso complexo
CRATES=("ample" "kernelspace" "userspace" "userspace_build")

for crate in "${CRATES[@]}"; do
    MANIFEST_PATH="./crates/$crate/Cargo.toml"
    echo "Atualizando crate $crate para $MAX_VERSION..."
    cargo set-version "$MAX_VERSION" --manifest-path "$MANIFEST_PATH"

    # Descobre dependências internas do nosso complexo via cargo tree
    INTERNAL_DEPS=$(cargo tree --prefix none --manifest-path "$MANIFEST_PATH" \
        | awk '{print $1}' \
        | grep -E "^($(IFS="|"; echo "${CRATES[*]}"))\$" \
        | sort -u)

    for dep in $INTERNAL_DEPS; do
        echo "  Atualizando dependência interna $dep"
        cargo add "$dep@$MAX_VERSION" --manifest-path "$MANIFEST_PATH"
    done

    # Se quiser diferenciar dev/build, dá para usar `cargo tree --edges dev` e `--edges build`
    # e repetir o mesmo filtro com grep
done

echo "Todas as crates do workspace foram atualizadas para $MAX_VERSION."
