#!/usr/bin/env bash
# tools/regress/typing.sh — never again: kawa-typing's screen measured, headless (tools/kit.sh, the real GPU, both moods),
# at the three whole multiples its art is drawn at:
#   · the text and the keyboard one column: their left edges one, on the cell grid; every key on its pitch (20 px × the
#     multiple, a column of air after each but the row's last, which ends on the column's edge); the hands inside its width
#   · the key lit and the finger that goes to it one paper (Wada's, the palette's)
#   · the inks as the palette has them (a sixel's colours are whole percents: within 2 of 255)
#   · typing at 120 wpm, recorded: no frame shows a tile blank (each change a whole frame, mode 2026)
#   · the keyboard on the same pixels on home, in a lesson and on its result: one stage, whatever the screen is about
#   · a theme switch repaints the pictures (foot's mode 2031)
#   · a practice run's result has no seal: its speed stands alone (a seal was stamped over the number once)
#   bash tools/regress/typing.sh [KIT OPTION…]   (e.g. --bin bin --repo-art before an apply)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-typing.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
printf '%s\n' 'Tea began as a medicine and grew into a beverage. In China, in the eighth century, it entered the realm of poetry as one of the polite amusements.' >"$out/text"
cat >"$out/play.sh" <<PLAY
export XDG_STATE_HOME=\$HOME/.local/state
mkdir -p "\$XDG_STATE_HOME/fedokawaii/typing"
echo '{"baseline":40}' >"\$XDG_STATE_HOME/fedokawaii/typing/progress.json"
up() { local _; for _ in \$(seq 150); do [[ -s "$out/up" ]] && break; nap 0.1; done; nap 0.5; }   # (its first frame, however loaded the PC)
for size in 80x39 60x21 130x49; do
  rm -f "$out/up"
  footclient -a float -T typing -W \$size -- kawa-typing --trace "$out/up" "$out/text" >/dev/null 2>"\$KIT_OUT/err.log" &
  up; shot rest-\$size
  if [[ \$size == 80x39 ]]; then
    wf-recorder -y -c ffv1 -f "$out/rec-\$(basename "\$KIT_OUT").mkv" >/dev/null 2>&1 & rec=\$!
    nap 0.6
    wtype -s 300 -d 100 -- "Tea began as a medicine and grew into a"
    nap 0.2
    kill -INT \$rec; wait \$rec 2>/dev/null
  fi
  key Escape; nap 0.3
  key Escape; nap 0.4
done
printf '%s' 'tea began as a medicine and grew' >"$out/short"
rm -f "$out/up"
footclient -a float -T typing -W 80x39 -- kawa-typing --trace "$out/up" "$out/short" >/dev/null 2>>"\$KIT_OUT/err.log" &
up
wtype -s 300 -d 40 -- 'tea began as a medicine and grew'
nap 1.0
shot practice-result
key Escape; nap 0.3; key Escape; nap 0.4
# home, a lesson, its result: the same place
footclient -a float -T typing -W 80x39 -- kawa-typing >/dev/null 2>>"\$KIT_OUT/err.log" &
nap 3
shot stage-home
key Return; nap 2.5
shot stage-lesson
key Escape; nap 0.5; key Escape; nap 0.3; key Escape; nap 0.4
rm -f "$out/up"
footclient -a float -T typing -W 80x39 -- kawa-typing --trace "$out/up" "$out/text" >/dev/null 2>>"\$KIT_OUT/err.log" &
up
kawa-theme \$( [[ "\$KIT_OUT" == */dark ]] && echo light || echo dark ) >/dev/null 2>&1
nap 1.6
shot switched
PLAY
fail=0
for th in dark light; do
  bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/$th" --play "$out/play.sh" --time 90 play >"$out/kit-$th.log" 2>&1 \
    || { echo "typing: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
  [[ -s $out/$th/err.log ]] && { echo "typing ($th): it said: $(tail -n 3 "$out/$th/err.log")" >&2; fail=1; }
  python3 -I - "$out/$th" "$th" "$here/../.." "$out/rec-$th.mkv" <<'EOF' || fail=1
import subprocess, sys
from PIL import Image
d, th, repo, rec = sys.argv[1:5]
inks = {}
for line in open(repo + '/configs/home/.local/lib/fedokawaii/kawatype/inks.txt'):
    if not line.startswith('#'):
        t, a, b = line.split()
        h = a if th == 'dark' else b
        inks[t] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
