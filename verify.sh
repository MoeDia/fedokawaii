#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  verify.sh — proves the machine matches the manifest. Read-only; safe any time.
#
#    fedokawai verify                    (or: sudo bash fedokawai.sh verify)
#    sudo bash verify.sh --pre-finalize  used by setup.sh before enabling the login
#
#  System checks always run. Theme checks run once the theme has been applied
#  (otherwise they are listed as "not applied", which is not a failure).
#  Every check fails if its probe fails — a broken tool can never produce a pass.
#  Exit 0 = all passed. Log: /var/log/fedokawai-verify.log
# ═════════════════════════════════════════════════════════════════════════════
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8      # every tool's output in one language and format, whatever yours is
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
PRE=0; [[ ${1:-} == --pre-finalize ]] && PRE=1
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 2; }

STATE_DIR=/var/lib/fedokawai
LOG_FILE=/var/log/fedokawai-verify.log; : >"$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/manifest.sh"
source "$REPO_DIR/lib/upstream.sh"
read_conf "$REPO_DIR/fedokawai.conf"
[[ -f $STATE_DIR/user ]] || { echo "setup has not started — nothing to verify yet (try: check)" >&2; exit 2; }
TARGET_USER=$(<"$STATE_DIR/user"); TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER"); TARGET_GID=$(id -g "$TARGET_USER")
export TARGET_USER TARGET_HOME TARGET_UID TARGET_GID
GPU_KIND=$(cat "$STATE_DIR/gpu" 2>/dev/null || echo amd)
THEMED=0; [[ -f $TARGET_HOME/.local/state/fedokawai/theme-applied ]] && THEMED=1
U() { as_user "$@"; }
dump=$(dnf --dump-main-config 2>/dev/null)
dnfopt() { sed -n "s/^$1 *= *//p" <<<"$dump"; }

hdr "Fedokawai · verify · $(date '+%F %H:%M')"

# ── system ───────────────────────────────────────────────────────────────────
section "system"
# shellcheck disable=SC1091
source /etc/os-release
check "Fedora $VERSION_ID (44 or newer)"              test "$VERSION_ID" -ge 44
check "SELinux enforcing"                              test "$(getenforce 2>/dev/null)" = Enforcing
check "/ is Btrfs"                                     test "$(findmnt -no FSTYPE /)" = btrfs
check "no root-owned files in your home"               bash -c 'o=$(find "$1" -xdev -user root -print -quit) && [ -z "$o" ]' _ "$TARGET_HOME"
check "user in video, input, render"                   bash -c "id -nG $TARGET_USER | tr ' ' '\n' | grep -cxE 'video|input|render' | grep -qx 3"
check "EDITOR=nvim system-wide"                        grep -qx 'export EDITOR=nvim' /etc/profile.d/editor.sh
check "vi → nvim"                                       test "$(readlink -f /usr/local/bin/vi)" = /usr/bin/nvim
check "i2c-dev loaded (monitor brightness over DDC/CI)" test -d /sys/module/i2c_dev

