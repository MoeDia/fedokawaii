# lane-torrents — T29 and the owner's 17:04 magnet note

Status: see the last line of this file.

## What it is now
torrra is gone. **kawa-torrents**: our own engine (libtorrent, Fedora's `rb_libtorrent-python3` on Fedora's python3: no Python of its own, no
Textual) and our own window, in the design system's grammar. `bin/kawa-torrents`, `configs/home/.local/lib/fedokawaii/kawa-torrents/`
(`engine.py`, `app.py`, `term.py`, `common.py`, `cli.py`, `prowlarr.py`), units `kawa-torrents.socket` + `.service`, keys `keys/torrents.txt`.

**Why not the plan's patch of torrra** (decided, with evidence): torrra keeps no resume data (core/download.py re-adds every torrent from its magnet at
each open: metadata fetched again, every file hashed again; that was also the repeat "finished" notice: a torrent seen "checking" for one tick counted as
seen downloading), its 10 s fetch of Prowlarr's link was the "Failed to resolve", one whole search waited for the slowest site, and its window is Textual,
monkey-patched at nine points by kawa-torrra. A patch would have been larger than the replacement.

| measured here, 4 Nov | torrra | kawa-torrents |
|---|---|---|
| the window: start to first frame | 665 ms | 204 ms (load 30) |
| the window's memory | 63.5 MB (38.2 own) | 22.3 MB (14.3 own) at 500 rows |
| the engine's memory, 50 torrents | (in the window) | 41 MB (20 own); the real network, a real ISO: 37.7 (16.7 own) |
| a key to its frame at 500 rows, p50 · p95 · worst | | 6 · 12 · 24 ms (the bar: < 50) |
| its CPU, moving icons on, 500 rows · the engine idle | | 2.2 % → 1 ms a frame after the caches · 0.2 % |
| a reopen with 50 torrents | re-hash of everything, metadata again | 100 ms, nothing hashed |
| first results of a search | the slowest site: YTS 39.6 s, LimeTorrents 18.9 s | the quickest site: 0.3 s (each site on its own) |
| add → first peer, real network, a hash alone | | 1.0 s; its files known 5–6 s; 54 peers, 46 seeds |
| "failed to resolve" | 10 s limit on Prowlarr's link, in a modal | not asked at all when the result has its hash (almost all do); else a row at once, 60 s × 3 tries, the reason in words |

`python3 tools/torrent-stress.py [--torrra] [--real HASH…]` gives these numbers again.

