## Copy validated SDK views into Narthex's owned policy values. No wire offsets.
import std/options
import
  ../types/
    [desktop_sdk, shell_files, shell_v1, shell_tabs, shell_reference, shell_launcher]
import ./desktop_sdk

proc sdkCheck*(status: cint) =
  if status != 0:
    raise newException(ValueError, "desktop SDK refused value: " & $status)

proc borrowedText*(text: string): SfText =
  if text.len > high(uint16).int:
    raise newException(ValueError, "text exceeds SDK bound")
  result.size = text.len.uint16
  if text.len != 0:
    result.data = cast[ptr uint8](unsafeAddr text[0])

proc ownedText(value: SfText): string =
  if value.size != 0:
    if value.data == nil:
      raise newException(ValueError, "absent SDK text")
    result = newString(value.size.int)
    copyMem(addr result[0], value.data, value.size.int)

proc requireRecord(value: var SfRecord, kind: uint16) =
  if value.header.kind != kind or sfRecordBytes(addr value) == 0:
    raise newException(ValueError, "invalid descriptor file record")

proc descriptor(value: SfDescriptorEntry): ShellDescriptor =
  ShellDescriptor(
    slot: value.slot,
    generation: value.generation,
    label:
      (if value.labelPresent == 1: some(value.label.ownedText())
      else: none(string)),
    labelRedacted: value.labelRedacted == 1,
    trust: uint8(value.trustLevel),
    attention: uint8(value.attention),
    action: ShellActionRef(
      token: value.actionToken,
      issuerEpoch: value.actionIssuerEpoch,
      issuerRevocationEpoch: value.actionIssuerRevocationEpoch,
      recipientEpoch: value.actionRecipientEpoch,
      targetSlot: value.actionTargetSlot,
      targetGeneration: value.actionTargetGeneration,
    ),
  )

proc snapshot*(record: var SfRecord): ShellSnapshot =
  record.requireRecord(5)
  var value = record.value.descriptors
  result = ShellSnapshot(
    connectionEpoch: value.connectionEpoch,
    generation: value.snapshotGeneration,
    output: value.outputId,
    outputGeneration: value.outputGeneration,
    brokerEpoch: value.brokerEpoch,
    brokerRevocationEpoch: value.brokerRevocationEpoch,
  )
  for i in 0 ..< value.descriptorCount.int:
    var entry: SfDescriptorEntry
    sdkCheck(sfDescriptorEntryAt(addr value, i.csize_t, addr entry))
    result.descriptors.add(entry.descriptor())

proc tabSnapshot*(record: var SfRecord): ShellTabSnapshot =
  record.requireRecord(6)
  var value = record.value.tabs
  result.connectionEpoch = value.connectionEpoch
  result.generation = value.generation
  var offset = 0
  for i in 0 ..< value.groupCount.int:
    var row: SfTabGroup
    sdkCheck(sfTabGroupAt(addr value, i.csize_t, addr row))
    var group = ShellTabGroup(
      slot: row.groupSlot,
      output: row.outputId,
      selected: row.selectedSlot,
      focused: row.focused == 1,
    )
    for j in 0 ..< row.entryCount.int:
      var entry: SfDescriptorEntry
      sdkCheck(sfTabEntryAt(addr value, (offset + j).csize_t, addr entry))
      group.entries.add(entry.descriptor())
    offset += row.entryCount.int
    result.groups.add(group)

proc shortcutCatalog*(record: var SfRecord): ShortcutCatalog =
  record.requireRecord(7)
  var value = record.value.shortcuts
  result.epoch = value.connectionEpoch
  result.generation = value.generation
  for i in 0 ..< value.entryCount.int:
    var row: SfShortcutEntry
    sdkCheck(sfShortcutEntryAt(addr value, i.csize_t, addr row))
    result.rows.add(
      ShortcutRow(
        slot: row.slot,
        chord: row.chord.ownedText(),
        action: row.action.ownedText(),
        label: row.label.ownedText(),
        group: row.group.ownedText(),
      )
    )

proc applicationCatalog*(record: var SfRecord): ApplicationCatalog =
  record.requireRecord(3)
  var value = record.value.catalog
  result.epoch = value.connectionEpoch
  result.generation = value.generation
  for i in 0 ..< value.entryCount.int:
    var row: SfCatalogEntry
    sdkCheck(sfCatalogEntryAt(addr value, i.csize_t, addr row))
    result.entries.add(
      ApplicationDescriptor(
        slot: row.slot,
        available: row.available == 1,
        label: row.label.ownedText(),
        keywords: row.keywords.ownedText(),
      )
    )

