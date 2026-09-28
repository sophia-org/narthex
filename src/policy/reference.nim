import std/[algorithm, strutils]
import ../types/[shell_reference, desktop_sdk, shell_files]
import ../sdk/[desktop_sdk, values]

proc require(ok: bool) =
  if not ok:
    raise newException(ValueError, "invalid reference sheet")

proc reconcile*(model: var ReferenceModel, catalog: ShortcutCatalog) =
  require(
    model.catalog.epoch == 0 or (
      catalog.epoch == model.catalog.epoch and
      catalog.generation > model.catalog.generation
    )
  )
  model.catalog = catalog
  model.visible = false
  model.page = 0
  model.pages = 1
  model.presentation = 0
  model.pendingGeneration = 0

proc purpose(row: ShortcutRow): string =
  if row.group.len > 0:
    return row.group
  let action = row.action.split(':')[^1]
  if action.startsWith("spawn"):
    return "Applications"
  if action.startsWith("focus"):
    return "Navigation"
  if action.contains("layout") or action.contains("split"):
    return "Layouts"
  if action.contains("view") or action.contains("workspace") or action.startsWith("tag"):
    return "Workspaces"
  if row.action.startsWith("session:"):
    return "Session"
  "Windows"

proc displayLabel(row: ShortcutRow): string =
  if row.label.len > 0:
    return row.label
  let raw = row.action.split(':')[^1].replace('-', ' ').replace('_', ' ')
  if raw.len == 0:
    return "Shortcut"
  raw[0].toUpperAscii() & raw[1 .. ^1]

proc proposeReference*(
    model: var ReferenceModel,
    request: ReferenceRequest,
    generation, transaction: uint64,
): ShellFileCandidate =
  require(
    request.epoch == model.catalog.epoch and request.catalog == model.catalog.generation and
      request.generation > model.lastRequest and generation > 0 and
      model.pendingGeneration == 0
  )
  if request.operation in
      {ReferenceOperation.next, ReferenceOperation.previous, ReferenceOperation.dismiss}:
    require(
      model.visible and request.presentation == model.presentation and
        model.presentation > 0
    )
  var visible = model.visible
  var page = model.page
  case request.operation
  of ReferenceOperation.startup:
    visible = not model.skipAtStartup
  of ReferenceOperation.toggle:
    visible = not visible
    page = 0
  of ReferenceOperation.next:
    page = min(page + 1, max(1'u16, model.pages) - 1)
  of ReferenceOperation.previous:
    page =
      if page > 0:
        page - 1
      else:
        0
  of ReferenceOperation.dismiss:
    visible = false
  var rows = model.catalog.rows
  rows.sort(
    proc(a, b: ShortcutRow): int =
      cmp(a.purpose(), b.purpose())
  )
  result.record.header.kind = 276
  result.record.value.referenceCandidate = SfReferenceCandidate(
    transaction: transaction,
    connectionEpoch: request.epoch,
    catalogGeneration: request.catalog,
    requestGeneration: request.generation,
    candidateGeneration: generation,
    outputId: request.output,
    visible: uint16(visible),
    page: page,
    entryCount: uint16(rows.len),
    style: SfReferenceStyle(
      bodySize: 14,
      titleSize: 16,
      padding: 24,
      rowGap: 10,
      keyGap: 28,
      columnGap: 32,
      border: 4,
      margin: 48,
      columns: 2,
      colors: [
        0xdd111318'u32, 0xff62a8ff'u32, 0xfff4f7fb'u32, 0xffaab3c2'u32, 0xff262a33'u32,
        0xffffffff'u32,
      ],
      title: SfText(data: cast[ptr uint8](cstring("Important Hotkeys")), size: 17),
    ),
  )
  result.rows = newSeq[byte](rows.len * 204)
  for i, row in rows:
    var label = row.displayLabel()
    var entry = SfReferenceEntry(
      slot: row.slot, key: row.chord.borrowedText(), label: label.borrowedText()
    )
    sdkCheck(sfReferenceEntryEncode(addr result.rows[i * 204], addr entry))
  model.lastRequest = request.generation
  model.pendingRequest = request.generation
  model.pendingTransaction = transaction
  model.pendingGeneration = generation
  model.pendingVisible = visible

proc rememberReference*(model: var ReferenceModel, value: SfReferenceOutcome) =
  require(
    value.transaction > 0 and value.connectionEpoch == model.catalog.epoch and
      value.catalogGeneration == model.catalog.generation and
      value.requestGeneration == model.pendingRequest and
      value.candidateGeneration == model.pendingGeneration and value.pages > 0 and
      value.page < value.pages and value.kind in 1'u16 .. 4'u16
  )
  if value.kind == 2:
    require(value.presentationEpoch > 0)
    model.visible = model.pendingVisible
    model.page = value.page
    model.pages = value.pages
    model.presentation = value.presentationEpoch
    model.pendingGeneration = 0
  elif value.kind in [3'u16, 4'u16]:
    model.pendingGeneration = 0
