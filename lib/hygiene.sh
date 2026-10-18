#!/usr/bin/env bash
# shellcheck disable=SC2034  # lists consumed by verify.sh and setup.sh
# lib/hygiene.sh — one tool per job, nothing doubled, nothing fighting.
#
#   the scan   (read-only; verify.sh shows it, repair and update act on it)
#     hy_duplicates      packages installed twice (a transaction cut off half way)
#     hy_dnf_problems    what `dnf check` finds: broken dependencies, obsoleted, duplicates
#     hy_services        system services enabled that fight one of the desktop's own
#     hy_user_services   the same, among your own services (notifications, sound)
#     hy_display_manager what boots the login: greetd, and nothing else
#     hy_unneeded        dependencies nothing needs any more (dnf autoremove would take them)
#     hy_rpmnew          configuration files a package update could not merge (yours to look at)
#     hy_leftovers       what a stopped run left: half-made toolkits, old temp folders
#   the heals  (as root, in setup.sh: r_hygiene — repair, update, after a move)
#
# Every package the desktop does not want at all is FORBIDDEN_PKGS (lib/manifest.sh):
# update and repair take those out. This file is about the rest — what is installed or
# enabled twice, and what fights.

# services that fight one of the desktop's own: UNIT|what it fights
CONFLICT_SERVICES=(
  "power-profiles-daemon.service|tuned, the performance profile: both set the CPU's power policy"
  "gdm.service|greetd, the login: two login managers race for the screen"
  "sddm.service|greetd, the login"
  "lightdm.service|greetd, the login"
  "lxdm.service|greetd, the login"
  "systemd-networkd.service|NetworkManager: two network managers configure the same cards"
  "iwd.service|NetworkManager's Wi-Fi (wpa_supplicant): two programs drive the same radio"
)
# your own services that fight the session's: UNIT|what it fights
CONFLICT_USER_SERVICES=(
  "dunst.service|mako: only one program can show notifications"
  "swaync.service|mako: only one program can show notifications"
  "pulseaudio.service|PipeWire: two sound servers for one sound card"
  "pulseaudio.socket|PipeWire: two sound servers for one sound card"
)

hy_duplicates()   { dnf -q repoquery --duplicates --qf '%{name}-%{evr}.%{arch}\n' 2>/dev/null || true; }
hy_dnf_problems() { dnf -q check 2>&1 | grep -v '^[[:space:]]*$' || true; }
hy_unneeded()     { dnf -q repoquery --unneeded --qf '%{name}\n' 2>/dev/null | sort -u || true; }
hy_rpmnew()       { find /etc \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null | sort || true; }

# hy_on SYSTEMCTL… UNIT — the unit starts by itself (enabled) or runs now. By what is-enabled
# says, not its status: it answers 0 for a unit that has no [Install] at all (static — dunst,
# which D-Bus starts on demand), and such a unit fights only while it runs
hy_on() {
  local u=${*: -1} st
  st=$("${@:1:$#-1}" is-enabled "$u" 2>/dev/null) || true
  [[ $st == enabled || $st == enabled-runtime ]] && return 0
  "${@:1:$#-1}" is-active --quiet "$u" 2>/dev/null
}
hy_services() {   # → "UNIT|why" for every fighting system service that is enabled or running
  local e u why
  for e in "${CONFLICT_SERVICES[@]}"; do
    u=${e%%|*} why=${e#*|}
    if hy_on systemctl "$u"; then printf '%s|%s\n' "$u" "$why"; fi
  done
}
hy_user_services() {   # hy_user_services → "UNIT|why", as above, among the desktop user's services
  local e u why
  for e in "${CONFLICT_USER_SERVICES[@]}"; do
    u=${e%%|*} why=${e#*|}
    if hy_on as_user systemctl --user "$u"; then printf '%s|%s\n' "$u" "$why"; fi
  done
}
hy_display_manager() {   # → the unit display-manager.service points at ("" when none)
  local t; t=$(readlink /etc/systemd/system/display-manager.service 2>/dev/null) || t=""
  printf '%s' "${t##*/}"
}
hy_leftovers() {   # → paths a stopped run left behind (safe to remove: nothing uses them)
  local d
  # (the old one only beside a toolkit: alone, it is the toolkit, and toolkit_back puts it back)
  [[ -e /usr/local/lib/fedokawaii.new ]] && echo /usr/local/lib/fedokawaii.new
  [[ -e /usr/local/lib/fedokawaii.old && -d /usr/local/lib/fedokawaii ]] && echo /usr/local/lib/fedokawaii.old
  # temp folders of runs that ended more than a day ago (a live run's is younger, and in use)
  find /var/tmp -maxdepth 1 -name 'fedokawaii.*' -user root -mmin +1440 2>/dev/null || true
}
