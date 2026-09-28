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

This first import does not change Narthex's executable. The next changes replace
its IPC codec and socket loop with thin Nim bindings to the SDK. Ordering,
selection, reservations, shortcut-help policy and launcher ranking remain
Narthex's responsibility. Only the SDK's 9P, shell-file and shell-session
modules will be compiled for the client. No server checkout is a build input.

The migration must preserve the existing descriptor, tabs, reference-sheet and
launcher assertions, add 9P custody and disconnect coverage, and qualify the
three CLI modes against the file conformance hosts before replacing the
published client. No live session or installed binary has been changed.
