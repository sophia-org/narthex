import std/[algorithm, sets, strutils, unicode]
import ../types/[shell_v1, shell_launcher]
import shell_v1

proc fail() {.noreturn.} =
  raise newException(ShellProtocolError, "invalid application launcher exchange")

proc takeText(bytes: openArray[byte], at: var int, maximum: int): string =
  if at + 2 > bytes.len:
    fail()
  let n = int(bytes.u16At(at))
  at += 2
  if n > maximum or at + n > bytes.len:
    fail()
  for i in 0 ..< n:
    result.add(char(bytes[at + i]))
  at += n
  if result.validateUtf8() != -1:
    fail()
  for rune in result.runes:
    let c = int(rune)
    if c < 32 or c in 127 .. 159 or c in 0x202a .. 0x202e or c in 0x2066 .. 0x2069:
      fail()

proc decodeApplications*(frames: openArray[ShellFrame]): ApplicationCatalog =
  if frames.len < 2 or frames.len > maxApplications + 2:
    fail()
  let first = frames[0]
  if first.kind != ShellMessageKind.applicationsBegin or first.payload.len != 20:
    fail()
  result.epoch = first.payload.u64At(0)
  result.generation = first.payload.u64At(8)
  let count = int(first.payload.u16At(16))
  if result.epoch == 0 or result.generation == 0 or first.payload.u16At(18) != 0 or
      count + 2 != frames.len:
    fail()
  var slots = initHashSet[uint16]()
  for i in 1 ..< frames.len:
    let frame = frames[i]
    if frame.transaction != first.transaction or frame.payload.len < 16 or
        frame.payload.u64At(0) != result.epoch or
        frame.payload.u64At(8) != result.generation:
      fail()
    if i == frames.high:
      if frame.kind != ShellMessageKind.applicationsEnd or frame.payload.len != 16:
        fail()
    else:
      if frame.kind != ShellMessageKind.applicationsEntry or frame.payload.len < 24:
        fail()
      var entry = ApplicationDescriptor(
        slot: frame.payload.u16At(16), available: frame.payload.u16At(18) == 1
      )
      if entry.slot == 0 or entry.slot > uint16(maxApplications) or entry.slot in slots or
          frame.payload.u16At(18) > 1:
        fail()
      slots.incl(entry.slot)
      var at = 20
      entry.label = frame.payload.takeText(at, 128)
      entry.keywords = frame.payload.takeText(at, 256)
      if at != frame.payload.len or entry.label.len == 0:
        fail()
      result.entries.add(entry)

proc reconcileApplications*(model: var LauncherModel, catalog: ApplicationCatalog) =
  if model.catalog.epoch == catalog.epoch and
      catalog.generation <= model.catalog.generation:
    fail()
  model = LauncherModel(
    catalog: catalog,
    fontSize: 14,
    colors: [0xf0202020'u32, 0xffdddddd'u32, 0xff525f66'u32, 0xffffffff'u32],
  )

proc decodeLauncherRequest*(frame: ShellFrame): LauncherRequest =
  let b = frame.payload
  if frame.kind != ShellMessageKind.launcherRequest or b.len < 54:
    fail()
  result = LauncherRequest(
    epoch: b.u64At(0),
    catalog: b.u64At(8),
    request: b.u64At(16),
    output: b.u64At(24),
    outputGeneration: b.u64At(32),
    presentation: b.u64At(40),
    operation: b.u16At(48),
  )
  if result.epoch == 0 or result.catalog == 0 or result.request == 0 or
      result.output == 0 or result.outputGeneration == 0 or result.operation > 4 or
      b.u16At(50) != 0:
    fail()
  var at = 52
  result.query = b.takeText(at, 256)
  if at != b.len:
    fail()

proc proposeLauncher*(
    model: var LauncherModel, request: LauncherRequest, generation, transaction: uint64
): ShellFrame =
  if request.epoch != model.catalog.epoch or request.catalog != model.catalog.generation or
      request.request <= model.lastRequest or model.pendingCandidate != 0 or
      generation <= model.lastCandidate:
    fail()
  model.lastRequest = request.request
  model.lastCandidate = generation
  let query = unicode.toLower(request.query)
  var matches: seq[int]
  for i, entry in model.catalog.entries:
    if query.len == 0 or query in unicode.toLower(entry.label & " " & entry.keywords):
      matches.add(i)
  let catalog = model.catalog
  matches.sort(
    proc(a, b: int): int =
      let left = unicode.toLower(catalog.entries[a].label)
      let right = unicode.toLower(catalog.entries[b].label)
      result = cmp(not left.startsWith(query), not right.startsWith(query))
      if result == 0:
        result = cmp(left, right)
      if result == 0:
        result = cmp(catalog.entries[a].slot, catalog.entries[b].slot)
  )
  var selected = 0
  if request.operation in [2'u16, 3'u16]:
    for i, index in matches:
      if model.catalog.entries[index].slot == model.selected:
        selected = i
    if matches.len > 0:
      selected =
        (selected + (if request.operation == 2: 1
          else: matches.len - 1)) mod matches.len
  model.selected =
    if matches.len == 0:
      0
    else:
      model.catalog.entries[matches[selected]].slot
  model.pendingEntries.setLen(0)
  let first = max(0, selected - maxLauncherRows div 2)
  for i in first ..< min(first + maxLauncherRows, matches.len):
    model.pendingEntries.add(model.catalog.entries[matches[i]].slot)
  model.pendingRequest = request.request
  model.pendingCandidate = generation
  model.pendingTransaction = transaction
  model.pendingVisible = request.operation != 4
  model.lastOutcome = ShellCandidateOutcomeKind.superseded
  result =
    ShellFrame(kind: ShellMessageKind.launcherCandidate, transaction: transaction)
  for n in [request.epoch, request.catalog, request.request, generation, request.output]:
    result.payload.addU64(n)
  for n in [
    uint16(model.pendingVisible),
    model.selected,
    uint16(model.pendingEntries.len),
    model.fontSize,
  ]:
    result.payload.addU16(n)
  for color in model.colors:
    result.payload.addU32(color)
  for slot in model.pendingEntries:
    result.payload.addU16(slot)

