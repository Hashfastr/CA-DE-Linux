# cede-linux

Run [Capture Age](https://www.captureage.com/) under Proton on Linux so you can
view Age of Empires II: Definitive Edition replays without leaving your Linux
desktop. The helper installs Capture Age into the same Proton prefix that
AoE2:DE uses, so it can read your replays directly with no symlinking.

Targets the **Flatpak** Steam install (`com.valvesoftware.Steam`). If you run
native Steam, edit `STEAMBASE` in `script.sh`.

## Human notes
This is AI written, although it's small enough to be auditable and I couldn't find anything nefarious.
Basically it sets up dotnet via proton and installs ce:de to a common directory for the existing AoE2 install.
The script will run the executable via proton and will talk to the existing process for AoE2

AoE2 needs to be running or else capture age poops itself, it can't launch it itself.
Otherwise works well.

I use flatpak steam so native might require tinkering, if you find something, let me know, I don't trust claude to write code for something it cannot get feedback from.
It also uses flatpak for proton tricks as well, if this interferes with a native steam install, unsure.

## Prerequisites

Install the following on the host:

- **Flatpak Steam** with **AoE2:DE installed and launched at least once**
  (so Proton creates the prefix at
  `~/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/compatdata/813780/`).
- **Protontricks** (Flatpak version, to match Flatpak Steam):

  ```sh
  flatpak install -y flathub com.github.Matoking.protontricks
  ```

- **`CaptureAgeSetup.exe`** placed next to `script.sh` (or pointed at via the
  `INSTALLER` env var). Grab the latest from
  <https://www.captureage.com/>. The installer can live anywhere — the
  `install` step copies it into the prefix before running it, so the Flatpak
  protontricks sandbox doesn't need access to its source directory.

## Setup

From this directory:

```sh
# 1. Install .NET 8 Desktop Runtime into the AoE2:DE Proton prefix,
#    and symlink the game files to the Windows-style path Capture Age
#    expects (otherwise it'll load with no audio/textures).
./script.sh prep

# 2. Run the Capture Age installer inside that prefix. Click through the
#    NSIS wizard; accept the default install location.
./script.sh install

# 3. Launch Capture Age.
./script.sh run
```

Use `./script.sh paths` to see resolved paths if anything goes wrong.

## Launching from Steam

Add `script.sh` as a non-Steam game so Capture Age shows up in your library:

1. In Steam: **Games → Add a Non-Steam Game to My Library → Browse…**
2. Pick `/home/hashfastr/git/cede-linux/script.sh` (toggle the file filter to
   "All Files" if it's hidden).
3. After it's added, right-click the entry → **Properties**:
   - **Launch options**: `run`
   - **Name**: `Capture Age` (rename to taste)
   - Leave the compatibility tool **off** — the script handles Proton itself
     via `protontricks-launch`.

The script auto-detects when it's running inside the Steam Flatpak sandbox and
uses `flatpak-spawn --host` to reach the host's `protontricks` Flatpak.

## Troubleshooting

- **"AoE2:DE Proton prefix not found"** — launch AoE2:DE from Steam once so
  Proton creates `compatdata/813780/`.
- **Capture Age crashes on first launch** — confirm .NET 8 was installed:
  `flatpak run com.github.Matoking.protontricks 813780 -q --self-update` then
  re-run `./script.sh prep`.
- **`run` can't find the exe** — installer may have used an unusual path. Find
  the .exe under `compatdata/813780/pfx/drive_c/` and set `CEDE_EXE` to it:

  ```sh
  CEDE_EXE="/path/to/Capture Age.exe" ./script.sh run
  ```

## Layout

- `script.sh` — `prep` / `install` / `run` / `paths` subcommands.
- `CaptureAgeSetup.exe` — vendor installer (not committed).
