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
9. ELF Conformance

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
- Sprint I.8 — ELF Graph: **complete**
- Sprint I.9 — ELF Conformance: **complete**

The integrated Publication Unit is green through I.9 — ELF Conformance.
The canonical `userspace_build` projection matches `userspace`, the workspace
compiles with warnings denied, and the ELF host gate passes all 207 tests at the
integrated pins. A real C++ COMDAT fixture was also inspected successfully
through the host ELF inspector, exercising the section-group, signature-symbol,
member-section, symbol-table, and relocation relationships together.

I.5 is reopened narrowly to restore the project's declarative syscall language
and to relax the earlier underscore rule before further target reshaping.

I.7 was rebuilt from the normative GABI. The prior ELF implementation was
deleted early and was not used as a compatibility source. Its completion gate
covers representation across ELF classes and byte orders, dynamic and section
relationships, relative relocations, symbol visibility, link-order metadata,
and compressed-section rules without crossing into relocation execution or
linker policy.

I.8 connects the graph formed by ELF relationships already represented by I.7
without introducing a generic graph framework. The completed navigation covers
normative `sh_link` relationships, relocation target sections, section-group
members and signature symbols, symbol-to-section relationships, and the
relationships already carried directly by relocation and dynamic table views.
Undefined and special section indices remain semantic values rather than false
section edges. Runtime relocation application, inter-object symbol resolution,
dependency loading, GNU-specific ABI extensions, and linker or loader policy
remain outside ELF Graph.


I.9 validates generic gABI object conformance without crossing into psABI,
link-editor, dynamic-linker, or relocation-execution semantics. The completed
scope covers the intrinsic generic conformance described by gABI Chapters 2–8:
ELF headers, section tables and relationships, string tables, symbol tables,
REL/RELA/RELR structure, program-loading structures, notes, dynamic arrays,
dynamic string and symbol tables, System V hash tables, and the structural
relationships among dynamic relocation metadata.

The completion gate is `rust_userspace/project-revision`
`93bc668c48c4d69e2b076bec183a6ee1841257cf`, with 207 passing ELF host tests.
Its canonical projection is `rust_userspace_build/main`
`b7f8457aab25faab121485575dfc94be131facb4`, integrated by
`rust_userspace_hub/project-revision`
`759b128f5a14e457453f486bbc64ed884885681f`.

The remaining gABI work is operational rather than intrinsic object
conformance. Relocation composition and application, RELR address expansion,
program-image construction, dependency loading and search, `$ORIGIN`
processing, inter-object symbol lookup and resolution, initialization and
termination ordering, and processor-specific `R_*` semantics remain outside
I.9. The next planned boundary is I.10 — Relative Relocation Semantics.
