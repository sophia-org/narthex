import std/[os, strutils, unittest]
import types/[shell_v1, shell_tabs]
import wire/[shell_v1, shell_tabs]

proc hexBytes(s: string): seq[byte] =
  for i in countup(0, s.high, 2):
    result.add(byte(parseHexInt(s[i .. i + 1])))

suite "persistent tab descriptors":
  test "independent decoder and candidate match Sophia's golden transfer":
    var frames: seq[ShellFrame]
    var expected: seq[byte]
    for line in readFile(
      getEnv("SOPHIA_STACK_ROOT") / "protocol/golden/sophia-shell-tabs.frames"
    )
        .splitLines():
      if line.len == 0:
        continue
      let row = line.split('|')
      if row[0] == "snapshot":
        frames.add(row[1].hexBytes().decodeShellFrame())
      else:
        expected = row[1].hexBytes()
    let snapshot = frames.decodeTabs()
    check snapshot.groups.len == 1
    check snapshot.groups[0].entries.len == 2
    check snapshot.groups[0].selected == 1
    var model: ShellTabModel
    check model.proposeTabs(snapshot, 7, 8).encodeShellFrame() == expected
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
    for i in 0 .. frames.high:
      var changed = frames
      changed.delete(i)
      expect ShellProtocolError:
        discard changed.decodeTabs()
    var changed = frames
    changed[1].payload[34] = 2
    expect ShellProtocolError:
      discard changed.decodeTabs()
