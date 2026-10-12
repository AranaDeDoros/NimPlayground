Build and run

```bash
nimble install winim
nim c -d:release --app:gui drivetemp.nim
drivetemp.exe
```

You can pass a background colour as hex, e.g. drivetemp.exe 101010, to match your taskbar. The text switches between black and white automatically to stay readable.

# How it works

- Placement: it attaches itself as a child of the taskbar and sits just left of the notification area. On Windows 10 it also shrinks the task-button bar so it doesn’t cover your pinned apps.
- Layout: drives are drawn in two rows so the widget stays compact.
- Temperatures: each drive letter is mapped to its physical disk, and the temperature is read from Windows’ built-in storage temperature query. No admin rights or extra drivers are needed.
- Updates: values refresh every 5 seconds. The text turns amber at 55°C and red at 70°C. Drives that don’t report a temperature show N/A.
- Controls: left-click refreshes, and right-click gives an Exit menu. Only one copy can run at a time.
- Explorer restarts: it re-attaches itself if Explorer restarts.

# Limitations

- Temperature support: it works on NVMe and most SATA drives on Windows 10 1607 or later.
- USB enclosures and some RAID setups don’t pass the query through, so they will show N/A.
- Shared disks: partitions on the same physical disk show the same temperature, as you’d expect.
- Windows 11: the taskbar is built differently, so the widget will sit left of the whole tray area rather than right next to the clock. It may need position tweaks on newer 11 builds.
- Horizontal taskbar only: a vertical taskbar isn’t handled.
- Background colour: it’s a solid colour, not transparent, which is why the colour option exists.