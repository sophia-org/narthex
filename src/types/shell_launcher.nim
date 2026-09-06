import ./shell_v1

const
  launcherCapabilities* = 96'u64
  maxApplications* = 4096
  maxLauncherRows* = 32

type
  ApplicationDescriptor* = object
    slot*: uint16
    available*: bool
    label*, keywords*: string

  ApplicationCatalog* = object
    epoch*, generation*: uint64
    entries*: seq[ApplicationDescriptor]

  LauncherRequest* = object
    epoch*, catalog*, request*, output*, outputGeneration*, presentation*: uint64
    operation*: uint16
    query*: string

  LauncherActivation* = object
    epoch*, catalog*, request*, candidate*, presentation*, activation*: uint64
    slot*: uint16

  LauncherModel* = object
    catalog*: ApplicationCatalog
    selected*: uint16
    pendingRequest*, pendingCandidate*, pendingTransaction*: uint64
    pendingVisible*: bool
    pendingEntries*: seq[uint16]
    presentedRequest*, presentedCandidate*, presentation*: uint64
    presentedEntries*: seq[uint16]
    lastRequest*, lastActivation*: uint64
    fontSize*: uint16
    colors*: array[4, uint32]
    lastOutcome*: ShellCandidateOutcomeKind
    expectedActivation*: LauncherActivation
    activationTransaction*: uint64
    activationPending*: bool
    lastCandidate*: uint64
    activatedCandidate*: uint64
