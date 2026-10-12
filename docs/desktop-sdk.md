# Desktop SDK migration

Narthex's `sdk/descriptor-9p` branch starts from master `50b9014`. The separate
`overview` branch is unchanged; its unmerged protocol extension is not part of
this migration.

The standalone C desktop SDK is vendored at
`vendor/sophia-desktop-sdk`, revision
`74498734f314c0e9847fb01991e83eed35930833`, from
`https://github.com/sophia-org/sophia-desktop-sdk-c`. Its signed commit object is
preserved as `upstream.commit`; `manifest.json` binds the revision and every
file in `source/` by SHA-256. The snapshot is byte-identical to Sophia's import
from the same signed SDK commit. It contains 183 files.

Sophia accepted the descriptor contract at `3330ecf77`. The SDK carries its
normative KDL and `spec/sophia-shell-descriptors.md`; this SDK revision remains
unpublished.
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

After pinning the accepted contract at C SDK `88347eb7`, all 20 local tests and
the four protected host modes pass again. The copied snapshot's 183 files,
manifest and signed commit object match Sophia's verified import byte for byte.
Evidence: `accepted-contract-{local,build,conformance}.log` in the same directory.
This remains a development build with the fixed dependency inputs above; it
does not update an installed component or establish physical acceptance.

The follow-up pin `74498734` changes only contract prose, provenance and its
digest list: it corrects the accepted native bounds in the main shell document.
All library and test files are byte-identical to `88347eb7`, the tested revision.

## Authenticated launch migration

The signed C SDK snapshot `73fe8106da63e1586ab5a900401fb051bb625464`
provides the launch-authentication helper and authenticated shell handoff.
Narthex retains the provisioned relay for the process generation, drives the
bounded SDK conversation, and lends the authenticated role wire to the shell
session until close. Descriptor flags are checked and CLOEXEC is set before
opening the role connection. A present invalid descriptor or failed conversation
cannot fall back to plain attach. No identity is selected from environment data.

`nimble verify` passes with two new descriptor-admission tests plus the existing
binding and policy suite. The copied SDK file manifest and signed commit object
were verified. Local evidence is `t317-narthex-local-01` under the development
evidence directory. The first formatting check failed, was corrected, and the
final gate passed. This checkpoint has no successful protected Narthex
owner/restart join yet; generic SDK joins are not a substitute for that gate.
No installed client or live session was changed.

The subsequent device-hidden owner join used Narthex `244c3c8` with Sophia's
generic supplied-client conformance check, committed as `c2df6a428`. Narthex
authenticated and reported revision-8 readiness at epochs 1 and 2; the normal
owner revoked each launch and reaped it before replacement. An archived client
changing its `shell` claim to `wm` failed authentication and never reported
readiness. The expected failing test exited 101 at its authentication deadline.
Evidence package `t317-narthex-owner-01` has manifest SHA-256
`a6cf14025da687fc038e2df427a58c4d1da4707584c13fcfa42328af0f5ac747`.
The trusted Session-to-Factotum channel is supplied. This is an authentication
and recovery join with idle liveness observation, not descriptor presentation,
a semantic round trip or physical acceptance. The original client source was
unchanged by the control, and no binary was copied into evidence.
