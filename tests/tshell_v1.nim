import std/[options, unittest]
import types/[shell_v1, desktop_sdk]
import sdk/[desktop_sdk, values]
import policy/switcher
import support/file_records

suite "descriptor file conversion and switcher policy":
  test "native record round trips and rejects truncated or trailing data":
    var rows: seq[byte]
    var record = descriptors(rows)
    var bytes = record.encoded()
    var decoded: SfRecord
    check sfDecode(addr bytes[0], bytes.len.csize_t, addr decoded) == 0
    check decoded.encoded() == bytes
    for length in 0 ..< bytes.len:
      check sfDecode(addr bytes[0], length.csize_t, addr decoded) != 0
    bytes.add(0)
    check sfDecode(addr bytes[0], bytes.len.csize_t, addr decoded) != 0
    record.value.descriptors.connectionEpoch += 1
    expect ValueError:
      discard record.snapshot()

  test "unlabeled descriptor remains absent and unredacted":
    var rows: seq[byte]
    var record = descriptors(rows, false)
    let snapshot = record.snapshot()
    check snapshot.descriptors.len == 1
    check snapshot.descriptors[0].label.isNone
    check not snapshot.descriptors[0].labelRedacted

  test "presented activation is exact and consumed at most once":
    var rows: seq[byte]
    var record = descriptors(rows)
    let snapshot = record.snapshot()
    var model = ShellModel(connectionEpoch: snapshot.connectionEpoch)
    model.reconcile(snapshot)
    let candidate = model.candidate(1, true)
    check candidate.visible
    check candidate.selected.get() == 2
    check candidate.entries.len == 1
    model.rememberPresented(
      ShellCandidateOutcome(
        connectionEpoch: 5,
        candidateGeneration: 1,
        presentationEpoch: 10,
        kind: ShellCandidateOutcomeKind.presented,
      )
    )
    let activation = ShellActivation(
      connectionEpoch: 5,
      candidateGeneration: 1,
      presentationEpoch: 10,
      activation: 1,
      action: snapshot.descriptors[0].action,
    )
    check model.accept(activation) == ShellActivationDisposition.consumed
    check model.accept(activation) == ShellActivationDisposition.rejectedStale
    var stale = activation
    stale.activation += 1
    stale.presentationEpoch += 1
    check model.accept(stale) == ShellActivationDisposition.rejectedStale

  test "reserving candidate retains its native transaction and reservation":
    var rows: seq[byte]
    var record = descriptors(rows)
    var model: ShellModel
    model.reconcile(record.snapshot())
    let reserving = model.candidate(
      2,
      true,
      some(ShellReservation(edge: ShellReservationEdge.bottom, thicknessPx: 28)),
    )
    let transaction = 0x0102030405060708'u64
    var candidate = reserving.fileCandidate(transaction)
    candidate.record.header = SfHeader(kind: 273, epoch: 5, submission: 1)
    var bytes = candidate.record.encoded()
    var decoded: SfRecord
    check sfDecode(addr bytes[0], bytes.len.csize_t, addr decoded) == 0
    check decoded.value.descriptorCandidate.transaction == transaction
    check decoded.value.descriptorCandidate.reservationEdge == 2
    check decoded.value.descriptorCandidate.reservationThickness == 28
    check decoded.value.descriptorCandidate.entries[0].slot == 2

  test "complete snapshot withdrawal clears visible shell state":
    var rows: seq[byte]
    var record = descriptors(rows)
    let snapshot = record.snapshot()
    var model: ShellModel
    model.reconcile(snapshot)
    var empty = snapshot
    empty.generation += 1
    empty.descriptors.setLen(0)
    model.reconcile(empty)
    let withdrawal = model.candidate(2, false)
    check not withdrawal.visible
    check withdrawal.selected.isNone
    check withdrawal.entries.len == 0
