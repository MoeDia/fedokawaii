#!/usr/bin/env bash
# tests/look/test_launcher.sh — what the launcher (fuzzel) lists, and how it is drawn:
#   · the package entries hidden by an entry of the same name (NoDisplay): exactly this set,
#     each still a whole entry (Type, Name, Exec) so the program keeps working
#   · every entry of the desktop's own shows a window program's official icon (a name a
#     package installs into hicolor, or the app's own picture by its path) or our app seal
#     (current/apps/NAME.png, tools/build-appicons.py: both themes, 18 × 18, key ground, edge2 frame, accent_text kanji)
#     — never an icon pack's name, never foot's or neovim's for what is not them
#   · no icon pack anywhere: no Papirus in a config, a script or the manifest (but as retired)
#   · no big copy of the chosen entry's icon under a short list (image-size-ratio=1)
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
eq "$(grep '^fields=' "$REPO/configs/home/.config/fuzzel/fuzzel.ini")" "fields=name,generic,keywords" \
  "the launcher matches what a program is and its keywords too (Network: wifi; System monitor: task manager)"

case_ "every listed entry: a window program's own icon, or our app seal (current/apps)"
OFFICIAL=" com.github.xournalpp.xournalpp steam "
SEALS="footclient:terminal kawa-edit:editor kawa-files:files kawa-agents:agents kawa-git:git kawa-notes:notes
  kawa-clip:clipboard kawa-books:books kawa-wallpaper:wallpaper kawa-backup:backup kawa-calc:calc kawa-disk:disk
  kawa-tables:tables btop:monitor kawa-mixer:mixer kawa-network:network kawa-bluetooth:bluetooth kawa-file:file
  kawa-torrents:torrents kawa-prowlarr:prowlarr spotify:spotify whatsapp:whatsapp"
for f in "$A"/*.desktop; do
  [[ $(key "$f" NoDisplay) == true ]] && continue
  i=$(key "$f" Icon)
  if [[ $i == @HOME@/.config/fedokawaii/current/apps/* ]]; then n=${f##*/}; [[ $SEALS == *"${n%.desktop}:"* ]] && _ok || _no "$n: a seal no list here names"
  elif [[ $i == @HOME@/* ]]; then [[ $i == *.png ]] && _ok || _no "${f##*/}: a picture by path that is no PNG: $i"
  else [[ $OFFICIAL == *" $i "* ]] && _ok || _no "${f##*/}: Icon=$i is no window program's own icon"; fi
done
for s in $SEALS; do
  eq "$(key "$A/${s%%:*}.desktop" Icon)" "@HOME@/.config/fedokawaii/current/apps/${s#*:}.png" "${s%%:*}: its seal"
done
eq "$(key "$A/kawa-sketch.desktop" Icon)" com.github.xournalpp.xournalpp "Sketch: Xournal++'s own (it is Xournal++)"
case_ "the app seals: every one an entry names, in both themes, 18 × 18 (shown 1:1), nothing else in apps/, only the palette's inks"
names=$(for s in $SEALS; do printf '%s\n' "${s#*:}"; done | LC_ALL=C sort)
for t in dark light; do
  eq "$(cd "$REPO/configs/home/.config/fedokawaii/themes/$t/apps" && ls | sed 's/\.png$//' | LC_ALL=C sort)" "$names" "$t: the seals the entries name, and no more"
done
out=$(python3 -I - "$REPO" <<'PY'
import sys, glob, importlib.util
from PIL import Image
root = sys.argv[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("themes", root + "/tools/build-themes.py")
themes = importlib.util.module_from_spec(spec); spec.loader.exec_module(themes)
for t in ("dark", "light"):
    pal = themes.P[t]
    want = {tuple(int(pal[k][i:i + 2], 16) for i in (0, 2, 4)) for k in ("key", "edge2", "accent_text")}
    for f in sorted(glob.glob(f"{root}/configs/home/.config/fedokawaii/themes/{t}/apps/*.png")):
        im = Image.open(f).convert("RGBA")
        n = f.split("/")[-1]
        if im.size != (18, 18): print(t, n, "is", im.size); continue
        inks = {px[:3] for px in im.getdata()}
        if any(px[3] != 255 for px in im.getdata()) or inks != want: print(t, n, "inks", inks ^ want)
        a = im.load()
        e2 = tuple(int(pal["edge2"][i:i + 2], 16) for i in (0, 2, 4)) + (255,)
        if any(a[x, y] != e2 for x in range(18) for y in (0, 17)) or any(a[y, x] != e2 for x in range(18) for y in (0, 17)): print(t, n, "no 1 px frame")
PY
)
eq "$out" "" "the seals as drawn"
has "$(key "$A/syncplay.desktop" Icon)" "/.local/share/fedokawaii/syncplay/syncplay/resources/hicolor/" "Syncplay's own, from its copy"
has "$(key "$A/localsend.desktop" Icon)" "/.local/share/localsend/data/flutter_assets/assets/img/logo-" "LocalSend's own, from its release"
eq "$(key "$A/spotify.desktop" Exec)" "@HOME@/.local/bin/brave-origin --app=https://open.spotify.com" "Spotify: a Brave app window"
eq "$(key "$A/whatsapp.desktop" Exec)" "@HOME@/.local/bin/brave-origin --app=https://web.whatsapp.com" "WhatsApp: a Brave app window"

case_ "no icon pack: nothing names Papirus (the manifest only to retire it, the report to see it gone), fuzzel keeps its default (hicolor)"
bad=$(grep -rli papirus "$REPO"/{configs,bin,lib,tools,system,theme.sh,setup.sh,verify.sh} 2>/dev/null | grep -v '__pycache__' \
      | grep -v -e '/lib/manifest.sh$' -e '/system/fedokawaii-report$')
eq "$bad" "" "Papirus named in: $bad"
eq "$(bash -c '. "$1/lib/manifest.sh"; printf "%s\n" "${RETIRED_PKGS[@]}"' _ "$REPO" | grep -cx papirus-icon-theme)" 1 "papirus-icon-theme retired (update hands it back to dnf)"
eq "$(grep -rh '^icon-theme' "$REPO/configs/home/.config/fuzzel" "$REPO/configs/home/.config/fedokawaii/themes"/*/fuzzel.ini)" "" "no icon-theme for fuzzel"
eq "$(grep -h '^icon_theme=' "$REPO/configs/home/.config/fedokawaii/themes"/*/qt6ct.conf | sort -u)" "icon_theme=Adwaita" "Qt: GTK's own Adwaita"
has "$(cat "$REPO/configs/system/etc/dconf/db/local.d/00-fedokawaii")" "icon-theme='Adwaita'" "GTK: Adwaita"

case_ "fuzzel: no big copy of the chosen entry's icon under a short list"
eq "$(grep '^image-size-ratio=' "$REPO/configs/home/.config/fuzzel/fuzzel.ini")" "image-size-ratio=1"

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
