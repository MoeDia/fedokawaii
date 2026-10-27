#!/usr/bin/env bash
# tests/look/test_launcher.sh — what the launcher (kawa-panel's) lists, and how it is drawn:
#   · the package entries hidden by an entry of the same name (NoDisplay): exactly this set,
#     each still a whole entry (Type, Name, Exec) so the program keeps working
#   · every entry of the desktop's own shows a window program's official icon (a name a
#     package installs into hicolor, or the app's own picture by its path) or our seal — its
#     kanji (X-Fedokawaii-Kanji), drawn by the panel in a 22 × 22 seal: key ground, edge2
#     frame, accent_text kanji, a kanji Sumi UI draws — never an icon pack's name, never
#     foot's or neovim's for what is not them
#   · no icon pack anywhere: no Papirus in a config, a script or the manifest (but as retired)
#   · the icons drawn at the row's size (22 px, forced: never a bigger copy)
#   · GTK 3 and 4: windows, dialogs, decorations and popovers square, no shadow, no margin
#     around them; buttons square, a radio button round
. "$(dirname "$0")/../lib/harness.sh"
sandbox
A=$REPO/configs/home/.local/share/applications
# key FILE KEY — the value of KEY in FILE's [Desktop Entry] ("" when absent)
key() { awk -F= -v k="$2" '/^\[/ { s = ($0 == "[Desktop Entry]") } s && $1 == k { sub(/^[^=]*=/, ""); print; exit }' "$1"; }

case_ "the package entries hidden from the launcher: exactly these, each a whole entry"
HIDDEN="foot foot-server mpv nvim org.pwmt.zathura qt6ct visidata"
got=$(for f in "$A"/*.desktop; do n=${f##*/}; n=${n%.desktop}
        [[ $n == kawa-* ]] && continue; [[ $(key "$f" NoDisplay) == true ]] && printf '%s ' "$n"; done)
eq "$(tr ' ' '\n' <<<"${got% }" | LC_ALL=C sort | tr '\n' ' ')" "$(tr ' ' '\n' <<<"$HIDDEN" | LC_ALL=C sort | tr '\n' ' ')"
for n in $HIDDEN; do
  f=$A/$n.desktop
  [[ $(key "$f" Type) == Application && -n $(key "$f" Name) && -n $(key "$f" Exec) ]] && _ok \
    || _no "$n.desktop: not a whole entry (Type=Application, Name, Exec)"
done
eq "$(key "$A/kawa-edit.desktop" NoDisplay)" "" "Editor (neovim through kawa-term) is listed, in place of neovim's own"
eq "$(key "$A/kawa-play.desktop" NoDisplay)" true "kawa-play: an opener only"
eq "$(key "$A/kawa-tables.desktop" NoDisplay)" "" "Tables (VisiData through kawa-term) is listed, in place of visidata's own"
eq "$(key "$A/btop.desktop" NoDisplay)" "" "System monitor (btop.desktop, in place of btop's own) is listed"
eq "$(key "$A/btop.desktop" Exec)" "@HOME@/.local/bin/kawa-term --float --once btop btop 140x41 -- btop" "System monitor: the bar's memory window"
has "$(cat "$REPO/configs/home/.config/waybar/config.jsonc")" '"on-click": "setsid -f kawa-term --float --once btop btop 140x41 -- btop"' "… the same as the bar's"

case_ "every program a person opens has a listed entry (fixtures/launched.txt); all else installed says why not (fixtures/not-launched.txt)"
FX=$REPO/tests/look/fixtures
names() { grep -v '^#' "$1" | awk 'NF { print $1 }'; }
# what the toolkit installs: the manifest (both GPUs, with Steam), the release binaries,
# LocalSend and Syncplay (lib/upstream.sh), torrra (uv tool) and Prowlarr (a container), the helpers
installed=$(bash -c '. "$1/lib/manifest.sh"; . "$1/lib/upstream.sh"; STEAM=yes STATE_DIR=/nonexistent
  manifest_all amd; printf "%s\n" "${PKG_GPU_intel[@]}"; for u in "${UPSTREAM[@]}"; do echo "${u%%|*}"; done' _ "$REPO"
  grep -q '^LOCALSEND_TAG=' "$REPO/lib/upstream.sh" && echo localsend
  grep -q '^SYNCPLAY_TAG=' "$REPO/lib/upstream.sh" && echo syncplay
  grep -q 'uv tool install .*torrra' "$REPO/setup.sh" && echo torrra
  [[ -f $REPO/system/prowlarr.container ]] && echo prowlarr
  for b in "$REPO"/bin/kawa-*; do echo "${b##*/}"; done)