proc rememberLauncher*(model: var LauncherModel, frame: ShellFrame) =
  let b = frame.payload
  if frame.kind != ShellMessageKind.launcherOutcome or b.len != 36 or
      b.u64At(0) != model.catalog.epoch or b.u64At(8) != model.pendingRequest or
      b.u64At(16) != model.pendingCandidate or
      frame.transaction != model.pendingTransaction or b.u16At(34) != 0 or
      b.u16At(32) notin 1'u16 .. 4'u16:
    fail()
  let kind = ShellCandidateOutcomeKind(b.u16At(32))
  if kind == ShellCandidateOutcomeKind.prepared:
    if model.lastOutcome == ShellCandidateOutcomeKind.prepared or b.u64At(24) != 0:
      fail()
  elif kind == ShellCandidateOutcomeKind.presented:
    if model.lastOutcome != ShellCandidateOutcomeKind.prepared or b.u64At(24) == 0:
      fail()
    model.presentation = b.u64At(24)
    model.presentedRequest = model.pendingRequest
    model.presentedCandidate = model.pendingCandidate
    model.presentedEntries =
      if model.pendingVisible:
        model.pendingEntries
      else:
        @[]
  if kind != ShellCandidateOutcomeKind.prepared:
    model.pendingCandidate = 0
  model.lastOutcome = kind

proc decodeLauncherActivation*(frame: ShellFrame): LauncherActivation =
  let b = frame.payload
  if frame.kind != ShellMessageKind.launcherActivation or b.len != 52 or b.u16At(50) != 0:
    fail()
  result = LauncherActivation(
    epoch: b.u64At(0),
    catalog: b.u64At(8),
    request: b.u64At(16),
    candidate: b.u64At(24),
    presentation: b.u64At(32),
    activation: b.u64At(40),
    slot: b.u16At(48),
  )
  for v in [
    result.epoch, result.catalog, result.request, result.candidate, result.presentation,
    result.activation,
  ]:
    if v == 0:
      fail()
  if result.slot == 0 or result.slot > uint16(maxApplications):
    fail()

proc acknowledgeLauncher*(model: var LauncherModel, frame: ShellFrame): ShellFrame =
  let a = frame.decodeLauncherActivation()
  let valid =
    a.epoch == model.catalog.epoch and a.catalog == model.catalog.generation and
    a.request == model.presentedRequest and a.candidate == model.presentedCandidate and
    a.presentation == model.presentation and a.activation > model.lastActivation and
    a.slot in model.presentedEntries and model.pendingCandidate == 0 and
    not model.activationPending and model.activatedCandidate != a.candidate
  if not model.activationPending:
    model.expectedActivation = a
    model.activationTransaction = frame.transaction
    model.activationPending = true
  if valid:
    model.lastActivation = a.activation
    model.activatedCandidate = a.candidate
    model.expectedActivation = a
    model.activationTransaction = frame.transaction
    model.activationPending = true
  result = ShellFrame(
    kind: ShellMessageKind.launcherActivationAck,
    transaction: frame.transaction,
    payload: frame.payload[0 ..< 50],
  )
  result.payload.addU16(uint16(valid))

proc validateLaunchOutcome*(model: var LauncherModel, frame: ShellFrame) =
  let b = frame.payload
  let a = model.expectedActivation
  if frame.kind != ShellMessageKind.launchOutcome or b.len != 52 or
      not model.activationPending or frame.transaction != model.activationTransaction or
      b.u16At(50) notin 1'u16 .. 3'u16:
    fail()
  for i, value in [
    a.epoch, a.catalog, a.request, a.candidate, a.presentation, a.activation
  ]:
    if b.u64At(i * 8) != value:
      fail()
  if b.u16At(48) != a.slot:
    fail()
  model.activationPending = false
