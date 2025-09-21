#!/usr/bin/python3

import subprocess
import networkx as nx
import re

workspace = "/backup/rustics/userspace_hub"

skip = ["cc", "find-msvc-tools", "shlex"]

result = subprocess.run(
    ["cargo", "deps", "--all-deps"],
    cwd=workspace,
    capture_output=True,
    text=True,
    check=True,
)
graph_dot = result.stdout

nodes = {
    m.group(1): m.group(2)
    for m in re.finditer(r'(n[0-9]+) \[label="([^"]+)"', graph_dot)
}

nodes = {k: v for k, v in nodes.items() if v not in skip}

edges = [
    (nodes[src], nodes[dst])
    for src, dst in re.findall(r"(n[0-9]+) -> (n[0-9]+)", graph_dot)
    if src in nodes and dst in nodes
]

G = nx.DiGraph()
G.add_edges_from(edges)

order = list(nx.topological_sort(G))
order.reverse()
print(*order)
