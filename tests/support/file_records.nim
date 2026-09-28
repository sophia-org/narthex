## SDK-encoded native fixtures for Narthex conversion and policy tests.
## Independent codec vectors belong to the pinned SDK; no Sophia tree is read.
import ../../src/types/desktop_sdk
import ../../src/sdk/[desktop_sdk, values]

proc entry*(slot: uint16, labelled = true): SfDescriptorEntry =
  result = SfDescriptorEntry(
    slot: slot,
    generation: 4,
    actionToken: slot.uint64 + 10,
    actionIssuerEpoch: 6,
    actionIssuerRevocationEpoch: 7,
    actionRecipientEpoch: 5,
    actionTargetSlot: slot,
    actionTargetGeneration: 4,
    labelPresent: uint16(labelled),
  )
  if labelled:
    result.label = "Window".borrowedText()

proc descriptors*(rows: var seq[byte], labelled = true): SfRecord =
  rows = newSeq[byte](196)
  var e = entry(2, labelled)
  sdkCheck(sfDescriptorEntryEncode(addr rows[0], addr e))
  result.header = SfHeader(kind: 5, epoch: 5)
  result.value.descriptors = SfDescriptors(
    transaction: 1,
    connectionEpoch: 5,
    snapshotGeneration: 7,
    outputId: 1,
    outputGeneration: 1,
    brokerEpoch: 6,
    brokerRevocationEpoch: 7,
    descriptorCount: 1,
    rows: addr rows[0],
    rowsBytes: rows.len.csize_t,
  )

proc tabs*(rows: var seq[byte]): SfRecord =
  rows = newSeq[byte](24 + 2 * 196)
  var group =
    SfTabGroup(groupSlot: 1, outputId: 1, selectedSlot: 1, focused: 1, entryCount: 2)
  sdkCheck(sfTabGroupEncode(addr rows[0], addr group))
  for i in 0 .. 1:
    var e = entry((i + 1).uint16)
    sdkCheck(sfDescriptorEntryEncode(addr rows[24 + i * 196], addr e))
  result.header = SfHeader(kind: 6, epoch: 5)
  result.value.tabs = SfTabs(
    transaction: 1,
    connectionEpoch: 5,
    generation: 7,
    groupCount: 1,
    entryCount: 2,
    rows: addr rows[0],
    rowsBytes: rows.len.csize_t,
  )

proc shortcuts*(rows: var seq[byte]): SfRecord =
  rows = newSeq[byte](2 * 408)
  for i in 0 .. 1:
    var e = SfShortcutEntry(
      slot: (i + 1).uint16,
      chord: "Super+h".borrowedText(),
      action: "policy:focus-left".borrowedText(),
    )
    sdkCheck(sfShortcutEntryEncode(addr rows[i * 408], addr e))
  result.header = SfHeader(kind: 7, epoch: 5)
  result.value.shortcuts = SfShortcuts(
    transaction: 1,
    connectionEpoch: 5,
    generation: 7,
    entryCount: 2,
    rows: addr rows[0],
    rowsBytes: rows.len.csize_t,
  )

proc applications*(rows: var seq[byte]): SfRecord =
  rows = newSeq[byte](3 * 656)
  for i in 0 .. 2:
    let label = "Application " & $(i + 1)
    var e = SfCatalogEntry(
      slot: (i + 1).uint16,
      available: 1,
      label: label.borrowedText(),
      keywords: "app".borrowedText(),
    )
    sdkCheck(sfCatalogEntryEncode(addr rows[i * 656], addr e))
  result.header = SfHeader(kind: 3, epoch: 5)
  result.value.catalog = SfCatalog(
    transaction: 1,
    connectionEpoch: 5,
    generation: 7,
    entryCount: 3,
    rows: addr rows[0],
    rowsBytes: rows.len.csize_t,
  )

proc encoded*(record: var SfRecord): seq[byte] =
  let size = sfRecordBytes(addr record)
  if size == 0:
    raise newException(ValueError, "invalid fixture or candidate")
  result = newSeq[byte](size.int)
  var written: csize_t
  sdkCheck(sfEncode(addr result[0], size, addr record, addr written))
  doAssert written == size

proc referenceRequestRecord*(): SfRecord =
  result.header = SfHeader(kind: 48, epoch: 5, sequence: 1)
  result.value.referenceRequest = SfReferenceRequest(
    transaction: 1,
    connectionEpoch: 5,
    catalogGeneration: 7,
    requestGeneration: 8,
    outputId: 1,
    outputGeneration: 1,
    operation: 0,
  )

proc referenceOutcome*(kind: uint16): SfReferenceOutcome =
  SfReferenceOutcome(
    transaction: 1,
    connectionEpoch: 5,
    catalogGeneration: 7,
    requestGeneration: 8,
    candidateGeneration: 9,
    kind: kind,
    presentationEpoch: (if kind == 2: 10'u64 else: 0'u64),
    pages: 5,
  )

proc launcherRequestRecord*(): SfRecord =
  result.header = SfHeader(kind: 50, epoch: 5, sequence: 1)
  result.value.descriptorLauncherRequest.request = SfReferenceRequest(
    transaction: 1,
    connectionEpoch: 5,
    catalogGeneration: 7,
    requestGeneration: 8,
    outputId: 1,
    outputGeneration: 1,
    operation: 1,
  )

proc launcherOutcome*(kind: uint16): SfDescriptorLauncherOutcome =
  SfDescriptorLauncherOutcome(
    transaction: 1,
    connectionEpoch: 5,
    requestGeneration: 8,
    candidateGeneration: 9,
    kind: kind,
    presentationEpoch: (if kind == 2: 10'u64 else: 0'u64),
  )

proc launcherActivationRecord*(): SfDescriptorLauncherActivation =
  SfDescriptorLauncherActivation(
    transaction: 3,
    connectionEpoch: 5,
    catalogGeneration: 7,
    requestGeneration: 8,
    candidateGeneration: 9,
    presentationEpoch: 10,
    activation: 11,
    slot: 1,
  )
