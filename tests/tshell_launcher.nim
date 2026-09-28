import std/unittest
import types/[shell_launcher, desktop_sdk]
import sdk/[desktop_sdk, values]
import policy/launcher
import support/file_records

suite "application launcher":
  test "native candidate and activation acknowledgement require presentation":
    var rows: seq[byte]
    var record = applications(rows)
    var requestRecord = launcherRequestRecord()
    var model: LauncherModel
    model.reconcileApplications(record.applicationCatalog())
    var candidate = model.proposeLauncher(requestRecord.launcherRequest(), 9, 1)
    candidate.record.header = SfHeader(kind: 277, epoch: 5, submission: 1)
    discard candidate.record.encoded()
    check candidate.record.value.descriptorLauncherCandidate.selected == 1
    check candidate.record.value.descriptorLauncherCandidate.entryCount == 3
    let activation = launcherActivationRecord()
    check model.acknowledgeLauncher(activation).record.value.descriptorLauncherActivationAck.consumed ==
      0
    model.validateLaunchOutcome(SfDescriptorLaunchOutcome(grant: activation, status: 2))
    model.rememberLauncher(launcherOutcome(1))
    model.rememberLauncher(launcherOutcome(2))
    var ack = model.acknowledgeLauncher(activation)
    check ack.record.value.descriptorLauncherActivationAck.consumed == 1
    ack.record.header = SfHeader(kind: 278, epoch: 5, submission: 2)
    discard ack.record.encoded()
    model.validateLaunchOutcome(SfDescriptorLaunchOutcome(grant: activation, status: 1))
    check model.acknowledgeLauncher(activation).record.value.descriptorLauncherActivationAck.consumed ==
      0

  test "query matching and navigation belong to shell":
    var rows: seq[byte]
    var record = applications(rows)
    var requestRecord = launcherRequestRecord()
    var request = requestRecord.launcherRequest()
    request.query = "application 3"
    var model: LauncherModel
    model.reconcileApplications(record.applicationCatalog())
    let candidate = model.proposeLauncher(request, 9, 1)
    check candidate.record.value.descriptorLauncherCandidate.selected == 3
    check candidate.record.value.descriptorLauncherCandidate.entryCount == 1

  test "wrong tuple, duplicate slots and unsafe text are rejected":
    var rows: seq[byte]
    var record = applications(rows)
    copyMem(addr rows[656], addr rows[0], 656)
    expect ValueError:
      discard record.applicationCatalog()
    record = applications(rows)
    var model: LauncherModel
    model.reconcileApplications(record.applicationCatalog())
    var requestRecord = launcherRequestRecord()
    discard model.proposeLauncher(requestRecord.launcherRequest(), 9, 1)
    var wrong = launcherOutcome(2)
    wrong.requestGeneration += 1
    expect ValueError:
      model.rememberLauncher(wrong)
    expect ValueError:
      model.rememberLauncher(launcherOutcome(2))
    var bytes = requestRecord.encoded()
    bytes.add(0)
    var decoded: SfRecord
    check sfDecode(addr bytes[0], bytes.len.csize_t, addr decoded) != 0
    requestRecord.value.descriptorLauncherRequest.query = "bad\nquery".borrowedText()
    expect ValueError:
      discard requestRecord.launcherRequest()
