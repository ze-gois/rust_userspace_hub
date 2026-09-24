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
10. Relative Relocation Semantics
11. Program Image
12. Shared Object Dependencies
13. Processor-Specific ELF

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
- Sprint I.5 — Target & Process Boundary: **complete**
- Sprint I.6 — File Substrate: **complete**
- Sprint I.7 — ELF Zero: **complete**
- Sprint I.8 — ELF Graph: **complete**
- Sprint I.9 — ELF Conformance: **complete**
- Sprint I.10 — Relative Relocation Semantics: **complete**
- Sprint I.11 — Program Image: **complete**
- Sprint I.12 — Shared Object Dependencies: **complete**
- Sprint I.13 — Processor-Specific ELF: **complete**

Project Revision I is **complete**.

I.13 closes the processor-specific execution gap beneath the generic gABI
model. ELF processor-specific semantics live under
`file::format::elf::processor_specific::{x86_64,aarch64}`; both architectures
remain representable independent of the host, while native execution is gated
by the compilation architecture.

For x86-64, the completed execution path covers:

- `R_X86_64_RELATIVE` according to the AMD64 psABI;
- real Linux `PT_LOAD` materialization through `mmap`, zero-fill, relocation,
  and final `mprotect`;
- executable-entry validation against `PF_X` load segments;
- the x86-64 initial process stack layout, including 16-byte `%rsp`
  alignment, `argc`, `argv`, `envp`, and the auxiliary vector;
- explicit process-entry register state, including `%rdx` and the outermost
  zero `%rbp` frame marker; and
- a `noreturn` transfer of control to `e_entry`.

The final validated Publication Unit pins are:

- `rust_userspace/project-revision`:
  `ec1d8529644f660293f3cdc8aeca53ee4a35504c`
- `rust_userspace_build/main`:
  `a39d77811ed9738dc50dcccb0a599a2e391bb886`
- `rust_userspace_hub/project-revision` integration checkpoint:
  `4715ef3c6051777101b7b24dc6a91b67b040b35e`

At these pins, the canonical build projection matches the source, the workspace
compiles with warnings denied, the full ELF host gate is green, the isolated
x86-64 process-entry test transfers control to the mapped `e_entry` and
terminates observably through the Linux syscall ABI with status 42, and the hub
working tree is clean.

Project Revision I therefore closes at actual ELF execution rather than at
representation, program-image construction, or callable-entry proof. Further
work should begin as a separately named development unit rather than silently
extending this revision's scope.

I.5 — Target & Process Boundary separates compilation architecture from the
operating-system ABI used by the userspace runtime. The Rust compilation target
may be `x86_64-unknown-none` while the concrete userspace ABI remains Linux;
`cfg(target_os)` therefore does not select the runtime operating-system layer.
The canonical domains are `Architecture` and `OperatingSystem`, with short
forms retained only as aliases. The architecture identifier is the normative
`x86_64`; the duplicate `x86::bit64` hierarchy has been removed.

The syscall declaration table remains the reviewable source for Linux syscall
number, module, signature arity, and label through `syscall_modules!(...)`,
and each syscall continues to bind itself to that declaration through
`hooking!(IDENTIFIER)`. Architecture-level invocation remains distinct from
Linux syscall identity. The review also restored `openat` to its four-argument
x86-64 Linux syscall ABI, consistent with the table's `Syscall4` declaration.

The I.5 completion gate is `rust_userspace/project-revision`
`3099d8ebcc1ff1c13e661acbf13e23ff2a2abc7c`. The workspace compiles with
warnings denied under the freestanding target configuration and the unchanged
ELF host gate remains green. Its canonical projection is
`rust_userspace_build/main`
`ae33f1a91b68142b3a404ca9d255c4dd5f096e8e`. This checkpoint is integrated
by the hub commit that records these pins.

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

The remaining gABI work after I.9 is operational rather than intrinsic object
conformance. Program-image construction, dependency loading and search,
`$ORIGIN` processing, inter-object symbol lookup and resolution,
initialization and termination ordering, and processor-specific `R_*`
semantics remain outside I.9.

I.10 implements the generic RELR execution semantics without introducing
processor-specific relocation types. It preserves the layers between
representation, RELR virtual-address expansion, relocation-factor calculation,
storage-unit decoding, relocated-value calculation, checked ELF32/ELF64
representation, byte order, write planning, load-time address resolution,
read-only memory-image access, and explicit mutation. Planned storage-unit
writes distinguish link-time from load-time virtual addresses. Batch
application validates every destination before mutation, so a failed batch does
not leave a partially relocated memory image.

