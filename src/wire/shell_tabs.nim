import std/[sets]
import ../types/[shell_v1, shell_tabs]
import ./shell_v1

proc fail(message: string) {.noreturn.} =
  raise newException(ShellProtocolError, message)

proc decodeTabs*(frames: seq[ShellFrame]): ShellTabSnapshot =
  if frames.len < 2 or frames.len > 2 + maxShellTabGroups + maxShellTabEntries:
    fail("invalid tab transfer length")
  let first = frames[0]
  if first.kind != ShellMessageKind.tabsBegin or first.payload.len != 20:
    fail("invalid tab begin")
  result.connectionEpoch = first.payload.u64At(0)
  result.generation = first.payload.u64At(8)
  let groups = int(first.payload.u16At(16))
  let entries = int(first.payload.u16At(18))
  if result.connectionEpoch == 0 or result.generation == 0 or groups > maxShellTabGroups or
      entries > maxShellTabEntries or frames.len != 2 + groups + entries:
    fail("invalid tab bounds")
  var remaining = 0
  var slots = initHashSet[uint16]()
  var groupSlots = initHashSet[uint64]()
  for i in 1 ..< frames.len:
    let frame = frames[i]
    let p = frame.payload
    if frame.transaction != first.transaction or p.u64At(0) != result.connectionEpoch or
        p.u64At(8) != result.generation:
      fail("mixed tab transfer")
    case frame.kind
    of ShellMessageKind.tabsGroup:
      if i == frames.high or remaining != 0 or p.len != 40 or p.u16At(38) != 0 or
          p.u16At(34) > 1:
        fail("invalid tab group")
      let slot = p.u64At(16)
      let output = p.u64At(24)
      if slot == 0 or output == 0 or slot in groupSlots:
        fail("invalid group identity")
      groupSlots.incl(slot)
      remaining = int(p.u16At(36))
      result.groups.add(
        ShellTabGroup(
          slot: slot, output: output, selected: p.u16At(32), focused: p.u16At(34) == 1
        )
      )
    of ShellMessageKind.tabsEntry:
      if remaining == 0 or i == frames.high or result.groups.len == 0 or
          p.u64At(16) != result.groups[^1].slot:
        fail("detached tab entry")
      let snapshot = ShellFrame(
        kind: ShellMessageKind.descriptorSnapshot,
        transaction: frame.transaction,
        payload: p[24 .. ^1],
      ).decodeSnapshot()
      if snapshot.connectionEpoch != result.connectionEpoch or
          snapshot.generation != result.generation or
          snapshot.output != result.groups[^1].output or snapshot.descriptors.len != 1:
        fail("mixed tab descriptor")
      let d = snapshot.descriptors[0]
      if d.slot in slots:
        fail("duplicate tab slot")
      slots.incl(d.slot)
      result.groups[^1].entries.add(d)
      dec remaining
    of ShellMessageKind.tabsEnd:
      if i != frames.high or remaining != 0 or p.len != 16:
        fail("invalid tab end")
    else:
      fail("unexpected tab frame")
  if frames[^1].kind != ShellMessageKind.tabsEnd or result.groups.len != groups or
      slots.len != entries:
    fail("incomplete tab transfer")
  for group in result.groups:
    var selected = group.entries.len == 0 and group.selected == 0
    for d in group.entries:
      if d.slot == group.selected:
        selected = true
    if not selected:
      fail("tab selection is missing")

proc proposeTabs*(
    model: var ShellTabModel,
    snapshot: ShellTabSnapshot,
    generation, transaction: uint64,
): ShellFrame =
  if generation == 0 or snapshot.generation <= model.snapshot.generation:
    fail("stale tab snapshot")
  model.snapshot = snapshot
  model.pendingGeneration = generation
  model.prepared = false
  result.kind = ShellMessageKind.tabsCandidate
  result.transaction = transaction
  result.payload.addU64(snapshot.connectionEpoch)
  result.payload.addU64(snapshot.generation)
  result.payload.addU64(generation)
  result.payload.addU16(uint16(snapshot.groups.len))
  result.payload.addU16(0)
  for group in snapshot.groups:
    result.payload.addU64(group.slot)

proc rememberTabs*(model: var ShellTabModel, outcome: ShellCandidateOutcome) =
  if outcome.kind == ShellCandidateOutcomeKind.superseded and
      outcome.candidateGeneration < model.pendingGeneration:
    return
  if outcome.connectionEpoch != model.snapshot.connectionEpoch or
      outcome.candidateGeneration != model.pendingGeneration:
    fail("stale tab outcome")
  case outcome.kind
  of ShellCandidateOutcomeKind.prepared:
    if model.prepared:
      fail("duplicate tab preparation")
    model.prepared = true
  of ShellCandidateOutcomeKind.presented:
    if not model.prepared:
      fail("unprepared tab presentation")
    model.presented = model.snapshot
    model.presentedGeneration = model.pendingGeneration
    model.presentationEpoch = outcome.presentationEpoch
    model.pendingGeneration = 0
  of ShellCandidateOutcomeKind.rejected, ShellCandidateOutcomeKind.superseded:
    model.pendingGeneration = 0

proc acceptTab*(
    model: var ShellTabModel, activation: ShellActivation
): ShellActivationDisposition =
  if activation.connectionEpoch != model.presented.connectionEpoch or
      activation.candidateGeneration != model.presentedGeneration or
      activation.presentationEpoch != model.presentationEpoch or
      activation.activation <= model.lastActivation:
    return ShellActivationDisposition.rejectedStale
  for group in model.presented.groups:
    for d in group.entries:
      if d.action == activation.action:
        model.lastActivation = activation.activation
        return ShellActivationDisposition.consumed
  ShellActivationDisposition.rejectedStale
