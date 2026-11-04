"""tests/engine/torrents_swarm.py — a little swarm on this computer alone, for kawa-torrents' engine:
real libtorrent on both sides, over the loopback, so nothing is mocked and nothing leaves the machine.

    swarm = Swarm(tmp); t = swarm.torrent("name", {"a.mkv": 1 << 24})   # files made, a seeder seeding
    t.magnet (with x.pe: where the seeder listens) · t.path (its .torrent) · t.hash · swarm.close()
    e = Engine(); e.start(); c = e.client(); c.ask({"op": "add", …}); c.wait(lambda: …, seconds)
"""
import json
import os
import random
import select
import socket
import subprocess
import sys
import time

import libtorrent as lt

REPO = os.environ["REPO"]


class Torrent:
    pass


class Swarm:
    def __init__(self, root):
        self.root = root
        os.makedirs(root, exist_ok=True)
        self.ses = lt.session({"listen_interfaces": "127.0.0.1:0", "enable_dht": False, "enable_lsd": False,
                               "enable_upnp": False, "enable_natpmp": False, "allow_multiple_connections_per_ip": True,
                               "alert_mask": lt.alert_category.error})

    def torrent(self, name, files, piece=1 << 18, seed=True, rate=0):
        """FILES: {relative path: bytes}. A folder of its own for each; a .torrent beside it."""
        where = os.path.join(self.root, "seed-" + name)
        os.makedirs(where, exist_ok=True)
        rng = random.Random(name)
        fs = lt.file_storage()
        for rel, n in files.items():
            full = os.path.join(where, name, rel)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as f:
                left = n
                while left:
                    k = min(left, 1 << 20)
                    f.write(rng.randbytes(k))
                    left -= k
        lt.add_files(fs, os.path.join(where, name))
        ct = lt.create_torrent(fs, piece, flags=lt.create_torrent.v1_only)
        lt.set_piece_hashes(ct, where)
        data = lt.bencode(ct.generate())
        t = Torrent()
        t.path = os.path.join(self.root, name + ".torrent")
        with open(t.path, "wb") as f:
            f.write(data)
        t.bytes = data
        t.name, t.where, t.total = name, where, sum(files.values())
        t.ti = lt.torrent_info(lt.bdecode(data))
        t.hash = str(t.ti.info_hashes().v1)
        if seed:
            self.seed(t, rate)
        return t

    def seed(self, t, rate=0):
        atp = lt.add_torrent_params()
        atp.ti = t.ti
        atp.save_path = t.where
        atp.flags = lt.torrent_flags.seed_mode
        t.handle = self.ses.add_torrent(atp)
        if rate:
            t.handle.set_upload_limit(rate)
        t.magnet = f"magnet:?xt=urn:btih:{t.hash}&dn={t.name}&x.pe=127.0.0.1:{self.ses.listen_port()}"
        return t

    def close(self):
        self.ses.pause()
        del self.ses


class Client:
    def __init__(self, sock_path):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.settimeout(10)
        self.s.connect(sock_path)
        self.buf, self.n = b"", 0
        self.rows, self.events, self.answers = {}, [], {}
        self.send({"op": "hello"})

    def send(self, q):
        self.s.sendall((json.dumps(q) + "\n").encode())

    def pump(self, wait=0.1):
        r, _, _ = select.select([self.s], [], [], wait)
        if not r:
            return
        data = self.s.recv(1 << 20)
        if not data:
            raise ConnectionError("the engine closed")
        self.buf += data
        *lines, self.buf = self.buf.split(b"\n")
        for line in lines:
            m = json.loads(line)
            if "re" in m:
                self.answers[m["re"]] = m
            elif m.get("ev") == "rows":
                for r in m["rows"]:
                    self.rows[r["id"]] = r
                for i in m["gone"]:
                    self.rows.pop(i, None)
                self.events.append(m)
            else:
                self.events.append(m)

    def ask(self, q, seconds=10):
        self.n += 1
        n = self.n
        self.send({**q, "n": n})
        end = time.monotonic() + seconds
        while n not in self.answers:
            if time.monotonic() > end:
                raise TimeoutError(f"no answer to {q}")
            self.pump()
        return self.answers.pop(n)

    def wait(self, cond, seconds=20, what="it"):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            self.pump()
            v = cond()
            if v:
                return v
        raise TimeoutError(f"waited {seconds} s for {what}; rows: {json.dumps(list(self.rows.values()))[:1200]}")

    def event(self, ev, seconds=20, **want):
        return self.wait(lambda: next((m for m in self.events if m.get("ev") == ev and all(m.get(k) == v for k, v in want.items())), None),
                         seconds, f"the event {ev}")

    def close(self):
        self.s.close()


class Engine:
    def __init__(self):
        self.proc = None
        self.sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")

    def start(self, idle=600):
        try:
            os.unlink(self.sock)
        except FileNotFoundError:
            pass
        env = dict(os.environ, KAWA_TORRENTS_NET="local", KAWA_TORRENTS_IDLE=str(idle),
                   KAWA_TORRENTS_LIB=os.path.join(REPO, "configs/home/.local/lib/fedokawaii/kawa-torrents"))
        self.proc = subprocess.Popen([sys.executable, os.path.join(REPO, "bin/kawa-torrents"), "engine"], env=env)
        end = time.monotonic() + 15
        while not os.path.exists(self.sock):
            if time.monotonic() > end or self.proc.poll() is not None:
                raise RuntimeError("the engine did not start")
            time.sleep(0.02)
        return self

    def client(self):
        return Client(self.sock)

    def stop(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()
            self.proc.wait(15)
        return self.proc.returncode if self.proc else None