The I.10 completion gate is `rust_userspace/project-revision`
`5ae705988a337252d8893b0f8f3c7ec0fff82ca1`, with 260 passing ELF host
tests. Its canonical projection is `rust_userspace_build/main`
`3e73c65e6bcecd67216515e98ce40cfa6ecc6d35`, integrated by
`rust_userspace_hub/project-revision`
`75d0570cc8b1583cb7b93a4ae6b568b0e047b4e4`. At those integrated pins,
`userspace_build` matches `userspace`, the workspace compiles with warnings
denied, and the ELF host gate remains 260/260 green.

I.11 — Program Image constructs the loadable program image described by
`PT_LOAD` entries without introducing operating-system mapping policy. Each
segment preserves its program-header index, link-time virtual-address range,
file-image bytes, explicit zero-fill when `p_memsz > p_filesz`, `p_flags`,
and `p_align`. The program image calculates the gABI base address from the
lowest load-segment virtual address and materializes owned memory-image regions
at load-time virtual addresses. The materialized image exposes separate
read-only and writing views, allowing RELR planning and mutation to operate on
the same owned segment storage while keeping representation, value, planning,
and mutation distinct. RELR derives its relocation factor from the same
`BaseAddress` used to materialize the program image. System calls, `mmap`,
page allocation, and translation of ELF segment flags into operating-system
protection policy remain outside I.11.

The I.11 completion gate is `rust_userspace/project-revision`
`5073fede4d5a0e178323a8a56ab887a9e8720c6a`, with 283 passing ELF host
tests. Its canonical projection is `rust_userspace_build/main`
`9685c867495a894e2f724e6efcd714c543448d7d`, integrated by
`rust_userspace_hub/project-revision`
`78ff619fd31d2d2870df9484dadc836b48f1ffd8`. At those integrated pins,
`userspace_build` matches `userspace`, the workspace compiles with warnings
denied, and the ELF host gate remains 283/283 green.


I.12 — Shared Object Dependencies implements the generic gABI semantics that
are intrinsic to dependency names and search-path metadata without becoming a
dynamic linker. Each `DT_NEEDED` entry is represented as a concrete dependency
with its dynamic-array entry index and name from `DT_STRTAB`; relative order
and repeated names are preserved. Names containing a slash are interpreted as
direct pathnames after the applicable substitution sequences have been
processed.

`DT_SONAME`, `DT_RPATH`, and `DT_RUNPATH` remain distinct object metadata.
The gABI applicability rules are preserved: `DT_SONAME` is ignored for
executables, `DT_RPATH` is ignored for shared objects, and `DT_RUNPATH`
supersedes `DT_RPATH` when both are present. Search-path strings are resolved
into their colon-separated directory components while preserving the current
directory represented by an empty component.

The gABI `$ORIGIN` substitution is implemented for `DT_NEEDED` and
`DT_RUNPATH` strings. The containing object's origin directory is supplied by
the caller; ELF code does not discover it through filesystem policy.
Substitution precedes the decision whether a needed name is a direct pathname.
Unspecified substitution sequences are reported explicitly rather than assigned
project-local semantics.

A `DT_RUNPATH` remains structurally attached to the object whose dynamic array
contains it, matching the gABI rule that it applies only to that object's
immediate `DT_NEEDED` dependencies. Environment search through
`LD_LIBRARY_PATH`, default library directories, object opening or mapping,
recursive process-image construction, duplicate-object connection policy,
inter-object symbol lookup, and initialization ordering remain dynamic-linker or
process-image work outside `file::format::elf`.

The I.12 completion gate is `rust_userspace/project-revision`
`de19a41124ac0b99adda37aad11b4d158cad83f5`, with 295 passing ELF host
tests across 30 test binaries. Its canonical projection is
`rust_userspace_build/main`
`e746e0371ceab9315d6a65b9839f8ffded9b4997`, integrated by
`rust_userspace_hub/project-revision`
`d737dfbdc8aa1a6b96383acefe7d0f8201ab3ceb`. At those integrated pins,
`userspace_build` matches `userspace`, the workspace compiles with warnings
denied, the full ELF host gate remains 295/295 green, and the hub working tree
is clean.
