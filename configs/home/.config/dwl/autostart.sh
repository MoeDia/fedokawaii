#!/bin/sh
# ~/.config/dwl/autostart.sh — run by dwl (-s). Its stdin is dwl's status stream; only the
# status reader at the end keeps it, everything else reads /dev/null instead (not a closed
# stdin: wl-paste refuses to start without one, and gave up five times at every login).
# Run by hand while the session runs, it would start every helper a second time (a second
# bar, the drives' notices twice) and wipe the bar's files: only dwl's pipe is taken.
[ -p /dev/stdin ] || {
  echo "autostart.sh: dwl runs this at login, with its status as input; to start the session's helpers again, log out and in" >&2
  exit 2
}
# the session's settings (night light…); should the file be gone, the rest still starts
[ -r "$HOME/.config/fedokawaii/env" ] && . "$HOME/.config/fedokawaii/env"
# what the helpers keep for one session only: $XDG_RUNTIME_DIR outlives a login (linger),
# so the last session's bar state, notice id, monitor list and open drives go now
rm -rf "$XDG_RUNTIME_DIR/dwl-bar" "$XDG_RUNTIME_DIR/kawa-ddc-buses" "$XDG_RUNTIME_DIR/kawa-osd-id" \
  "$XDG_RUNTIME_DIR/kawa-drives" "$XDG_RUNTIME_DIR/kawa-screens" "$XDG_RUNTIME_DIR/kawa-downloads"

# Hand this session to systemd --user, so the services D-Bus starts on demand — the portals
# behind every file dialog and screen share, the notification daemon — open their windows
# here (Fedora's D-Bus, dbus-broker, starts each through systemd: its environment is theirs). Then tell systemd a graphical session is running (the portals start
# only inside one). Stopping the session target first ends anything an earlier login
# left behind — your user manager outlives a login (linger keeps it, so update, repair and
# verify can reach your services even from a text console).
# Every GTK program's Open and Save dialogs through the portal — yazi (kawa-pick) — the GTK 3
# ones too (they draw their own dialog unless told; GTK 4 asks the portal by itself). Only a
# program that builds GTK's dialog itself keeps it — LibreOffice does: its dialogs are GTK's,
# in the desktop's GTK theme. Exported before anything starts, handed to systemd
export GTK_USE_PORTAL=1 GDK_DEBUG=portals
# the session's own notices: the window icon (Sumi Icons' "window", written as its bytes —
# icons.sh is bash's, this is sh), two spaces, then the title, as every notice of the desktop
SEAL=$(printf '\363\276\200\256')
SESSION_VARS="WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE GTK_USE_PORTAL GDK_DEBUG"
# shellcheck disable=SC2086  # a list of names
systemctl --user import-environment $SESSION_VARS \
  || notify-send -a desktop -u critical -- "$SEAL  session" \
       "its settings did not reach systemd: apps it starts may miss the display or the file dialog; see ~/.cache/dwl.log" 2>/dev/null
systemctl --user stop dwl-session.target 2>/dev/null
systemctl --user start dwl-session.target
# the update season's reminder (fedokawaii remind): a look two minutes in, then every six
# hours; it stops with the session
systemctl --user start fedokawaii-remind.timer 2>/dev/null
# the weekly tidy of your home (kawa-tidy): looked at 20 minutes in, never while the login settles
systemctl --user start kawa-tidy.timer 2>/dev/null
# the wallpaper every 4 hours (Super+W: "a new one every 4 hours", off unless switched on)
systemctl --user start kawa-wallpaper-next.timer 2>/dev/null
# GRUB's hidden menu: this boot counts as successful once the desktop has run two minutes
# (the timer stops with the session: one that ends sooner leaves the boot unmarked)
systemctl --user start grub-boot-success.timer 2>/dev/null

# keep CMD… — run a session helper and start it again should it ever crash; a clean exit
# (status 0) ends it, and five crashes inside a minute give up with a notice rather than
# loop; one that is not installed is said once. swayidle alone is never given up on (it locks
# the screen before every sleep): five crashes in a minute pause it 30 s instead, with sleep
# blocked meanwhile (systemd-inhibit), and a notice the first time. dwl ends every one of
# these with the session (they share its process group).
keep() {
  always=0; [ "$1" = swayidle ] && always=1
  command -v "$1" >/dev/null || {
    notify-send -a desktop -u critical -- "$SEAL  $1 is not installed" "the session runs without it; fedokawaii repair puts it back" 2>/dev/null
    return 127
  }
  n=0 t0=$(date +%s) said=0
  while :; do
    "$@" && return 0
    now=$(date +%s)
    [ $((now - t0)) -gt 60 ] && n=0 t0=$now
    n=$((n + 1))
    if [ "$n" -ge 5 ] && [ "$always" = 1 ]; then
      [ "$said" = 1 ] || notify-send -a desktop -u critical -- "$SEAL  $1 keeps stopping" \
        "it is started again every 30 s, and the computer cannot sleep meanwhile; see ~/.cache/dwl.log" 2>/dev/null
      said=1
      systemd-inhibit --what=sleep --mode=block --who="$1" --why="$1 keeps stopping: nothing would lock before a sleep" sleep 30
      n=0 t0=$(date +%s)
      continue
    fi
    if [ "$n" -ge 5 ]; then
      notify-send -a desktop -u critical -- "$SEAL  $1 keeps stopping" "it was restarted 4 times in a minute; see ~/.cache/dwl.log" 2>/dev/null
      return 1
    fi
    sleep 1
  done
}

kawa-display </dev/null                            # resolution + refresh rate
kawa-theme apply </dev/null                        # dark or light: GTK/Qt settings, wallpaper
kawa-state restore </dev/null                      # what you set, as you left it, before the bar draws
                                                   #   (do not disturb, Bluetooth, brightness; kawa-state)
