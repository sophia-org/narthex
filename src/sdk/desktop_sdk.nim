## Thin FFI over the signed SDK snapshot; no private state or wire codec.
import std/os
import ../types/desktop_sdk

const sdkSource =
  currentSourcePath().parentDir.parentDir.parentDir /
  "vendor/sophia-desktop-sdk/source/src"
{.passC: "-I" & sdkSource.}
{.passC: "-I" & currentSourcePath().parentDir.}
{.compile: sdkSource / "nine_p/client.c".}
{.compile: sdkSource / "nine_p/replies.c".}
{.compile: sdkSource / "nine_p/requests.c".}
{.compile: sdkSource / "shell_files/actions.c".}
{.compile: sdkSource / "shell_files/allocation.c".}
{.compile: sdkSource / "shell_files/api.c".}
{.compile: sdkSource / "shell_files/candidate.c".}
{.compile: sdkSource / "shell_files/catalog.c".}
{.compile: sdkSource / "shell_files/client.c".}
{.compile: sdkSource / "shell_files/control.c".}
{.compile: sdkSource / "shell_files/descriptor_candidates.c".}
{.compile: sdkSource / "shell_files/descriptor_control.c".}
{.compile: sdkSource / "shell_files/descriptor_objects.c".}
{.compile: sdkSource / "shell_files/descriptor_profile.c".}
{.compile: sdkSource / "shell_files/descriptor_reference.c".}
{.compile: sdkSource / "shell_files/descriptor_rows.c".}
{.compile: sdkSource / "shell_files/events.c".}
{.compile: sdkSource / "shell_files/indicators.c".}
{.compile: sdkSource / "shell_files/limits.c".}
{.compile: sdkSource / "shell_files/native.c".}
{.compile: sdkSource / "shell_files/native_validation.c".}
{.compile: sdkSource / "shell_files/objects.c".}
{.compile: sdkSource / "shell_files/outputs.c".}
{.compile: sdkSource / "shell_files/records.c".}
{.compile: sdkSource / "shell_files/resources.c".}
{.compile: sdkSource / "shell_files/role_candidate_validation.c".}
{.compile: sdkSource / "shell_files/role_candidates.c".}
{.compile: sdkSource / "shell_files/roles.c".}
{.compile: sdkSource / "shell_files/text.c".}
{.compile: sdkSource / "shell_files/upload.c".}
{.compile: sdkSource / "shell_files/validation.c".}
{.compile: sdkSource / "shell_session/events.c".}
{.compile: sdkSource / "shell_session/queue.c".}
{.compile: sdkSource / "shell_session/session.c".}

{.push cdecl, gcsafe, raises: [].}
proc sfEncode*(
  dst: pointer, capacity: csize_t, value: ptr SfRecord, bytes: ptr csize_t
): cint {.importc: "sophia_sf_encode", header: "sophia_shell_files.h".}

proc sfDecode*(
  src: pointer, bytes: csize_t, value: ptr SfRecord
): cint {.importc: "sophia_sf_decode", header: "sophia_shell_files.h".}

proc sfRecordBytes*(
  value: ptr SfRecord
): csize_t {.importc: "sophia_sf_record_bytes", header: "sophia_shell_files.h".}

proc sfDescriptorEntryEncode*(
  bytes: pointer, value: ptr SfDescriptorEntry
): cint {.
  importc: "sophia_sf_descriptor_entry_encode",
  header: "sophia_shell_files_descriptors.h"
.}

proc sfDescriptorEntryDecode*(
  bytes: pointer, value: ptr SfDescriptorEntry
): cint {.
  importc: "sophia_sf_descriptor_entry_decode",
  header: "sophia_shell_files_descriptors.h"
.}

proc sfDescriptorEntryAt*(
  value: ptr SfDescriptors, index: csize_t, row: ptr SfDescriptorEntry
): cint {.
  importc: "sophia_sf_descriptor_entry_at", header: "sophia_shell_files_descriptors.h"
.}

proc sfTabGroupEncode*(
  bytes: pointer, value: ptr SfTabGroup
): cint {.
  importc: "sophia_sf_tab_group_encode", header: "sophia_shell_files_descriptors.h"
.}

proc sfTabGroupDecode*(
  bytes: pointer, value: ptr SfTabGroup
): cint {.
  importc: "sophia_sf_tab_group_decode", header: "sophia_shell_files_descriptors.h"
.}

proc sfTabGroupAt*(
  value: ptr SfTabs, index: csize_t, row: ptr SfTabGroup
): cint {.
  importc: "sophia_sf_tab_group_at", header: "sophia_shell_files_descriptors.h"
.}

proc sfShortcutEntryEncode*(
  bytes: pointer, value: ptr SfShortcutEntry
): cint {.
  importc: "sophia_sf_shortcut_entry_encode", header: "sophia_shell_files_descriptors.h"
.}

proc sfShortcutEntryDecode*(
  bytes: pointer, value: ptr SfShortcutEntry
): cint {.
  importc: "sophia_sf_shortcut_entry_decode", header: "sophia_shell_files_descriptors.h"
.}

proc sfShortcutEntryAt*(
  value: ptr SfShortcuts, index: csize_t, row: ptr SfShortcutEntry
): cint {.
  importc: "sophia_sf_shortcut_entry_at", header: "sophia_shell_files_descriptors.h"
.}

proc sfReferenceEntryEncode*(
  bytes: pointer, value: ptr SfReferenceEntry
): cint {.
  importc: "sophia_sf_reference_entry_encode",
  header: "sophia_shell_files_descriptors.h"
.}

