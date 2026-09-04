# Narthex Style Guide

Narthex follows the same Nim conventions as Hagia and Triad. Sophia's authority
rules override any convention that would widen this client's reach.

## Nim Style

Follow NEP-1 and let `nph` decide formatting:

- indent with two spaces and never tabs;
- use `PascalCase` for types;
- use `camelCase` for values, procedures, and constants;
- make enums pure with `{.pure.}`;
- prefer a noun for a read accessor; and
- use an explicit domain verb for a transition, such as `model.reconcile(...)`.

Run `nph` on every touched Nim-family file. `nimble verify` checks formatting
without rewriting files.

## Data And Code Are Separate Modules

Data stays passive and logic stays in procedures, and the two do not share a
module. Every record, enum, wire layout, and bound belongs in `src/types`; the
procedures that read and change it belong in `src/wire` or the entry point.

This is not a filing preference. A record declared beside its consumer makes
that consumer a mandatory dependency of everyone who only wanted the record, and
the coupling is invisible until you try to remove it. Narthex exists as its own
project because that coupling was absent here; keep it absent.

When you add a type, ask where the data goes first, then write the procedure.
Do not import data through a logic module that re-exports it. Run `nimble layout`
before you commit.

## Dot Syntax

Put the primary state or value first and call procedures with UFCS:

```nim
model.reconcile(snapshot)
let candidate = model.candidate(generation, visible, reservation)
```

Dot syntax is a reading convention, not object-oriented ownership. It must not
hide mutation, I/O, or a Sophia round trip.

## Boundary Code

Protocol code should be plain enough to audit from offsets to semantic records.
Validate counts, reserved fields, generations, and identities before exposing a
complete value. Do not hide wire operations behind generic reflection or macros
that make the fixed layout difficult to compare with Sophia's corpus.

The `--proof`, `--bar-proof`, and `--serve` flags and the `SOPHIA_SHELL_*`
environment variable names are a contract with Sophia's conformance host.
Renaming one requires a coordinated change in `sophia-stack`.

## Errors, Comments, And Tests

- Fail closed at malformed or unauthorized boundaries.
- Keep the last presented state intact when a candidate fails.
- Comment ownership, invariants, and surprising bounds; do not narrate syntax.
- Add a focused deterministic test for wire or reducer behavior.
- Name unfinished behavior directly in documentation.
