# lane-torrents (T29 + the owner's 17:04 note)

Status: WORK IN PROGRESS. See the end of this file when it says DONE.

Decisions so far (each with its evidence; to fold into the ledger as r27-33):
- torrra is replaced, not patched. Evidence: torrra keeps no resume data (core/download.py adds every torrent from its magnet
  at each open: metadata fetched again, every file hashed again; that is also the repeat "finished" notice), its window is
  Textual (50.5 MB RSS before a window opens, 110 ms of imports) monkey-patched by kawa-torrra, libtorrent wheels stop at
  Python 3.13 (uv's CPython kept only for it). Ours: Fedora's python3 + rb_libtorrent-python3 2.0.11 (F44 and F45), stdlib only.