proc candidateOutcome*(record: var SfRecord): ShellCandidateOutcome =
  record.requireRecord(46)
  let value = record.value.descriptorOutcome
  ShellCandidateOutcome(
    connectionEpoch: value.connectionEpoch,
    candidateGeneration: value.candidateGeneration,
    presentationEpoch: value.presentationEpoch,
    kind: ShellCandidateOutcomeKind(value.kind),
  )

proc descriptorActivation*(record: var SfRecord): ShellActivation =
  record.requireRecord(47)
  let value = record.value.descriptorActivation
  ShellActivation(
    connectionEpoch: value.connectionEpoch,
    candidateGeneration: value.candidateGeneration,
    presentationEpoch: value.presentationEpoch,
    activation: value.activation,
    action: ShellActionRef(
      token: value.actionToken,
      issuerEpoch: value.actionIssuerEpoch,
      issuerRevocationEpoch: value.actionIssuerRevocationEpoch,
      recipientEpoch: value.actionRecipientEpoch,
      targetSlot: value.actionTargetSlot,
      targetGeneration: value.actionTargetGeneration,
    ),
  )

proc referenceRequest*(record: var SfRecord): ReferenceRequest =
  record.requireRecord(48)
  let value = record.value.referenceRequest
  ReferenceRequest(
    epoch: value.connectionEpoch,
    catalog: value.catalogGeneration,
    generation: value.requestGeneration,
    output: value.outputId,
    outputGeneration: value.outputGeneration,
    presentation: value.presentationEpoch,
    operation: ReferenceOperation(value.operation),
  )

proc launcherRequest*(record: var SfRecord): LauncherRequest =
  record.requireRecord(50)
  let value = record.value.descriptorLauncherRequest
  LauncherRequest(
    epoch: value.request.connectionEpoch,
    catalog: value.request.catalogGeneration,
    request: value.request.requestGeneration,
    output: value.request.outputId,
    outputGeneration: value.request.outputGeneration,
    presentation: value.request.presentationEpoch,
    operation: value.request.operation,
    query: value.query.ownedText(),
  )

proc launcherActivation*(value: SfDescriptorLauncherActivation): LauncherActivation =
  LauncherActivation(
    epoch: value.connectionEpoch,
    catalog: value.catalogGeneration,
    request: value.requestGeneration,
    candidate: value.candidateGeneration,
    presentation: value.presentationEpoch,
    activation: value.activation,
    slot: value.slot,
  )

proc fileCandidate*(
    candidate: ShellCandidate, transaction: uint64
): ShellFileCandidate =
  if candidate.entries.len > shellMaxDescriptors:
    raise newException(ValueError, "excessive descriptor candidate")
  result.record.header.kind = 273
  result.record.value.descriptorCandidate = SfDescriptorCandidate(
    transaction: transaction,
    connectionEpoch: candidate.connectionEpoch,
    snapshotGeneration: candidate.snapshotGeneration,
    candidateGeneration: candidate.generation,
    outputId: candidate.output,
    visible: uint16(candidate.visible),
    selectedSlot: candidate.selected.get(0),
    entryCount: candidate.entries.len.uint16,
  )
  if candidate.reservation.isSome:
    result.record.value.descriptorCandidate.reservationEdge =
      uint16(candidate.reservation.get().edge)
    result.record.value.descriptorCandidate.reservationThickness =
      candidate.reservation.get().thicknessPx
  for i, entry in candidate.entries:
    result.record.value.descriptorCandidate.entries[i] =
      SfDescriptorCandidateEntry(slot: entry.slot, generation: entry.generation)

proc activationAck*(
    epoch, activation, transaction: uint64, disposition: ShellActivationDisposition
): ShellFileCandidate =
  result.record.header.kind = 274
  result.record.value.descriptorActivationAck = SfDescriptorActivationAck(
    transaction: transaction,
    connectionEpoch: epoch,
    activation: activation,
    disposition: uint16(disposition),
  )

proc bindRows*(candidate: var ShellFileCandidate) =
  let data =
    if candidate.rows.len == 0:
      nil
    else:
      addr candidate.rows[0]
  case candidate.record.header.kind
  of 275:
    candidate.record.value.tabsCandidate.rows = data
    candidate.record.value.tabsCandidate.rowsBytes = candidate.rows.len.csize_t
  of 276:
    candidate.record.value.referenceCandidate.rows = data
    candidate.record.value.referenceCandidate.rowsBytes = candidate.rows.len.csize_t
  else:
    discard
