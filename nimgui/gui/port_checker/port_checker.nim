import std/net
import std/posix

proc isPortInUse*(host: string, port: Port): bool =
  try:
    var socket = newSocket(
    Domain.AF_INET,
    SockType.SOCK_STREAM,
    Protocol.IPPROTO_TCP
    )
    defer: socket.close()

    socket.bindAddr(port, host)
    result = false
  except OSError as e:
    if e.errorCode == EADDRINUSE:
      result = true
    elif e.errorCode == EACCES:
      raise newException(IOError, "Permission denied binding to port " & $port.int & " (requires elevated privileges)")
    else:
      raise

