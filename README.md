# Narthex

Narthex is the reference shell for the
[Sophia display server](https://github.com/sophia-org/sophia). It's the
entryway around the workspace: it decides what appears in a shell surface and
what a selection means, and it owns no pixels. As a reference implementation
it stays deliberately small — the standing proof that a useful shell can live
in Sophia's most confined tier, and the client to copy from if you're building
one of your own.

Sophia launches Narthex in a separate protected domain and sends it only
bounded, sanitized descriptors and opaque actions. Engine renders the
presented list, captures input, and arbitrates pointer grabs. Narthex supplies
ordering and selection, receives an exact activation, and acknowledges it.
Surface identifiers, coordinates, and icons never reach this process.

Narthex is not a window manager. Window placement, tags, views, layouts, and
focus policy belong to [Hagia](https://github.com/sophia-org/hagia), the
reference window manager. The two are separate clients of the same display
server and share no state. If you're deciding what to build and where it
goes, start with Sophia's
[Building on Sophia](https://github.com/sophia-org/sophia/blob/master/docs/building-on-sophia.md).

## Scope

Narthex owns shell surface policy: descriptor sets, reservations, and
activation handling over Sophia's descriptor files on 9P2000.L. It does not own
rendering, hit testing, physical input, window placement, session launching, or
process supervision. Sophia owns those.

## Provenance

Split from Hagia at commit `07ad3e6338da61319c5058f7593949c8810b25da`, where this code was carried as the
`hagia-shell` executable and its `shell_v1` codec. The socket codec has since
been removed. Narthex now uses thin Nim bindings to the standalone C desktop
SDK, pinned inside its signed source tree; its descriptor policies remain here.

## Evidence

Signed archive `0006` proves the retained generic switcher lifecycle — launch,
shortcut admission, presentation, exact activation, broker-checked dispatch,
withdrawal, and fresh-epoch reconnect in a separate protected process. Signed
archive `0007` separately proves coherent work-area reservation and reconnect.
Both were produced while this code was in-tree in Hagia as `hagia-shell`; the
archives concern the former IPC implementation, not the current file transport.

Current local checks cover SDK bindings and policy. Protected conformance uses
Sophia's generic hosts. These checks do not establish physical display behavior;
whole-desktop acceptance belongs in external desktop tooling.

## Verification

Run the local tests without a Sophia checkout:

```sh
nimble test
```

The tests cover public C SDK layouts, native file records, malformed values,
presentation and activation policy, reference paging, and launcher selection.
The executable rejects the retired socket variable even when it is empty.

For protected 9P conformance, supply prebuilt compatible Sophia hosts:

```sh
SOPHIA_DESCRIPTOR_HOST=/absolute/path/shell_descriptor_conformance_host \
SOPHIA_LAUNCHER_HOST=/absolute/path/shell_launcher_conformance_host \
nimble conformance
```

This checks all three client modes plus the launcher exchange. The hosts must
implement the revision-8 descriptor file contract. No gate builds a sibling
Sophia checkout. Nim binaries and caches are placed in a private temporary
directory, removed at the end.

`nimble verify` additionally checks formatting. `nimble layout` runs the
data-oriented layout gate alone.

## Modes

| Mode | Purpose |
| --- | --- |
| `--proof` | scripted descriptor conformance sequence, emits `narthex_proof` |
| `--bar-proof` | work-area reservation conformance, emits `narthex_bar_proof` |
| `--serve` | live switcher loop driven by Sophia snapshots |

`SOPHIA_SHELL_9P_SOCKET` is required and must be absolute.
`SOPHIA_SHELL_SOCKET` is refused. `SOPHIA_SHELL_BAR_THICKNESS` enables the
bottom-edge reservation; unset or zero reserves nothing.

[Persistent tab descriptors](docs/tabbed-layouts.md) use the revision-8
descriptor file profile in `--serve`, alongside switcher and reservation records.
SIGTERM and SIGINT stop the client loop and release its SDK session; there is no
reconnect, replay, or IPC fallback.

## Shortcut help

The descriptor reference sheet uses the active key and
pointer bindings, with two columns and Page Up/Down or wheel paging. The next
ordinary key dismisses and is consumed. Modifiers alone do not dismiss.
`Super+?` is the default desktop toggle; help shows once per login unless the
private `~/.config/narthex/config.kdl` (or XDG equivalent) contains:

```kdl
hotkey-overlay {
    skip-at-startup #true
}
```

Absent configuration defaults to `#false`. Session exposes only the selected
read-only file through `SOPHIA_SHELL_CONFIG`; it does not parse these settings.
Narthex supplies the Triad `fb8fb27` style and readable grouped rows. Sophia
renders the shared bundled JetBrains Mono default through its normal GPU path.
There are no toolkit, X11, image-buffer, hit-testing, or WM dependencies here.
The catalog carries public action names for display, never invocation tokens.
See Sophia's `docs/shell-reference-sheets.md` for the independent wire contract.

## Application launcher

Serve mode requires the application catalog and descriptor launcher
capabilities. Narthex ranks bounded application descriptors and returns selected
slots; Engine owns text input, GPU rendering and hit testing. Only the session
executes a presented selection after a matching activation acknowledgement.
No executable path, desktop-entry file, display credential or host control socket
is added to this client. The launcher uses the shared JetBrains Mono presentation
default. Configure catalogs and `session:application-launcher` in Sophia; this
client requires no Rofi or Quickshell runtime.
