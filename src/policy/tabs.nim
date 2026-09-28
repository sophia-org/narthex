import ../types/[shell_v1, shell_tabs, desktop_sdk, shell_files]
import ../sdk/desktop_sdk
import ../sdk/values

proc fail(message: string) {.noreturn.} =
  raise newException(ValueError, message)

proc proposeTabs*(
    model: var ShellTabModel,
    snapshot: ShellTabSnapshot,
    generation, transaction: uint64,
): ShellFileCandidate =
  if generation == 0 or snapshot.generation <= model.snapshot.generation:
    fail("stale tab snapshot")
  model.snapshot = snapshot
  model.pendingGeneration = generation
  model.prepared = false
  result.record.header.kind = 275
  result.record.value.tabsCandidate = SfTabsCandidate(
    transaction: transaction,
    connectionEpoch: snapshot.connectionEpoch,
    snapshotGeneration: snapshot.generation,
    candidateGeneration: generation,
    groupCount: uint16(snapshot.groups.len),
  )
  result.rows = newSeq[byte](snapshot.groups.len * 8)
  for i, group in snapshot.groups:
    sdkCheck(sfTabOrderEncode(addr result.rows[i * 8], group.slot))

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
