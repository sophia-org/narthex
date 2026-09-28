## Owned rows accompany the public SDK record until local admission copies it.
import ./desktop_sdk

type ShellFileCandidate* = object
  record*: SfRecord
  rows*: seq[byte]
