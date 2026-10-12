# drivetemp.nim - taskbar widget showing drive letters + temperatures
#
# Setup:    nimble install winim
# Build:    nim c -d:release --app:gui drivetemp.nim
# Run:      drivetemp.exe            (optional: drivetemp.exe 202020  -> background hex color)
#
# Right-click the widget for the Exit menu, left-click to refresh.

import winim/lean
import std/[strutils, tables, os]

# ----------------------------------------------------------------------------
# Storage temperature query (works on NVMe and most SATA drives, Windows 10 1607+)
# ----------------------------------------------------------------------------
const
  kIoctlGetDevNum = DWORD(0x002D1080)   # IOCTL_STORAGE_GET_DEVICE_NUMBER
  kIoctlQueryProp = DWORD(0x002D1400)   # IOCTL_STORAGE_QUERY_PROPERTY
  kPropDeviceTemperature = 52'u32       # StorageDeviceTemperatureProperty
  kQueryStandard = 0'u32                # PropertyStandardQuery

type
  DevNum = object
    deviceType, deviceNumber, partitionNumber: uint32
  StorQuery = object
    propertyId, queryType: uint32
    extra: array[1, byte]
  TempInfo = object
    index: uint16
    temperature, overThreshold, underThreshold: int16
    flags: array[4, byte]
    reserved1: uint32
  TempDesc = object
    version, size: uint32
    critical, warning: int16
    infoCount: uint16
    reserved0: array[2, byte]
    reserved1: array[2, uint32]
    info: array[1, TempInfo]

proc openRaw(path: string): HANDLE =
  # access = 0 -> enough for property queries, no admin rights needed
  CreateFileW(path, 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0)

proc physicalNumber(letter: char): int =
  let h = openRaw("\\\\.\\" & $letter & ":")
  if h == INVALID_HANDLE_VALUE: return -1
  var dn: DevNum
  var ret: DWORD
  let ok = DeviceIoControl(h, kIoctlGetDevNum, nil, 0, addr dn,
                           DWORD sizeof(dn), addr ret, nil)
  CloseHandle(h)
  if ok != 0: int(dn.deviceNumber) else: -1

proc readTemp(phys: int): int =
  ## Returns temperature in Celsius, or -1 if unavailable.
  if phys < 0: return -1
  let h = openRaw("\\\\.\\PhysicalDrive" & $phys)
  if h == INVALID_HANDLE_VALUE: return -1
  var q = StorQuery(propertyId: kPropDeviceTemperature, queryType: kQueryStandard)
  var buf: array[512, byte]
  var ret: DWORD
  let ok = DeviceIoControl(h, kIoctlQueryProp, addr q, DWORD sizeof(q),
                           addr buf[0], DWORD buf.len, addr ret, nil)
  CloseHandle(h)
  if ok == 0: return -1
  let d = cast[ptr TempDesc](addr buf[0])
  if d.infoCount == 0: return -1
  let t = int(d.info[0].temperature)
  if t <= 0 or t > 150: -1 else: t

# ----------------------------------------------------------------------------
# State
# ----------------------------------------------------------------------------
type Item = object
  text: string
  temp: int

const
  PadX = 8
  ColGap = 14
  TimerId = 1
  RefreshMs = 5000

var
  gHwnd: HWND
  gFont: HFONT
  gItems: seq[Item]
  gPhys = initTable[char, int]()
  gColW: seq[int]
  gRows, gLineH, gW, gH: int
  gBg: COLORREF = RGB(32, 32, 32)
  gFg: COLORREF = RGB(255, 255, 255)

proc refresh() =
  gItems.setLen(0)
  let mask = GetLogicalDrives()
  for i in 0 ..< 26:
    if ((int(mask) shr i) and 1) == 0: continue
    let letter = char(ord('A') + i)
    if GetDriveType(letter & ":\\") != DRIVE_FIXED: continue
    if gPhys.getOrDefault(letter, -1) < 0:
      gPhys[letter] = physicalNumber(letter)
    let t = readTemp(gPhys[letter])
    let txt = $letter & ": " & (if t >= 0: $t & "\u00B0C" else: "N/A")
    gItems.add Item(text: txt, temp: t)
  if gItems.len == 0:
    gItems.add Item(text: "No drives", temp: -1)

