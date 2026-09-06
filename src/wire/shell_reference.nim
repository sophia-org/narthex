import std/[algorithm, sets, strutils, unicode]
import ../types/[shell_v1, shell_reference]
import ./shell_v1

proc require(ok: bool) =
  if not ok:
    raise newException(ShellProtocolError, "invalid reference sheet")

proc readText(bytes: openArray[byte], at: var int, bound: int): string =
  let size = int(bytes.u16At(at))
  at += 2
  require(size <= bound and at + size <= bytes.len)
  for i in 0 ..< size:
    result.add(char(bytes[at + i]))
  at += size
  require(result.validateUtf8() == -1)
  for c in result.runes():
    let n = int(c)
    require(
      n >= 32 and n notin 127 .. 159 and n notin 0x202a .. 0x202e and
        n notin 0x2066 .. 0x2069
    )

proc decodeShortcuts*(frames: seq[ShellFrame]): ShortcutCatalog =
  require(frames.len in 2 .. maxShortcuts + 2)
  let first = frames[0]
  require(
    first.kind == ShellMessageKind.shortcutsBegin and first.transaction > 0 and
      first.payload.len == 20
  )
  result.epoch = first.payload.u64At(0)
  result.generation = first.payload.u64At(8)
  require(
    result.epoch > 0 and result.generation > 0 and first.payload.u16At(18) == 0 and
      int(first.payload.u16At(16)) == frames.len - 2
  )
  var seen: HashSet[uint16]
  for i, frame in frames:
    require(
      frame.transaction == first.transaction and frame.payload.u64At(0) == result.epoch and
        frame.payload.u64At(8) == result.generation
    )
    if i == 0:
      continue
    if i == frames.high:
      require(frame.kind == ShellMessageKind.shortcutsEnd and frame.payload.len == 16)
      continue
    require(
      frame.kind == ShellMessageKind.shortcutsEntry and frame.payload.u16At(18) == 0
    )
    var row = ShortcutRow(slot: frame.payload.u16At(16))
    require(row.slot > 0 and row.slot notin seen)
    seen.incl(row.slot)
    var at = 20
    row.chord = frame.payload.readText(at, 64)
    row.action = frame.payload.readText(at, 128)
    row.label = frame.payload.readText(at, 128)
    row.group = frame.payload.readText(at, 64)
    require(at == frame.payload.len and row.chord.len > 0 and row.action.len > 0)
    result.rows.add(row)

proc decodeReferenceRequest*(frame: ShellFrame): ReferenceRequest =
  require(
    frame.kind == ShellMessageKind.referenceRequest and frame.transaction > 0 and
      frame.payload.len == 52 and frame.payload.u16At(50) == 0
  )
  let p = frame.payload
  result = ReferenceRequest(
    epoch: p.u64At(0),
    catalog: p.u64At(8),
    generation: p.u64At(16),
    output: p.u64At(24),
    outputGeneration: p.u64At(32),
    presentation: p.u64At(40),
  )
  require(
    result.epoch > 0 and result.catalog > 0 and result.generation > 0 and
      result.output > 0 and result.outputGeneration > 0 and p.u16At(48) <= 4
  )
  result.operation = ReferenceOperation(p.u16At(48))

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

proc addText(bytes: var seq[byte], text: string) =
  bytes.addU16(uint16(text.len))
  for c in text:
    bytes.add(byte(c))

proc proposeReference*(
    model: var ReferenceModel,
    request: ReferenceRequest,
    generation, transaction: uint64,
): ShellFrame =
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
  result =
    ShellFrame(kind: ShellMessageKind.referenceCandidate, transaction: transaction)
  for n in [
    request.epoch, request.catalog, request.generation, generation, request.output
  ]:
    result.payload.addU64(n)
  for n in [uint16(visible), page, uint16(rows.len), 0'u16]:
    result.payload.addU16(n)
  # Triad fb8fb27 visual policy, rendered in Sophia's shared JetBrains Mono.
  for n in [14'u16, 16, 24, 10, 28, 32, 4, 48, 2]:
    result.payload.addU16(n)
  for n in [
    0xdd111318'u32, 0xff62a8ff'u32, 0xfff4f7fb'u32, 0xffaab3c2'u32, 0xff262a33'u32,
    0xffffffff'u32,
  ]:
    result.payload.addU32(n)
  let title = "Important Hotkeys"
  result.payload.addU16(uint16(title.len))
  for c in title:
    result.payload.add(byte(c))
  for row in rows:
    result.payload.addU16(row.slot)
    result.payload.addU16(0)
    result.payload.addText(row.chord)
    result.payload.addText(row.displayLabel())
  model.lastRequest = request.generation
  model.pendingRequest = request.generation
  model.pendingTransaction = transaction
  model.pendingGeneration = generation
  model.pendingVisible = visible

proc rememberReference*(model: var ReferenceModel, frame: ShellFrame) =
  let p = frame.payload
  require(
    frame.kind == ShellMessageKind.referenceOutcome and frame.transaction > 0 and
      p.len == 48 and p.u16At(46) == 0
  )
  require(
    p.u64At(0) == model.catalog.epoch and p.u64At(8) == model.catalog.generation and
      p.u64At(16) == model.pendingRequest and p.u64At(24) == model.pendingGeneration
  )
  require(
    p.u16At(42) > 0 and p.u16At(40) < p.u16At(42) and p.u16At(44) in 1'u16 .. 4'u16
  )
  if p.u16At(44) == 2:
    require(p.u64At(32) > 0)
    model.visible = model.pendingVisible
    model.page = p.u16At(40)
    model.pages = p.u16At(42)
    model.presentation = p.u64At(32)
    model.pendingGeneration = 0
  elif p.u16At(44) in [3'u16, 4'u16]:
    model.pendingGeneration = 0