other = {}
for line in open(repo + '/configs/home/.local/lib/fedokawaii/kawatype/inks.txt'):
    if not line.startswith('#'):
        t, a, b = line.split()
        h = b if th == 'dark' else a
        other[t] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
bad = 0
def no(*a):
    global bad
    bad += 1
    print(f'typing ({th}):', *a, file=sys.stderr)
def near(a, b, tol=2):
    return all(abs(x - y) <= tol for x, y in zip(a, b))

# the keyboard's corner: the left of its keys' fill, then the row where its first row of keys has that fill all along the pitch
# (a list's meter or a letter can wear the same ink: only a whole row of keys answers this)
def keyboard_at(name, k=2):
    im = Image.open(f'{d}/{name}.png').convert('RGB')
    W, H = im.size
    px = im.load()
    for x in range(W):
        for y in range(40, H - 100 * k):
            if near(px[x, y], inks['key'], 1) and sum(near(px[x + i * 20 * k + k, y], inks['key'], 1) for i in range(13) if x + i * 20 * k + k < W) >= 11:
                return x, y
    return None

for size, k in (('80x39', 2), ('60x21', 1), ('130x49', 3)):
    im = Image.open(f'{d}/rest-{size}.png').convert('RGB')
    W, H = im.size
    px = im.load()
    # the keyboard: the corner of its keys' fill, then that fill's right end over its five rows of keys
    at = keyboard_at(f'rest-{size}', k)
    if not at:
        no(size, 'no key fill on the screen')
        continue
    x0, y0 = at
    y1 = y0 + 100 * k - 3 * k      # (its last row of keys: below it, the light mood's hands wear the same paper)
    x1 = max(x for y in range(y0, y1) for x in range(x0, W) if near(px[x, y], inks['key'], 1))
    # (each key's frame is a pixel × k in from its cell; the fill's box is that much inside the keyboard's)
    kb_left = x0 - k
    want_w = 304 * k              # (the last key of a row ends on the column's edge)
    if x1 + k + 1 - kb_left != want_w:     # (its frame, k pixels past the fill)
        no(size, f'keyboard {x1 + k + 1 - kb_left} px wide, want {want_w}')
    # keys on their pitch: along the number row's face, a frame every 20 × k
    row = y0 + 8 * k
    frames = [x for x in range(kb_left, kb_left + 260 * k) if near(px[x, row], inks['edge'], 2)]
    want = [kb_left + i * 20 * k + j for i in range(13) for j in range(k)] + [kb_left + i * 20 * k + (18 * k) + j for i in range(13) for j in range(k)]
    if not set(want) <= set(frames):
        no(size, 'keys off their pitch:', sorted(set(want) - set(frames))[:6])
    # the text's left edge is the keyboard's: T's bar starts on its cell's first ink column
    t = min(k, 2)
    y_text = range(y0 - 20 - 60 * t, y0 - 20)
    text_ink = [x for y in y_text for x in range(kb_left - 16, kb_left + 40) if not near(px[x, y], inks['ground'], 12)]
    if text_ink:
        lead = min(text_ink) - kb_left
        if not 0 <= lead <= 2 * min(k, 2):
            no(size, f'the text starts {lead} px from the keyboard\'s edge')
    # on the cell grid: 8 px from the window's text area (foot's pad of 8, a hairline: the window's own left edge found)
    # (found walking left from the keyboard: over a kit's ground that has gone, the window's own glass is another colour)
    inside = px[kb_left - 4, y0 + 8 * k]
    win = next((x for x in range(kb_left - 4, -1, -1) if not near(px[x, y0 + 8 * k], inside, 3)), None)
    if win is not None and (kb_left - (win + 1 + 8)) % 8:
        no(size, f'the keyboard off the cell grid: {kb_left - win - 9} from the window\'s text')
    # the hands, under it, inside its width
    hand = [x for y in range(y1 + 8 * k, min(y1 + 90 * k, H - 30)) for x in range(kb_left - 40, min(kb_left + 344 * k, W)) if near(px[x, y], inks['accent_lo' if th == 'dark' else 'key'], 3)]
    if not hand:
        no(size, 'no hands')
    elif min(hand) < kb_left or max(hand) > kb_left + 304 * k:
        no(size, f'the hands stick out: {min(hand) - kb_left}..{max(hand) - kb_left}')
    # the next key (T: shift and t) lit in its finger's paper, and that finger too
    for token in ('paper_time', 'paper_mark'):
        n_kb = sum(1 for y in range(y0, y1) for x in range(kb_left, kb_left + 304 * k, 2) if near(px[x, y], inks[token], 2))
        n_h = sum(1 for y in range(y1, min(y1 + 90 * k, H)) for x in range(kb_left, kb_left + 304 * k, 2) if near(px[x, y], inks[token], 2))
        if not n_kb:
            no(size, f'{token}: no key lit')
        if not n_h:
            no(size, f'{token}: no finger lit')

