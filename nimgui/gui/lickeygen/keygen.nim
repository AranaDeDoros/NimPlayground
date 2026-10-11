import std/[sysrand, strutils]

proc generateLicenseKey*(): string =
  let bytes = urandom(8) # 8 bytes -> 16 hex chars -> 4 groups of 4
  var hexStr = ""
  for b in bytes:
    hexStr.add(toHex(b, 2))
  result = hexStr[0..3] & "-" & hexStr[4..7] & "-" & hexStr[8..11] & "-" & hexStr[12..15]
