#!/usr/bin/env bash
# tools/regress/downloads-tools.sh — never again a download the bar does not know of ("any download
# from any source", the owner): the real watcher in a headless kit, the real curl and yt-dlp against a
# slow local server: each known as its file comes (the kernel's word as it starts, nothing polled at
# rest), named by its file, its notice at the end; and a quiet curl of a small answer: nothing at all.
#   bash tools/regress/downloads-tools.sh [KIT OPTION…]   (e.g. --bin bin)
# Exit 0 held · 1 not (each said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-tools.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
cat >"$out/slow.py" <<'SERVER'
import http.server, sys, time
size, rate = 60000000, 12000000
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        small = self.path == "/small"
        n = 500 if small else size
        self.send_response(200); self.send_header("Content-Type", "video/mp4"); self.send_header("Content-Length", str(n)); self.end_headers()
        sent, t0, chunk = 0, time.monotonic(), b"\0" * 262144
        try:
            while sent < n:
                k = min(len(chunk), n - sent); self.wfile.write(chunk[:k]); sent += k
                w = sent / rate - (time.monotonic() - t0)
                if w > 0: time.sleep(w)
        except OSError: pass
    def log_message(self, *a): pass
http.server.ThreadingHTTPServer(("127.0.0.1", 18473), H).serve_forever()
SERVER
cat >"$out/play.sh" <<PLAY
python3 -I "$out/slow.py" >/dev/null 2>&1 &
S=\$!
for _ in \$(seq 200); do curl -s -o /dev/null http://127.0.0.1:18473/small && break; nap 0.1; done
kawa-downloads watch >"\$KIT_OUT/watch.log" 2>&1 &
W=\$!
nap 1
said() { say "\$1: \$(kawa-downloads list | cut -f1-4 | tr '\t' ' ')"; }
curl -s -o "\$HOME/quiet.json" http://127.0.0.1:18473/small; nap 1.5; said quiet
curl -s -o "\$HOME/disk.iso" http://127.0.0.1:18473/big & C=\$!
nap 3.5; said curl
wait \$C; nap 3
say "curl's notice: \$(makoctl list 2>&1 | grep -c 'disk.iso')"
yt-dlp --no-progress --quiet --force-generic-extractor -o "\$HOME/film.mp4" http://127.0.0.1:18473/film.mp4 >"\$KIT_OUT/ytdlp.log" 2>&1 & Y=\$!
for _ in \$(seq 60); do [ -s "\$HOME/film.mp4.part" ] && break; nap 0.25; done   # (Python starts slowly under load)
nap 1.5; said yt-dlp
wait \$Y; nap 3
say "yt-dlp's notice: \$(makoctl list 2>&1 | grep -c 'film.mp4')"
say "left: \$(kawa-downloads list | wc -l)"
kill \$W \$S
PLAY
bash "$here/../kit.sh" --theme dark "$@" --out "$out" --play "$out/play.sh" --time 90 play >"$out/kit.log" 2>&1 \
  || { echo "downloads-tools: the kit did not run: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
cat "$out/play.log"
grep -q '^quiet: $' "$out/play.log" || { echo "downloads-tools: a small answer counted"; exit 1; }
grep -qE '^curl: curl disk\.iso [0-9]+ 0$' "$out/play.log" || { echo "downloads-tools: curl not known"; exit 1; }
grep -qE '^yt-dlp: yt-dlp film\.mp4 [0-9]+ 0$' "$out/play.log" || { echo "downloads-tools: yt-dlp not known"; exit 1; }
grep -q "^curl's notice: 1" "$out/play.log" || { echo "downloads-tools: no notice at curl's end"; exit 1; }
grep -q "^yt-dlp's notice: 1" "$out/play.log" || { echo "downloads-tools: no notice at yt-dlp's end"; exit 1; }
grep -q '^left: 0' "$out/play.log" || { echo "downloads-tools: something left on the list"; exit 1; }
echo "downloads-tools: held — curl and yt-dlp known as they fetch, a notice at each end, a small answer nothing"
