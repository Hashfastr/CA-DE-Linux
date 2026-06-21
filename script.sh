#!/usr/bin/env bash
# cede-linux — set up and launch Capture Age inside the AoE2:DE Proton prefix.

set -euo pipefail

AOE2DE_APPID=813780
STEAM_FLATPAK="com.valvesoftware.Steam"
PROTONTRICKS_FLATPAK="com.github.Matoking.protontricks"

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
INSTALLER="${INSTALLER:-${SCRIPT_DIR}/CaptureAgeSetup.exe}"

STEAMBASE="${HOME}/.var/app/${STEAM_FLATPAK}/.local/share/Steam"
PREFIX="${STEAMBASE}/steamapps/compatdata/${AOE2DE_APPID}/pfx"
DRIVE_C="${PREFIX}/drive_c"

# Common install locations Capture Age may end up at.
CEDE_CANDIDATES=(
  "${DRIVE_C}/users/steamuser/AppData/Local/Programs/CaptureAge/CaptureAge.exe"
  "${DRIVE_C}/Program Files/CaptureAge/CaptureAge.exe"
  "${DRIVE_C}/Program Files (x86)/CaptureAge/CaptureAge.exe"
)

# When Steam launches us as a non-Steam shortcut under Flatpak Steam, we're
# inside the Steam sandbox and have to escape to call host flatpaks.
if [[ -f /.flatpak-info ]] || [[ -n "${FLATPAK_ID:-}" ]]; then
  HOST=(flatpak-spawn --host)
else
  HOST=()
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

  prep      Install .NET 8 Desktop Runtime into the AoE2:DE Proton prefix.
  install   Run CaptureAgeSetup.exe inside the prefix.
  run       Launch Capture Age from the prefix.
  paths     Print resolved paths (for debugging).

Environment overrides:
  INSTALLER   Path to CaptureAgeSetup.exe (default: alongside this script).
  CEDE_EXE    Path to the installed Capture Age.exe inside drive_c.
EOF
}

require_prefix() {
  if [[ ! -d "$PREFIX" ]]; then
    echo "ERROR: AoE2:DE Proton prefix not found at:" >&2
    echo "  $PREFIX" >&2
    echo "Launch AoE2:DE through Steam once so Proton creates the prefix." >&2
    exit 1
  fi
}

require_protontricks() {
  if ! "${HOST[@]}" flatpak info "${PROTONTRICKS_FLATPAK}" >/dev/null 2>&1; then
    echo "ERROR: ${PROTONTRICKS_FLATPAK} is not installed." >&2
    echo "Install it with:" >&2
    echo "  flatpak install -y flathub ${PROTONTRICKS_FLATPAK}" >&2
    exit 1
  fi
}

protontricks() {
  "${HOST[@]}" flatpak run "${PROTONTRICKS_FLATPAK}" "$@"
}

protontricks_launch() {
  "${HOST[@]}" flatpak run --command=protontricks-launch "${PROTONTRICKS_FLATPAK}" "$@"
}

find_cede_exe() {
  if [[ -n "${CEDE_EXE:-}" ]]; then
    echo "$CEDE_EXE"
    return
  fi
  for c in "${CEDE_CANDIDATES[@]}"; do
    if [[ -f "$c" ]]; then
      echo "$c"
      return
    fi
  done
}

link_aoe2de() {
  local src="${STEAMBASE}/steamapps/common/AoE2DE"
  local link_dir="${DRIVE_C}/Program Files (x86)/Steam/steamapps/common"
  local link="${link_dir}/AoE2DE"
  if [[ ! -d "$src" ]]; then
    echo "WARNING: AoE2:DE install not found at $src — skipping link." >&2
    return
  fi
  mkdir -p "$link_dir"
  if [[ -L "$link" || -e "$link" ]]; then
    return
  fi
  ln -s "$src" "$link"
  echo "Linked $link -> $src"
}

cmd_prep() {
  require_prefix
  require_protontricks
  protontricks "${AOE2DE_APPID}" -q dotnet8
  # Capture Age looks for AoE2:DE under the Windows-default Steam path it
  # finds in the prefix registry. Symlink that path to the real install so
  # it can load .pck audio banks and other game assets.
  link_aoe2de
}

cmd_install() {
  require_prefix
  require_protontricks
  if [[ ! -f "$INSTALLER" ]]; then
    echo "ERROR: installer not found at $INSTALLER" >&2
    echo "Set INSTALLER=<path> or place CaptureAgeSetup.exe next to this script." >&2
    exit 1
  fi
  # The protontricks Flatpak sandbox can't read arbitrary host paths (e.g.
  # ~/git), so stage the installer inside the prefix where it has access.
  local staged_dir="${DRIVE_C}/users/steamuser/Temp"
  local staged="${staged_dir}/$(basename "$INSTALLER")"
  mkdir -p "$staged_dir"
  cp -f "$INSTALLER" "$staged"
  protontricks_launch --appid "${AOE2DE_APPID}" "$staged"
  rm -f "$staged"
}

cmd_run() {
  require_prefix
  require_protontricks
  local exe
  exe="$(find_cede_exe)"
  if [[ -z "$exe" ]]; then
    echo "ERROR: Capture Age exe not found in any known location:" >&2
    printf '  %s\n' "${CEDE_CANDIDATES[@]}" >&2
    echo "Run '$(basename "$0") install' first, or set CEDE_EXE=<path>." >&2
    exit 1
  fi
  protontricks_launch --appid "${AOE2DE_APPID}" "$exe"
}

cmd_paths() {
  echo "STEAMBASE:  $STEAMBASE"
  echo "PREFIX:     $PREFIX"
  echo "INSTALLER:  $INSTALLER"
  echo "CEDE_EXE:   $(find_cede_exe || echo '(not found)')"
}

case "${1:-}" in
  prep)    cmd_prep ;;
  install) cmd_install ;;
  run)     cmd_run ;;
  paths)   cmd_paths ;;
  -h|--help|"") usage ;;
  *) usage; exit 1 ;;
esac
