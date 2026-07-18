#!/usr/bin/env bash
set -euo pipefail


WORKSPACE_ROOT="/backup/rustics/userspace_hub"
RELEASE_TYPE=${1:-patch}

# --- 1. Descobre ordem topológica das crates do workspace ---
TOPO_ORDER=$(python3 <<'PYTHON'
import subprocess, networkx as nx, re, json

workspace = "/backup/rustics/userspace_hub"

# Metadata do workspace
metadata = subprocess.run(
    ["cargo", "metadata", "--format-version=1", "--no-deps"],
    cwd=workspace, capture_output=True, text=True, check=True
)
metadata_json = json.loads(metadata.stdout)
workspace_crates = {pkg["name"] for pkg in metadata_json["packages"]}

# Grafo de dependências completo
result = subprocess.run(
    ["cargo", "deps", "--all-deps"], cwd=workspace, capture_output=True, text=True, check=True
)
graph_dot = result.stdout

# Nodes (apenas workspace crates)
nodes = {m.group(1): m.group(2) for m in re.finditer(r'(n[0-9]+) \[label="([^"]+)"', graph_dot)}
nodes = {k: v for k, v in nodes.items() if v in workspace_crates}

# Edges (somente entre workspace crates)
edges = [(nodes[src], nodes[dst]) for src, dst in re.findall(r"(n[0-9]+) -> (n[0-9]+)", graph_dot)
         if src in nodes and dst in nodes]

G = nx.DiGraph()
G.add_edges_from(edges)

order = list(nx.topological_sort(G))
order.reverse()
print(*order)
PYTHON
)

echo "Ordem topológica das crates: $TOPO_ORDER"
# --- 2. Descobre todas as crates ---
mapfile -t ALL_CRATES < <(
    cargo metadata --format-version=1 --no-deps --manifest-path "$WORKSPACE_ROOT/Cargo.toml" \
        | jq -r '.packages[] | "\(.name) \(.manifest_path) \(.publish) \(.version)"'
)

declare -A CRATE_PATH
declare -A CRATE_TOML
declare -A CRATE_VERSION
declare -A CRATE_PUBLISHABLE

for line in "${ALL_CRATES[@]}"; do
    read -r name path publish version <<<"$line"

    CRATE_PATH[$name]="$(dirname $path)"
    CRATE_TOML[$name]="$path"
    CRATE_VERSION[$name]="$version"
    CRATE_PUBLISHABLE[$name]=$([[ "$publish" != "[]" ]] && echo true || echo false)

    echo "$name => $path => $publish => $version"
done

# --- 3. Incrementa versão linear ---
increment_version() {
    local type="$1"
    local version="$2"
    IFS='.' read -r major minor patch <<<"$version"

    case "$type" in
        patch) patch=$((patch + 1)) ;;
        minor) minor=$((minor + 1)); patch=0 ;;
        major) major=$((major + 1)); minor=0; patch=0 ;;
        *) echo "Tipo de release inválido: $type"; exit 1 ;;
    esac

    echo "$major.$minor.$patch"
}

# --- 4. Calcula nova versão máxima semanticamente correta ---
declare -A CRATE_VERSION_NEW
for crate in $TOPO_ORDER; do
    CRATE_VERSION_NEW[$crate]=$(increment_version "$RELEASE_TYPE" "${CRATE_VERSION[$crate]}")
done

MAX_VERSION=$(printf "%s\n" "${CRATE_VERSION_NEW[@]}" | sort -V | tail -n1)
echo "Nova versão máxima: $MAX_VERSION"

# --- 5. Função genérica para atualizar dependências internas ---
update_deps() {
    local crate="$1"
    local edge_type="$2" # normal, dev, build

    local cargo_tree
    cargo_tree=$(cargo tree --depth 1 --edges "$edge_type" --prefix none --manifest-path "${CRATE_TOML[$crate]}" 2>/dev/null | awk '{print $1}' || true)

    local edge_dependencies
    if [ -n "$cargo_tree" ]; then
        edge_dependencies=$(echo "$cargo_tree"  | tr ' ' '\n' | grep -E "($(echo "$TOPO_ORDER" | tr ' ' '|'))" 2>/dev/null || true)
        edge_dependencies=$(echo $edge_dependencies | tr ' ' '\n' | grep -v -x "$crate" 2>/dev/null || true)
        edge_dependencies=$(echo $edge_dependencies | tr ' ' '\n' | sort -u || echo "")
    else
        edge_dependencies=""
    fi

    for dependency in $edge_dependencies; do
        echo "  Atualizando $edge_type-dependency $dependency"
        cargo add "$dep@$MAX_VERSION" --path="${CRATE_PATH[$dep]}" --"$edge_type" --manifest-path "${CRATE_TOML[$crate]}"
    done
}

cargo build

bash $WORKSPACE_ROOT/pre_release.sh

# --- 6. Atualiza dependências internas e executa pre-hooks ---
for crate in $TOPO_ORDER; do
    echo "Atualizando dependências internas de $crate..."
    update_deps "$crate" normal
    update_deps "$crate" dev
    update_deps "$crate" build

    crate_dir=$(dirname "${CRATE_TOML[$crate]}")

    if [[ -f "$crate_dir/pre_release.sh" ]]; then
        echo "Executando pre-release hook de $crate..."
        bash "$crate_dir/pre_release.sh"
    fi

    cd ${CRATE_PATH[$crate]}

    git add .
    git commit -m "Release version $MAX_VERSION." || true

    cargo release "$RELEASE_TYPE" --manifest-path="${CRATE_TOML[$crate]}" --target=x86_64-unknown-none --execute
    # exit 1
    # if [[ -f "$crate_dir/pos_release.sh" ]]; then
    #     echo "Executando pos-release hook de $crate..."
    #     bash "$crate_dir/pos_release.sh"
    # fi
done

# --- 7. Release final com cargo-release no workspace ---
echo "Rodando cargo-release para todo o workspace..."

cd "$WORKSPACE_ROOT"
cargo release "$RELEASE_TYPE" --unpublished --workspace --no-dev-version --execute --verbose

for crate in $TOPO_ORDER; do
    crate_dir=$(dirname "${CRATE_TOML[$crate]}")
    if [[ -f "$crate_dir/pos_release.sh" ]]; then
        echo "Executando pos-release hook de $crate..."
        bash "$crate_dir/pos_release.sh"
    fi
done

bash $WORKSPACE_ROOT/pos_release.sh

echo "=== Todas as crates publicadas com sucesso ==="

exit 1
