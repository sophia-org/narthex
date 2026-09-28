import std/[os, posix, strutils, unittest]
import ../src/types/desktop_sdk
import ../src/sdk/desktop_sdk

{.passC: "-I" & currentSourcePath().parentDir / "support".}
proc checkCandidate(
  value: ptr SfRecord
): cint {.importc: "narthex_check_candidate", header: "desktop_sdk_abi.h".}

proc fillActivation(
  value: ptr SfRecord
) {.importc: "narthex_fill_activation", header: "desktop_sdk_abi.h".}

proc checkReference(
  value: ptr SfRecord
): cint {.importc: "narthex_check_reference", header: "desktop_sdk_abi.h".}

var msgDontwait {.importc: "MSG_DONTWAIT", header: "<sys/socket.h>".}: cint

suite "standalone desktop SDK bindings":
  test "Nim candidate fields reach the C reader and native encoder":
    var value: SfRecord
    value.header = SfHeader(kind: 273, epoch: 11, submission: 12)
    value.value.descriptorCandidate = SfDescriptorCandidate(
      transaction: 13,
      connectionEpoch: 11,
      snapshotGeneration: 14,
      candidateGeneration: 15,
      outputId: 16,
      visible: 1,
      reservationEdge: 2,
      reservationThickness: 24,
      selectedSlot: 7,
      entryCount: 1,
    )
    value.value.descriptorCandidate.entries[0] =
      SfDescriptorCandidateEntry(slot: 7, generation: 17)
    check checkCandidate(addr value) == 1
    var bytes: array[512, byte]
    var size: csize_t
    check sfEncode(addr bytes[0], bytes.len.csize_t, addr value, addr size) == 0
    check size == sfRecordBytes(addr value)
    var decoded: SfRecord
    check sfDecode(addr bytes[0], size, addr decoded) == 0
    check checkCandidate(addr decoded) == 1
    # A short record must not replace the caller's prior decoded value.
    check sfDecode(addr bytes[0], size - 1, addr decoded) != 0
    check checkCandidate(addr decoded) == 1

  test "C activation fields reach Nim without a private session layout":
    var value: SfRecord
    fillActivation(addr value)
    check value.header.kind == 47
    check value.header.epoch == 11
    check value.header.sequence == 12
    let action = value.value.descriptorActivation
    check action.transaction == 13
    check action.connectionEpoch == 11
    check action.candidateGeneration == 14
    check action.presentationEpoch == 15
    check action.activation == 16
    check action.actionToken == 17
    check action.actionIssuerEpoch == 18
    check action.actionIssuerRevocationEpoch == 19
    check action.actionRecipientEpoch == 20
    check action.actionTargetSlot == 21
    check action.actionTargetGeneration == 22

  test "reference style and borrowed row pointers have their C layout":
    var title = "title"
    var rows: array[204, byte]
    var value: SfRecord
    value.value.referenceCandidate = SfReferenceCandidate(
      transaction: 1,
      connectionEpoch: 2,
      catalogGeneration: 3,
      requestGeneration: 4,
      candidateGeneration: 5,
      outputId: 6,
      visible: 1,
      page: 2,
      entryCount: 1,
      rows: addr rows[0],
      rowsBytes: rows.len.csize_t,
      style: SfReferenceStyle(
        bodySize: 14,
        titleSize: 20,
        padding: 8,
        rowGap: 9,
        keyGap: 10,
        columnGap: 11,
        border: 1,
        margin: 12,
        columns: 2,
        title: SfText(data: cast[ptr uint8](addr title[0]), size: 5),
      ),
    )
    value.value.referenceCandidate.style.colors[5] = 0x123456
    check checkReference(addr value) == 1

  test "descriptor rows borrow exactly the caller's encoded bytes":
    var label = "browser"
    var row = SfDescriptorEntry(
      slot: 3,
      generation: 4,
      trustLevel: 1,
      labelPresent: 1,
      actionToken: 5,
      actionIssuerEpoch: 6,
      actionIssuerRevocationEpoch: 7,
      actionRecipientEpoch: 8,
      actionTargetSlot: 3,
      actionTargetGeneration: 4,
      label: SfText(data: cast[ptr uint8](addr label[0]), size: label.len.uint16),
    )
    var bytes: array[196, byte]
    check sfDescriptorEntryEncode(addr bytes[0], addr row) == 0
    var decoded: SfDescriptorEntry
    check sfDescriptorEntryDecode(addr bytes[0], addr decoded) == 0
    check decoded.slot == 3
    check decoded.generation == 4
    check decoded.label.size == 7
    let start = cast[uint](addr bytes[0])
    let text = cast[uint](decoded.label.data)
    check text >= start
    check text + decoded.label.size.uint <= start + bytes.len.uint
    check cast[ptr UncheckedArray[byte]](decoded.label.data)[0] == byte('b')
    var snapshot =
      SfDescriptors(descriptorCount: 1, rows: addr bytes[0], rowsBytes: 196)
    check sfDescriptorEntryAt(addr snapshot, 0, addr decoded) == 0
    check sfDescriptorEntryAt(addr snapshot, 1, addr decoded) != 0

  test "opaque session uses caller storage and starts 9P2000.L":
    var sockets: array[2, cint]
    require socketpair(AF_UNIX, SOCK_STREAM, 0, sockets) == 0
    defer:
      discard posix.close(sockets[0])
      discard posix.close(sockets[1])
    let session = cast[ptr Ss](alloc0(ssStateBytes().int))
    var config = SsConfig(
      offer:
        SfNegotiate(minimumRevision: 8, maximumRevision: 8, requiredCapabilities: 5),
      profile: SfProfile.descriptor,
      msize: 65536,
      queueSlots: 8,
      queueBytes: 65536,
    )
    let capacity = ssStorageBytes(config.msize, config.queueBytes)
    require capacity > 0
    let storage = alloc0(capacity.int)
    let transaction = alloc0(65536)
    defer:
      ssClose(session)
      dealloc(session)
      dealloc(storage)
      dealloc(transaction)
    check ssOpenFdStaging(
      session, sockets[0], addr config, storage, capacity, transaction, 65536
    ) == 0
    check ssState(session) == SsState.negotiating
    check ssEpoch(session) == 0
    var welcome: SfNegotiated
    check ssWelcome(session, addr welcome) != 0
    check ssPollFd(session) == sockets[0]
    var candidate: SfRecord
    var ticket = 123'u64
    check ssSubmit(session, addr candidate, 1, addr ticket) != 0
    check ticket == 123
    var copiedEvent: SfRecord
    copiedEvent.header.kind = 777
    check ssEvent(session, addr copiedEvent) != 0
    check copiedEvent.header.kind == 777
    check ssDispatch(session, 0, 65536, 10) == 0
    var data: array[128, char]
    let count = recv(SocketHandle(sockets[1]), addr data[0], data.len, msgDontwait)
    require count > 0
    var version = newString(count)
    copyMem(addr version[0], addr data[0], count)
    check count == 21
    check byte(data[4]) == 100 # Tversion, before any application transaction.
    check version.endsWith("9P2000.L")
    ssClose(session)
    check ssState(session) == SsState.closed
    check fcntl(sockets[0], F_GETFD) >= 0 # SDK close leaves fd ownership here.
