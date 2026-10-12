## One connected SDK session. No reconnect, protocol fallback or replay.
import std/[monotimes, net, os, posix]
import ../types/[desktop_sdk, file_session, shell_files]
import ./[desktop_sdk, values]

{.compile: currentSourcePath().parentDir / "termination.c".}
proc installTermination*(): cint {.
  importc: "narthex_install_termination", header: "termination.h"
.}

proc stopRequested*(): cint {.
  importc: "narthex_stop_requested", header: "termination.h"
.}

type
  ShellClosedError* = object of CatchableError
  ShellStoppedError* = object of CatchableError

proc nowMillis*(): uint64 =
  uint64(getMonoTime().ticks div 1_000_000)

proc close*(owner: FileSession) =
  if owner.session != nil:
    ssClose(owner.session)
    dealloc(owner.session)
    owner.session = nil
  for storage in [
    owner.storage,
    owner.transaction,
    owner.objects,
    owner.roleStorage,
    owner.relayStorage,
    cast[pointer](owner.role),
    cast[pointer](owner.relay),
  ]:
    if storage != nil:
      dealloc(storage)
  owner.storage = nil
  owner.transaction = nil
  owner.objects = nil
  owner.roleStorage = nil
  owner.relayStorage = nil
  owner.role = nil
  owner.relay = nil
  if owner.relayFd >= 3:
    discard posix.close(owner.relayFd)
    owner.relayFd = -1
  if owner.socket != nil:
    owner.socket.close()
    owner.socket = nil

proc checkTickets(owner: FileSession) =
  var remaining: seq[uint64]
  for ticket in owner.tickets:
    var outcome: SsOutcome
    var error: uint32
    sdkCheck(ssOutcome(owner.session, ticket, addr outcome, addr error))
    case outcome
    of SsOutcome.submitted:
      discard
    # Custody, not Prepared or Presented.
    of SsOutcome.admittedLocal, SsOutcome.inFlight:
      remaining.add(ticket)
    else:
      raise newException(
        ValueError, "shell submission ended: " & $outcome & " errno=" & $error
      )
  owner.tickets = remaining

proc ack(owner: FileSession) =
  let status = ssAck(owner.session)
  if status notin [0.cint, 2.cint]:
    sdkCheck(status)

