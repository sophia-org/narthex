import std/[os, strutils, unittest]
import types/[shell_v1, shell_reference]
import wire/[shell_v1, shell_reference]
import config

proc hexBytes(s: string): seq[byte] =
  for i in countup(0, s.high, 2):
    result.add(byte(parseHexInt(s[i .. i + 1])))

var catalogFrames: seq[ShellFrame]
var requestFrame, prepared, presented: ShellFrame
var expected: seq[byte]
for line in readFile(
  getEnv("SOPHIA_STACK_ROOT") / "protocol/golden/sophia-shell-reference.frames"
)
    .splitLines():
  if line.len == 0:
    continue
  let row = line.split('|')
  let bytes = row[1].hexBytes()
  case row[0]
  of "catalog":
    catalogFrames.add(bytes.decodeShellFrame())
  of "request":
    requestFrame = bytes.decodeShellFrame()
  of "candidate":
    expected = bytes
  of "prepared":
    prepared = bytes.decodeShellFrame()
  of "presented":
    presented = bytes.decodeShellFrame()
  else:
    discard

suite "read-only reference sheets":
  test "independent wire matches the shared corpus and settles only on presentation":
    var model: ReferenceModel
    model.reconcile(catalogFrames.decodeShortcuts())
    let request = requestFrame.decodeReferenceRequest()
    check model.proposeReference(request, 9, 1).encodeShellFrame() == expected
    check not model.visible
    model.rememberReference(prepared)
    check not model.visible
    model.rememberReference(presented)
    check model.visible
    check model.pages == 5
    var next = request
    next.generation = 9
    next.presentation = 10
    next.operation = ReferenceOperation.next
    check model.proposeReference(next, 10, 2).payload.u16At(42) == 1
    check model.page == 0
    expect ShellProtocolError:
      discard model.proposeReference(next, 11, 3)
  test "mixed epochs, missing end, invalid UTF-8, and duplicate slots fail closed":
    var bad = catalogFrames
    bad[1].payload[0] = 99
    expect ShellProtocolError:
      discard bad.decodeShortcuts()
    expect ShellProtocolError:
      discard catalogFrames[0 ..< catalogFrames.high].decodeShortcuts()
    bad = catalogFrames
    bad[1].payload[22] = 0xff
    expect ShellProtocolError:
      discard bad.decodeShortcuts()
    bad = catalogFrames
    bad[2] = bad[1]
    expect ShellProtocolError:
      discard bad.decodeShortcuts()
  test "startup skip is shell-private and explicit toggle still opens":
    var model = ReferenceModel(skipAtStartup: true)
    model.reconcile(catalogFrames.decodeShortcuts())
    var request = requestFrame.decodeReferenceRequest()
    check model.proposeReference(request, 9, 1).payload.u16At(40) == 0
    model.rememberReference(prepared)
    model.rememberReference(presented)
    request.generation += 1
    request.operation = ReferenceOperation.toggle
    check model.proposeReference(request, 10, 2).payload.u16At(40) == 1
  test "private KDL boolean controls startup":
    let path = getTempDir() / ("narthex-help-config-" & $getCurrentProcessId())
    defer:
      removeFile(path)
      delEnv("SOPHIA_SHELL_CONFIG")
    putEnv("SOPHIA_SHELL_CONFIG", path)
    writeFile(path, "hotkey-overlay { skip-at-startup #true; }\n")
    check skipHelpAtStartup()
    writeFile(path, "hotkey-overlay { skip-at-startup #false; }\n")
    check not skipHelpAtStartup()

suite "reference content policy":
  test "public authority prefixes do not hide the action purpose":
    var model: ReferenceModel
    model.reconcile(
      ShortcutCatalog(
        epoch: 5,
        generation: 7,
        rows: @[
          ShortcutRow(slot: 1, chord: "Super+h", action: "policy:focus-left"),
          ShortcutRow(slot: 2, chord: "Super+l", action: "policy:cycle-layout"),
          ShortcutRow(slot: 3, chord: "Super+Enter", action: "session:spawn-terminal"),
        ],
      )
    )
    let frame = model.proposeReference(requestFrame.decodeReferenceRequest(), 9, 1)
    let firstRow = 92 + int(frame.payload.u16At(90))
    check frame.payload.u16At(firstRow) == 3
