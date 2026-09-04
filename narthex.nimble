version = "0.1.0"
author = "Mason Austin Green"
description = "Standalone shell client for the Sophia display server"
license = "BSD-3-Clause"
srcDir = "src"
bin = @["narthex"]

requires "nim >= 2.2.4"

task layout, "Check the data-oriented layout of the source tree":
  exec "sh tools/check_data_oriented_layout.sh"

task test, "Run the independent Sophia shell descriptor conformance suite":
  exec "sh tools/check_data_oriented_layout.sh"
  exec "sh tools/check_narthex.sh"

task verify, "Check formatting and run the independent conformance suite":
  exec "nph --check src tests narthex.nimble"
  exec "sh tools/check_data_oriented_layout.sh"
  exec "sh tools/check_narthex.sh"
