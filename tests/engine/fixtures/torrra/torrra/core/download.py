"""torrra's download manager: its torrents, each a libtorrent handle (here, what the test says)."""
from types import SimpleNamespace


class Handle:
    def __init__(self, d):
        self.d = d

    def status(self):
        d = self.d
        return SimpleNamespace(name=d["name"], save_path=d["save_path"], total_wanted=d["total"],
                               total_wanted_done=d["done"], is_finished=d.get("finished", False),
                               is_seeding=d.get("finished", False), flags=1 if d.get("paused") else 0)


class Manager:
    torrents = {}


_m = Manager()


def get_download_manager():
    return _m
