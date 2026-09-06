import std/[os, strutils, tables, unittest]
import types/[shell_v1, shell_launcher]
import wire/[shell_v1, shell_launcher]
proc hexBytes(s: string): seq[byte] =
  for i in countup(0, s.high, 2):
    result.add(byte(parseHexInt(s[i .. i + 1])))

var catalogFrames: seq[ShellFrame]
var records = initTable[string, ShellFrame]()
for line in readFile(
  getEnv("SOPHIA_STACK_ROOT") / "protocol/golden/sophia-shell-launcher.frames"
)
    .splitLines():
  if line.len == 0:
    continue
  let row = line.split('|')
  let frame = row[1].hexBytes().decodeShellFrame()
  if row[0] == "catalog":
    catalogFrames.add(frame)
  else:
    records[row[0]] = frame
suite "application launcher":
  test "independent wire matches corpus and launch requires presentation":
    var model: LauncherModel
    model.reconcileApplications(catalogFrames.decodeApplications())
    check model
      .proposeLauncher(records["request"].decodeLauncherRequest(), 9, 1)
      .encodeShellFrame() == records["candidate"].encodeShellFrame()
    check model.acknowledgeLauncher(records["activation"]).payload.u16At(50) == 0
    var rejected = records["started"]
    rejected.payload[50] = 2
    model.validateLaunchOutcome(rejected)
    model.rememberLauncher(records["prepared"])
    model.rememberLauncher(records["presented"])
    check model.acknowledgeLauncher(records["activation"]).encodeShellFrame() ==
      records["ack"].encodeShellFrame()
    model.validateLaunchOutcome(records["started"])
    check model.acknowledgeLauncher(records["activation"]).payload.u16At(50) == 0
  test "query matching and navigation belong to shell":
    var model: LauncherModel
    model.reconcileApplications(catalogFrames.decodeApplications())
    var request = records["request"].decodeLauncherRequest()
    request.query = "application 3"
    let candidate = model.proposeLauncher(request, 9, 1)
    check candidate.payload.u16At(42) == 3
    check candidate.payload.u16At(44) == 1
  test "wrong tuple, duplicate slots and unsafe text are rejected":
    var frames = catalogFrames
    frames[2].payload[16] = 1
    expect ShellProtocolError:
      discard frames.decodeApplications()
    var model: LauncherModel
    model.reconcileApplications(catalogFrames.decodeApplications())
    discard model.proposeLauncher(records["request"].decodeLauncherRequest(), 9, 1)
    var wrong = records["presented"]
    wrong.payload[16] = 10
    expect ShellProtocolError:
      model.rememberLauncher(wrong)
    expect ShellProtocolError:
      model.rememberLauncher(records["presented"])
    var request = records["request"]
    request.payload.add(0)
    expect ShellProtocolError:
      discard request.decodeLauncherRequest()