installed=$(LC_ALL=C sort -u <<<"$installed")
listed=$(names "$FX/launched.txt"; names "$FX/not-launched.txt")
x=$(LC_ALL=C sort <<<"$listed" | uniq -d | tr '\n' ' '); [[ -z $x ]] && _ok || _no "named twice: $x"
x=$(LC_ALL=C comm -23 <(echo "$installed") <(LC_ALL=C sort -u <<<"$listed") | tr '\n' ' ')
[[ -z $x ]] && _ok || _no "installed, but neither launched.txt (its entry) nor not-launched.txt (why none) names it: $x"
x=$(LC_ALL=C comm -13 <(echo "$installed") <(LC_ALL=C sort -u <<<"$listed") | tr '\n' ' ')
[[ -z $x ]] && _ok || _no "named in the fixtures, but no longer installed: $x"
# runs FILE PROG — FILE's Exec runs PROG: a word of it (a path's last part), or inside the
# kawa-* script it starts
runs() {
  local w
  for w in $(key "$1" Exec); do
    w=${w##*/}; [[ $w == "$2" ]] && return 0
    [[ $w == kawa-* && -f $REPO/bin/$w ]] && grep -qw -- "$2" "$REPO/bin/$w" && return 0
  done
  return 1
}
while read -r n e p; do
  case $e in
    pkg:*) [[ $(key "$A/${e#pkg:}" NoDisplay 2>/dev/null) == true ]] && _no "$n: its package's entry ${e#pkg:} is hidden here" || _ok ;;
    \*)    hit=""
           for f in "$A"/*.desktop; do [[ $(key "$f" NoDisplay) == true ]] && continue; runs "$f" "$p" && hit=${f##*/}; done
           [[ -n $hit ]] && _ok || _no "$n: no listed entry runs $p" ;;
    *)     f=$A/$e.desktop
           if [[ ! -f $f ]]; then _no "$n: no $e.desktop"
           elif [[ $(key "$f" NoDisplay) == true ]]; then _no "$n: $e.desktop is hidden"
           elif [[ -n $p ]] && ! runs "$f" "$p"; then _no "$n: $e.desktop does not run $p"
           else _ok; fi ;;
  esac
done < <(grep -v '^#' "$FX/launched.txt" | awk 'NF')

case_ "each entry of the desktop's own that is listed: a plain name, what it is, and words to find it by"
for f in "$A"/*.desktop; do
  [[ $(key "$f" NoDisplay) == true ]] && continue
  n=${f##*/}
  [[ -n $(key "$f" Name) && -n $(key "$f" Comment) ]] && _ok || _no "$n: no Name or Comment"
  [[ -n $(key "$f" GenericName) ]] && _ok || _no "$n: no GenericName (what it is)"
  [[ -n $(key "$f" Keywords) ]] && _ok || _no "$n: no Keywords"
done
out=$(python3 -I -B - "$REPO/bin/kawa-panel" <<'PY'
import importlib.machinery as m, importlib.util as u, sys
sys.dont_write_bytecode = True; sys.modules["gi"] = None
l = m.SourceFileLoader("kp", sys.argv[1]); k = u.module_from_spec(u.spec_from_loader("kp", l)); l.exec_module(k)
net = k.App("kawa-network.desktop", "Network", "Wi-Fi and wired", ["wifi", "internet"], "網", None)
mon = k.App("btop.desktop", "System monitor", "Processes", ["task manager", "cpu"], "視", None)
print(k.rank(net, ["wifi"]), k.rank(mon, ["task"]), k.rank(net, ["net"]), k.rank(net, ["zzz"]))
PY
)
eq "$out" "3 3 0 None" "the launcher matches what a program is and its keywords too (Network: wifi; System monitor: task manager), its name first"

