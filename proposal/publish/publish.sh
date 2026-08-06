#!/usr/bin/env bash
set -euo pipefail

PUBLISH_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$PUBLISH_DIR/../.." && pwd)"
CRATE=""
EXECUTE=false

usage() {
    printf 'Uso: %s --crate NOME [--dry-run|--execute]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --crate)
            [ "$#" -ge 2 ] || { usage >&2; exit 2; }
            CRATE="$2"
            shift 2
            ;;
        --execute)
            EXECUTE=true
            shift
            ;;
        --dry-run)
            EXECUTE=false
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
done

[ -n "$CRATE" ] || { usage >&2; exit 2; }
cd "$ROOT"

MANIFEST="$(cargo metadata --format-version 1 --no-deps | python3 -c '
import json
import sys
wanted = sys.argv[1]
data = json.load(sys.stdin)
found = [p["manifest_path"] for p in data["packages"] if p["name"] == wanted]
if len(found) != 1:
    raise SystemExit(f"crate inexistente ou ambígua no workspace: {wanted}")
print(found[0])
' "$CRATE")"

PACKAGE_DIR="$(dirname -- "$MANIFEST")"

if [ -n "$(git status --short)" ]; then
    printf '%s\n' 'O hub possui alterações locais; release interrompido.' >&2
    exit 1
fi
if [ -n "$(git -C "$PACKAGE_DIR" status --short)" ]; then
    printf 'A crate %s possui alterações locais; release interrompido.\n' "$CRATE" >&2
    git -C "$PACKAGE_DIR" status --short
    exit 1
fi

printf 'Crate: %s\nManifest: %s\n' "$CRATE" "$MANIFEST"
printf '%s\n' 'Executando validação do pacote...'
cargo package --manifest-path "$MANIFEST" --verify

if [ "$EXECUTE" = false ]; then
    printf '%s\n' 'Modo dry-run: executando cargo publish --dry-run.'
    cargo publish --manifest-path "$MANIFEST" --dry-run
    printf '%s\n' 'Nenhuma publicação real foi feita. Use --execute após revisar o resultado.'
    exit 0
fi

[ -n "${CARGO_REGISTRY_TOKEN:-}" ] || {
    printf '%s\n' 'CARGO_REGISTRY_TOKEN não está definido.' >&2
    exit 1
}

printf '%s\n' 'Publicação real solicitada.'
cargo publish --manifest-path "$MANIFEST"
printf 'Crate %s publicada. O próximo passo é atualizar os consumidores e o gitlink no hub.\n' "$CRATE"
