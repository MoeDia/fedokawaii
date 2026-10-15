#!/bin/sh
# ~/.config/dwl/autostart.sh — run by dwl (-s). Its stdin is dwl's status stream; only the
# status reader at the end keeps it, everything else closes it (<&-).
. "$HOME/.config/fedokawaii/env"
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
SESSION_VARS="WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE"
# shellcheck disable=SC2086  # a list of names
dbus-update-activation-environment --systemd $SESSION_VARS 2>/dev/null \
  || systemctl --user import-environment $SESSION_VARS
systemctl --user stop dwl-session.target 2>/dev/null
systemctl --user start dwl-session.target
# the update season's reminder (fedokawaii remind): a look two minutes in, then every six
# hours; it stops with the session
systemctl --user start fedokawaii-remind.timer 2>/dev/null

# keep CMD… — run a session helper and start it again should it ever crash; a clean exit
# (status 0) ends it, and five crashes inside a minute give up with a notice rather than
# loop. dwl ends every one of these with the session (they share its process group).
keep() {
  n=0 t0=$(date +%s)
  while :; do
    "$@" && return 0
    now=$(date +%s)
    [ $((now - t0)) -gt 60 ] && n=0 t0=$now
    n=$((n + 1))
    if [ "$n" -ge 5 ]; then
      notify-send -u critical "$1 keeps stopping" "it was restarted 4 times in a minute; see ~/.cache/dwl.log" 2>/dev/null
      return 1
    fi
    sleep 1
  done
}

kawa-display <&-                                   # resolution + refresh rate
kawa-theme apply <&-                               # dark or light: GTK/Qt settings, wallpaper
keep waybar <&- >"$HOME/.cache/waybar.log" 2>&1 &
mako <&- &                                         # notifications (if it ever stops, D-Bus starts it
                                                   # again with the next one — so no keep here)
# nmtui (quick settings → network) and other newt dialogs in the terminal's own 16 colours,
# so they follow the theme like everything in foot; every terminal inherits it from here
export NEWT_COLORS='root=lightgray,default;border=gray,default;window=lightgray,default;shadow=default,default;title=white,default;button=lightgray,black;actbutton=black,red;compactbutton=lightgray,default;checkbox=lightgray,default;actcheckbox=black,brightcyan;entry=white,black;disentry=gray,black;label=lightgray,default;listbox=lightgray,default;actlistbox=white,black;sellistbox=lightgray,black;actsellistbox=black,red;textbox=lightgray,default;acttextbox=white,black;helpline=gray,default;roottext=gray,default;emptyscale=,black;fullscale=,red'
keep foot --server <&- &                           # Super+Return → footclient (instant)
# auth dialogs: the agent wherever this Fedora puts it (its own autostart entry names it;
# it has moved between /usr/bin and /usr/libexec before)
polkit=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' /etc/xdg/autostart/lxqt-policykit-agent.desktop 2>/dev/null | head -n1)
case $polkit in /*) ;; ?*) polkit=$(command -v "$polkit") ;; esac
for p in "$polkit" /usr/libexec/lxqt-policykit-agent /usr/bin/lxqt-policykit-agent; do
  [ -x "$p" ] && { keep "$p" <&- & break; }
done
keep udiskie <&- &                                 # drives: open when plugged in (~/.config/udiskie, kawa-drives)
command -v kawa-clipkeep >/dev/null && keep kawa-clipkeep <&- &   # a copy outlives the app it came from
keep wl-paste --watch cliphist store <&- &         # clipboard history (Super+V)
gammastep -l "$NIGHT_LIGHT" -t 6500:4200 <&- &     # night light (quick settings turns it off and on)

# a notice 10 s before · lock 10 min · screens off 15 min (wlopm: the outputs stay, so windows stay where they
# are) · lock before suspend
keep swayidle -w \
  timeout 590 'notify-send -a desktop -u low -t 9500 "$(. ~/.config/fedokawaii/icons.sh; printf %s "$ICON_LOCK")  locking in 10 s"' \
  timeout 600 'kawa-lock' \
  timeout 900 "wlopm --off '*'" resume "wlopm --on '*'" \
  before-sleep 'kawa-lock --now' <&- &

# yours: ~/.config/dwl/autostart.local.sh, if you made one — the theme never writes it. It
# runs on its own, beside the session (it can never hold the bar back): end each program
# that keeps running with &, as here (handbook §15.1)
[ -f "$HOME/.config/dwl/autostart.local.sh" ] && sh "$HOME/.config/dwl/autostart.local.sh" <&- >>"$HOME/.cache/dwl.log" 2>&1 &

# the bar's workspaces, layout, title and keyboard layout, from dwl's status on stdin
keep kawa-dwlstatus
