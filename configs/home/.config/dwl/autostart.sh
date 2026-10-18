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
  "$XDG_RUNTIME_DIR/kawa-drives"

# Hand this session to systemd --user and D-Bus, so the services they start on demand —
# the portals behind every file dialog and screen share, the notification daemon — open
# their windows here. Then tell systemd a graphical session is running (the portals start
# only inside one). Stopping the session target first ends anything an earlier login
# left behind — your user manager outlives a login (linger keeps it, so update, repair and
# verify can reach your services even from a text console).
# Every GTK program's Open and Save dialogs through the portal — yazi (kawa-pick) — the GTK 3
# ones too (they draw their own dialog unless told; GTK 4 asks the portal by itself). Only a
# program that builds GTK's dialog itself keeps it — LibreOffice does: its dialogs are GTK's,
# in the desktop's GTK theme. Exported before anything starts, handed to D-Bus and systemd
export GTK_USE_PORTAL=1 GDK_DEBUG=portals
SESSION_VARS="WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE GTK_USE_PORTAL GDK_DEBUG"
# shellcheck disable=SC2086  # a list of names
dbus-update-activation-environment --systemd $SESSION_VARS 2>/dev/null \
  || systemctl --user import-environment $SESSION_VARS
systemctl --user stop dwl-session.target 2>/dev/null
systemctl --user start dwl-session.target
# the update season's reminder (fedokawaii remind): a look two minutes in, then every six
# hours; it stops with the session
systemctl --user start fedokawaii-remind.timer 2>/dev/null
# GRUB's hidden menu: this boot counts as successful once the desktop has run two minutes
# (the timer stops with the session: one that ends sooner leaves the boot unmarked)
systemctl --user start grub-boot-success.timer 2>/dev/null

# keep CMD… — run a session helper and start it again should it ever crash; a clean exit
# (status 0) ends it, and five crashes inside a minute give up with a notice rather than
# loop; one that is not installed is said once. dwl ends every one of these with the
# session (they share its process group).
keep() {
  command -v "$1" >/dev/null || {
    notify-send -a desktop -u critical "$1 is not installed" "the session runs without it; fedokawaii repair puts it back" 2>/dev/null
    return 127
  }
  n=0 t0=$(date +%s)
  while :; do
    "$@" && return 0
    now=$(date +%s)
    [ $((now - t0)) -gt 60 ] && n=0 t0=$now
    n=$((n + 1))
    if [ "$n" -ge 5 ]; then
      notify-send -a desktop -u critical "$1 keeps stopping" "it was restarted 4 times in a minute; see ~/.cache/dwl.log" 2>/dev/null
      return 1
    fi
    sleep 1
  done
}

kawa-display </dev/null                            # resolution + refresh rate
kawa-theme apply </dev/null                        # dark or light: GTK/Qt settings, wallpaper
keep waybar </dev/null >"$HOME/.cache/waybar.log" 2>&1 &
# quick settings (the bar's cat, Super+X): drawn once, then hidden until asked, so it opens
# at once — kawa-quick asks it (SIGUSR1)
keep kawa-panel </dev/null >"$HOME/.cache/kawa-panel.log" 2>&1 &
mako </dev/null &                                  # notifications (if it ever stops, D-Bus starts it
                                                   # again with the next one — so no keep here)
# nmtui (quick settings → network) and other newt dialogs in the terminal's own 16 colours,
# so they follow the theme like everything in foot; every terminal inherits it from here
export NEWT_COLORS='root=lightgray,default;border=gray,default;window=lightgray,default;shadow=default,default;title=white,default;button=lightgray,black;actbutton=black,red;compactbutton=lightgray,default;checkbox=lightgray,default;actcheckbox=black,brightcyan;entry=white,black;disentry=gray,black;label=lightgray,default;listbox=lightgray,default;actlistbox=white,black;sellistbox=lightgray,black;actsellistbox=black,red;textbox=lightgray,default;acttextbox=white,black;helpline=gray,default;roottext=gray,default;emptyscale=,black;fullscale=,red'
keep foot --server </dev/null &                    # Super+Return → footclient (instant)
keep /usr/libexec/lxqt-policykit-agent </dev/null &   # auth dialogs (an app asking for your password;
                                                   # Fedora keeps it out of PATH, in libexec)
keep udiskie </dev/null &                          # drives: open when plugged in (~/.config/udiskie, kawa-drives)
keep kawa-drives watch </dev/null &               # the bar's USB mark and ~/Drives, on every change
keep kawa-clipkeep </dev/null &                   # a copy outlives the app it came from
keep wl-paste --watch kawa-clip --store </dev/null &   # clipboard history (Super+V): text and pictures
gammastep -l "$NIGHT_LIGHT" -t 6500:4200 </dev/null &   # night light (quick settings turns it off and on)
kawa-steam --warm </dev/null &                    # Steam, quietly, a minute in (its menu turns it off; STEAM=no: nothing)

# away: nothing locks and nothing sleeps — the screens only go dark after an hour (wlopm: the
# outputs stay, so windows stay where they are; a key wakes them). Sleep is yours to ask for:
# the power menu, or a lock (Super+Escape) left locked for 90 s (kawa-lock --sleep). Every
# sleep is locked first
keep swayidle -w \
  timeout 3600 "wlopm --off '*'" resume "wlopm --on '*'" \
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