## The owner's requests, each with how it was verified
- **Add a magnet, super easily**: paste anywhere (any text: found in a page's source, a chat line, a list); Ctrl+V; `a` (the clipboard's link already on the line, under it what it understood, Ctrl+O a .torrent in yazi); on opening or coming back to the window the clipboard's magnet and a .torrent just downloaded are offered over the list (Enter adds, x not now, never twice, not if already here); the browser's magnet: click, and yazi's Enter on a .torrent, go to the same place: a window opened for it, or added to the one open with a notice, never two windows. A bare hash typed for the purpose works; a git commit on the clipboard is never offered. Tests: `words`, `keys_`, `offers`, `hand_over`, `stream_from_search`; the real clipboard in the kit (shot).
- **Copy / extract a magnet**: `y` on a row or a result (right click on a row too), said in place ("magnet copied"; decided against the plan's mako notice: the key's answer belongs where the key was pressed); `kawa-torrents magnet FILE` prints and copies; Alt+F in yazi on a .torrent: "copy its magnet link", "download it" (`bin/kawa-file`). Tests: `keys_`, `find`, tests/content/test_file.sh.
- **Stream at once**: `v` on a row, on a search's result (added and played with nothing more pressed), Enter on a video in its files. The engine serves the file over the loopback by byte ranges (a token in the URL), reads wait for their pieces, the pieces ahead of the reader rushed (`set_piece_deadline`), sequential after that, its head and tail first; the player (kawa-play) opens when they are here. Tests: `stream` (every byte right, ranges, tail first, wrong token 404, past the end 416), `real_player` (real mpv on a film not yet here, jumping to 0:30), a real mpv at 40 % of a film jumping to 0:45 by hand. A bug only mpv shows found and fixed: ffmpeg takes a server's silence on `Connection` for keep-alive and its next seek failed with "End of file".
- **Finished notice once**: remembered in state.json, and only for bytes that came over the network; five reopens with the seeder gone: one notice, each reopen < 3 s (`magnet_to_done`). Choosing more of a finished torrent tells again when that comes (`choose_files`).
- **Prowlarr's warning**: read from its own API on a private copy of his config (another port, another key, his service untouched). Two warnings, both dealt with at their cause:
  `AllowedHostsCheck`: `PROWLARR__SERVER__ALLOWEDHOSTS=localhost,127.0.0.1` (source: wiki.servarr.com/prowlarr/environment-variables; tried: 127.0.0.1 and localhost 200, another host 400: it also shuts out DNS rebinding).
  `IndexerLongTermStatusCheck` ("SubsPlease, Tokyo Toshokan, Torrent Downloads"): www.torrentdownloads.pro: his ISP's resolver answers NXDOMAIN, 1.1.1.1 / 8.8.8.8 / 9.9.9.9 answer: `DNS=1.1.1.1`, `DNS=9.9.9.9` in the quadlet (this container alone: `man podman-systemd.unit` has the key) and it works. subsplease.org: no answer from any resolver from this network: `tend` rests it (switched off, noted, tried again each time, on again the day it answers). Tokyo Toshokan: "Cloudflare protection detected": taken out of the usual sites, and out of his Prowlarr by `prowlarr.py add`.
  After them, on the private copy with these settings: `GET /api/v1/health` → `[]`, after a search too. Tend runs before the page opens (`kawa-prowlarr`) and after a window's first search. Its debug log switched off (`PROWLARR__LOG__LEVEL=info`).
