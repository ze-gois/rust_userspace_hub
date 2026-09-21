# Project Revision I

This branch is the integration surface for the coordinated semantic revision of
the userspace.party Rust ecosystem.

## Participating repositories

- `rust_ample`: `project-revision`
- `rust_userspace`: `project-revision`
- `rust_userspace_hub`: `project-revision`

The hub pins exact submodule commits while its workspace-level
`[patch.crates-io]` entries make the local crates compile against each other.

## Revision sequence

1. Hub Revision Ground
2. Representation Semantics
3. Allocation Semantics
4. Memory Reformation
5. Target & Process Boundary
6. File Substrate
7. ELF Zero
8. ELF Graph

## Semantic invariants

- Representation and Rust memory layout are distinct.
- Serialization and deserialization are operations over representation.
- `Bytes<Origin, Destination>` describes representation, not allocation.
- `REPRESENTATION_SIZE` describes representation extent.
- `Allocating` consumes `core::alloc::Layout`.
- Generic memory is independent from operating-system policy.
- `memory::stack` models stack memory rather than process startup ABI.
- Full semantic names are canonical; short forms belong in aliases.
- ELF is a file format and belongs under `file::format::elf`.
- Legacy functionality may be removed when preserving it would retain
  semantically incorrect architecture.

## Lexicon and onomastics

- Every identifier must say what it means.
- Established Rust, systems, ABI, file-format, and standards vocabulary takes
  precedence over project-local vocabulary.
- Normative names remain traceable to their standards.
- Acronyms and abbreviations are aliases unless a normative identifier must be
  reproduced verbatim.
- Internal underscore-composed module names indicate hidden hierarchy.
- Concrete nouns precede qualifications.

## Status

- Sprint I.1 — Hub Revision Ground: **complete**
- Sprint I.2 — Representation Semantics: **complete**
- Sprint I.3 — Allocation Semantics: **complete**
- Sprint I.4 — Memory Reformation: **complete**
- Sprint I.5 — Target & Process Boundary: **complete**
- Sprint I.6 — File Substrate: **complete**
- Sprint I.7 — ELF Zero: **in progress**
- Sprint I.8 — ELF Graph: **pending**

The integrated Publication Unit is green through the completed file-substrate
checkpoint.

I.7 begins from the normative GABI. The prior ELF implementation was deleted
early and is not a compatibility source.
