# Package

version       = "0.1.0"
author        = "Peter Munch-Ellingsen"
description   = "A tool to build minimal standard libraries for NimScript"
license       = "MIT"
srcDir        = "src"
bin           = @["libbuilder"]



# Dependencies

requires "nim >= 1.2.0"
requires "compiler >= 1.3.5"
