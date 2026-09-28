import std/[algorithm, options, sequtils, sets]
import ../types/shell_v1

proc fail(message: string) {.noreturn.} =
  raise newException(ValueError, message)

proc reconcile*(model: var ShellModel, snapshot: ShellSnapshot) =
  if model.connectionEpoch != snapshot.connectionEpoch:
    model = ShellModel(connectionEpoch: snapshot.connectionEpoch)
  var live = initHashSet[ShellDescriptorKey]()
  for descriptor in snapshot.descriptors:
    live.incl(
      ShellDescriptorKey(slot: descriptor.slot, generation: descriptor.generation)
    )
  model.order.keepItIf(it in live)
  var additions: seq[ShellDescriptorKey]
  for key in live:
    if key notin model.order:
      additions.add(key)
  additions.sort(
    proc(a, b: ShellDescriptorKey): int =
      result = cmp(a.slot, b.slot)
      if result == 0:
        result = cmp(a.generation, b.generation)
  )
  model.order.add(additions)
  model.snapshotGeneration = snapshot.generation
  model.output = snapshot.output
  if model.selected.isNone or model.order.allIt(it.slot != model.selected.get()):
    model.selected =
      if model.order.len == 0:
        none(uint16)
      else:
        some(model.order[0].slot)

proc candidate*(
    model: ShellModel,
    generation: uint64,
    visible: bool,
    reservation = none(ShellReservation),
): ShellCandidate =
  result.connectionEpoch = model.connectionEpoch
  result.snapshotGeneration = model.snapshotGeneration
  result.generation = generation
  result.output = model.output
  result.visible = visible and model.order.len > 0
  if result.visible:
    result.selected = model.selected
    result.entries = model.order
    result.reservation = reservation

proc accept*(
    model: var ShellModel, activation: ShellActivation
): ShellActivationDisposition =
  let exact =
    activation.connectionEpoch == model.connectionEpoch and
    activation.candidateGeneration == model.presentedGeneration and
    activation.presentationEpoch == model.presentationEpoch and
    activation.activation > model.lastActivation and
    model.order.anyIt(
      it.slot == activation.action.targetSlot and
        it.generation == activation.action.targetGeneration
    )
  if not exact:
    return ShellActivationDisposition.rejectedStale
  model.lastActivation = activation.activation
  ShellActivationDisposition.consumed

proc rememberPresented*(model: var ShellModel, outcome: ShellCandidateOutcome) =
  if outcome.connectionEpoch != model.connectionEpoch or
      outcome.kind != ShellCandidateOutcomeKind.presented:
    fail("shell presentation outcome is not current")
  model.presentedGeneration = outcome.candidateGeneration
  model.presentationEpoch = outcome.presentationEpoch
