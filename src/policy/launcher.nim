import std/[algorithm, strutils, unicode]
import ../types/[shell_v1, shell_launcher, desktop_sdk, shell_files]
import ../sdk/values

proc fail() {.noreturn.} =
  raise newException(ValueError, "invalid application launcher exchange")

proc reconcileApplications*(model: var LauncherModel, catalog: ApplicationCatalog) =
  if model.catalog.epoch == catalog.epoch and
      catalog.generation <= model.catalog.generation:
    fail()
  model = LauncherModel(
    catalog: catalog,
    fontSize: 14,
    colors: [0xf0202020'u32, 0xffdddddd'u32, 0xff525f66'u32, 0xffffffff'u32],
  )

proc proposeLauncher*(
    model: var LauncherModel, request: LauncherRequest, generation, transaction: uint64
): ShellFileCandidate =
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
  result.record.header.kind = 277
  result.record.value.descriptorLauncherCandidate = SfDescriptorLauncherCandidate(
    transaction: transaction,
    connectionEpoch: request.epoch,
    catalogGeneration: request.catalog,
    requestGeneration: request.request,
    candidateGeneration: generation,
    outputId: request.output,
    visible: uint16(model.pendingVisible),
    selected: model.selected,
    entryCount: uint16(model.pendingEntries.len),
    fontSize: model.fontSize,
    colors: model.colors,
  )
  for i, slot in model.pendingEntries:
    result.record.value.descriptorLauncherCandidate.entries[i] = slot

proc rememberLauncher*(model: var LauncherModel, value: SfDescriptorLauncherOutcome) =
  if value.connectionEpoch != model.catalog.epoch or
      value.requestGeneration != model.pendingRequest or
      value.candidateGeneration != model.pendingCandidate or
      value.transaction != model.pendingTransaction or value.kind notin 1'u16 .. 4'u16:
    fail()
  let kind = ShellCandidateOutcomeKind(value.kind)
  if kind == ShellCandidateOutcomeKind.prepared:
    if model.lastOutcome == ShellCandidateOutcomeKind.prepared or
        value.presentationEpoch != 0:
      fail()
  elif kind == ShellCandidateOutcomeKind.presented:
    if model.lastOutcome != ShellCandidateOutcomeKind.prepared or
        value.presentationEpoch == 0:
      fail()
    model.presentation = value.presentationEpoch
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

proc acknowledgeLauncher*(
    model: var LauncherModel, value: SfDescriptorLauncherActivation
): ShellFileCandidate =
  let a = value.launcherActivation()
  let valid =
    a.epoch == model.catalog.epoch and a.catalog == model.catalog.generation and
    a.request == model.presentedRequest and a.candidate == model.presentedCandidate and
    a.presentation == model.presentation and a.activation > model.lastActivation and
    a.slot in model.presentedEntries and model.pendingCandidate == 0 and
    not model.activationPending and model.activatedCandidate != a.candidate
  if not model.activationPending:
    model.expectedActivation = a
    model.activationTransaction = value.transaction
    model.activationPending = true
  if valid:
    model.lastActivation = a.activation
    model.activatedCandidate = a.candidate
    model.expectedActivation = a
    model.activationTransaction = value.transaction
    model.activationPending = true
  result.record.header.kind = 278
  result.record.value.descriptorLauncherActivationAck =
    SfDescriptorLauncherActivationAck(grant: value, consumed: uint16(valid))

proc validateLaunchOutcome*(
    model: var LauncherModel, value: SfDescriptorLaunchOutcome
) =
  if not model.activationPending or
      value.grant.transaction != model.activationTransaction or
      value.status notin 1'u16 .. 3'u16 or
      value.grant.launcherActivation() != model.expectedActivation:
    fail()
  model.activationPending = false