proc sfReferenceEntryDecode*(
  bytes: pointer, value: ptr SfReferenceEntry
): cint {.
  importc: "sophia_sf_reference_entry_decode",
  header: "sophia_shell_files_descriptors.h"
.}

proc sfReferenceEntryAt*(
  value: ptr SfReferenceCandidate, index: csize_t, row: ptr SfReferenceEntry
): cint {.
  importc: "sophia_sf_reference_entry_at", header: "sophia_shell_files_descriptors.h"
.}

proc sfCatalogEntryEncode*(
  bytes: pointer, value: ptr SfCatalogEntry
): cint {.
  importc: "sophia_sf_catalog_entry_encode", header: "sophia_shell_files_roles.h"
.}

proc sfCatalogEntryDecode*(
  bytes: pointer, value: ptr SfCatalogEntry
): cint {.
  importc: "sophia_sf_catalog_entry_decode", header: "sophia_shell_files_roles.h"
.}

proc sfCatalogEntryAt*(
  value: ptr SfCatalog, index: csize_t, row: ptr SfCatalogEntry
): cint {.importc: "sophia_sf_catalog_entry_at", header: "sophia_shell_files_roles.h".}

proc sfTabEntryAt*(
  value: ptr SfTabs, index: csize_t, row: ptr SfDescriptorEntry
): cint {.
  importc: "sophia_sf_tab_entry_at", header: "sophia_shell_files_descriptors.h"
.}

proc sfTabOrderEncode*(
  dst: pointer, slot: uint64
): cint {.
  importc: "sophia_sf_tab_order_encode", header: "sophia_shell_files_descriptors.h"
.}

proc sfTabOrderAt*(
  value: ptr SfTabsCandidate, index: csize_t, slot: ptr uint64
): cint {.
  importc: "sophia_sf_tab_order_at", header: "sophia_shell_files_descriptors.h"
.}

proc ssStorageBytes*(
  msize: uint32, queueBytes: csize_t
): csize_t {.importc: "sophia_ss_storage_bytes", header: "sophia_shell_session.h".}

proc ssOpenFdStaging*(
  session: ptr Ss,
  fd: cint,
  config: ptr SsConfig,
  storage: pointer,
  bytes: csize_t,
  transaction: pointer,
  capacity: csize_t,
): cint {.importc: "sophia_ss_open_fd_staging", header: "sophia_shell_session.h".}

proc ssPollFd*(
  session: ptr Ss
): cint {.importc: "sophia_ss_poll_fd", header: "sophia_shell_session.h".}

proc ssPollEvents*(
  session: ptr Ss
): cshort {.importc: "sophia_ss_poll_events", header: "sophia_shell_session.h".}

proc ssTimeout*(
  session: ptr Ss, nowMs: uint64
): cint {.importc: "sophia_ss_timeout", header: "sophia_shell_session.h".}

proc ssDispatch*(
  session: ptr Ss, revents: cshort, byteBudget: csize_t, nowMs: uint64
): cint {.importc: "sophia_ss_dispatch", header: "sophia_shell_session.h".}

proc ssState*(
  session: ptr Ss
): SsState {.importc: "sophia_ss_state", header: "sophia_shell_session.h".}

proc ssEpoch*(
  session: ptr Ss
): uint64 {.importc: "sophia_ss_epoch", header: "sophia_shell_session.h".}

proc ssSubmit*(
  session: ptr Ss, records: ptr SfRecord, count: csize_t, firstTicket: ptr uint64
): cint {.importc: "sophia_ss_submit", header: "sophia_shell_session.h".}

proc ssOutcome*(
  session: ptr Ss, ticket: uint64, outcome: ptr SsOutcome, error: ptr uint32
): cint {.importc: "sophia_ss_outcome", header: "sophia_shell_session.h".}

proc ssConsume*(
  session: ptr Ss
): cint {.importc: "sophia_ss_consume", header: "sophia_shell_session.h".}

proc ssAck*(
  session: ptr Ss
): cint {.importc: "sophia_ss_ack", header: "sophia_shell_session.h".}

proc ssAckLimit*(
  session: ptr Ss
): uint64 {.importc: "sophia_ss_ack_limit", header: "sophia_shell_session.h".}

proc ssObligations*(
  session: ptr Ss, obligations: ptr SsObligations
): cint {.importc: "sophia_ss_obligations", header: "sophia_shell_session.h".}

proc ssObject*(
  session: ptr Ss, kind: uint16, generation: uint64, qid: uint64
): cint {.importc: "sophia_ss_object", header: "sophia_shell_session.h".}

proc ssRefusal*(
  session: ptr Ss, reason: ptr uint16, denied: ptr uint64
): cint {.importc: "sophia_ss_refusal", header: "sophia_shell_session.h".}

proc ssClose*(
  session: ptr Ss
): void {.importc: "sophia_ss_close", header: "sophia_shell_session.h".}

proc ssStateBytes*(): csize_t {.
  importc: "narthex_ss_state_bytes", header: "desktop_sdk_ffi.h"
.}

proc ssEvent*(
  session: ptr Ss, record: ptr SfRecord
): cint {.importc: "narthex_ss_event", header: "desktop_sdk_ffi.h".}

proc ssObjectResult*(
  session: ptr Ss, record: ptr SfRecord
): cint {.importc: "narthex_ss_object_result", header: "desktop_sdk_ffi.h".}

proc ssWelcome*(
  session: ptr Ss, value: ptr SfNegotiated
): cint {.importc: "narthex_ss_welcome", header: "desktop_sdk_ffi.h".}

{.pop.}
