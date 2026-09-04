import ./shell_v1

type
  ShellTabGroup* = object
    slot*, output*: uint64
    selected*: uint16
    focused*: bool
    entries*: seq[ShellDescriptor]

  ShellTabSnapshot* = object
    connectionEpoch*, generation*: uint64
    groups*: seq[ShellTabGroup]

  ShellTabModel* = object
    snapshot*: ShellTabSnapshot
    pendingGeneration*, presentedGeneration*, presentationEpoch*, lastActivation*:
      uint64
    prepared*: bool
    presented*: ShellTabSnapshot

const
  shellTabCapability* = 4'u64
  maxShellTabGroups* = 1024
  maxShellTabEntries* = 2048
