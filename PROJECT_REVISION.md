# Project Revision I

This branch is the integration surface for the first coordinated semantic
revision of the userspace.party Rust ecosystem.

## Participating repositories

- `rust_ample`: `project-revision`
- `rust_userspace`: `project-revision`
- `rust_userspace_hub`: `project-revision`

The hub pins exact submodule commits while its workspace-level
`[patch.crates-io]` entries make the local crates compile against each other.
This allows `ample` and `userspace` to evolve together without publishing
intermediate crate versions.

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

- Serialization representation and Rust memory layout are distinct.
- `Bytes<Origin, Destination>` describes representation, not allocation.
- `Allocating<T>` remains a first-class abstraction but must use memory-layout
  semantics rather than serialized byte size.
- `memory::stack` remains an educational, OS-neutral model of stack memory.
- Linux process startup is target-specific and must not define generic memory.
- ELF remains a file format under `file::format::elf`.
- Legacy functionality may be removed when preserving it would retain
  semantically incorrect architecture.
- Module hierarchy is expressed by modules rather than underscore-composed
  module names.

## Sprint I.1 — Hub Revision Ground

Exit criteria:

- all three repositories have a `project-revision` branch;
- hub pins exact revision commits for `ample` and `userspace`;
- hub remains the workspace used to test their interaction;
- subsequent cross-crate changes are coordinated through the hub revision PR.
