"""What is kept between sittings: JSON written whole or not at all, games as PGN.

A file cut short or broken (a power cut, a full disk) is never fatal: the last good copy (.bak) is
taken, or the part starts afresh, and the broken file is kept beside it as .broken.
"""
import json
import os
import time


class Store:
    def __init__(self, folder):
        self.folder = folder
        os.makedirs(os.path.join(folder, "games"), exist_ok=True)

    def path(self, name):
        return os.path.join(self.folder, name)

    def load(self, name, default):
        """The value in name, or the backup's, or default; never an exception for a damaged file."""
        p = self.path(name)
        for candidate in (p, p + ".bak"):
            try:
                with open(candidate, encoding="utf-8") as f:
                    value = json.load(f)
            except FileNotFoundError:
                continue
            except (OSError, ValueError):
                if candidate == p:
                    try:
                        os.replace(p, p + ".broken")
                    except OSError:
                        pass
                continue
            if type(value) is type(default):
                return value
        return default

    def save(self, name, value):
        """Written to a new file, flushed, then put in place; the old one stays as .bak. A full disk
        leaves the last good file: False."""
        p = self.path(name)
        tmp = f"{p}.{os.getpid()}.new"
        try:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(tmp, "w", encoding="utf-8") as f:
                json.dump(value, f, separators=(",", ":"))
                f.flush()
                os.fsync(f.fileno())
            if os.path.exists(p):
                os.replace(p, p + ".bak")
            os.replace(tmp, p)
            return True
        except OSError:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            return False

    def delete(self, name):
        for suffix in ("", ".bak"):
            try:
                os.unlink(self.path(name) + suffix)
            except OSError:
                pass

    def write_text(self, name, text):
        p = self.path(name)
        tmp = f"{p}.{os.getpid()}.new"
        try:
            os.makedirs(os.path.dirname(p), exist_ok=True)
            with open(tmp, "w", encoding="utf-8") as f:
                f.write(text)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, p)
            return True
        except OSError:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            return False

    def read_text(self, name):
        try:
            with open(self.path(name), encoding="utf-8", errors="replace") as f:
                return f.read()
        except OSError:
            return None

    def note_crash(self, text):
        """A traceback, for the record: the destruction tests look for this file."""
        try:
            with open(self.path("crash.log"), "a", encoding="utf-8") as f:
                f.write(time.strftime("%F %T ") + text + "\n")
        except OSError:
            pass
