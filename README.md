# rust_userspace_hub

Workspace de integração para nove crates Rust independentes:

```text
userspace_hub
├── ample
├── computers
├── humans
├── kernelspace
├── twins
├── userspace
├── userspace_build
└── webspace
```

Os oito crates filhos são submodules Git e continuam clonáveis isoladamente. Seus
manifests usam dependências do crates.io; o hub substitui essas dependências pelas
cópias locais através de `[patch.crates-io]`.

## Clone do workspace

```bash
git clone https://github.com/ze-gois/rust_userspace_hub
cd rust_userspace_hub
git submodule update --init
bash scripts/submodules/attach.sh
```

Para avançar todos os submodules até suas `main` remotas quando houver fast-forward:

```bash
bash scripts/submodules/attach.sh --pull
```

## Build

O projeto usa o toolchain e target definidos no repositório:

```bash
cargo check --workspace
cargo run
```

Em Arch Linux, o ambiente também precisa de toolchain C/linker apropriado (por exemplo,
GCC/LLVM) para as partes que compilam código nativo.

## Publicação coordenada

Existe uma única unidade de publicação para os nove crates:

```bash
python3 scripts/publish.py plan
python3 scripts/publish.py next-patch
python3 scripts/publish.py prepare X.Y.Z
python3 scripts/publish.py check
python3 scripts/publish.py publish          # dry-run
python3 scripts/publish.py publish --execute
```

A ordem de publicação é calculada a partir do grafo real de dependências, e
`userspace_hub` só é publicado depois dos oito crates que integra.

Veja [`scripts/README.md`](scripts/README.md) para o contrato completo, gates de Git,
lockstep, crates.io e retomada de publicações parciais.