proc layout() =
  let dc = GetDC(gHwnd)
  let old = SelectObject(dc, gFont)
  var tm: TEXTMETRIC
  GetTextMetrics(dc, addr tm)
  gLineH = int(tm.tmHeight)
  gRows = if gItems.len <= 1: 1 else: 2
  let cols = (gItems.len + gRows - 1) div gRows
  gColW = newSeq[int](cols)
  for i, it in gItems:
    var r: RECT
    DrawText(dc, it.text, -1, addr r, DT_CALCRECT or DT_SINGLELINE or DT_NOPREFIX)
    let w = int(r.right - r.left)
    let c = i div gRows
    if w > gColW[c]: gColW[c] = w
  SelectObject(dc, old)
  ReleaseDC(gHwnd, dc)
  gW = PadX * 2 + ColGap * (cols - 1)
  for w in gColW: gW += w
  gH = gRows * gLineH + 2

proc trayRects(tray, notify: var HWND, rTray, rNotify: var RECT): bool =
  tray = FindWindow("Shell_TrayWnd", nil)
  if tray == 0: return false
  notify = FindWindowEx(tray, 0, "TrayNotifyWnd", nil)
  if notify == 0: return false
  GetWindowRect(tray, addr rTray)
  GetWindowRect(notify, addr rNotify)
  true

proc place() =
  var tray, notify: HWND
  var rTray, rNotify: RECT
  if not trayRects(tray, notify, rTray, rNotify): return
  if GetParent(gHwnd) != tray:          # explorer restarted -> re-attach
    SetParent(gHwnd, tray)
  let trayH = int(rTray.bottom - rTray.top)
  let x = int(rNotify.left - rTray.left) - gW
  let y = (trayH - gH) div 2
  SetWindowPos(gHwnd, HWND_TOP, int32 x, int32 y, int32 gW, int32 gH, SWP_SHOWWINDOW)

  # Windows 10: shrink the task-button bar so it doesn't run underneath us
  let rebar = FindWindowEx(tray, 0, "ReBarWindow32", nil)
  if rebar != 0:
    var rr: RECT
    GetWindowRect(rebar, addr rr)
    let rl = int(rr.left - rTray.left)
    let nw = x - rl
    if nw > 0 and nw != int(rr.right - rr.left):
      MoveWindow(rebar, int32 rl, int32(rr.top - rTray.top), int32 nw,
                 int32(rr.bottom - rr.top), TRUE)

proc restoreRebar() =
  var tray, notify: HWND
  var rTray, rNotify: RECT
  if not trayRects(tray, notify, rTray, rNotify): return
  let rebar = FindWindowEx(tray, 0, "ReBarWindow32", nil)
  if rebar == 0: return
  var rr: RECT
  GetWindowRect(rebar, addr rr)
  let nw = int(rNotify.left - rr.left)
  if nw > 0:
    MoveWindow(rebar, int32(rr.left - rTray.left), int32(rr.top - rTray.top),
               int32 nw, int32(rr.bottom - rr.top), TRUE)

proc update() =
  refresh()
  layout()
  place()
  InvalidateRect(gHwnd, nil, FALSE)

proc tempColor(t: int): COLORREF =
  if t >= 70: RGB(255, 90, 90)
  elif t >= 55: RGB(255, 190, 60)
  else: gFg

