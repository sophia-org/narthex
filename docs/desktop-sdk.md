# Desktop SDK migration

Narthex's `sdk/descriptor-9p` branch starts from master `50b9014`. The separate
`overview` branch is unchanged; its unmerged protocol extension is not part of
this migration.

The standalone C desktop SDK is vendored at
`vendor/sophia-desktop-sdk`, revision
`2b00a7766c856b36e3604d68087b90f747bc1296`, from
`https://github.com/sophia-org/sophia-desktop-sdk-c`. Its signed commit object is
preserved as `upstream.commit`; `manifest.json` binds the revision and every
file in `source/` by SHA-256. The snapshot is byte-identical to Sophia's import
at `40b88fc5ed51aea865d7bb4158c866aa403993f9`. It contains 185 files.

The descriptor record contract under the SDK's `spec/proposed/` remains a
development proposal. Vendoring it does not accept or publish that contract.
The SDK's codecs and session have independent production-export and protected
Session CPU-presentation evidence in Sophia's IPC retirement branch, most
recently `6e7ddf8ea742e267d250fe86ab708a047aedda31`.

Narthex's executable now uses thin Nim bindings to the SDK. Its IPC codec and
socket loop have been removed. Ordering,
selection, reservations, shortcut-help policy and launcher ranking remain
Narthex's responsibility. Only the SDK's 9P, shell-file and shell-session
modules are compiled for the client. No server checkout is a build input.

The migration must preserve the existing descriptor, tabs, reference-sheet and
launcher assertions, add 9P custody and disconnect coverage, and qualify the
three CLI modes against the file conformance hosts before replacing the
published client. No live session or installed binary has been changed.

## Thin binding checkpoint

`src/types/desktop_sdk.nim` declares public C values, and `src/sdk/desktop_sdk.nim`
compiles the three SDK modules and imports their functions. Session state stays
opaque. The small C interop header obtains its allocation size and copies public
borrowed event/object values; it does not implement a codec or mutate SDK state.
Decoded rows and text remain borrowed until the event is consumed or object
storage reused. The policy adapter must copy them before that point.

`tests/tdesktop_sdk.nim` checks Nim-to-C candidate and style fields, C-to-Nim
activation fields, native record validation, bounded borrowed descriptor rows,
and an opaque session's actual `9P2000.L` version request over a private socket
pair. It checks refusal before readiness without assigning a ticket, unchanged
output on absent events, and caller ownership of the fd after session close.
These are binding tests, distinct from the protected client/host exchanges.

Initialize `SfRecord` as a zero-initialized variable, then assign its header and
chosen union member. A Nim object constructor for the whole imported record emits
an invalid positional initializer for the C anonymous union on Nim 2.2.12.

## File client evidence

The five binding tests and fifteen policy tests pass with the SDK file records.
The former IPC frame corpora are retired with the codec. Native record boundary
tests replace the framing assertions; activation identity, duplicate refusal,
presentation settlement, paging, query selection and withdrawal assertions remain.
Tests use no `SOPHIA_ROOT` or server fixture files.

The development binary passes the protected 9P descriptor host in `--proof`,
`--bar-proof` and `--serve`, and the launcher host with a 4,096-entry catalog.
The serve and launcher hosts require a zero-status exit after signalling the
admitted client with SIGTERM. This checks the client's handler, not the live
Session restart command or supervisor group-termination behavior.

The production file owner rejects stale or unpresented grants before it sends
them; the hosts report that server-side refusal explicitly. Client policy tests
separately cover stale presentation and pre-presentation grants.

Development evidence is under `development-evidence/narthex-descriptor-9p`:
`t*-final.log`, `protected-proof3.log`, `protected-bar2.log`,
`protected-serve2.log` and `protected-launcher-1.log`. The four dependency
directories were checked against the prior reviewed Narthex package inventory;
this is not a newly reviewed release build. Nim 2.2.12 emits const-qualifier
warnings in its generated C (including its standard library); the C binding
header separately passes C99 `-Wall -Wextra -Wpedantic -Werror`.
