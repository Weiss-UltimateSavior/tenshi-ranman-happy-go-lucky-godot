# Japanese Kirikiri Maintenance Launcher

`E:\Galgame\天神乱漫 Happy GO Lucky!!\天神乱漫 Happy Go Lucky!! 日文维护版.exe`
is the supported launcher for the original Japanese Kirikiri build. It is built
from `tools/tenshin_jp_maintenance_launcher.c` with MinGW-w64.

## Scope

- Finds `tenshin_hgl.exe` beside itself and starts it with that directory as
  the current working directory.
- Forwards command-line arguments to the original executable.
- Writes startup failures and spawned process IDs to
  `japanese_maintenance_launcher.log` in the original game directory.
- Does not load Godot, `ShiraYukiNoa.dll`, or `tenshin_chs.xp3`.
- Does not alter, remove, emulate, or bypass the original PlayDRM licensing
  workflow. Authorization remains the responsibility of the licensed original
  executable.

## Build

```powershell
& 'F:\Program Files\mingw64\bin\gcc.exe' -std=c17 -O2 -s -mwindows -municode -static -static-libgcc `
  -o 'E:\Galgame\天神乱漫 Happy GO Lucky!!\天神乱漫 Happy Go Lucky!! 日文维护版.exe' `
  'F:\Galgame\天神乱漫 Happy GO Lucky!!_godot\tools\tenshin_jp_maintenance_launcher.c' -lshell32
```

The former Godot-oriented maintenance launcher is preserved at
`F:\Galgame\天神乱漫 Happy GO Lucky!!_godot\天神乱漫 Happy Go Lucky!! 日文维护版.exe.godot_launcher_backup`.