# ----------------------------------------------------------------------------
# Window procedure
# ----------------------------------------------------------------------------
proc wndProc(hwnd: HWND, msg: UINT, wp: WPARAM, lp: LPARAM): LRESULT {.stdcall.} =
  case msg
  of WM_TIMER:
    update()
    return 0
  of WM_ERASEBKGND:
    return 1
  of WM_LBUTTONUP:
    update()
    return 0
  of WM_RBUTTONUP:
    let menu = CreatePopupMenu()
    AppendMenu(menu, MF_STRING, 1, "Exit")
    var pt: POINT
    GetCursorPos(addr pt)
    SetForegroundWindow(hwnd)
    let cmd = TrackPopupMenu(menu, TPM_RETURNCMD or TPM_BOTTOMALIGN or TPM_RIGHTALIGN,
                             pt.x, pt.y, 0, hwnd, nil)
    DestroyMenu(menu)
    if cmd == 1: DestroyWindow(hwnd)
    return 0
  of WM_PAINT:
    var ps: PAINTSTRUCT
    let dc = BeginPaint(hwnd, addr ps)
    var rc: RECT
    GetClientRect(hwnd, addr rc)
    let br = CreateSolidBrush(gBg)
    FillRect(dc, addr rc, br)
    DeleteObject(br)
    let old = SelectObject(dc, gFont)
    SetBkMode(dc, TRANSPARENT)
    let y0 = (int(rc.bottom) - gRows * gLineH) div 2
    for i, it in gItems:
      let col = i div gRows
      let row = i mod gRows
      var x = PadX + col * ColGap
      for c in 0 ..< col: x += gColW[c]
      var r = RECT(left: int32 x, top: int32(y0 + row * gLineH),
                   right: int32(x + gColW[col]), bottom: int32(y0 + (row + 1) * gLineH))
      SetTextColor(dc, tempColor(it.temp))
      DrawText(dc, it.text, -1, addr r, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX)
    SelectObject(dc, old)
    EndPaint(hwnd, addr ps)
    return 0
  of WM_DESTROY:
    KillTimer(hwnd, TimerId)
    restoreRebar()
    PostQuitMessage(0)
    return 0
  else:
    discard
  DefWindowProc(hwnd, msg, wp, lp)

# ----------------------------------------------------------------------------
# Entry point
# ----------------------------------------------------------------------------
proc main() =
  SetProcessDPIAware()

  # single instance
  let mutex = CreateMutex(nil, TRUE, "DriveTempTaskbarWidget")
  if GetLastError() == ERROR_ALREADY_EXISTS: return

  # optional background colour override: drivetemp.exe 202020
  if paramCount() >= 1:
    try:
      let v = parseHexInt(paramStr(1))
      let r = (v shr 16) and 0xFF
      let g = (v shr 8) and 0xFF
      let b = v and 0xFF
      gBg = RGB(r, g, b)
      if (r * 299 + g * 587 + b * 114) div 1000 > 140: gFg = RGB(0, 0, 0)
    except ValueError:
      discard

  let tray = FindWindow("Shell_TrayWnd", nil)
  if tray == 0:
    MessageBox(0, "Could not find the Windows taskbar.", "DriveTemp", MB_ICONERROR)
    return

  let hInst = GetModuleHandle(nil)
  let cls = "DriveTempWidget"
  var wc: WNDCLASSEX
  wc.cbSize = UINT sizeof(WNDCLASSEX)
  wc.lpfnWndProc = wndProc
  wc.hInstance = hInst
  wc.hCursor = LoadCursor(0, IDC_ARROW)
  wc.lpszClassName = cls
  RegisterClassEx(addr wc)

  let screenDc = GetDC(0)
  let dpi = GetDeviceCaps(screenDc, LOGPIXELSY)
  ReleaseDC(0, screenDc)
  gFont = CreateFont(-MulDiv(9, dpi, 72), 0, 0, 0, FW_NORMAL, 0, 0, 0,
                     DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                     CLEARTYPE_QUALITY, DEFAULT_PITCH or FF_DONTCARE, "Segoe UI")

  gHwnd = CreateWindowEx(0, cls, "DriveTemp",
                         WS_CHILD or WS_VISIBLE or WS_CLIPSIBLINGS,
                         0, 0, 100, 30, tray, 0, hInst, nil)
  if gHwnd == 0:
    MessageBox(0, "Could not create the widget window.", "DriveTemp", MB_ICONERROR)
    return

  update()
  SetTimer(gHwnd, TimerId, RefreshMs, nil)

  var msg: MSG
  while GetMessage(addr msg, 0, 0, 0) > 0:
    TranslateMessage(addr msg)
    DispatchMessage(addr msg)

  CloseHandle(mutex)

main()