import std/[cmdline, os, streams, parseopt]
import nimcrypto

proc sha256File(filename: string): string =
  var ctx: sha256
  ctx.init()

  let file = newFileStream(filename, fmRead)
  if file.isNil:
    raise newException(IOError, "Cannot open file: " & filename)

  defer:
    file.close()

  const ChunkSize = 64 * 1024
  var buffer = newString(ChunkSize)

  while true:
    let n = file.readData(addr buffer[0], ChunkSize)
    if n == 0:
      break

    ctx.update(buffer.toOpenArray(0, n - 1))

  var digest: array[32, byte]
  ctx.finish(digest)

  result = digest.toHex()


proc hashFile(path: string) =
  echo sha256File(path), "  ", path


proc hashDir(path: string) =
  for kind, filePath in walkDir(path):
    if kind == pcFile:
      hashFile(filePath)


when isMainModule:
  var
    path = ""
    isDir = false

  var p = initOptParser(commandLineParams())

  while true:
    p.next()

    case p.kind
    of cmdArgument:
      if path == "":
        path = p.key
      else:
        quit("Unexpected argument: " & p.key, QuitFailure)

    of cmdLongOption, cmdShortOption:
      case p.key
      of "d", "directory":
        isDir = true
      of "h", "help":
        echo "Usage: hasher [options] <path>"
        echo ""
        echo "Options:"
        echo "  -d, --directory    Hash files in directory"
        echo "  -h, --help         Show this help"
        quit(0)

      else:
        quit("Unknown option: " & p.key, QuitFailure)

    of cmdEnd:
      break

  if path == "":
    quit("Usage: hasher [-d] <path>", QuitFailure)

  if isDir:
    if not dirExists(path):
      quit("Not a directory: " & path, QuitFailure)

    hashDir(path)
  else:
    if not fileExists(path):
      quit("Not a file: " & path, QuitFailure)

    hashFile(path)