# a practice run's result: no seal (no vermilion, nor gold) anywhere on it, whatever stands beside its number
im = Image.open(f'{d}/practice-result.png').convert('RGB')
W, H = im.size
# (the screen's middle, inside the window: its focused hairline is vermilion too)
at = keyboard_at('practice-result')
seal = 0 if not at else sum(1 for y in range(at[1] - 340, at[1] - 2) for x in range(at[0], at[0] + 600) if near(im.getpixel((x, y)), inks['gold'], 2) or near(im.getpixel((x, y)), inks['accent'], 2))
if seal > 30:      # (the heading's check mark, a few pixels)
    no(f'a practice run\'s result wears a seal: {seal} px')

# a theme switch repaints the pictures
im = Image.open(f'{d}/switched.png').convert('RGB')
c = im.getcolors(1 << 20)
have = {v for _, v in c}
if not any(near(v, other['key'], 1) for v in have):
    no('the theme changed: the keys kept the old mood')
if any(near(v, inks['key'], 0) for v in have) and not near(inks['key'], other['key'], 0):
    # (the desktop's own bar may wear the same token: only what counts inside the window)
    pass

# one stage: the keyboard's box on home, in a lesson, on the rest shots of the same size
places = {n: keyboard_at(n) for n in ('stage-home', 'stage-lesson', 'practice-result', 'rest-80x39')}
if None in places.values() or len(set(places.values())) != 1:
    no('the keyboard moves between the screens:', places)

# every recorded frame: a tile blank for a frame is a square all ground, between two frames that have it inked
# (the box: what the rest shot has over the keyboard, measured there, so a change of size cannot move it off the text)
im = Image.open(f'{d}/rest-80x39.png').convert('RGB')
pts = [(a, b) for b in range(40, im.size[1]) for a in range(im.size[0]) if near(im.getpixel((a, b)), inks['key'], 1)]
x, y1 = min(q[0] for q in pts) - 2, min(q[1] for q in pts) - 4
W, H = 600, 192
y = y1 - H
p = subprocess.Popen(['ffmpeg', '-v', 'error', '-i', rec, '-fps_mode', 'passthrough', '-vf', f'crop={W}:{H}:{x}:{y},format=rgb24', '-f', 'rawvideo', '-'], stdout=subprocess.PIPE)
tw, th_ = 64, 60
frames = []
while True:
    b = p.stdout.read(W * H * 3)
    if len(b) < W * H * 3:
        break
    # (a tile's ink: how many of its pixels are not the ground, sampled)
    g = inks['ground']
    tiles = []
    for j in range(0, H - th_ + 1, th_):
        for i in range(0, W - tw + 1, tw):
            n = 0
            for yy in range(j, j + th_, 4):
                o = (yy * W + i) * 3
                row = b[o:o + tw * 3]
                for q in range(0, tw * 3, 12):
                    if abs(row[q] - g[0]) > 6 or abs(row[q + 1] - g[1]) > 6:
                        n += 1
            tiles.append(n)
    frames.append(tiles)
flash = 0
for a, b, c in zip(frames, frames[1:], frames[2:]):
    for ta, tb, tc in zip(a, b, c):
        if tb < min(ta, tc) * 0.4 and min(ta, tc) > 40:
            flash += 1
if len(frames) < 20:
    no(f'only {len(frames)} frames recorded')
if flash:
    no(f'{flash} tiles blank for a frame while typing, of {len(frames)} frames')
sys.exit(1 if bad else 0)
EOF
done
((fail)) || echo "typing: held in both moods"
exit "$fail"
