import std/[os, unittest]
import types/[shell_reference, desktop_sdk]
import sdk/[desktop_sdk, values]
import policy/reference
import support/file_records
import config

suite "read-only reference sheets":
  test "native candidate settles only on presentation":
    var rows: seq[byte]
    var record = shortcuts(rows)
    var requestRecord = referenceRequestRecord()
    let request = requestRecord.referenceRequest()
    var model: ReferenceModel
    model.reconcile(record.shortcutCatalog())
    var candidate = model.proposeReference(request, 9, 1)
    candidate.bindRows()
    candidate.record.header = SfHeader(kind: 276, epoch: 5, submission: 1)
    discard candidate.record.encoded()
    check candidate.record.value.referenceCandidate.entryCount == 2
    check not model.visible
    model.rememberReference(referenceOutcome(1))
    check not model.visible
    model.rememberReference(referenceOutcome(2))
    check model.visible
    check model.pages == 5
    var next = request
    next.generation = 9
    next.presentation = 10
    next.operation = ReferenceOperation.next
    check model.proposeReference(next, 10, 2).record.value.referenceCandidate.page == 1
    check model.page == 0
    expect ValueError:
      discard model.proposeReference(next, 11, 3)

  test "mixed epochs, truncated rows, invalid UTF-8 and duplicate slots fail closed":
    var rows: seq[byte]
    var record = shortcuts(rows)
    record.value.shortcuts.connectionEpoch += 1
    expect ValueError:
      discard record.shortcutCatalog()
    record.value.shortcuts.connectionEpoch = 5
    record.value.shortcuts.rowsBytes -= 1
    expect ValueError:
      discard record.shortcutCatalog()
    record.value.shortcuts.rowsBytes += 1
    var invalid = "\xff"
    var e = SfShortcutEntry(
      slot: 1, chord: invalid.borrowedText(), action: "focus".borrowedText()
    )
    check sfShortcutEntryEncode(addr rows[0], addr e) != 0
    copyMem(addr rows[408], addr rows[0], 408)
    expect ValueError:
      discard record.shortcutCatalog()

  test "startup skip is shell-private and explicit toggle still opens":
    var rows: seq[byte]
    var record = shortcuts(rows)
    var requestRecord = referenceRequestRecord()
    var request = requestRecord.referenceRequest()
    var model = ReferenceModel(skipAtStartup: true)
    model.reconcile(record.shortcutCatalog())
    check model.proposeReference(request, 9, 1).record.value.referenceCandidate.visible ==
      0
    model.rememberReference(referenceOutcome(1))
    model.rememberReference(referenceOutcome(2))
    request.generation += 1
    request.operation = ReferenceOperation.toggle
    check model.proposeReference(request, 10, 2).record.value.referenceCandidate.visible ==
      1

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
    var requestRecord = referenceRequestRecord()
    var candidate = model.proposeReference(requestRecord.referenceRequest(), 9, 1)
    candidate.bindRows()
    var row: SfReferenceEntry
    check sfReferenceEntryAt(
      addr candidate.record.value.referenceCandidate, 0, addr row
    ) == 0
    check row.slot == 3
