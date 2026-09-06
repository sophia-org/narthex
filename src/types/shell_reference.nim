## Read-only reference sheets have no descriptor activation capabilities.
const
  maxShortcuts* = 256
  referenceCapabilities* = 24'u64

type
  ReferenceOperation* {.pure.} = enum
    startup
    toggle
    next
    previous
    dismiss

  ShortcutRow* = object
    slot*: uint16
    chord*, action*, label*, group*: string

  ShortcutCatalog* = object
    epoch*, generation*: uint64
    rows*: seq[ShortcutRow]

  ReferenceRequest* = object
    epoch*, catalog*, generation*, output*, outputGeneration*, presentation*: uint64
    operation*: ReferenceOperation

  ReferenceModel* = object
    catalog*: ShortcutCatalog
    visible*, pendingVisible*, skipAtStartup*: bool
    page*, pages*: uint16
    lastRequest*, pendingRequest*, pendingGeneration*, pendingTransaction*,
      presentation*: uint64
