"""libtorrent: present (FAKE_LT=broken: a build that no longer loads)."""
import os
from types import SimpleNamespace

if os.environ.get("FAKE_LT") == "broken":
    raise ImportError("libtorrent.so: undefined symbol: _ZN5boost")
torrent_flags = SimpleNamespace(paused=1)
