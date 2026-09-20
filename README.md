# userspace_hub

[![crates.io](https://img.shields.io/crates/v/userspace_hub.svg)](https://crates.io/crates/userspace_hub)
[![docs.rs](https://docs.rs/userspace_hub/badge.svg)](https://docs.rs/userspace_hub)

Integration workspace and publication hub for the [userspace.party](https://userspace.party) Rust ecosystem.

## Ecosystem

`userspace_hub` brings nine independently published crates into one workspace:

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

The eight child repositories remain independent Git repositories and crates.io packages. In the hub they are pinned as Git submodules and overridden locally with `[patch.crates-io]`, so workspace development uses the checked-out source while published manifests continue to use registry dependencies.

The family is intentionally `no_std`-first and keeps its external dependency surface small. Platform-specific exceptions are kept explicit, such as `libm` in `ample` and the WebAssembly bindings used by `webspace`.

## Clone the workspace

```bash
git clone https://github.com/ze-gois/rust_userspace_hub
cd rust_userspace_hub
git submodule update --init
bash scripts/submodules/attach.sh
```

To fast-forward attached submodules to their remote `main` branches:

```bash
bash scripts/submodules/attach.sh --pull
```

## Build

The repository carries its Rust toolchain and target configuration.

```bash
cargo check --workspace
cargo run
```

Some members also compile native/assembly pieces and therefore require the corresponding C toolchain/linker on the host.

## Coordinated publication

The nine crates form one coordinated publication unit. The hub computes the dependency graph and publishes in dependency order:

```bash
python3 scripts/publish.py plan
python3 scripts/publish.py next-patch
python3 scripts/publish.py prepare X.Y.Z
python3 scripts/publish.py check
python3 scripts/publish.py publish
python3 scripts/publish.py publish --execute
```

See [scripts/README.md](scripts/README.md) for the full release contract, gates, lockstep rules, and partial-publication recovery.

## Links

- Ecosystem: https://userspace.party
- Hub: https://userspace.party/hub
- API documentation: https://docs.rs/userspace_hub
- crates.io: https://crates.io/crates/userspace_hub
- Source: https://github.com/ze-gois/rust_userspace_hub

## Status

Experimental systems software. APIs and crate boundaries may evolve while the ecosystem converges on a small, dependency-light userspace stack.

## License

See [LICENSE](LICENSE).
