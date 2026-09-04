# Narthex Agent Guide

Read `README.md`, `docs/architecture.md`, and `docs/data-oriented-design.md`
before changing Narthex.

## Working Rules

1. Keep Narthex standalone. Do not add Sophia, Wayland, or Hagia as a runtime
   or build dependency. The value of this client is that it is an independent
   implementation of the wire.
2. Narthex is a shell client only. It owns descriptor sets, reservations, and
   activation handling. It does not own rendering, hit testing, physical input,
   window placement, focus policy, session launching, or process supervision.
   Window management belongs to Hagia; presentation belongs to Sophia.
3. Narthex never grows a renderer. It may exercise the reservation wire and
   claim work area, but Engine draws every pixel. A change that adds drawing,
   hit testing, or a toolkit dependency is out of scope for this project.
4. **Strict style and architecture adherence.** `docs/style-guide.md` and
   `docs/data-oriented-design.md` are foundational mandates, not suggestions.
   Two-space indentation, `camelCase` values and procs, `PascalCase` types,
   pure enums, UFCS. Format every touched Nim-family file with `nph`.

   **Separate data from code.** Every record, enum, distinct ID, mask, wire
   layout, and bound belongs in `src/types`; procedures belong in the module
   that owns the behavior. A types module is a leaf and imports only the
   standard library and its siblings. Do not reach data through a logic module
   that re-exports it. `tools/check_data_oriented_layout.sh` enforces this and
   fails the build; run `nimble layout` before you commit.

   **Re-read the mandates.** Re-read `docs/style-guide.md` and
   `docs/data-oriented-design.md` on every session initialization and after
   every context compaction. These rules erode silently; that is why this
   project inherited a gate for them. Do not rely on a summary.
5. Protocol code should be plain enough to audit from offsets to semantic
   records. Validate counts, reserved fields, generations, and identities
   before exposing a complete value. Fail closed on malformed input.
6. Run Nim builds and tests serially because they share Nim caches. The
   cross-repository gate is:

   ```sh
   SOPHIA_STACK_ROOT=~/dev/sophia-stack nimble test
   ```

7. Do not run Narthex inside a live Sophia session without explicit approval.
   Offline unit and local socket-conformance tests are safe.
8. The `--proof`, `--bar-proof`, and `--serve` flags and the `SOPHIA_SHELL_*`
   environment variable names are a contract with Sophia's conformance host.
   Do not rename them without a coordinated change in `sophia-stack`.
9. Do not kill or restart `gpg-agent`. If signing is unavailable, preserve the
   staged work and ask the user to unlock it.
