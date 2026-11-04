#!/usr/bin/env bash
# tools/chess-gallery.sh [--theme dark|light] [--sf PATH] [--out DIR] — kawa-chess's screens as the desktop draws them: a
# headless dwl (tools/kit.sh) in a throw-away home, the repository's files, positions set up from fixtures; PNGs of every
# screen at the sizes that matter, to be looked at and measured. Nothing of the session is touched.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
theme=dark sf=$(command -v stockfish || true) out=""
while (($#)); do
  case $1 in
    --theme) theme=$2; shift 2 ;;
    --sf) sf=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    *) echo "usage: chess-gallery.sh [--theme dark|light] [--sf PATH] [--out DIR]" >&2; exit 2 ;;
  esac
done
out=${out:-/dev/shm/r27/chess/$theme}
mkdir -p "$out"
export PATH="$HOME/.local/bin:$PATH"
play=$(mktemp /tmp/chess-play.XXXXXX)
trap 'rm -f "$play"' EXIT
# (a play gets no variables from here: the paths written into it)
{
  printf 'REPO=%q\nSF=%q\n' "$repo" "$sf"
  cat <<'PLAY'
ST=$HOME/.local/state/fedokawaii/chess
mkdir -p "$HOME/.local/lib/fedokawaii" "$HOME/.local/share/fedokawaii" "$ST/games" "$HOME/sf"
cp -r "$REPO/configs/home/.local/lib/fedokawaii/kawa-chess" "$HOME/.local/lib/fedokawaii/"
rm -rf "$HOME/.local/share/fedokawaii/chess"; cp -r "$REPO/configs/home/.local/share/fedokawaii/chess" "$HOME/.local/share/fedokawaii/"
cp "$REPO/configs/home/.config/fedokawaii/keys/chess.txt" "$HOME/.config/fedokawaii/keys/" 2>/dev/null
[ -n "$SF" ] && ln -sf "$SF" "$HOME/sf/stockfish"
export PATH=$REPO/bin:$HOME/sf:$PATH
win() { footclient -E -a float -T chess -W "$1" -- bash -c 'kawa-chess 2>>$HOME/err.log; echo "rc=$?" >>$HOME/err.log' >/dev/null 2>&1 & sleep 1.6; }
quit() { wtype -M ctrl -k c -m ctrl; sleep 0.6; }
game() {   # game FEN MOVES… — a game left open at this position (you: white unless FEN says otherwise)
  local fen=$1 c=$2; shift 2
  python3 -I -c 'import json,sys
fen,c,moves,st=sys.argv[1],int(sys.argv[2]),sys.argv[3:-1],sys.argv[-1]
spec=dict(title="game 57 of 730",goal="win something with a fork, or make one possible. look at their knights too.",fen=fen,line=[],colour=c,elo=1400,clock=[20,10],hints=3,threats=True,opponent="tengu",no=None,card=True)
json.dump(dict(spec=spec,moves=moves,clock=[1124.0,1187.0],times=[],hints_used=0),open(st+"/current.json","w"))' "$fen" "$c" "$@" "$ST"
}
START="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# ── the first screens ──
win 126x33; grim "$KIT_OUT/01-today.png"
key Tab; sleep 0.25; grim "$KIT_OUT/02-lessons.png"
key Tab; sleep 0.25; grim "$KIT_OUT/03-puzzles.png"
key Tab; sleep 0.25; grim "$KIT_OUT/04-games.png"
key Tab; sleep 0.4; grim "$KIT_OUT/05-progress.png"; quit
# ── a game: what the hand shows ──
game "$START" 0 e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4 c3d4 c5b4 b1c3 f6e4 e1g1 e4c3 b2c3 b4c3 a1b1 c3d4
win 126x33; grim "$KIT_OUT/10-game.png"
text N; sleep 0.25; grim "$KIT_OUT/11-typed.png"; key Escape; sleep 0.2
at 700 650; sleep 0.1
key Up; key Up; sleep 0.2; grim "$KIT_OUT/12-cursor.png"; key Escape; sleep 0.2
text '?'; sleep 2.5; grim "$KIT_OUT/13-hint.png"; text '?'; sleep 0.4; grim "$KIT_OUT/14-hint-arrow.png"
key Escape; sleep 0.3; grim "$KIT_OUT/15-menu.png"; key Escape; sleep 0.2; quit
game "r1bqk2r/pppp1ppp/2n2n2/2b1p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4" 0
win 126x33; text Qx; sleep 0.25; grim "$KIT_OUT/16-capture.png"; key BackSpace; key BackSpace; text 'Qxf7'; sleep 0.2; key Return; sleep 1.2; grim "$KIT_OUT/17-mate.png"; key Return; sleep 0.4; quit
# ── a lesson, a drill, the puzzles ──
win 126x33; key Tab; sleep 0.2; for _ in 1 2 3 4 5 6 7 8 9; do key Down; done; sleep 0.2; grim "$KIT_OUT/30-lesson-list.png"; key Return; sleep 0.5; grim "$KIT_OUT/31-lesson-page.png"; key Return; sleep 0.3; grim "$KIT_OUT/32-lesson-try.png"; key Escape; sleep 0.2; quit
win 126x33; key Tab; key Tab; sleep 0.2; key Return; sleep 1.2; grim "$KIT_OUT/33-puzzle.png"; key Escape; sleep 0.3; quit
# ── a review ──
printf '%s\n' '[Event "x"]' '[White "you"]' '[Black "tengu"]' '[Result "0-1"]' '' '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nf6 4. Ng5 d5 5. exd5 Nxd5 6. Nxf7 Kxf7 7. Qf3+ Ke6 8. Nc3 Nb4 9. O-O c6 10. d4 Nxc2 11. Qg3 Nxa1 0-1' >"$ST/games/57.pgn"
python3 -I -c 'import json,sys
json.dump(dict(day=29,items={"29/lesson-is-it-safe":"x","29/game57":"x"},played={"57":dict(score="loss",elo=1100,t=1,me=0,times=[8]*11,check="safe",goal="not one piece given away.",accuracy=None)}),open(sys.argv[1]+"/progress.json","w"))' "$ST"
win 126x33; key Return; sleep 25; grim "$KIT_OUT/40-review-judge.png"; key Return; sleep 0.4; grim "$KIT_OUT/41-review-moment.png"; key Escape; sleep 0.3; grim "$KIT_OUT/42-review-shown.png"
key Return; sleep 0.2; key Escape; sleep 0.2; key Return; sleep 0.2; key Escape; sleep 0.2; key Return; sleep 0.3; text "look at f7 before anything else"; sleep 0.2; grim "$KIT_OUT/43-review-summary.png"; key Return; sleep 0.3; grim "$KIT_OUT/44-after-review.png"; quit
rm -f "$ST/progress.json"* "$ST/current.json"*
# ── sizes ──
for size in 60x20 64x24 86x24 100x33 60x45 118x50 236x51; do
  game "$START" 0 e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7
  win $size; grim "$KIT_OUT/20-game-$size.png"; quit
done
win 40x12; grim "$KIT_OUT/29-small.png"; key Escape; sleep 0.4
say "err: $(tail -3 $HOME/err.log 2>/dev/null | tr '\n' ' ')"
say "crash: $(tail -30 $ST/crash.log 2>/dev/null)"
PLAY
} >"$play"
bash "$here/kit.sh" --theme "$theme" --time 230 --out "$out" --play "$play" play
