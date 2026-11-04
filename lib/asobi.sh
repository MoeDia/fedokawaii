# lib/asobi.sh — ASOBI 遊び, the play world (setup.sh's s_asobi; update and repair run it again, it
# changes only what differs): a user of its own that holds every game, on its own VT, and nothing
# of the desktop's user. Its whole design: docs/design-system.md §14, the Learn piece "asobi".
#   /home/asobi            the world's home: a Btrfs subvolume, out of /home's snapshots and backups
#   /home/.asobi/snapshots its snapshots, read-only (root's); clean = the world as installed
#   /home/.asobi/drop      the one folder shared with the desktop's user (~/Drop there)
# shellcheck shell=bash
ASOBI_USER=asobi ASOBI_HOME=/home/asobi ASOBI_ROOT=/home/.asobi ASOBI_GROUP=asobi-drop
ASOBI_DROP=$ASOBI_ROOT/drop ASOBI_SNAPS=$ASOBI_ROOT/snapshots
# Flathub's own address (flathub.org/setup/Fedora); Steam (Valve's client, Flathub's package) and
# Bottles (usebottles.com: Flathub is its official way) installed per user, in the world's home
ASOBI_FLATHUB=https://dl.flathub.org/repo/flathub.flatpakrepo
ASOBI_APPS=(com.valvesoftware.Steam com.usebottles.bottles)

as_asobi() {   # as_asobi CMD… — as the world's user, with a clean environment
  (cd / && runuser -u "$ASOBI_USER" -- env -i HOME="$ASOBI_HOME" USER="$ASOBI_USER" LOGNAME="$ASOBI_USER" \
    PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 "$@")
}

# the account: no password (locked), no shell, no wheel, no subordinate ids; its home made first, as
# a subvolume, so the snapshots can hold it whole and /home's own snapshots and backups cannot
asobi_account() {
  [[ $(stat -f -c %T /home) == btrfs ]] || die "the play world needs /home on Btrfs (it is $(stat -f -c %T /home))"
  getent group gamemode >/dev/null || systemd-sysusers gamemode.conf
  if ! btrfs subvolume show "$ASOBI_HOME" >/dev/null 2>&1; then
    [[ -e $ASOBI_HOME ]] && die "$ASOBI_HOME is there and is no subvolume: moved away by hand, it can be made"
    run btrfs subvolume create "$ASOBI_HOME"
  fi
  if ! getent passwd "$ASOBI_USER" >/dev/null; then
    run useradd --no-create-home --home-dir "$ASOBI_HOME" --shell /usr/sbin/nologin \
      --comment "ASOBI the play world" -K SUB_UID_COUNT=0 -K SUB_GID_COUNT=0 "$ASOBI_USER"
  fi
  usermod -a -G gamemode "$ASOBI_USER"          # (GameMode's nice: limits.d, its own group)
  passwd -l "$ASOBI_USER" >/dev/null 2>&1 || true
  chown "$ASOBI_USER:$ASOBI_USER" "$ASOBI_HOME"; chmod 0700 "$ASOBI_HOME"
  restorecon "$ASOBI_HOME"
}

# the world's two neighbours on disk: the snapshots (root's alone), and the one folder shared with
# the desktop's user: a group of two, new files the group's by the set-group-id bit
asobi_drop() {
  getent group "$ASOBI_GROUP" >/dev/null || run groupadd "$ASOBI_GROUP"
  usermod -a -G "$ASOBI_GROUP" "$ASOBI_USER"
  usermod -a -G "$ASOBI_GROUP" "$TARGET_USER"     # (from the next login)
  install -d -m 0755 -o root -g root "$ASOBI_ROOT"
  install -d -m 0700 -o root -g root "$ASOBI_SNAPS"
  install -d -m 2770 -o root -g "$ASOBI_GROUP" "$ASOBI_DROP"
  restorecon "$ASOBI_ROOT" "$ASOBI_SNAPS" "$ASOBI_DROP"
  as_user bash -c 'cd && if [[ ! -e Drop || -L Drop ]]; then ln -sfn "$1" Drop; fi' _ "$ASOBI_DROP"
}

asobi_system() {
  local s="$REPO_DIR/system/asobi" u; u=$(id -u "$ASOBI_USER")
  install -m 0755 "$s/kawa-asobi-root" /usr/local/sbin/kawa-asobi-root
  install -m 0755 "$s/kawa-asobi-session" /usr/local/bin/kawa-asobi-session
  write_file /etc/systemd/system/kawa-asobi.service <"$s/kawa-asobi.service"
  write_file /etc/systemd/system/kawa-asobi-watch.service <"$s/kawa-asobi-watch.service"
  write_file /etc/systemd/system/kawa-asobi-op@.service <"$s/kawa-asobi-op@.service"
  write_file /etc/pam.d/kawa-asobi <"$s/kawa-asobi.pam"
  sed "s/DESK_USER/$TARGET_USER/g" "$s/kawa-asobi.rules" | write_file /etc/polkit-1/rules.d/60-kawa-asobi.rules
  write_file /etc/xkb/rules/kawa-asobi <"$s/xkb-rules"
  write_file /etc/xkb/symbols/kawa-asobi <"$s/xkb-symbols"
  write_file /etc/xkb/types/kawa-asobi <"$s/xkb-types"
  write_file /etc/gamemode.ini <"$s/gamemode.ini"
  # the world's user manager (its sound, its portals) behind the same walls as its session
  sed -n '/^# the walls/,/^RestrictSUIDSGID/p' "$s/kawa-asobi.service" \
    | { printf '# installed by setup.sh (s_asobi): the play world'"'"'s user manager behind the walls of its session\n[Service]\n'; grep -v '^#'; } \
    | write_file "/etc/systemd/system/user@$u.service.d/50-kawa-asobi.conf"
  printf 'hz=%s\n' "${MONITOR_HZ:-144}" | write_file /etc/fedokawaii/asobi.conf
  restorecon -R /etc/systemd/system/kawa-asobi* "/etc/systemd/system/user@$u.service.d" /etc/pam.d/kawa-asobi \
    /etc/polkit-1/rules.d/60-kawa-asobi.rules /etc/xkb /etc/gamemode.ini /etc/fedokawaii/asobi.conf \
    /usr/local/sbin/kawa-asobi-root /usr/local/bin/kawa-asobi-session 2>/dev/null || true
  systemctl daemon-reload
}

# the world's programs, each in its own Flatpak sandbox: Steam kept off the mounts, the disks' D-Bus
# service and the pictures it asks for by default; both given the drop folder and nothing of /home
asobi_flatpaks() {
  run as_asobi flatpak --user remote-add --if-not-exists flathub "$ASOBI_FLATHUB"
  run as_asobi flatpak --user install -y --noninteractive --or-update flathub "${ASOBI_APPS[@]}"
  as_asobi flatpak --user override com.valvesoftware.Steam --nofilesystem=/mnt --nofilesystem=/media \
    --nofilesystem=/run/media --nofilesystem=xdg-music --nofilesystem=xdg-pictures \
    --system-no-talk-name=org.freedesktop.UDisks2 --filesystem="$ASOBI_DROP"
  as_asobi flatpak --user override com.usebottles.bottles --filesystem="$ASOBI_DROP"
}

# clean: the world as installed, what "reset" can always go back to (taken once)
asobi_clean() {
  [[ -e $ASOBI_SNAPS/clean ]] && return 0
  run btrfs subvolume snapshot -r "$ASOBI_HOME" "$ASOBI_SNAPS/clean"
}

s_asobi() {
  asobi_account
  asobi_drop
  asobi_system
  asobi_flatpaks
  asobi_clean
}