proc step*(owner: FileSession, deadline = 0'u64) =
  if stopRequested() != 0:
    raise newException(ShellStoppedError, "termination requested")
  let now = nowMillis()
  if deadline != 0 and now >= deadline:
    raise newException(ValueError, "shell SDK wait deadline expired")
  var wait = ssTimeout(owner.session, now)
  if wait < 0 or wait > 50:
    wait = 50
  if deadline != 0:
    wait = min(wait, cint(min(deadline - now, 50)))
  var fd = TPollfd(fd: ssPollFd(owner.session), events: ssPollEvents(owner.session))
  if posix.poll(addr fd, Tnfds(1), wait) < 0 and errno != EINTR:
    raiseOSError(osLastError())
  if stopRequested() != 0:
    raise newException(ShellStoppedError, "termination requested")
  let status = ssDispatch(owner.session, fd.revents, 65536, nowMillis())
  owner.checkTickets()
  if status != 0:
    if ssState(owner.session) == SsState.closed:
      raise newException(ShellClosedError, "shell session closed")
    raise newException(
      ValueError, "shell SDK ended: " & $ssState(owner.session) & " code=" & $status
    )
  owner.ack()

proc launchAuthenticationFd*(value: string): cint =
  ## The environment advertises a descriptor, never an identity or authority.
  if value.len == 0:
    raise newException(ValueError, "empty SOPHIA_LAUNCH_AUTH_FD")
  var number = 0'u64
  for character in value:
    if character notin {'0' .. '9'}:
      raise newException(ValueError, "invalid SOPHIA_LAUNCH_AUTH_FD")
    let digit = uint64(ord(character) - ord('0'))
    if number > (uint64(high(cint)) - digit) div 10:
      raise newException(ValueError, "SOPHIA_LAUNCH_AUTH_FD exceeds descriptor range")
    number = number * 10 + digit
  if number < 3:
    raise newException(ValueError, "SOPHIA_LAUNCH_AUTH_FD must not name standard IO")
  cint(number)

proc authenticate(owner: FileSession, config: var SsConfig): uint32 =
  ## The SDK owns the conversation. Retain the borrowed role client until the
  ## shell session closes; keep the generation's relay capability until teardown.
  let bytes = ninePStorageBytes(config.msize, 8)
  owner.role = cast[ptr NinePClient](alloc0(int(ninePStateBytes())))
  owner.relay = cast[ptr NinePClient](alloc0(int(ninePStateBytes())))
  owner.roleStorage = alloc0(int(bytes))
  owner.relayStorage = alloc0(int(bytes))
  sdkCheck(
    ninePInit(
      owner.role,
      cint(owner.socket.getFd()),
      config.msize,
      8,
      32,
      owner.roleStorage,
      bytes,
    )
  )
  sdkCheck(
    ninePInit(
      owner.relay, owner.relayFd, config.msize, 8, 32, owner.relayStorage, bytes
    )
  )
  let auth = cast[ptr LaunchAuth](alloc0(int(laStateBytes())))
  try:
    sdkCheck(laInit(auth, owner.role, owner.relay, "shell", "descriptor", nowMillis()))
    while laReady(auth) == 0:
      if stopRequested() != 0:
        raise newException(ShellStoppedError, "termination requested")
      if laService(auth, nowMillis(), 65536) != 0:
        raise newException(ValueError, "shell launch authentication failed")
      if laReady(auth) != 0:
        break
      let now = nowMillis()
      let wake = laNextWake(auth)
      let wait =
        if wake <= now:
          0.cint
        else:
          cint(min(wake - now, 100))
      var descriptors = [
        TPollfd(fd: cint(owner.socket.getFd()), events: POLLIN),
        TPollfd(fd: owner.relayFd, events: POLLIN),
      ]
      if ninePWantsWrite(owner.role) != 0:
        descriptors[0].events = descriptors[0].events or POLLOUT
      if ninePWantsWrite(owner.relay) != 0:
        descriptors[1].events = descriptors[1].events or POLLOUT
      if posix.poll(addr descriptors[0], Tnfds(2), wait) < 0 and errno != EINTR:
        raiseOSError(osLastError())
    result = laRoot(auth)
  finally:
    laCancel(auth)
    dealloc(auth)

proc openSession*(path: string, required: uint64): FileSession =
  result = FileSession(relayFd: -1)
  try:
    if existsEnv("SOPHIA_LAUNCH_AUTH_FD"):
      result.relayFd = getEnv("SOPHIA_LAUNCH_AUTH_FD").launchAuthenticationFd()
      # Validate before opening the role socket, which could reuse a closed fd.
      let flags = fcntl(result.relayFd, F_GETFD)
      if flags < 0 or fcntl(result.relayFd, F_SETFD, flags or FD_CLOEXEC) < 0:
        raiseOSError(osLastError())
    result.socket = newSocket(Domain.AF_UNIX, SockType.SOCK_STREAM, Protocol.IPPROTO_IP)
    result.socket.connectUnix(path)
    result.session = cast[ptr Ss](alloc0(ssStateBytes().int))
    result.objects = alloc0(4 * 1024 * 1024)
    result.transaction = alloc0(65536)
    var config = SsConfig(
      offer: SfNegotiate(
        minimumRevision: 8, maximumRevision: 8, requiredCapabilities: required
      ),
      profile: SfProfile.descriptor,
      msize: 65536,
      queueSlots: 64,
      queueBytes: 512 * 1024,
      objectStorage: result.objects,
      objectCapacity: 4 * 1024 * 1024,
    )
    let capacity = ssStorageBytes(config.msize, config.queueBytes)
    if capacity == 0:
      raise newException(ValueError, "invalid shell SDK capacity")
    result.storage = alloc0(capacity.int)
    if result.relayFd >= 3:
      let root = result.authenticate(config)
      sdkCheck(
        ssOpenAttachedStaging(
          result.session,
          result.role,
          root,
          addr config,
          result.storage,
          capacity,
          result.transaction,
          65536,
        )
      )
    else:
      sdkCheck(
        ssOpenFdStaging(
          result.session,
          result.socket.getFd().cint,
          addr config,
          result.storage,
          capacity,
          result.transaction,
          65536,
        )
      )
    let deadline = nowMillis() + 10_000
    while ssState(result.session) == SsState.negotiating:
      result.step(deadline)
    if ssState(result.session) != SsState.ready:
      raise newException(ValueError, "descriptor negotiation refused")
    var welcome: SfNegotiated
    sdkCheck(ssWelcome(result.session, addr welcome))
    if welcome.selectedRevision != 8 or (welcome.capabilities and required) != required:
      raise newException(
        ValueError, "descriptor grant does not cover required capabilities"
      )
    result.epoch = welcome.connectionEpoch
    result.capabilities = welcome.capabilities
  except CatchableError:
    result.close()
    raise

proc nextRecord*(owner: FileSession, deadline = 0'u64): SfRecord =
  # The previous value remains borrowed until this call. Callers copy policy
  # rows first; dispatch/submit alone never invalidates those rows.
  if owner.pendingEvent:
    sdkCheck(ssConsume(owner.session))
    owner.pendingEvent = false
    owner.ack()
  while true:
    let status = ssEvent(owner.session, addr result)
    if status == 1:
      owner.step(deadline)
      continue
    sdkCheck(status)
    if result.header.kind != 19:
      owner.pendingEvent = true
      return
    let announcement = result.value.objectPublished
    if announcement.objectKind notin [3'u16, 5, 6, 7]:
      raise newException(ValueError, "unexpected descriptor object")
    sdkCheck(ssConsume(owner.session))
    sdkCheck(
      ssObject(
        owner.session, announcement.objectKind, announcement.generation,
        announcement.qid,
      )
    )
    let fetchDeadline = nowMillis() + 10_000
    while true:
      let fetched = ssObjectResult(owner.session, addr result)
      if fetched == 0:
        owner.ack()
        return
      if fetched != 2:
        sdkCheck(fetched)
      owner.step(fetchDeadline)

proc submit*(owner: FileSession, candidate: var ShellFileCandidate) =
  candidate.bindRows()
  owner.checkTickets()
  # SDK queue admission is atomic; a refusal is never silently retried.
  if owner.tickets.len >= 64:
    raise newException(ValueError, "shell ticket bound exceeded")
  var ticket: uint64
  sdkCheck(ssSubmit(owner.session, addr candidate.record, 1, addr ticket))
  owner.tickets.add(ticket)
  owner.ack()

proc settle*(owner: FileSession) =
  if owner.pendingEvent:
    sdkCheck(ssConsume(owner.session))
    owner.pendingEvent = false
  owner.ack()
  let deadline = nowMillis() + 10_000
  while owner.tickets.len != 0:
    owner.step(deadline)
