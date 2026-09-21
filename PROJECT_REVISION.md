# Project Revision I

This branch is the integration surface for the first coordinated semantic
revision of the userspace.party Rust ecosystem.

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
- `Allocating` is the canonical allocation capability and consumes
  `core::alloc::Layout`.
- `memory::stack` remains an educational, operating-system-neutral model of
  stack memory.
- Linux process startup is target-specific and must not define generic memory.
- ELF is a file format and will return under `file::format::elf` only after
  earlier boundaries are sound.
- Legacy functionality may be removed when preserving it would retain
  semantically incorrect architecture.

## Lexicon and onomastics

Names are part of the architecture and are reviewed for semantic correctness.

- Every identifier must say what it means.
- Prefer established Rust, systems, ABI, file-format, and standards vocabulary
  over project-local vocabulary.
- When a specification names a thing, the implementation preserves that
  semantic correspondence.
- Acronyms and abbreviations are aliases unless an external normative
  identifier must be reproduced verbatim.
- An underscore in an internal module name is evidence of an unexpressed module
  boundary.
- Within a hierarchy, concrete nouns precede qualifications.
- Renaming is not cosmetic in this revision: a misleading identifier is a
  semantic defect.

## Status

Sprint I.1 is complete.

Sprint I.2 is complete:

- `BYTES_SIZE` became `REPRESENTATION_SIZE`;
- `BYTES_ALIGN` was removed from representation;
- the integrated hub gate passed.

Sprint I.3 is complete:

- `Allocating` is the single allocation abstraction exposed by ample;
- allocation layout is expressed by `core::alloc::Layout`;
- userspace heap allocation no longer depends on `Bytes`;
- the userspace global allocator preserves the `mmap` base address;
- `Allocatable` / `AllocatableResult` and dormant allocation scaffolding were
  removed;
- the integrated hub gate passed.

Sprint I.4 is in progress:

- generic `memory::stack` has been separated from process startup ABI;
- the legacy ELF tree was removed early so it cannot constrain the revised
  memory model;
- the next boundary to revise is target/process semantics.