# ── packages ─────────────────────────────────────────────────────────────────
section "packages (lib/manifest.sh)"
mapfile -t WANT < <(manifest_all "$GPU_KIND")
# a package Fedora renamed counts (the new one provides the old name); one it retired, that
# the last update could not find anywhere, is a warning — the desktop goes on without it
miss=()
for p in "${WANT[@]}"; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || miss+=("$p"); done
gone=$(cat "$STATE_DIR/unavailable" 2>/dev/null || true)
real=() ret=()
for p in "${miss[@]}"; do if grep -qx -- "$p" <<<"$gone"; then ret+=("$p"); else real+=("$p"); fi; done
if ((${#miss[@]} == 0)); then pass "all ${#WANT[@]} manifest packages installed"
elif ((${#real[@]})); then fail "missing packages" "$(IFS=' '; echo "${real[*]}")"
else pass "$((${#WANT[@]} - ${#ret[@]})) of ${#WANT[@]} manifest packages installed"; fi
((${#ret[@]} == 0)) || warn "no longer in Fedora (renamed or retired)" "$(IFS=' '; echo "${ret[*]}")"

# ── zero redundancy ──────────────────────────────────────────────────────────
section "zero redundancy"
forbid=("${FORBIDDEN_PKGS[@]}"); [[ $GPU_KIND == amd ]] && forbid+=("${FORBIDDEN_amd[@]}")
q=$(rpm -q "${forbid[@]}" 2>/dev/null || true)          # (one line per name, whichever the answer)
present=$(grep -v 'is not installed' <<<"$q" | tr '\n' ' ' || true)
if (($(grep -c . <<<"$q" || true) < ${#forbid[@]})); then
  fail "forbidden packages: rpm gave no answer" "its database may be damaged: sudo rpm --rebuilddb, then verify again"
elif [[ -z ${present// /} ]]; then pass "none of ${#forbid[@]} forbidden packages present"
else fail "forbidden packages present" "$present"; fi
# what you installed yourself (reason "user", or an rpm outside dnf): a package a comps group
# brought in — kmscon, which Fedora 45's core group gained, arriving with the move — is the
# release's own, not yours (a dnf without the reason tag: every user-installed name counts)
if ui=$(dnf repoquery --userinstalled --qf '%{name} %{reason}\n' 2>/dev/null) && [[ -n $ui ]]; then
  ui=$(awk 'NF < 2 || tolower($0) ~ / (external )?user$/ { print $1 }' <<<"$ui")
elif ui=$(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null) && [[ -n $ui ]]; then :; else ui=""; fi
if [[ -n $ui ]]; then
  # (the manifest by its names, and by the names its packages have now — Fedora renames some)
  extras=$(comm -23 <(sort -u <<<"$ui") <({ cat "$STATE_DIR/baseline-userinstalled" 2>/dev/null; printf '%s\n' "${WANT[@]}"
                                             rpm -q --qf '%{NAME}\n' --whatprovides "${WANT[@]}" 2>/dev/null | grep -v ' '; } | sort -u) \
           | grep -v '^kernel' | tr '\n' ' ')
  if [[ -z $extras ]]; then pass "nothing user-installed beyond the manifest"; else fail "installed outside the manifest" "$extras"; fi
else fail "nothing user-installed beyond the manifest" "dnf repoquery failed"; fi
check "no Flatpak, no Snap"                            bash -c 'command -v dnf && ! command -v flatpak && ! command -v snap'
check "one editor (no vim, nano, emacs)"               bash -c 'command -v nvim && ! command -v vim && ! command -v nano && ! command -v emacs'

# ── repositories & dnf ───────────────────────────────────────────────────────
section "repositories & dnf"
enabled=$(dnf repolist --enabled 2>/dev/null | awk 'NR>1{print $1}')
for r in fedora updates rpmfusion-free rpmfusion-free-updates rpmfusion-nonfree rpmfusion-nonfree-updates brave-browser claude-code; do
  check "repo $r enabled" grep -qx "$r" <<<"$enabled"
done
for c in "${COPRS[@]}"; do check "COPR $c enabled" grep -q "copr.*${c#*/}" <<<"$enabled"; done
for pr in brave-origin:brave-browser claude-code:claude-code; do
  check "${pr%%:*} from ${pr#*:} (gpgcheck=1)" \
    bash -c "test \"\$(dnf repoquery --installed --qf '%{from_repo}' ${pr%%:*})\" = ${pr#*:} && grep -qx gpgcheck=1 /etc/yum.repos.d/${pr#*:}.repo"
done
check "dnf max_parallel_downloads=$DNF_PARALLEL"       test "$(dnfopt max_parallel_downloads)" = "$DNF_PARALLEL"
check "dnf fastestmirror on"                           grep -qxiE '1|true' <<<"$(dnfopt fastestmirror)"
check "dnf timeout=20 (slow mirrors dropped)"          test "$(dnfopt timeout)" = 20
check "dnf installonly_limit=2 (dnf5 minimum)"         test "$(dnfopt installonly_limit)" = 2
check "dnf minrate=50k (stalled mirrors dropped)"      grep -qxE '51200|50[kK]' <<<"$(dnfopt minrate)"
check "dnf defaultyes on"                              grep -qxiE '1|true' <<<"$(dnfopt defaultyes)"

# ── upkeep: the toolkit and its control ──────────────────────────────────────
section "upkeep (fedokawai · Super+U)"
TK=/usr/local/lib/fedokawai
check "the toolkit: root's own copy, writable by root alone" \
  bash -c 'test -f "$1/setup.sh" && test -z "$(find "$1" \( ! -user root -o \( ! -type l -perm /022 \) \) -print -quit)"' _ "$TK"
check "the control: fedokawai is the toolkit's"         cmp -s "$TK/system/fedokawai" /usr/local/bin/fedokawai
check "the manifest's packages marked as yours (dnf's clean-up never takes them)" \
  bash -c 'u=$(dnf repoquery --userinstalled --qf "%{name}\n" 2>/dev/null) || exit 1
           for p; do n=$p; rpm -q "$p" >/dev/null 2>&1 || n=$(rpm -q --qf "%{NAME}\n" --whatprovides "$p" 2>/dev/null | awk "NR == 1")
                     grep -qx "${n:-$p}" <<<"$u" || exit 1; done' \
  _ greetd NetworkManager sudo snapper

# ── boot & kernel ────────────────────────────────────────────────────────────
section "boot & kernel"
if ((THEMED && BOOT_MENU_SECONDS > 0)); then
  check "GRUB menu shown for $BOOT_MENU_SECONDS s (themed)" bash -c 'l=$(grub2-editenv - list) && ! grep -qx menu_auto_hide=1 <<<"$l"'
else
  check "GRUB menu hidden (shows after a failed boot)" bash -c 'l=$(grub2-editenv - list) && grep -qx menu_auto_hide=1 <<<"$l"'
fi
check "boot-success timer enabled"                     bash -c 'systemctl --global is-enabled grub-boot-success.timer | grep -qx enabled'
mapfile -t kv < <(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v 'not installed' | sort -V)
running=$(uname -r)
if ((${#kv[@]} >= 1 && ${#kv[@]} <= 2)) && [[ ${kv[-1]} == "$running" ]]; then
  pass "kernels: the newest running ($running)$( ((${#kv[@]} == 2)) && echo ", the one before kept to fall back to")"
elif ((${#kv[@]} >= 1 && ${#kv[@]} <= 2)); then warn "new kernel ${kv[-1]} installed" "restart to use it (running: $running)"
else fail "at most two kernels" "installed: $(IFS=" "; echo "${kv[*]:-none}") · running: $running"; fi
check "no rescue kernel or boot entry"                 bash -c '! ls /boot/vmlinuz-0-rescue-* /boot/loader/entries/*-0-rescue*.conf 2>/dev/null | grep -q .'
if [[ $GPU_KIND == amd ]]; then
  check "amdgpu.ppfeaturemask on the kernel"           bash -c 'a=$(grubby --info=ALL | grep "^args=") && [ -n "$a" ] && ! printf "%s\n" "$a" | grep -vq amdgpu.ppfeaturemask'
  check "amdgpu.ppfeaturemask active now"              grep -q amdgpu.ppfeaturemask /proc/cmdline
fi

# ── GPU & media ──────────────────────────────────────────────────────────────
section "GPU & media"
rnd=$(compgen -G '/dev/dri/renderD*' | head -n1)
va=$(vainfo --display drm --device "$rnd" 2>/dev/null)
for p in VAProfileH264High VAProfileHEVCMain; do check "hardware decode: ${p#VAProfile}" grep -q "$p" <<<"$va"; done
# AV1 decoding needs AMD RDNA 2+ or Intel Tiger Lake+: older cards get a note, not a failure
if grep -q VAProfileAV1Profile0 <<<"$va"; then pass "hardware decode: AV1Profile0"
elif [[ -n $va ]]; then warn "no AV1 hardware decode" "this GPU predates it; AV1 video decodes on the CPU"
else fail "hardware decode" "vainfo found no VA-API driver on ${rnd:-any render node}"; fi
check "Vulkan driver present"                          compgen -G '/usr/share/vulkan/icd.d/*.json'
enc=$(ffmpeg -hide_banner -encoders 2>/dev/null)
for e in libx264 libx265 libsvtav1 libaom-av1; do check "ffmpeg encoder $e" grep -qw "$e" <<<"$enc"; done

# ── compositor & login ───────────────────────────────────────────────────────
section "compositor & login"
check "dwl $DWL_TAG installed"                         U bash -c "/usr/local/bin/dwl -v 2>&1 | grep -q '${DWL_TAG#v}'"
check "dwl at the pinned commit"                       test "$(U git -C "$TARGET_HOME/.local/src/dwl" rev-parse HEAD 2>/dev/null)" = "$DWL_COMMIT"
check "dwl built with XWayland (Steam, X11 apps)"      U bash -c 'ldd /usr/local/bin/dwl | grep -q libxcb'
check "dwl.patch applied (keys, gaps, frames, centring, layout, clean status)" \
  bash -c 'grep -q "layout = 0; /\* keybindings always read" "$1" && grep -q "gap = (int)gappx" "$1" && grep -qF "corners closed" "$1" && grep -q "open centred on their monitor" "$1" && grep -q "kblayout %u" "$1" && grep -q "^printclean(" "$1"' _ "$TARGET_HOME/.local/src/dwl/dwl.c"
check "dwl's own wlroots $DWL_WLROOTS kept"             wlr_kept
check "dwl finds every library (its wlroots: its own)"  U bash -c 'l=$(ldd /usr/local/bin/dwl) && ! grep -q "not found" <<<"$l" && grep -qF "$1/lib/libwlroots" <<<"$l"' _ "$(wlr_home)"
check "session launcher (start-dwl)"                   test -x /usr/local/bin/start-dwl
check "keyboard layouts $KB_LAYOUTS"                   grep -q "XKB_DEFAULT_LAYOUT=\"$KB_LAYOUTS\"" /usr/local/bin/start-dwl
check "greetd SELinux module loaded"                   bash -c 'semodule -l | grep -qw greetd'
check "greetd runs kawa-greeter"                       grep -q '/usr/local/bin/kawa-greeter' /etc/greetd/fedokawai.toml
check "greetd reads fedokawai.toml"                    bash -c 'systemctl cat greetd.service | grep -qx "ExecStart=/usr/bin/greetd --config /etc/greetd/fedokawai.toml"'
check "agreety (greetd's text greeter) installed"      test -x /usr/bin/agreety
check "kawa-greeter starts agreety → start-dwl"       grep -q 'exec agreety --cmd /usr/local/bin/start-dwl' /usr/local/bin/kawa-greeter
# the file dialog: yazi through xdg-desktop-portal-termfilechooser, which setup.sh builds. Not
# built (its build failed): the dialogs are GTK's meanwhile — a warning. Installed but not
# running would leave apps with no file dialog at all — a failure.
tfc=/usr/local/libexec/xdg-desktop-portal-termfilechooser
if [[ ! -e $tfc ]]; then
  warn "yazi file dialog not built (termfilechooser)" "file dialogs are GTK's meanwhile — update or repair builds it"
else
  check "yazi file dialog: termfilechooser ${TFC_TAG:-?} runs" U bash -c '[[ $("$1" -v 2>/dev/null) == "xdg-desktop-portal-termfilechooser ${2#v}" ]]' _ "$tfc" "${TFC_TAG:-}"
  check "termfilechooser known to the portals, D-Bus, systemd" test -f /usr/local/share/xdg-desktop-portal/portals/termfilechooser.portal \
    -a -f /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service \
    -a -f /usr/local/lib/systemd/user/xdg-desktop-portal-termfilechooser.service
fi

# ── services ─────────────────────────────────────────────────────────────────
section "services"
svcs=("${SVC_SYSTEM[@]}"); [[ $GPU_KIND == amd ]] && svcs+=("${SVC_SYSTEM_amd[@]}")
for s in "${svcs[@]}"; do
  [[ $PRE == 1 && ( $s == greetd.service || $s == snapper-* ) ]] && continue
  check "$s enabled" systemctl is-enabled --quiet "$s"
done
for s in "${SVC_USER_GLOBAL[@]}"; do check "user unit $s enabled" bash -c "systemctl --global is-enabled $s | grep -qx enabled"; done
check "tuned profile fedokawai (always-plugged desktop)" bash -c 'tuned-adm active 2>/dev/null | grep -q fedokawai'
check "Wi-Fi power saving off"                         test -f /etc/NetworkManager/conf.d/90-fedokawai.conf
[[ $STEAM == yes ]] && check "ntsync ready for Proton (/dev/ntsync)" test -c /dev/ntsync
check "linger on (update, repair, verify reach your services)" test -f "/var/lib/systemd/linger/$TARGET_USER"
check "secrets.sh private (yours, chmod 600)"          bash -c '[[ ! -e $1 ]] || [[ $(stat -c "%a %U" "$1") == "600 $2" ]]' _ "$TARGET_HOME/.config/fedokawai/secrets.sh" "$TARGET_USER"
# torrents: one key, in secrets.sh only; Prowlarr takes it, torrra gets it from kawa-torrra
# shellcheck disable=SC2016  # expanded by the user's bash, after sourcing the file
pkey=$(U bash -c '. "$1" >/dev/null 2>&1; printf %s "${PROWLARR_API_KEY:-}"' _ "$TARGET_HOME/.config/fedokawai/secrets.sh" 2>/dev/null) || pkey=""
prowlarr_get() {   # prowlarr_get PATH — the key goes to curl on stdin, never as an argument
  printf 'header = "X-Api-Key: %s"\n' "$pkey" | U curl -fsS --max-time 5 -K - "http://127.0.0.1:9696/api/v1/$1"
}
# (tested here, in this shell: the key never goes on a command line)
if [[ $pkey =~ ^[0-9a-f]{32}$ ]]; then pass "Prowlarr key in secrets.sh (PROWLARR_API_KEY)"
else fail "Prowlarr key in secrets.sh (PROWLARR_API_KEY)" "missing or not 32 hex characters — repair makes one"; fi
check "Prowlarr container file current"                cmp -s "$REPO_DIR/system/prowlarr.container" "$TARGET_HOME/.config/containers/systemd/prowlarr.container"
# Prowlarr runs on demand: started for these checks, and stopped again after if it was not
# running before
prowlarr_was=0; U systemctl --user is-active --quiet prowlarr.service && prowlarr_was=1
check "Prowlarr starts (it runs on demand)"           U systemctl --user start prowlarr.service
check "Prowlarr answers on 127.0.0.1:9696"             U curl -fsS --max-time 5 -o /dev/null http://127.0.0.1:9696/ping
check "Prowlarr takes the key from secrets.sh"         prowlarr_get health
check "Prowlarr's files are yours (~/.config/prowlarr)" bash -c '[[ -d $1 && -z $(find "$1" ! -user "$2" -print -quit) ]]' _ "$TARGET_HOME/.config/prowlarr" "$TARGET_USER"
nidx=$(prowlarr_get indexer 2>/dev/null | jq '[.[] | select(.enable)] | length' 2>/dev/null) || nidx=""
if [[ $nidx =~ ^[1-9] ]]; then pass "Prowlarr has $nidx indexer(s)"
else warn "Prowlarr has no indexers yet" "open http://localhost:9696 → Indexers → Add Indexer (torrra finds nothing until then)"; fi
((prowlarr_was)) || U systemctl --user stop --no-block prowlarr.service 2>/dev/null || true
dbb=$(U podman info --format '{{.Host.DatabaseBackend}}' 2>/dev/null) || dbb=""
if [[ $dbb == sqlite ]]; then pass "podman database: sqlite (ready for Podman 6)"
else warn "podman database: ${dbb:-unknown}" "Podman 6 (Fedora 45) reads only sqlite — podman system migrate --migrate-db"; fi
if [[ $(stat -f -c %T "$TARGET_HOME") == btrfs ]]; then
  # shellcheck disable=SC2088  # literal ~ in labels
  if btrfs subvolume show "$TARGET_HOME/Downloads" >/dev/null 2>&1; then pass "~/Downloads kept out of /home's snapshots (own subvolume)"
  else warn "~/Downloads is inside /home's snapshots" "a deleted download keeps its space until the last snapshot holding it expires"; fi
fi
ports=$(firewall-cmd --list-ports 2>/dev/null) || ports="(firewalld not answering)"
fwsvc=$(firewall-cmd --list-services 2>/dev/null) || fwsvc="(firewalld not answering)"
check "torrent port 6881 open (tcp + udp)"             bash -c "grep -q 6881/tcp <<<'$ports' && grep -q 6881/udp <<<'$ports'"
if [[ $SSH_SERVER == no ]]; then
  check "sshd off (SSH_SERVER=no)"                     bash -c '! systemctl is-enabled --quiet sshd.service'
  check "firewall: no ssh / cockpit"                   bash -c "[[ '$fwsvc' != *'not answering'* ]] && ! grep -qwE 'ssh|cockpit' <<<'$fwsvc'"
else
  check "sshd on (SSH_SERVER=yes)"                     systemctl is-enabled --quiet sshd.service
fi

# ── upstream binaries ────────────────────────────────────────────────────────
section "upstream binaries (lib/upstream.sh)"
for e in "${UPSTREAM[@]}"; do
  IFS='|' read -r name _ tag _ _ bins <<<"$e"; IFS=' ' read -r -a list <<<"$bins"
  [[ $(up_tag "$name") == "$tag" ]] || { fail "$name is not the pinned $tag" "repair puts it back"; continue; }
  for b in "${list[@]}"; do
    f=$TARGET_HOME/.local/bin/$b
    if [[ ! -x $f ]]; then fail "$b missing" "repair puts it back"; continue; fi
    if grep -q 'not found' <<<"$(U ldd "$f" 2>/dev/null)"; then fail "$b has missing libraries"; continue; fi
    check "$b $tag runs" U timeout 10 "$f" --version
  done
done
check "PixelMplus 12 (Japanese pixel font)"          compgen -G "$TARGET_HOME/.local/share/fonts/PixelMplus/PixelMplus12-*.ttf"
for e in "${NERD_FONTS[@]}"; do
  f=${e%%|*}
  check "$f Nerd Font $NERD_FONTS_TAG"                 test "$(up_tag "nerd-$f")" = "$NERD_FONTS_TAG" -a -n "$(compgen -G "$(font_dir "$f")/*.[ot]tf")"
done
[[ $STEAM == yes ]] && check "GE-Proton $(up_tag ge-proton)" test -d "$(proton_dir)/$(up_tag ge-proton)"

# ── applications (do they actually start?) ──────────────────────────────────
section "applications"
check "Brave Origin starts (headless)" \
  U sh -c 'd=$(mktemp -d); timeout 60 brave-origin --headless --disable-gpu --user-data-dir="$d" --dump-dom about:blank 2>/dev/null | grep -q "<html"; r=$?; rm -rf "$d"; exit $r'
check "Claude Code runs"                               U timeout 20 claude --version
check "LazyVim plugins installed"                      test -d "$TARGET_HOME/.local/share/nvim/lazy/LazyVim"
check "torrra $TORRRA_VERSION loads (Python 3.13, libtorrent)" U "$TARGET_HOME/.local/share/pipx/venvs/torrra/bin/python" -I -c 'import sys, importlib.metadata as m, torrra, libtorrent; assert sys.version_info[:2] == (3, 13) and m.version("torrra") == sys.argv[1]' "$TORRRA_VERSION"
check "torrra runs through kawa-torrra (key from secrets.sh)" U bash -c 'test -f /etc/profile.d/kawa-torrra.sh && kawa-torrra --version'
check "torrra uses Prowlarr, and no key in its config" bash -c 'grep -qx "default = \"prowlarr\"" "$1" && ! grep -q api_key "$1"' _ "$TARGET_HOME/.config/torrra/config.toml"
check "mpv in the bar and on the media keys (mpv-mpris)" test -f /etc/mpv/scripts/mpris.so
check "yt-dlp can answer YouTube's challenges (Node.js ≥ 20)" bash -c 'v=$(node --version 2>/dev/null) || exit 1; v=${v#v}; ((${v%%.*} >= 20))'
check "lazygit runs"                                   U lazygit --version
check "qalc runs"                                      U qalc -t 1+1
[[ $STEAM == yes ]] && check "user in gamemode group"  bash -c "id -nG $TARGET_USER | grep -qw gamemode"

# ── snapshots ────────────────────────────────────────────────────────────────
if ((PRE == 0)); then
  section "snapshots"
  check "snapper config for /"                         bash -c 'snapper list-configs | grep -q "^root "'
  # (yours to delete when space runs short — the next move to a Fedora takes a new one)
  if [[ $(snapper -c root list 2>/dev/null) == *"fedokawai baseline"* ]]; then pass "baseline snapshot exists"
  else warn "no baseline snapshot" "deleted? the next move to a new Fedora takes one; or now: sudo snapper -c root create -d \"fedokawai baseline\""; fi
  check "pre/post snapshot around every dnf run"       test -x /usr/local/sbin/kawa-snap -a -f /etc/dnf/libdnf5-plugins/actions.d/fedokawai-snapper.actions
  check "snapshots kept within bounds (a fifth of the disk stays free)" \
    bash -c 'snapper --csvout -c root get-config | grep -qE "^FREE_LIMIT,0\.2"'
fi

# ── theme (only once applied) ────────────────────────────────────────────────
section "theme"
if ((THEMED == 0)); then
  info "not applied — menu → Theme when you want it (setup alone gives dwl with upstream defaults)"
else
  info "applied $(cat "$TARGET_HOME/.local/state/fedokawai/theme-applied")"
  check "every file in sync with the repo"             bash "$REPO_DIR/theme.sh" --user "$TARGET_USER" --check
  if grep -q 'vt.default_red=15,' /proc/cmdline; then pass "console palette active (the login console)"
  else info "console palette recorded for the kernel; it shows after the next boot"; fi
  check "dwl built from src/dwl/config.h"            cmp -s "$REPO_DIR/src/dwl/config.h" "$TARGET_HOME/.local/src/dwl/config.h"
  check "foot config valid"                            U foot --check-config
  check "fuzzel config valid"                          U fuzzel --check-config
  # every fuzzel option the menus use must exist in the installed fuzzel (≥ 1.14 for --mesg)
  fzhelp=$(U fuzzel --help 2>&1) fzbad=""
  for f in $(grep -oE 'args\+?=\([^)]*\)' "$REPO_DIR/bin/kawa-menu" | grep -o -- '--[a-z][a-z-]*' | sort -u); do
    grep -q -- "$f" <<<"$fzhelp" || fzbad+=" $f"
  done
  if [[ -n $fzhelp && -z $fzbad ]]; then pass "every fuzzel option the menus use exists"; else fail "fuzzel options" "${fzbad:-fuzzel missing}"; fi
  check "waybar config valid JSON"                     bash -c "grep -v '^[[:space:]]*//' $TARGET_HOME/.config/waybar/config.jsonc | jq -e ."
  mode=$(readlink "$TARGET_HOME/.config/fedokawai/current"); mode=${mode##*/}
  check "theme link → ${mode:-none} (dark or light)"   test -r "$TARGET_HOME/.config/fedokawai/current/colors.sh"
  check "Qt palette has 3 × 21 colours"                awk -F, '/_colors=/{n++; if (NF!=21) bad=1} END{exit (n!=3 || bad)}' "$TARGET_HOME/.config/fedokawai/current/qt6ct-colors.conf"
  check "GTK and the portal follow the theme (prefer-$mode)" grep -q "prefer-$mode" <<<"$(U gsettings get org.gnome.desktop.interface color-scheme 2>&1)"
  gtk=Fedokawai; [[ $mode == dark ]] && gtk=Fedokawai-dark
  check "GTK 3 theme $gtk (adw-gtk3 + the palette)"    grep -q "'$gtk'" <<<"$(U gsettings get org.gnome.desktop.interface gtk-theme 2>&1)"
  check "no window buttons in title bars (GTK, Brave)"  grep -qx "':'" <<<"$(U gsettings get org.gnome.desktop.wm.preferences button-layout 2>&1)"
  check "folders open in yazi, text in neovim"         test "$(U xdg-mime query default inode/directory) $(U xdg-mime query default text/plain)" = "kawa-files.desktop kawa-edit.desktop"
  check "links open in Brave Origin"                   test "$(U xdg-mime query default x-scheme-handler/https)" = brave-origin.desktop
  check "file dialogs → yazi (FileChooser: termfilechooser, then gtk)" \
    grep -qx 'org.freedesktop.impl.portal.FileChooser=termfilechooser;gtk' "$TARGET_HOME/.config/xdg-desktop-portal/wlroots-portals.conf"
  check "the file dialog runs kawa-pick (executable)" \
    bash -c 'grep -qx "cmd=$1/.local/bin/kawa-pick" "$1/.config/xdg-desktop-portal-termfilechooser/config" && test -x "$1/.local/bin/kawa-pick"' _ "$TARGET_HOME"
  check "Brave starts with screen-share sound (launcher entry → ~/.local/bin/brave-origin)" \
    grep -q "^Exec=$TARGET_HOME/.local/bin/brave-origin" "$TARGET_HOME/.local/share/applications/brave-origin.desktop"
  # set once by Theme; what you choose in Brave afterwards is yours, so only a note
  if jq -e '((.extensions.theme.id // "") != "" or .extensions.theme.system_theme == 1) and .brave.new_tab_page.background.type == "color"' \
       "$TARGET_HOME/.config/BraveSoftware/Brave-Origin/Default/Preferences" >/dev/null 2>&1; then
    pass "Brave in the desktop's colours (GTK mode, ground-coloured new tab)"
  else warn "Brave not in the desktop's colours" "your choice in Brave — or Settings → Appearance → Theme → GTK"; fi
  check "magnet links and .torrent files open in torrra" test "$(U xdg-mime query default x-scheme-handler/magnet) $(U xdg-mime query default application/x-bittorrent)" = "kawa-torrents.desktop kawa-torrents.desktop"
  check "GTK 3 themes find adw-gtk3"                   bash -c 'for t in "" -dark; do f=$(sed -n "s|.*url(\"file://\([^\"]*\)\").*|\1|p" "$1/Fedokawai$t/gtk-3.0/gtk.css"); [[ -r $f ]] || exit 1; done' _ "$TARGET_HOME/.local/share/themes"
  check "monospace → JetBrainsMono Nerd Font"          grep -q JetBrainsMono <<<"$(U fc-match monospace 2>&1)"
  check "Arabic → Noto Naskh Arabic"                   grep -q Naskh <<<"$(U fc-match 'sans-serif:lang=ar' 2>&1)"
  check "Japanese / Chinese / Korean → Noto Sans CJK"  U bash -c 'for l in ja zh-cn ko; do [[ $(fc-match "sans-serif:lang=$l") == *"Noto Sans CJK"* ]] || exit 1; done'
  check "mpv: the theme's colours, players follow switches" test -r "$TARGET_HOME/.config/fedokawai/current/mpv.conf" -a -f "$TARGET_HOME/.config/mpv/scripts/kawa-ipc.lua"
  check "neovim colourscheme gruvbox (remapped)"       U sh -c 'timeout 60 nvim --headless "+lua io.write(vim.g.colors_name or \"\")" +qa 2>&1 | grep -q gruvbox'
  check "icon themes present (Papirus, Adwaita beneath the pointers)" test -d /usr/share/icons/Papirus-Dark -a -d /usr/share/icons/Papirus -a -d /usr/share/icons/Adwaita/cursors
  check "pixel pointers in place (Fedokawai, with their X11 names)" test -s "$TARGET_HOME/.local/share/icons/Fedokawai/cursors/default" \
    -a -L "$TARGET_HOME/.local/share/icons/Fedokawai/cursors/left_ptr" -a -s "$TARGET_HOME/.local/share/icons/default/index.theme"
  check "UI font → DepartureMono Nerd Font"           grep -q DepartureMono <<<"$(U fc-match 'DepartureMono Nerd Font' 2>&1)"
  check "pixel icons → Sumi Icons"                     grep -q 'Sumi Icons' <<<"$(U fc-match 'Sumi Icons' 2>&1)"
  check "pixel icons in the terminal → Sumi Icons Term"  grep -q 'Sumi Icons Term' <<<"$(U fc-match 'Sumi Icons Term' 2>&1)"
  # without a Wayland display it simply runs the command: proves it was built and links
  # two niceties built from src/: without them the desktop works the same, only plainer
  if U env -u WAYLAND_DISPLAY "$TARGET_HOME/.local/bin/kawa-veil" -- true >/dev/null 2>&1; then pass "transitions (kawa-veil) built and runnable"
  else warn "transitions (kawa-veil) not built" "theme and wallpaper changes work, without the fade — repair builds it"; fi
  if [[ -x $TARGET_HOME/.local/bin/kawa-clipkeep ]]; then pass "clipboard keeper (kawa-clipkeep) built"
  else warn "clipboard keeper (kawa-clipkeep) not built" "copy and paste work; a copy just ends with its app — repair builds it"; fi
  check "clipboard and wallpaper windows (fzf ≥ 0.68)" bash -c 'v=$(fzf --version 2>/dev/null) || exit 1; IFS=. read -r a b _ <<<"${v%% *}"; ((a > 0 || b >= 68))'
  check "wallpaper previews (ImageMagick draws sixels)" bash -c 'magick -size 2x2 xc:black sixel:- | grep -q "^.P"'
  art=$TARGET_HOME/.local/share/fedokawai
  check "pixel art drawn for both themes (waves, Fuji, padlock)" \
    test -s "$art/dark/pattern.png" -a -s "$art/dark/scene.png" -a -s "$art/dark/lock.png" \
      -a -s "$art/light/pattern.png" -a -s "$art/light/scene.png" -a -s "$art/light/lock.png"
  if [[ $WALLPAPER_PACK == yes ]]; then
    want=$(grep -cE '^(dark|light) ' "$art/wallpapers.list" 2>/dev/null || echo 0)
    have=$(find "$art/wallpapers" -name '*.png' 2>/dev/null | wc -l)
    if ((have >= want && want > 0)); then pass "wallpaper pack: $have pictures drawn"
    else warn "wallpaper pack: $have of $want pictures drawn" "re-run Theme when online (kawa-wallpaper --pack)"; fi
  fi
  check "music meter (cava) runs"                      U timeout 5 cava -v
  check "boot menu theme installed"                    bash -c 'test -s /boot/grub2/themes/sumi/theme.txt && grep -q /boot/grub2/themes/sumi/theme.txt /boot/grub2/grub.cfg'
  # shellcheck disable=SC2088  # literal ~ in a label
  check "~/.bashrc loads ~/.bashrc.d"                  grep -q bashrc.d "$TARGET_HOME/.bashrc"
fi

# ── live session (only while you are logged in) ─────────────────────────────
if pgrep -u "$TARGET_UID" -x dwl >/dev/null; then
  section "live session"
  check "PipeWire + WirePlumber active"                U systemctl --user is-active --quiet pipewire.service wireplumber.service
  # the portals behind file dialogs and screen sharing start only inside a graphical session
  check "graphical session known to systemd"           U systemctl --user is-active --quiet dwl-session.target graphical-session.target
  portal() { U busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop "$@" 2>/dev/null; }
  fcv=$(portal org.freedesktop.portal.FileChooser version) scs=$(portal org.freedesktop.portal.ScreenCast AvailableSourceTypes)
  check "file dialog portal (FileChooser ${fcv#u })"     bash -c '[[ $1 =~ ^u\ ([0-9]+)$ ]] && ((BASH_REMATCH[1] >= 3))' _ "$fcv"
  check "screen sharing portal: screens + windows"     test "$scs" = "u 3"
  check "\"Share\" sink + source for calls (PipeWire)"  grep -q "Share (as microphone)" <<<"$(U wpctl status 2>/dev/null)"
  if ((THEMED)); then
    for p in waybar mako foot swaybg swayidle udiskie kawa-dwlstatus kawa-nowplaying kawa-cpu lxqt-policykit-agent; do
      check "$p running" pgrep -u "$TARGET_UID" -f "(^|/)$p( |$)"
    done
    # night light is yours to switch off (quick settings): off is not a fault
    if pgrep -u "$TARGET_UID" -x gammastep >/dev/null; then pass "night light running"
    else info "night light off (quick settings turns it on)"; fi
    WD=$(find "/run/user/$TARGET_UID" -maxdepth 1 -name 'wayland-*' ! -name '*.lock' -printf '%f\n' -quit)
    check "clipboard history running"                  pgrep -u "$TARGET_UID" -f 'wl-paste --watch cliphist'
    check "the update season's reminder (timer) running" U systemctl --user is-active --quiet fedokawai-remind.timer
    [[ -x $TARGET_HOME/.local/bin/kawa-clipkeep ]] && check "copies outlive their app (kawa-clipkeep)" pgrep -u "$TARGET_UID" -x kawa-clipkeep
    IFS=' ' read -r cur best < <(U env WAYLAND_DISPLAY="$WD" wlr-randr | awk -v want="$MONITOR_HZ" '
      /^[^ ]/ { if (c) exit } /^    [0-9]+x[0-9]+ px/ { r[++n] = $1; hz[n] = $3 + 0; if ($0 ~ /current/) { c = $1; ch = $3 + 0 } }
      END { for (i = 1; i <= n; i++) if (r[i] == c && hz[i] <= want + 0.5 && hz[i] > b) b = hz[i]; printf "%d %d\n", ch + 0.5, b + 0.5 }')
    check "refresh ${cur:-?} Hz = best available ≤ $MONITOR_HZ" test "${cur:-0}" -ge "${best:-1}"
    check "mako config loads"                          U env WAYLAND_DISPLAY="$WD" makoctl reload
  fi
  # brightness over DDC/CI depends on the monitor having DDC/CI switched on in its own menu
  if [[ -n $(U ddcutil detect --terse 2>/dev/null | grep -m1 '^Display [0-9]') ]]; then
    pass "a monitor answers DDC/CI (brightness control works)"
  else
    warn "no monitor answered DDC/CI" "switch DDC/CI on in the monitor's on-screen menu, then try Super+]"
  fi
fi

((${#FAILS[@]} == 0)) || _out "  ${C_DIM}most of these fix themselves: fedokawai repair${C_RESET}"
summary "verified"; rc=$?
((rc == 0)) || rc=3          # (3: it ran, and things need you — 1 is verify itself failing)
# the outcome, for the menu (Super+U) and repair: WHEN PASSED FAILED WARNINGS
((PRE)) || printf '%s %s %s %s\n' "$(date +%s)" "$PASS" "${#FAILS[@]}" "${#WARNS[@]}" \
  | write_file "$STATE_DIR/last-verify" 0644 || true
exit "$rc"
