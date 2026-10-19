#!/usr/bin/env bash
# tests/look/test_launcher.sh — what the launcher (fuzzel) lists, and how it is drawn:
#   · the package entries hidden by an entry of the same name (NoDisplay): exactly this set,
#     each still a whole entry (Type, Name, Exec) so the program keeps working
#   · every entry of the desktop's own shows its program's official icon: a name a package
#     installs into hicolor, or the app's own picture by its path — never an icon pack's name
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
HIDDEN="btop calf foot foot-server mpv nvim org.pwmt.zathura qt6ct visidata"
got=$(for f in "$A"/*.desktop; do n=${f##*/}; n=${n%.desktop}
        [[ $n == kawa-* ]] && continue; [[ $(key "$f" NoDisplay) == true ]] && printf '%s ' "$n"; done)
eq "$(tr ' ' '\n' <<<"${got% }" | LC_ALL=C sort | tr '\n' ' ')" "$(tr ' ' '\n' <<<"$HIDDEN" | LC_ALL=C sort | tr '\n' ' ')"
for n in $HIDDEN; do
  f=$A/$n.desktop
  [[ $(key "$f" Type) == Application && -n $(key "$f" Name) && -n $(key "$f" Exec) ]] && _ok \
    || _no "$n.desktop: not a whole entry (Type=Application, Name, Exec)"
done
eq "$(key "$A/kawa-edit.desktop" NoDisplay)" "" "Editor (neovim through kawa-term) is listed, in place of neovim's own"
for n in kawa-play kawa-tables; do eq "$(key "$A/$n.desktop" NoDisplay)" true "$n: an opener only"; done

case_ "every listed entry: its program's own icon (hicolor names its packages install, or its own picture by path)"
OFFICIAL=" foot nvim mpv com.github.xournalpp.xournalpp steam @BRAVE_ICON@ "
for f in "$A"/*.desktop; do
  [[ $(key "$f" NoDisplay) == true ]] && continue
  i=$(key "$f" Icon)
  if [[ $i == @HOME@/* ]]; then [[ $i == *.png ]] && _ok || _no "${f##*/}: a picture by path that is no PNG: $i"
  else [[ $OFFICIAL == *" $i "* ]] && _ok || _no "${f##*/}: Icon=$i is no program's own icon"; fi
done
has "$(key "$A/syncplay.desktop" Icon)" "/.local/share/fedokawaii/syncplay/syncplay/resources/hicolor/" "Syncplay's own, from its copy"
has "$(key "$A/localsend.desktop" Icon)" "/.local/share/localsend/data/flutter_assets/assets/img/logo-" "LocalSend's own, from its release"
eq "$(key "$A/kawa-prowlarr.desktop" Icon)" "@BRAVE_ICON@" "Prowlarr's page: Brave's own (theme.sh reads it from Brave's entry)"
eq "$(key "$A/spotify.desktop" Icon)" "@BRAVE_ICON@" "Spotify (its web player in Brave): Brave's own"
eq "$(key "$A/spotify.desktop" Exec)" "@HOME@/.local/bin/brave-origin --app=https://open.spotify.com" "Spotify: a Brave app window"

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

case_ "GTK 3 (both themes) and GTK 4: square windows, dialogs, decorations and popovers, no shadow or margin; square buttons, round radios, the default button the accent"
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
  grep -qE "^radio[^{]*:not\(#kawa-round\) \{ border-radius: 9999px; \}" "$c" && _ok || _no "$n: a radio button no longer round (and outweighing the square rule)"
  grep -qE '^button\.default:not\(:disabled\).*\{ .*background-color: (@accent_bg_color|var\(--accent-bg-color\))' "$c" && _ok || _no "$n: the default button not the accent"
done

done_
