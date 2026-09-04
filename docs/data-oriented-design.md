# Narthex Data-Oriented Design

This document carries Triad's and Hagia's data-oriented discipline into
Narthex's smaller, capability-bounded shell role. It is a design contract.

## Authority Before Storage

Sophia owns scene truth, physical input, rendering, presentation, hit testing,
and process supervision. Narthex owns a private shell model and returns bounded
candidates. A convenient data structure never expands that authority.

Narthex never learns surface identifiers, coordinates, or icons. It receives
sanitized descriptors and opaque actions and returns descriptor sets,
reservations, and activation acknowledgements. If a design would require any of
the withheld facts, the design is wrong, not the boundary.

## Territories

Data is passive. Logic is active. They do not share a module. This is the
foundational rule of this document, and every other rule depends on it.

Narthex keeps three explicit territories:

1. `src/types` defines passive data and nothing else. Every record, enum, wire
   layout, and bound lives here.
2. `src/wire` owns frame encoding, decoding, validation, and the shell
   candidate reducer.
3. `src/narthex.nim` owns the socket lifecycle and the proof and serve modes.

## The Types Layer

A module under `src/types` declares data. No logic lives there.

The only admitted exception is the interop Nim requires to use a distinct type
at all, such as `==`, `$`, and `hash`. Nothing else. A helper that computes,
decides, validates, or transforms is logic and belongs with the procedures that
own the behavior. Narthex currently needs no such exception, and
`src/types/shell_v1.nim` declares zero routines.

A types module is a leaf. It may import the standard library and its siblings
under `src/types`. It may not import a logic module, so data can never depend on
behavior. When a logic module needs a record, it imports the types module by
name; it does not reach the record through some other logic module that happens
to re-export it. Re-exporting data from a logic module recreates exactly the
coupling this layer removes — it is how a codec becomes a mandatory dependency
of every module that only wanted a record.

An error type belongs to the module that raises it. That is the only kind of
public type declared outside `src/types`.

## Enforcement

`tools/check_data_oriented_layout.sh` fails the build when a routine appears in
`src/types`, when a types module imports a logic module, or when a public record
is declared outside the layer. It runs in `nimble test` and `nimble verify`, and
`nimble layout` runs it alone.

The gate exists because this separation decays without one. Hagia declared it
once and then eroded it across twenty of twenty-six modules before anyone
noticed; rebuilding it took a full day and touched forty-seven files. Narthex
starts compliant and is gated from its first commit. Adding a name to the gate's
allowlist must be a deliberate act with a reason recorded beside it, never a way
to make the check quiet.

## Canonical State

`ShellModel` is the canonical private shell state. A state transition updates
every related field in one procedure. Callers do not patch fields to implement
behavior; they invoke transitions.

Keep all collections protocol-bounded. Retain only state needed for a future
shell decision. Narthex owns no pixels and no screen-sized buffers.

## Unidirectional Settlement

State flows in one direction:

1. receive and validate a complete Sophia snapshot;
2. reconcile it into the model;
3. produce exactly one bounded candidate;
4. wait for Sophia's explicit prepared and presented outcomes; and
5. remember only what Sophia actually presented.

A rejected or superseded candidate advances the generation and retries. It never
becomes remembered state.
