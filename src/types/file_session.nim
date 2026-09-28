import std/net
import ./desktop_sdk

type FileSession* = ref object
  socket*: Socket
  session*: ptr Ss
  storage*, transaction*, objects*: pointer
  epoch*, capabilities*: uint64
  pendingEvent*: bool
  tickets*: seq[uint64]
