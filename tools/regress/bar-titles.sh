#!/usr/bin/env bash
# tools/regress/bar-titles.sh — never again a bar that grows with a title (r26-fu-4: 46 px with an
# Arabic, an emoji or a Thai title, whose fallback faces are taller than ours): the real bar on the
# real GPU, both themes, a real window under each title, then each as what plays (a stand-in player)
# — its rows the same to the pixel as with nothing there, and the title really drawn.
#   bash tools/regress/bar-titles.sh [KIT OPTION…]
# Exit 0 held · 1 broken (each title said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-titles.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
kit=() given=""
while (($#)); do case $1 in --bin) given=$2; shift 2 ;; *) kit+=("$1"); shift ;; esac; done
b=$out/bin; mkdir "$b"
if [[ -n $given ]]; then for f in "$given"/*; do ln -s "$(realpath "$f")" "$b/"; done; fi
: >"$out/feed"
cat >"$b/playerctl" <<STUB_END
#!/bin/sh
case "\$*" in
  *--follow*) exec tail -n +1 -f "$out/feed" ;;
  *metadata*) tail -n 1 "$out/feed" ;;
esac
STUB_END
printf '#!/bin/sh\nexec sleep 300\n' >"$b/pw-metadata"
printf '#!/bin/sh\nexec sleep 300\n' >"$b/cava"
chmod +x "$b"/playerctl "$b"/pw-metadata "$b"/cava
titles=('مرحبا بالعالم — نافذة' '🎉 party 👍🏽 🇯🇵' 'สวัสดีชาวโลก ทดสอบ' '日本語のタイトル・テスト' 'A plain title')
{
  echo 'nap 1.5; shot empty 0,0 1920x40'
  for i in "${!titles[@]}"; do
    printf 'foot --title %q sh -c "exec sleep 30" & w=$!; nap 1.5; shot w%d 0,0 1920x40; kill "$w"; wait "$w" 2>/dev/null; nap 0.6\n' "${titles[i]}" "$i"
  done
  for i in "${!titles[@]}"; do
    printf 'printf "mpv\\037Playing\\037%%s\\037%%s\\037file:///v/a.mkv\\037\\n" %q %q >>%q; nap 1.5; shot p%d 0,0 1920x40\n' "${titles[i]}" "${titles[i]}" "$out/feed" "$i"
  done
} >"$out/play.sh"
fail=0
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "${kit[@]}" --bin "$b" --time 200 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "bar-titles: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  : >"$out/feed"
  fibre=$HOME/.config/fedokawaii/themes/$th/kami-fibre.png
  [[ " ${kit[*]} " == *" --repo-art "* ]] && fibre=$here/../../configs/home/.config/fedokawaii/themes/$th/kami-fibre.png
  want=$(python3 -I "$here/shots.py" bar "$out/$th/empty.png" "$fibre" | grep '^rows ') || { echo "bar-titles: no bar measured" >&2; exit 2; }
  [[ $want == "rows 0+3 3+1 4+20 24+1 25+1 26+1" ]] || { echo "bar-titles ($th): the empty bar's $want" >&2; fail=1; }
  for n in w p; do for i in "${!titles[@]}"; do
    w=window; [[ $n == p ]] && w="what plays"
    got=$(python3 -I "$here/shots.py" bar "$out/$th/$n$i.png" "$fibre" | grep '^rows ')
    [[ $got == "$want" ]] || { echo "bar-titles ($th): $w [${titles[i]}]: $got (want $want)" >&2; fail=1; }
    python3 -I "$here/shots.py" differ "$out/$th/empty.png" "$out/$th/$n$i.png" 60,4,1800,20 >/dev/null \
      || { echo "bar-titles ($th): $w [${titles[i]}] was not drawn" >&2; fail=1; }
  done; done
done
((fail)) && exit 1
echo "bar-titles: held — 27 rows under Arabic, emoji, Thai, Japanese and plain titles, a window and what plays, both themes"
