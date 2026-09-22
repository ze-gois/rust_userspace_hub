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
- Existing macro tables and small declarative macros are part of the project's
  semantic language when they make relationships more explicit and reviewable;
  they must not be replaced merely to make the implementation more conventional.

## Lexicon and onomastics

- Every identifier must say what it means.
- Established Rust, systems, ABI, file-format, and standards vocabulary takes
  precedence over project-local vocabulary.
- Normative names remain traceable to their standards.
- Acronyms and abbreviations are aliases unless a normative identifier must be
  reproduced verbatim.
- Hierarchy should be expressed through modules when the words name genuinely
  distinct semantic objects or domains.
- Underscores are allowed when the words form one stable compound concept and
  splitting them into modules would create an artificial hierarchy. Thus a name
  such as `operating_system` may be preferable to `system::operating`, while
  names such as `elf_header`, `elf_segment`, `elf_program`, and
  `elf_section` should become `elf::header`, `elf::segment`,
  `elf::program`, and `elf::section`.
- Concrete nouns precede qualifications when that ordering reflects the actual
  semantic relation rather than a mechanical naming rule.
- Onomastic revision is conservative: an existing identifier or macro form is
  changed only when the replacement communicates meaning more faithfully.

## Target-specific preservation rules

- The syscall declaration table is an intentional, review-friendly semantic
  index and should remain table-shaped through `syscall_modules!(...)`.
- Per-syscall modules may continue to bind themselves to that declaration with
  `hooking!(IDENTIFIER)`.
- Syscall numbers, names, arity/signature, and labels should remain visibly
  co-located in the table unless a standards requirement makes that impossible.
- Architecture-level syscall invocation and operating-system syscall identity
  remain distinct concepts even when they are connected by these macros.
- The review must prefer restoring these declarative relationships over
  scattering the same facts across constants and hand-written matching code.

## Status

- Sprint I.1 — Hub Revision Ground: **complete**
- Sprint I.2 — Representation Semantics: **complete**
- Sprint I.3 — Allocation Semantics: **complete**
- Sprint I.4 — Memory Reformation: **complete**
- Sprint I.5 — Target & Process Boundary: **under review**
- Sprint I.6 — File Substrate: **complete**
- Sprint I.7 — ELF Zero: **complete**
- Sprint I.8 — ELF Graph: **in progress**

The integrated Publication Unit is green through the completed ELF Zero
checkpoint. The userspace projection into `userspace_build` matches, the
workspace compiles with warnings denied, and the ELF host conformance gate is
green.

I.5 is reopened narrowly to restore the project's declarative syscall language
and to relax the earlier underscore rule before further target reshaping.

I.7 was rebuilt from the normative GABI. The prior ELF implementation was
deleted early and was not used as a compatibility source. Its completion gate
covers representation across ELF classes and byte orders, dynamic and section
relationships, relative relocations, symbol visibility, link-order metadata,
and compressed-section rules without crossing into relocation execution or
linker policy.

I.8 begins from the graph formed by the ELF relationships already represented
by I.7. It should connect existing semantic objects without duplicating their
representations or moving linker and loader policy into the file-format layer.
