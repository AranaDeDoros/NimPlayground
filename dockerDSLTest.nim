import macros
import strutils

type
  Dockerfile = object
    lines: seq[string]

proc base(d: var Dockerfile, image: string) =
  d.lines.add("FROM " & image)

proc copy(d: var Dockerfile, origin: string, destiny: string) =
  d.lines.add("COPY " & origin & " " & destiny)

proc workdir(d: var Dockerfile, path: string) =
  d.lines.add("WORKDIR " & path)

proc run(d: var Dockerfile, command: string) =
  d.lines.add("RUN " & command)

proc `$`(d: Dockerfile): string =
  d.lines.join("\n")

macro dockerfile(body: untyped): untyped =
  result = newStmtList()
  
  let dVar = genSym(nskVar, "d")

  result.add quote do:
    var `dVar` = Dockerfile()

  for statement in body:
    let procName = statement[0]

    var call = newCall(procName, dVar)
    for i in 1 ..< statement.len:
      call.add(statement[i])

    result.add(call)

  result.add quote do:
    `dVar`

when isMainModule:
  block:
    let d = dockerfile:
        base "python:3.9-slim"
        workdir "/app"
        copy "requirements.txt", "./"
        run "pip install --no-cache-dir -r requirements.txt"

    echo d
    
