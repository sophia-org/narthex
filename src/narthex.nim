import std/[options, os, strutils]
import
  types/
    [shell_v1, shell_tabs, shell_reference, shell_launcher, shell_files, desktop_sdk]
import sdk/[file_session, values]
import policy/[switcher, tabs, reference, launcher]
import config

proc fail(message: string) {.noreturn.} =
  raise newException(ValueError, message)

## The bar strip is a bounded status zone the shell claims work area for.
## Its thickness comes from the session so the operator, not the shell, decides
## how much of the desktop a panel may take; an unset or zero value means this
## shell reserves nothing and behaves exactly as the switcher-only shell did.
proc barReservation(): Option[ShellReservation] =
  let configured = getEnv("SOPHIA_SHELL_BAR_THICKNESS")
  if configured.len == 0:
    return none(ShellReservation)
  var thickness: int
  try:
    thickness = parseInt(configured)
  except ValueError:
    fail("narthex: SOPHIA_SHELL_BAR_THICKNESS is not a number")
  if thickness <= 0:
    return none(ShellReservation)
  if thickness > int(shellMaxReservationThickness):
    fail("narthex: SOPHIA_SHELL_BAR_THICKNESS exceeds the protocol maximum")
  some(
    ShellReservation(edge: ShellReservationEdge.bottom, thicknessPx: uint16(thickness))
  )

proc runProof(socketPath: string, bar: bool) =
  let owner = openSession(socketPath, if bar: 3'u64 else: 1'u64)
  defer:
    owner.close()
  let deadline = nowMillis() + 10_000
  var model = ShellModel(connectionEpoch: owner.epoch)
  let reservation =
    if bar:
      barReservation()
    else:
      none(ShellReservation)
  if bar and reservation.isNone:
    fail("narthex: the bar proof requires SOPHIA_SHELL_BAR_THICKNESS")
  var firstRecord = owner.nextRecord(deadline)
  let first = firstRecord.snapshot()
  model.reconcile(first)
  var proposal = model.candidate(1, true, reservation).fileCandidate(
      firstRecord.value.descriptors.transaction
    )
  owner.submit(proposal)
  var event = owner.nextRecord(deadline)
  if event.candidateOutcome().kind != ShellCandidateOutcomeKind.prepared:
    fail("Sophia did not prepare the shell candidate")
  event = owner.nextRecord(deadline)
  model.rememberPresented(event.candidateOutcome())
  if not bar:
    event = owner.nextRecord(deadline)
    let activation = event.descriptorActivation()
    let disposition = model.accept(activation)
    var ack = activationAck(
      model.connectionEpoch, activation.activation,
      event.value.descriptorActivation.transaction, disposition,
    )
    owner.submit(ack)
    if disposition != ShellActivationDisposition.consumed:
      fail("Sophia delivered a stale shell activation")
  event = owner.nextRecord(deadline)
  model.reconcile(event.snapshot())
  proposal =
    model.candidate(2, false).fileCandidate(event.value.descriptors.transaction)
  owner.submit(proposal)
  event = owner.nextRecord(deadline)
  if event.candidateOutcome().kind != ShellCandidateOutcomeKind.prepared:
    fail("Sophia did not prepare the shell withdrawal")
  event = owner.nextRecord(deadline)
  if event.candidateOutcome().kind != ShellCandidateOutcomeKind.presented:
    fail("Sophia did not present the shell withdrawal")
  owner.settle()
  if bar:
    stdout.writeLine(
      "narthex_bar_proof schema=1 status=complete edge=bottom thickness=" &
        $reservation.get().thicknessPx & " withdrawn=true wire=9p"
    )
  else:
    stdout.writeLine(
      "narthex_proof schema=1 status=complete descriptors=" & $first.descriptors.len &
        " activations=1 withdrawn=true wire=9p"
    )

