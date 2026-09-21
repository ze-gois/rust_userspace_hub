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
- `memory::stack` remains an educational, operating-system-neutral model of
  stack memory.
- Linux process startup is target-specific and must not define generic memory.
- ELF remains a file format under `file::format::elf`.
- Legacy functionality may be removed when preserving it would retain
  semantically incorrect architecture.

## Lexicon and onomastics

Names are part of the architecture and are reviewed for semantic correctness.

- Every identifier must say what it means.
- Prefer the established lexicon of the Rust, systems, ABI, file-format, and
  standards communities over project-local vocabulary.
- When a specification names a thing, the implementation must preserve that
  semantic correspondence. A different Rust spelling may improve hierarchy,
  but must not silently change the concept named by the standard.
- Acronyms and abbreviations are aliases, not the canonical vocabulary, unless
  an external normative identifier must be reproduced verbatim at a standards
  boundary.
- An underscore in an internal module name is evidence of an unexpressed module
  boundary. Hierarchy belongs in modules rather than underscore-composed names.
- Within a hierarchy, concrete nouns come before qualifications. For example,
  `stack::initial`, not `initial_stack`.
- Concrete things receive concrete names. Generic abstractions must earn their
  generality from semantics rather than from vague naming.
- Aliases may provide conventional short spellings without replacing the
  canonical descriptive identifier.
- Constants and identifiers copied from an external ABI or specification may
  retain their normative spelling, with the source standard documented.
- Renaming is not cosmetic in this revision: a misleading identifier is a
  semantic defect.

## Sprint I.1 — Hub Revision Ground

Exit criteria:

- all three repositories have a `project-revision` branch;
- hub pins exact revision commits for `ample` and `userspace`;
- hub remains the workspace used to test their interaction;
- subsequent cross-crate changes are coordinated through the hub revision PR;
- the shared semantic and naming laws are recorded before structural changes.
