import std/unittest
import types/[shell_v1, shell_tabs, desktop_sdk]
import sdk/[desktop_sdk, values]
import policy/tabs
import support/file_records

suite "persistent tab descriptors over files":
  test "SDK rows become owned groups and settlement requires exact presentation":
    var rows: seq[byte]
    var record = tabs(rows)
    let snapshot = record.tabSnapshot()
    check snapshot.groups.len == 1
    check snapshot.groups[0].entries.len == 2
    check snapshot.groups[0].selected == 1
    var model: ShellTabModel
    var candidate = model.proposeTabs(snapshot, 7, 8)
    candidate.bindRows()
    candidate.record.header = SfHeader(kind: 275, epoch: 5, submission: 1)
    discard candidate.record.encoded()
    var slot: uint64
    check sfTabOrderAt(addr candidate.record.value.tabsCandidate, 0, addr slot) == 0
    check slot == 1
    model.rememberTabs(
      ShellCandidateOutcome(
        connectionEpoch: 5,
        candidateGeneration: 7,
        kind: ShellCandidateOutcomeKind.prepared,
      )
    )
    model.rememberTabs(
      ShellCandidateOutcome(
        connectionEpoch: 5,
        candidateGeneration: 7,
        presentationEpoch: 10,
        kind: ShellCandidateOutcomeKind.presented,
      )
    )
    var activation = ShellActivation(
      connectionEpoch: 5,
      candidateGeneration: 7,
      presentationEpoch: 9,
      activation: 1,
      action: snapshot.groups[0].entries[1].action,
    )
    check model.acceptTab(activation) == ShellActivationDisposition.rejectedStale
    activation.presentationEpoch = 10
    check model.acceptTab(activation) == ShellActivationDisposition.consumed
    check model.acceptTab(activation) == ShellActivationDisposition.rejectedStale

  test "incomplete rows and invalid focused flags fail before policy":
    var rows: seq[byte]
    var record = tabs(rows)
    for length in 0 ..< rows.len:
      record.value.tabs.rowsBytes = length.csize_t
      expect ValueError:
        discard record.tabSnapshot()
    record.value.tabs.rowsBytes = rows.len.csize_t
    var group =
      SfTabGroup(groupSlot: 1, outputId: 1, selectedSlot: 1, focused: 2, entryCount: 2)
    check sfTabGroupEncode(addr rows[0], addr group) != 0
    record.value.tabs.entryCount = 1
    expect ValueError:
      discard record.tabSnapshot()