case_ "every listed entry: a window program's own icon, or our seal (its kanji, X-Fedokawaii-Kanji)"
OFFICIAL=" com.github.xournalpp.xournalpp steam "
SEALS="footclient:端 kawa-edit:編 kawa-files:箱 kawa-agents:代 kawa-git:枝 kawa-notes:記
  kawa-clip:写 kawa-books:本 kawa-wallpaper:壁 kawa-backup:蔵 kawa-calc:算 kawa-disk:量
  kawa-tables:表 btop:視 kawa-mixer:混 kawa-network:網 kawa-bluetooth:青 kawa-file:具
  kawa-torrents:種 kawa-prowlarr:索 spotify:曲 whatsapp:話"
for f in "$A"/*.desktop; do
  [[ $(key "$f" NoDisplay) == true ]] && continue
  i=$(key "$f" Icon) k=$(key "$f" X-Fedokawaii-Kanji) n=${f##*/}
  if [[ -n $k ]]; then
    [[ -z $i ]] && _ok || _no "$n: a seal and an Icon= both (the icon would win)"
    [[ $SEALS == *"${n%.desktop}:$k"* ]] && _ok || _no "$n: a seal ($k) no list here names"
  elif [[ $i == @HOME@/* ]]; then [[ $i == *.png ]] && _ok || _no "$n: a picture by path that is no PNG: $i"
  else [[ $OFFICIAL == *" $i "* ]] && _ok || _no "$n: Icon=$i is no window program's own icon"; fi
done
for s in $SEALS; do
  eq "$(key "$A/${s%%:*}.desktop" X-Fedokawaii-Kanji)" "${s#*:}" "${s%%:*}: its seal"
done
eq "$(key "$A/kawa-sketch.desktop" Icon)" com.github.xournalpp.xournalpp "Sketch: Xournal++'s own (it is Xournal++)"
case_ "the pictures: an app's own icon at its native 16 px (design-system §3), forced to it; a terminal program's kanji (one each, wide, drawn by Sumi UI, no two alike — T16 draws them as icons) in the icon column in accent_text, no box round it"
out=$(python3 -I - "$REPO" $SEALS <<'PY'
import sys, unicodedata
from fontTools.ttLib import TTFont
cmap = TTFont(sys.argv[1] + "/system/fonts/SumiUI.ttf").getBestCmap()
ks = [a.split(":")[1] for a in sys.argv[2:]]
for k in ks:
    if len(k) != 1 or unicodedata.east_asian_width(k) != "W": print(f"{k}: not one wide kanji")
    elif ord(k) not in cmap: print(f"{k}: Sumi UI does not draw it")
if len(set(ks)) != len(ks): print("two entries share a seal")
PY
)
eq "$out" "" "the seals' kanji"
P=$REPO/bin/kawa-panel
grep -qx 'APP_ICON = 16 .*' "$P" && _ok || _no "an entry's icon is not 16 px"
grep -qF 'theme.lookup_by_gicon(g, APP_ICON, Gtk.IconLookupFlags.FORCE_SIZE)' "$P" && _ok || _no "the icons not loaded at the row's size, forced"
seal=$(sed -n '/elif it.kind == "app":/,/elif it.kind == "row":/p' "$P")
has "$seal" 'glyph(cr, it.x + GLYPH_X, ty, pic_, lk["glyph"] if lk["fill"] else "accent_text")' "the kanji: accent_text in the icon column (on the cursor: the cursor's ink)"
lacks "$seal" 'frame(cr, ix, iy' "no box round it (§4: never a second frame)"
has "$seal" 'Gdk.cairo_set_source_pixbuf(cr, pic_, ix, iy)' "an app's own icon as it is, centred in the row"
has "$(sed -n '/    def list(self):/,/return self.cache/p' "$P")" 'a.pic = a.kanji or self.icon(theme, info) or "窓"' "the seal first, then the icon, then a window's seal"
has "$(key "$A/syncplay.desktop" Icon)" "/.local/share/fedokawaii/syncplay/syncplay/resources/hicolor/" "Syncplay's own, from its copy"
has "$(key "$A/localsend.desktop" Icon)" "/.local/share/localsend/data/flutter_assets/assets/img/logo-" "LocalSend's own, from its release"
eq "$(key "$A/spotify.desktop" Exec)" "@HOME@/.local/bin/brave-origin --app=https://open.spotify.com" "Spotify: a Brave app window"
eq "$(key "$A/whatsapp.desktop" Exec)" "@HOME@/.local/bin/brave-origin --app=https://web.whatsapp.com" "WhatsApp: a Brave app window"

case_ "no icon pack: nothing names Papirus (the manifest only to retire it, the report to see it gone), the launcher's icons from GTK's own theme (Adwaita, then hicolor)"
bad=$(grep -rli papirus "$REPO"/{configs,bin,lib,tools,system,theme.sh,setup.sh,verify.sh} 2>/dev/null | grep -v '__pycache__' \
      | grep -v -e '/lib/manifest.sh$' -e '/system/fedokawaii-report$')
eq "$bad" "" "Papirus named in: $bad"
eq "$(bash -c '. "$1/lib/manifest.sh"; printf "%s\n" "${RETIRED_PKGS[@]}"' _ "$REPO" | grep -cx papirus-icon-theme)" 1 "papirus-icon-theme retired (update hands it back to dnf)"
grep -qF 'theme, got = Gtk.IconTheme.get_default(), []' "$REPO/bin/kawa-panel" && _ok || _no "the launcher's icons not from GTK's own theme"
eq "$(grep -h '^icon_theme=' "$REPO/configs/home/.config/fedokawaii/themes"/*/qt6ct.conf | sort -u)" "icon_theme=Adwaita" "Qt: GTK's own Adwaita"
has "$(cat "$REPO/configs/system/etc/dconf/db/local.d/00-fedokawaii")" "icon-theme='Adwaita'" "GTK: Adwaita"

case_ "GTK 3 (both themes) and GTK 4: square windows, dialogs, decorations and popovers, no shadow or margin; square buttons, check boxes and radios the panels' square check, the default button the accent"
for c in "$REPO/configs/home/.local/share/themes/Fedokawaii/gtk-3.0/gtk.css" \
         "$REPO/configs/home/.local/share/themes/Fedokawaii-dark/gtk-3.0/gtk.css" \
         "$REPO/configs/home/.config/gtk-4.0/gtk.css"; do
  css=$(cat "$c"); n=${c#"$REPO/configs/home/"}
  W=':not(#kawa-square):not(#kawa-sq)'
  has "$css" "*$W { border-radius: 0; }" "$n: everything square (two ids' weight: over the base theme's own rules)"
  rule=$(grep -F "window$W, " "$c" | grep -F '{ border-radius: 0; box-shadow: none; }')
  for s in window window.csd decoration ".csd decoration" headerbar messagedialog dialog popover; do
    [[ ", ${rule%% \{*}, " == *", $s$W, "* ]] && _ok || _no "$n: $s not square and shadowless"
  done
  has "$css" "decoration$W, .csd decoration$W, window.csd$W, window.solid-csd$W { margin: 0; }" "$n: a margin around the window"
  line=$(grep -F "check$W, radio$W { " "$c")
  [[ $line == *"border-radius: 0;"* ]] && _ok || _no "$n: check boxes and radios not the panels' square check"
  grep -q 'radio[^{]*border-radius: 9999px' "$c" && _no "$n: a round radio is back" || _ok
  line=$(grep -F "check$W:checked, radio$W:checked { " "$c")
  [[ $line == *"background-color: "* ]] && _ok || _no "$n: a chosen radio not a filled square"
  grep -qE '^button\.default:not\(#kawa-square\):not\(#kawa-sq\)[^{]*:not\(:disabled\).*\{ .*background-color: (@accent_bg_color|var\(--accent-bg-color\))' "$c" && _ok || _no "$n: the default button not the accent"
done

done_
