# ClaudeNotes — cede-linux setup log

Notes on what was built and the reasoning, for reproducibility on another
machine or another Linux distro.

## Goal
Run Capture Age (the AoE2:DE replay viewer, Windows-only) on Linux under the
same Proton prefix that AoE2:DE itself uses, so it has direct access to the
game's audio/texture assets and replay files. Launchable from a terminal and
optionally from Steam as a non-Steam-game shortcut.

## Environment assumed
- Flatpak Steam (`com.valvesoftware.Steam`).
- AoE2:DE installed and launched at least once (so Proton creates the prefix
  at `~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/813780/`).
- `com.github.Matoking.protontricks` installed as a Flatpak (matching
  Flatpak Steam — avoids the `--no-bwrap` workaround needed when mixing
  native protontricks with Flatpak Steam).
- `CaptureAgeSetup.exe` (the NSIS downloader stub from
  <https://www.captureage.com/>) placed next to `script.sh`.

## What `script.sh` does
Four subcommands. `prep` and `install` are one-time setup; `run` is the
launch path.

1. **`prep`**
   - Runs `protontricks 813780 -q dotnet8` to install the .NET 8 Desktop
     Runtime into the AoE2:DE prefix. Required by Capture Age's installer
     and runtime.
   - Symlinks `drive_c/Program Files (x86)/Steam/steamapps/common/AoE2DE`
     to the real `~/.var/app/.../Steam/steamapps/common/AoE2DE`. This is
     critical: Capture Age reads `InstallPath` from the prefix registry
     (which advertises `C:\Program Files (x86)\Steam`) and looks for the
     game's `.pck` audio banks and texture assets there. Without the
     symlink the window opens "partially" — no sound, missing textures.

2. **`install`**
   - The protontricks Flatpak sandbox can't read arbitrary host paths
     (e.g. `~/git/...`) — `protontricks-launch` raised
     `FileNotFoundError: '/home/<user>/git'`. Workaround is to stage the
     installer inside the prefix at
     `drive_c/users/steamuser/Temp/CaptureAgeSetup.exe`, which the sandbox
     can see, then run it from there and clean up.
   - The NSIS stub then downloads the real ~100 MB installer from
     captureage.com — needs internet.

3. **`run`**
   - Locates the installed exe (default
     `drive_c/users/steamuser/AppData/Local/Programs/CaptureAge/CaptureAge.exe`,
     with a couple of fallbacks) and launches it via `protontricks-launch`
     in the AoE2:DE prefix.

4. **`paths`** — debug print of resolved paths.

## Flatpak sandbox escape
When Steam (itself a Flatpak) launches `script.sh` as a non-Steam-game, the
script runs inside Steam's sandbox and cannot directly call the host's
protontricks Flatpak. The script detects this via `/.flatpak-info` /
`FLATPAK_ID` and prepends `flatpak-spawn --host` to its `flatpak run`
invocations. That's what makes the Steam shortcut work.

## Pitfalls encountered (in order)
1. `protontricks-launch` failed on a `~/git/` path → fixed by staging the
   installer inside the prefix before launch.
2. After install, `run` couldn't find the exe — initial candidate list
   guessed wrong names. Real install path is
   `AppData/Local/Programs/CaptureAge/CaptureAge.exe` (no space, no hyphen).
3. Window opened partially — Capture Age was looking at
   `C:\Program Files (x86)\Steam\steamapps\common\AoE2DE` for game assets
   (taken from registry InstallPath), which didn't exist. Fixed by
   symlinking that path to the real install dir in `prep`.

## Reproducing on a fresh machine
```sh
flatpak install -y flathub com.github.Matoking.protontricks
# install AoE2:DE in Steam, launch once
cd cede-linux
# put CaptureAgeSetup.exe in this directory
./script.sh prep      # dotnet8 + symlink
./script.sh install   # NSIS wizard
./script.sh run
```

## Steam shortcut
Add `script.sh` as a non-Steam game, set **Launch options** to `run`. Leave
the Steam compatibility tool **off** — the script handles Proton itself via
protontricks-launch.

## Files
- `script.sh` — subcommand dispatcher.
- `README.md` — user-facing setup doc.
- `CaptureAgeSetup.exe` — vendor installer stub (not committed).
- `script.log` — captured runtime output (used for diagnosis; not committed).

## Security caveats
See the separate security review for details. The big one: this puts
Capture Age inside the AoE2:DE prefix where Wine maps `Z:\` to `/`, giving
the Windows app effective access to your `$HOME`. The NSIS stub is also
fetched/run with no checksum verification. Acceptable for personal use;
worth knowing.
