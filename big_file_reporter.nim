import os
import std/[osproc, strformat, monotimes, times]

const THRESHOLD_SIZE = 1024 * 1024 * 1024 # 1024 MB
const LEVELS_TO_CHECK = 5
const REPORT_FILE = "big_files.txt"

type StorageError = object
    msg: string

type StorageReport = object
    totalSize: int64
    path: string

proc selectInExplorer(path: string) =
  let absPath = absolutePath(path)
  discard startProcess(
    "explorer.exe",
    args = @["/select," & absPath],
    options = {poUsePath}
  )

proc showReportLinux(filename: string) =
  echo fmt"cd {parentDir(absolutePath(filename))}"
  discard execCmd(fmt"cat {filename}")

func convertToGB(sizeInBytes: int64): float =
  return float(sizeInBytes) / (1024.0 * 1024.0 * 1024.0)

func checkOS(): bool =
  when defined(windows):
    return true
  else:
    return false

proc writeReportToFile(report: StorageReport | StorageError, filename: string) =
  let file = open(filename, fmAppend)
  try:
    when report is StorageError:
      file.writeLine(fmt"Error: {report.msg}")
    else:
      file.writeLine(fmt"Path: {report.path}")
      file.writeLine(fmt"Total Size: {convertToGB(report.totalSize):.2f} GB")
  finally:
    file.close()

proc walkDirMaxDepth(dir: string = "./", maxDepth: int = LEVELS_TO_CHECK, currentDepth: int = 1): int64 =
  ## Single walkDir pass per directory: sums file sizes directly and
  ## accumulates subdirectory sizes from their own recursive return value,
  ## instead of re-walking each directory a second time to total it.
  var totalSize: int64 = 0
  try:
    for kind, path in walkDir(dir):
      case kind
      of pcFile, pcLinkToFile:
        let size = getFileSize(path)
        totalSize += size
        if size > THRESHOLD_SIZE:
          writeReportToFile(StorageReport(totalSize: size, path: path), REPORT_FILE)
      of pcDir, pcLinkToDir:
        let dirSize =
          if currentDepth < maxDepth:
            walkDirMaxDepth(path, maxDepth, currentDepth + 1)
          else:
            0'i64 # depth cutoff reached: don't descend, so contents beyond this point aren't counted
        totalSize += dirSize
        if dirSize > THRESHOLD_SIZE:
          writeReportToFile(StorageReport(totalSize: dirSize, path: path), REPORT_FILE)
  except OSError:
    writeReportToFile(StorageError(msg: fmt"Skipping unreadable directory: {dir}"), REPORT_FILE)
  return totalSize

when isMainModule:
  let startTime = getMonoTime()

  const startDir = "C:\\Users\\dontb"
  writeFile(REPORT_FILE, "")
  discard walkDirMaxDepth(startDir, LEVELS_TO_CHECK)

  let elapsed = getMonoTime() - startTime
  echo fmt"Scan took {elapsed.inMilliseconds} ms"

  if getFileSize(REPORT_FILE) > 0:
    echo fmt"Report written to {REPORT_FILE}"
    if checkOS():
      selectInExplorer(REPORT_FILE)
    else:
      showReportLinux(REPORT_FILE)
  else:
    echo "Nothing over threshold found — no report to open."