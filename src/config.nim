import std/[os, tables]
import kdl

proc skipHelpAtStartup*(): bool =
  ## Session mounts only this selected private file. It never parses its keys.
  let path = getEnv("SOPHIA_SHELL_CONFIG")
  if path.len == 0:
    return false
  if getFileSize(path) > 65536:
    raise newException(ValueError, "shell config exceeds 64 KiB")
  let document = parseKdl(readFile(path))
  if document.len != 1 or document[0].name != "hotkey-overlay" or
      document[0].args.len != 0 or document[0].props.len != 0:
    raise newException(ValueError, "expected hotkey-overlay config")
  let children = document[0].children
  if children.len != 1 or children[0].name != "skip-at-startup" or
      children[0].args.len != 1 or children[0].props.len != 0 or
      children[0].children.len != 0:
    raise newException(ValueError, "expected skip-at-startup boolean")
  children[0].args[0].get(bool)
