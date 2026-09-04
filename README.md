# Narthex

Narthex is the standalone shell client for the Sophia display server. It is the
entryway around the workspace: it decides what appears in a shell surface and
what a selection means, and it owns no pixels.

Sophia launches Narthex in a separate protected domain and sends only bounded
sanitized descriptors and opaque actions. Engine renders the presented list,
captures input, and arbitrates pointer grabs. Narthex supplies ordering and
selection, receives an exact activation, and acknowledges it. Surface
identifiers, coordinates, and icons are never disclosed to this process.

Narthex is not a window manager. Window placement, tags, views, layouts, and
focus policy belong to [Hagia](https://github.com/sophia-org/hagia). The two are
separate clients of the same display server and share no state.

## Scope

Narthex owns shell surface policy: descriptor sets, reservations, and
activation handling over the `sophia_shell_v1` wire. It does not own
rendering, hit testing, physical input, window placement, session launching, or
process supervision. Sophia owns those.

## Provenance

Split from Hagia at commit `07ad3e6338da61319c5058f7593949c8810b25da`, where this code was carried as the
`hagia-shell` executable and its `shell_v1` codec. The wire implementation,
reducer, and conformance corpus are unchanged by the split; only module paths,
the binary name, and evidence prefixes differ.

## Evidence

Signed archive `0006` proves the retained generic switcher lifecycle — launch,
shortcut admission, presentation, exact activation, broker-checked dispatch,
withdrawal, and fresh-epoch reconnect in a separate protected process. Signed
archive `0007` separately proves coherent work-area reservation and reconnect.
Both were produced while this code was in-tree in Hagia as `hagia-shell`; the
wire implementation and reducer are unchanged by the split.

The gate below covers wire conformance only. Physical evidence on real hardware
comes from Sophia's tty4 gates, which build this repository and bind its commit
into the proof record.

## Verification

Run the cross-repository conformance gate against a Sophia checkout:

```sh
SOPHIA_STACK_ROOT=~/dev/sophia-stack nimble test
```

The gate checks the same valid, malformed, and fixed-record corpus used by
Sophia's generated codecs, then runs the independently compiled Narthex client
through Sophia's protected shell transport for both the descriptor proof and
the work-area reservation proof.

`nimble verify` additionally checks formatting. `nimble layout` runs the
data-oriented layout gate alone.

## Modes

| Mode | Purpose |
| --- | --- |
| `--proof` | scripted descriptor conformance sequence, emits `narthex_proof` |
| `--bar-proof` | work-area reservation conformance, emits `narthex_bar_proof` |
| `--serve` | live switcher loop driven by Sophia snapshots |

`SOPHIA_SHELL_SOCKET` is required. `SOPHIA_SHELL_BAR_THICKNESS` enables the
bottom-edge reservation; unset or zero reserves nothing.