- **Design**: tabs, headings, rows, the meter (its part-way segment in the dissolve's own Bayer pixels: `read-1…7`), the lacquer, a band on the list's row while the keyboard is in its files; adaptive columns per width band; nothing cut with "…" (`cut`, `cut_file`: at a word, a file's type kept). `tools/regress/torrents.sh` measures three sizes in both moods to the pixel (held); `every_size` runs from 2 × 2 to 70 × 400 on both tabs; `layout` asserts it cell by cell. New icons: magnet, sprout, pieces, read-1…7. design-system.md §7 and §14 say all this.
- **Hardening**: a real full disk (a tmpfs in a namespace): the row says so, one critical notice, `p` goes on once there is room (`disk_full`; libtorrent itself only stops writing, "upload mode", no error on the torrent). Killed outright midway: goes on, file right, one notice (`crash_midway`). Files moved away: never fetched anew unasked (`files_gone`; libtorrent would quietly start over: tens of GB). Nonsense on the socket: answered, the engine goes on (it found a real crash). A hostile name's escapes never reach the terminal. A libtorrent 2.0.11 trap found by test: once finished it lets its seeds go and never again counts them as worth connecting to, not when asked, not at a tracker's word (none in 130 s): choosing another episode of a finished season would have stalled for ever: such a torrent is added anew from its resume data (0.1 s).
- **The engine's walls** (`kawa-torrents.service`): it reads strangers' bytes, so: a tmpfs over the home but its own program, Downloads, its state and cache; read-only system; a syscall filter; no W^X. Tried with these same walls on the real network in a transient unit: 41 peers, pieces coming. It starts no program: its words wait in `$XDG_RUNTIME_DIR/kawa-downloads/said.*` for the session's watcher (`kawa-downloads watch`).

## r27-extra (small delights, the owner may veto)
The last 16 seconds of speed in the music's columns at the tabs' right end. Downloads go on with the window closed (the bar's mark shows them; at a login the engine comes back only if something was left unfinished). The add line says what it understood. `v` on a search's result. Results merged across sites by hash.

## What main (lane-integrate) must do
**Merge**: `git merge lane-torrents`. It was merged with main at bad3e35; expected conflicts only in the two icon fonts (binary) and maybe `bin/kawa-downloads` (lane-pixels' foot row, lane-browser): after any font conflict, `python3 tools/build-icons.py` and commit (the new icons are at the end of art/icons.txt, nothing renumbered). The row "torrents" in the downloads dropdown (his note: a normal row, not a slab) is lane-pixels'; it must call `kawa-torrents --open`.

**Apply, in this order**:
1. `sudo fedokawaii repair` or the update (the manifest installs `rb_libtorrent-python3`; `torrents_up` then hands his five torrents over to `inherited.json` and takes torrra out: uv's tool, its Python 3.13, `/usr/local/bin/kawa-torrra`, `/etc/profile.d/kawa-torrra.sh`, `~/.config/torrra`, `~/.cache/torrra`, `~/.local/share/torrra`). `prowlarr_up` restarts Prowlarr with the new container file and retires Tokyo Toshokan.
2. `fedokawaii apply` (the theme: the program, its units, the fonts, the keys).
3. In the live session, no re-login needed: `systemctl --user daemon-reload`, and the window starts the socket itself. The running `kawa-downloads watch` is the old one until the next login (its notices wait, harmlessly, in `said.*`): restart it if the notice is to be seen tonight.
4. Check live, in this order: open Torrents: five rows, the four finished ones checked once (their files hashed one last time: his 90 GB, minutes), no notice for them; `curl /api/v1/health` with the key: `[]` after a search; click a magnet in the browser; `y`; `v` on something small; the bar's mark while it downloads; close the window: it goes on.

**Tests**: `bash tests/engine/test_torrents.sh` needs `rb_libtorrent-python3` installed (before step 1 it says so and fails: here it ran against the rpm unpacked into a scratch folder, PYTHONPATH + LD_LIBRARY_PATH).

**Left for others, not done here** (outside this lane's files):
- The books (Guide ch. 20, the Learn book's torrra pages) and `docs/build/render/{apps.sh,shoot.sh,lib/fakeprowlarr.py}`, which still shoot torrra for their figures: at the book update. README.md lines 222 and 227 still say torrra in two long table rows that other lanes edit: one word each.
- The browser (T31a): `AutoLaunchProtocolsFromOrigins` for `magnet` would spare the "open with?" question once; `AutoOpenFileTypes` for `torrent` would add a .torrent the moment it lands. Its lane's file, a line each.
- His qBittorrent (his own install of 28 Oct, plan line ~570): nothing here needs it; `rb_libtorrent` stays either way as Fedora's dependency of the binding.
- T39 (network): the engine: UPnP, NAT-PMP and LSD off, port 6881 on 0.0.0.0 and [::], another port only if 6881 is taken.
- T54b/T62 (the wipe): `~/.local/state/fedokawaii/torrents` is his list; it is small and worth carrying.
- Renders for his page: `.claude/review/next/torrents-*` (tools/review-gather.sh picks them up).

## Ledger lines to copy (r27-33)
- r27-33 (T29 + inbox 17:04, 4 Nov 17:20–, lane-torrents): torrra replaced by kawa-torrents (evidence and numbers: .claude/notes/lane-torrents.md). VERIFIED: tests/engine/test_torrents.sh on a real local swarm and a pseudo-terminal; tools/regress/torrents.sh (3 sizes, both moods, to the pixel); real Prowlarr (a private copy), real network, real mpv. LIVE with the next repair + apply.
- r27-33-prowlarr: health `[]`: Allowed Hosts set, public DNS for the container, Tokyo Toshokan out, what fails rested (sources in the lane note).
- r27-extra: speed columns, the engine going on with the window closed, the add line's preview, `v` on a result.
