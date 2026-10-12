import std/[os, unittest]
import ../src/sdk/file_session

suite "launch authentication descriptor admission":
  test "only a bounded decimal non-stdio descriptor is accepted":
    check launchAuthenticationFd("3") == 3
    check launchAuthenticationFd($high(cint)) == high(cint)
    for invalid in [
      "", "0", "1", "2", "-1", "+3", " 3", "3 ", "3x", "2147483648",
      "999999999999999999999999999999",
    ]:
      expect ValueError:
        discard launchAuthenticationFd(invalid)

  test "a present malformed descriptor fails before connecting the role":
    let present = existsEnv("SOPHIA_LAUNCH_AUTH_FD")
    let previous = getEnv("SOPHIA_LAUNCH_AUTH_FD")
    try:
      for invalid in ["", "-1", "2", "not-an-fd"]:
        putEnv("SOPHIA_LAUNCH_AUTH_FD", invalid)
        expect ValueError:
          discard openSession("/nonexistent/narthex-role", 1)
    finally:
      if present:
        putEnv("SOPHIA_LAUNCH_AUTH_FD", previous)
      else:
        delEnv("SOPHIA_LAUNCH_AUTH_FD")