proc runServer(socketPath: string) =
  # Descriptor, tabs, shortcut/reference, application/launcher; no content grant.
  let owner = openSession(socketPath, 125)
  defer:
    owner.close()
  var model = ShellModel(connectionEpoch: owner.epoch)
  var reference = ReferenceModel(skipAtStartup: skipHelpAtStartup())
  var launcher: LauncherModel
  var tabs: ShellTabModel
  var candidateGeneration = 0'u64
  var showNext = true
  let reservation = barReservation()
  stdout.writeLine(
    "narthex schema=2 status=ready connection_epoch=" & $owner.epoch &
      " wire=9p revision=8"
  )
  while true:
    var record = owner.nextRecord()
    case record.header.kind
    of 5, 6, 48, 50:
      if candidateGeneration == high(uint64):
        fail("candidate generation exhausted")
      inc candidateGeneration
      var proposal: ShellFileCandidate
      case record.header.kind
      of 5:
        model.reconcile(record.snapshot())
        proposal = model
          .candidate(candidateGeneration, showNext, reservation)
          .fileCandidate(record.value.descriptors.transaction)
      of 6:
        let snapshot = record.tabSnapshot()
        if snapshot.connectionEpoch != owner.epoch:
          fail("stale tab epoch")
        proposal =
          tabs.proposeTabs(snapshot, candidateGeneration, record.value.tabs.transaction)
      of 48:
        proposal = reference.proposeReference(
          record.referenceRequest(),
          candidateGeneration,
          record.value.referenceRequest.transaction,
        )
      of 50:
        proposal = launcher.proposeLauncher(
          record.launcherRequest(),
          candidateGeneration,
          record.value.descriptorLauncherRequest.request.transaction,
        )
      else:
        discard
      owner.submit(proposal)
    of 3:
      let catalog = record.applicationCatalog()
      if catalog.epoch != owner.epoch:
        fail("stale application catalog")
      launcher.reconcileApplications(catalog)
    of 7:
      let catalog = record.shortcutCatalog()
      if catalog.epoch != owner.epoch:
        fail("stale shortcut epoch")
      reference.reconcile(catalog)
    of 46:
      let outcome = record.candidateOutcome()
      if outcome.candidateGeneration == tabs.pendingGeneration:
        tabs.rememberTabs(outcome)
      elif outcome.kind == ShellCandidateOutcomeKind.presented:
        model.rememberPresented(outcome)
        if not showNext:
          showNext = true
    of 47:
      let activation = record.descriptorActivation()
      var disposition: ShellActivationDisposition
      if activation.candidateGeneration == tabs.presentedGeneration:
        disposition = tabs.acceptTab(activation)
      else:
        disposition = model.accept(activation)
        if disposition == ShellActivationDisposition.consumed:
          showNext = false
      var ack = activationAck(
        owner.epoch, activation.activation,
        record.value.descriptorActivation.transaction, disposition,
      )
      owner.submit(ack)
    of 49:
      reference.rememberReference(record.value.referenceOutcome)
    of 51:
      launcher.rememberLauncher(record.value.descriptorLauncherOutcome)
    of 52:
      var ack = launcher.acknowledgeLauncher(record.value.descriptorLauncherActivation)
      owner.submit(ack)
    of 53:
      launcher.validateLaunchOutcome(record.value.descriptorLaunchOutcome)
    else:
      fail("unexpected descriptor file record: " & $record.header.kind)

proc run(arguments: seq[string]) =
  if existsEnv("SOPHIA_SHELL_SOCKET"):
    fail("narthex: retired SOPHIA_SHELL_SOCKET is refused")
  let socketPath = getEnv("SOPHIA_SHELL_9P_SOCKET")
  if not socketPath.isAbsolute():
    fail("narthex: SOPHIA_SHELL_9P_SOCKET must be an absolute path")
  if arguments notin [@["--proof"], @["--bar-proof"], @["--serve"]]:
    fail("narthex: expected --proof, --bar-proof, or --serve")
  if installTermination() != 0:
    fail("narthex: cannot install termination handlers")
  if arguments == @["--serve"]:
    socketPath.runServer()
  else:
    socketPath.runProof(arguments == @["--bar-proof"])

try:
  run(commandLineParams())
except ShellStoppedError:
  quit(0)
except ShellClosedError as error:
  if commandLineParams() == @["--serve"]:
    quit(0)
  stderr.writeLine("narthex: " & error.msg)
  quit(1)
except CatchableError as error:
  stderr.writeLine("narthex: " & error.msg)
  quit(1)