kawa-night restore </dev/null                      # night light: as you last left it (on or off, its warmth)
kawa-game restore </dev/null &                     # a session ended mid-game: the desktop's tuned profile back
kawa-glass ensure </dev/null                       # the terminal's glass file, there before foot starts (foot.ini
                                                   #   includes it: foot refuses its config without it)
keep waybar </dev/null >"$HOME/.cache/waybar.log" 2>&1 &
# quick settings (the bar's cat, Super+X): drawn once, then hidden until asked, so it opens
# at once — kawa-quick and kawa-menu ask it through its fifo (kawa-panel.in)
keep kawa-panel </dev/null >"$HOME/.cache/kawa-panel.log" 2>&1 &
# notifications: mako's own unit, once — started here and by D-Bus with the first notice
# alike, so never twice (a mako of its own beside D-Bus's started two, and the loser
# failed the unit: "degraded"); if it ever stops, D-Bus starts it again with the next one
systemctl --user --no-block start mako.service
# started from a snapshot in the boot menu (its root a layer in memory over it: setup.sh
# snap_boot): said once, and kept on screen until dismissed — nothing done here is kept
# what only you can do (a cable to plug …): kept until done, shown at every login
kawa-foryou show 2>/dev/null
if grep -q '/\.snapshots/' /proc/cmdline; then
  notify-send -a desktop -u critical -- "史  a snapshot" \
    "the system as it was — nothing done here is kept. Super+U → snapshots to restore it" 2>/dev/null &
fi
# nmtui (quick settings → network) and other newt dialogs in the terminal's own 16 colours,
# so they follow the theme like everything in foot; every terminal inherits it from here
export NEWT_COLORS='root=lightgray,default;border=gray,default;window=lightgray,default;shadow=default,default;title=white,default;button=lightgray,black;actbutton=black,red;compactbutton=lightgray,default;checkbox=lightgray,default;actcheckbox=black,brightcyan;entry=white,black;disentry=gray,black;label=lightgray,default;listbox=lightgray,default;actlistbox=white,black;sellistbox=lightgray,black;actsellistbox=black,red;textbox=lightgray,default;acttextbox=white,black;helpline=gray,default;roottext=gray,default;emptyscale=,black;fullscale=,red'
keep foot --server </dev/null &                    # Super+Return → footclient (instant)
kawa-warm --start </dev/null >/dev/null 2>&1 &      # notes, the clipboard, the system menu: running, put away (their keys show them in the frame)
keep /usr/libexec/lxqt-policykit-agent </dev/null &   # auth dialogs (an app asking for your password;
                                                   # Fedora keeps it out of PATH, in libexec)
keep udiskie </dev/null &                          # drives: open when plugged in (~/.config/udiskie, kawa-drives)
keep kawa-drives watch </dev/null &               # the bar's USB mark and ~/Drives, on every change
keep kawa-downloads watch </dev/null &            # the bar's download mark, and a notice as one finishes
keep kawa-clipkeep </dev/null &                   # a copy outlives the app it came from
keep wl-paste --watch kawa-clip --store </dev/null &   # clipboard history (Super+V): text and pictures
kawa-steam --warm </dev/null &                    # Steam, quietly, a minute in (its menu turns it off; STEAM=no: nothing)
kawa-steam --guard </dev/null &                   # Steam closed properly before a restart or shut down,
                                                   #   whoever asks (its saves to Steam Cloud; STEAM=no: nothing)

# away 15 minutes: the screensaver, the lock behind it (the first key or move ends the one
# and brings up the other; the screensaver switched off in quick settings: the lock at once);
# away 30 minutes: the screens dark (the outputs stay, so windows stay where they are; a key
# wakes them). Never while something plays (kawa-idle): a video holds the idle timer itself
# (Brave and mpv ask the compositor: idle-inhibit), music and anything holding logind's idle
# lock make kawa-idle wait until they end. Sleep is yours to ask for: the power menu, or a lock
# (Super+Escape) left locked for 90 s (kawa-lock --sleep). Every sleep is dark and locked
# first (so swayidle, which does it, is never given up on: see keep); as the machine wakes the
# screens light again and the journal notes the wake and whether the lock held
keep swayidle -w \
  timeout 900 'kawa-idle away' resume 'kawa-idle back' \
  timeout 1800 'kawa-idle dark' resume 'kawa-idle back; kawa-lock --screens on' \
  after-resume 'kawa-lock --resumed' \
  before-sleep 'kawa-lock --now' </dev/null &

# yours: ~/.config/dwl/autostart.local.sh, if you made one — the theme never writes it. It
# runs on its own, beside the session (it can never hold the bar back): end each program
# that keeps running with &, as here (handbook §42.1)
[ -f "$HOME/.config/dwl/autostart.local.sh" ] && sh "$HOME/.config/dwl/autostart.local.sh" </dev/null >>"$HOME/.cache/dwl.log" 2>&1 &

# When dwl ends, everything this session started goes with it: logging out, dwl signals this
# script's process group; should dwl crash, its status stream just ends, and no signal comes.
# What is no Wayland program (udiskie) would outlive it then, and run twice from the next
# login on — and anything started in a group of its own (waybar's scripts) is reached too.
leave() { trap '' TERM HUP; pkill -TERM -s 0 2>/dev/null; exit 0; }
trap leave TERM HUP

# the bar's workspaces, layout, title and keyboard layout, from dwl's status on stdin (should
# the reader give up, the stream is still read to its end: the session lasts while dwl does)
keep kawa-dwlstatus || cat >/dev/null
leave
