"""iso/screens/questions.py — the installer's %pre: what must be true, then the few questions.

It runs before Anaconda has any screen (anaconda.py: find_kickstart → run_pre_scripts → parse), on
tty1, and leaves /tmp/answers.ks for the kickstart's %include and /tmp/answers.env for its %post. The
disk is not touched before the last page is answered; refusals turn the PC off (any key), no retry.
"""
import ctypes
import glob
import hashlib
import json
import os
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import (ACCENT, ACCENT_TEXT, EDGE2, FAINT, MUTED, ON_SELECT, SELECT, STRONG, TEXT, WIDTH, G, Screen,  # noqa: E402
                     message_page, power_off, restart, run, wrap)

HERE = os.path.dirname(os.path.abspath(__file__))
MIN_DISK_GIB = 60
MIN_RAM_MIB = 3584               # (check.sh's: a "4 GB" machine shows about 3.7 GiB)
METALINK = "https://mirrors.fedoraproject.org/metalink?repo=fedora-@REL@&arch=x86_64"
RELEASE = "45"
VOLID = "Fedora-S-dvd-x86_64-45"
SYSTEM_NAMES = {"root", "bin", "daemon", "adm", "lp", "sync", "shutdown", "halt", "mail", "operator", "games",
                "ftp", "nobody", "dbus", "polkitd", "sshd", "chrony", "systemd-network", "greeter"}


def refuse(s, icon, title, text):
    lines = wrap(text) + ["", "any key turns the PC off"]
    message_page(s, icon, title, lines)
    while s.key(None) is None:
        pass
    power_off()


# ── what must be true ────────────────────────────────────────────────────────
def own_disk():
    """The disk this ISO is on: never offered."""
    r = run("blkid", "-L", VOLID)
    dev = r.stdout.strip()
    if not dev:
        return ""
    r = run("lsblk", "-no", "PKNAME", dev)
    return r.stdout.strip().splitlines()[0] if r.stdout.strip() else os.path.basename(dev)


def disks():
    """The disks an install can go on: inside this PC, never a stick or a USB drive (a backup drive
    larger than the system disk must not even be offered), never this ISO's. (name, model, bytes,
    what it holds now), largest first."""
    r = run("lsblk", "-bnJ", "-o", "NAME,MODEL,SIZE,TYPE,RO,RM,TRAN,FSTYPE")
    try:
        found = json.loads(r.stdout)["blockdevices"]
    except (ValueError, KeyError):
        return []
    own = own_disk()
    out = []
    for d in found:
        if d.get("type") != "disk" or d.get("ro") or d.get("rm") or d.get("tran") == "usb":
            continue
        if d["name"] == own or d["name"].startswith(("zram", "loop")):
            continue
        out.append((d["name"], (d.get("model") or "").strip(), int(d.get("size") or 0), holds(d)))
    return sorted(out, key=lambda x: -x[2])


def holds(d):
    """What is on a disk now, in a few words: its file systems, or that it is empty."""
    kinds = set()

    def walk(n):
        if n.get("fstype"):
            kinds.add(n["fstype"])
        for c in n.get("children") or ():
            walk(c)

    walk(d)
    return ", ".join(sorted(kinds)) if kinds else "empty"


def gib(n):
    return n / 1024 ** 3


def size_words(n):
    return f"{round(n / 1000 ** 3)} GB" if n < 1000 ** 4 else f"{n / 1000 ** 4:.1f} TB".replace(".0 ", " ")


def carrier():
    for n in sorted(os.listdir("/sys/class/net")):
        if n == "lo" or os.path.exists(f"/sys/class/net/{n}/wireless"):
            continue
        try:
            with open(f"/sys/class/net/{n}/carrier", encoding="ascii") as f:
                if f.read().strip() == "1":
                    return n
        except OSError:
            pass
    return ""


def has_address():
    r = run("ip", "-j", "route", "show", "default")
    try:
        return bool(json.loads(r.stdout or "[]"))
    except ValueError:
        return False


def answered():
    r = run("curl", "-sSf", "-o", "/dev/null", "--max-time", "6", METALINK.replace("@REL@", RELEASE))
    return r.returncode == 0


def network_reason(wait=30):
    """None when Fedora answers, else why not. Up to `wait` s: DHCP and the switch take time."""
    end = time.monotonic() + wait
    while True:
        if carrier() and has_address() and answered():
            return None
        if time.monotonic() >= end:
            break
        time.sleep(2)
    if not carrier():
        return "no cable: no wired network is connected. fedokawaii installs from the network, over a wire."
    if not has_address():
        return "no address: the wired network gave this PC none."
    return "no answer: this PC has a network, but Fedora's servers do not answer it."


def check_stick(s):
    """The media test, asked for in the boot menu: on this screen, its own numbers."""
    dev = run("blkid", "-L", VOLID).stdout.strip()
    if not dev:
        refuse(s, "cross", "this stick is damaged", "it cannot be read.")
    top = max(1, (s.rows - 12) // 2)
    s.clear()
    s.torii(top)
    s.heading(top + 6, "hg-0", "checking this stick")
    # (--gauge: a percent a line, what dialog would read)
    p = subprocess.Popen(["checkisomd5", "--gauge", dev], stdout=subprocess.PIPE,  # noqa: S603
                         stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, text=True)
    for line in p.stdout:
        if line.strip().isdigit():
            s.meter(top + 8, s.left, int(line), 100)
    if p.wait() != 0:
        refuse(s, "cross", "this stick is damaged", "its files are not as they were written. write it again.")


def installed_disk():
    """A finished install on some disk: the Btrfs layout we make, and fedokawaii's record of it."""
    r = run("blkid", "-t", "LABEL=fedora", "-o", "device")
    for dev in r.stdout.split():
        os.makedirs("/tmp/fk-look", exist_ok=True)
        # (nologreplay: ro alone still replays the tree log, and this must write nothing)
        if run("mount", "-o", "ro,rescue=nologreplay,subvolid=5", dev, "/tmp/fk-look").returncode != 0:
            continue
        try:
            for sub in ("root", "@", "."):
                if os.path.exists(f"/tmp/fk-look/{sub}/var/lib/fedokawaii/phase"):
                    return dev
        finally:
            run("umount", "/tmp/fk-look")
    return None


def gpu_problem():
    """What setup's own check would stop at, said before the disk is touched: the desktop is built on
    AMD's and Intel's open drivers. (A test VM brings systemd's credentials in its firmware's
    OEM strings: tools/vm-iso-test.sh; a real PC has none.)"""
    vendors = set()
    for d in glob.glob("/sys/class/drm/card[0-9]*/device/vendor"):
        try:
            with open(d, encoding="ascii") as f:
                vendors.add(f.read().strip())
        except OSError:
            pass
    if vendors & {"0x1002", "0x8086"}:
        return ""
    for raw in glob.glob("/sys/firmware/dmi/entries/11-*/raw"):
        try:
            with open(raw, "rb") as f:
                if b"io.systemd.credential" in f.read():
                    return ""
        except OSError:
            pass
    if "0x10de" in vendors:
        return "this PC has an NVIDIA card alone. fedokawaii is built on the open drivers of AMD and Intel."
    return "no AMD or Intel graphics were found on this PC. fedokawaii is built on their open drivers."


def checks(s):
    if not os.path.isdir("/sys/firmware/efi"):
        refuse(s, "power", "this PC started without UEFI",
               "fedokawaii installs on UEFI only. turn on UEFI in the PC's firmware settings "
               "(CSM or legacy off), then start from this stick again.")
    with open("/proc/meminfo", encoding="ascii") as f:
        mem = int(f.readline().split()[1]) // 1024
    if mem < MIN_RAM_MIB:
        refuse(s, "power", "not enough memory",
               f"this PC has {round(mem / 1024)} GB of memory. fedokawaii needs 4 GB.")
    gpu = gpu_problem()
    if gpu:
        refuse(s, "monitor", "no graphics to build on", gpu)
    ds = disks()
    if not ds or gib(ds[0][2]) < MIN_DISK_GIB:
        have = f"the largest disk here holds {size_words(ds[0][2])}." if ds else "no disk was found."
        refuse(s, "drive", "no disk large enough", f"{have} fedokawaii needs {MIN_DISK_GIB} GB.")
    reason = network_reason()
    if reason:
        refuse(s, "ethernet", "no network", reason)
    dev = installed_disk()
    if dev:
        message_page(s, "check", "fedokawaii is installed on this PC",
                     wrap(f"{dev} already holds it. take out the stick and restart.") +
                     ["", "enter  restart", "i      install again, erasing it"])
        while True:
            k = s.key(None)
            if k == "enter":
                restart()
            if k in ("i", "I"):
                break
    return ds


# ── the form ─────────────────────────────────────────────────────────────────
def geo():
    """Fedora's GeoIP, Anaconda's own default source: a default only, never asked for twice."""
    r = run("curl", "-sSf", "--max-time", "4", "https://geoip.fedoraproject.org/city")
    try:
        return json.loads(r.stdout)
    except ValueError:
        return {}


def zones():
    names = set()
    try:
        with open("/usr/share/zoneinfo/tzdata.zi", encoding="utf-8") as f:
            for line in f:
                p = line.split()
                if line.startswith("Z ") and len(p) > 1:
                    names.add(p[1])
                elif line.startswith("L ") and len(p) > 2:
                    names.add(p[2])
    except OSError:
        pass
    return sorted(n for n in names if "/" in n and not n.startswith(("Etc/", "SystemV/", "US/"))) + ["UTC"]


def keymaps():
    r = run("localectl", "list-keymaps")
    maps = r.stdout.split()
    return maps or ["us"]


def hash_password(pw):
    c = ctypes.CDLL("libcrypt.so.2", use_errno=True)
    c.crypt_gensalt.restype = ctypes.c_char_p
    c.crypt_gensalt.argtypes = [ctypes.c_char_p, ctypes.c_ulong, ctypes.c_char_p, ctypes.c_int]
    c.crypt.restype = ctypes.c_char_p
    c.crypt.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
    salt = c.crypt_gensalt(b"$y$", 0, None, 0)
    if not salt:
        raise RuntimeError("no salt")
    h = c.crypt(pw.encode("utf-8"), salt)
    if not h or not h.startswith(b"$y$"):
        raise RuntimeError("no hash")
    return h.decode("ascii")


class Field:
    def __init__(self, key, icon, label, value="", secret=False, picker=None):
        self.key, self.icon, self.label, self.value = key, icon, label, value
        self.secret, self.picker = secret, picker
        self.problem = ""


NAME_RE = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")
HOST_RE = re.compile(r"^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$")


def validate(f, fields):
    """The row's problem, in a few words; "" when it is good. Empty answers come back at the end."""
    v = f.value
    if f.key == "name":
        if not v:
            return "a name for you"
        if not NAME_RE.match(v):
            return "small letters and digits, a letter first"
        if v in SYSTEM_NAMES:
            return "that name is the system's"
    elif f.key == "password":
        if not v:
            return "a password"
    elif f.key == "again":
        if v != fields["password"].value:
            return "not the same"
    elif f.key == "disk":
        if not v:
            return "choose the disk"
    elif f.key == "host":
        if not HOST_RE.match(v):
            return "small letters, digits and hyphens"
    return ""


class Form:
    ROW0 = 8                     # the first row under the heading

    def __init__(self, s, ds, geoip):
        self.s, self.ds = s, ds
        # (the one that fits, if there is only one; among several the choice is yours, never a default)
        fit = [d for d in ds if gib(d[2]) >= MIN_DISK_GIB]
        self.disk = fit[0][0] if len(fit) == 1 else ""
        tz = geoip.get("time_zone") or "UTC"
        if tz not in zones():
            tz = "UTC"
        self.geo = geoip
        self.fields = {}
        rows = [Field("name", "user", "your name"),
                Field("password", "lock", "password", secret=True),
                Field("again", "lock", "again", secret=True),
                Field("disk", "drive", "disk", self.disk_words(fit[0]) if self.disk else "", picker=self.pick_disk),
                Field("zone", "globe", "time zone", tz, picker=self.pick_zone),
                Field("keys", "keyboard", "keyboard", "us", picker=self.pick_keys),
                Field("host", "monitor", "this PC", "fedokawaii")]
        self.rows = rows
        for f in rows:
            self.fields[f.key] = f
        self.cur = 0
        self.top = max(0, (s.rows - 7 - 2 - len(rows) - 3) // 2)
        self.msg = ""

    @staticmethod
    def disk_words(d, room=WIDTH - 19):
        """Its name and size always; what it holds, then its model, as far as they fit (never cut)."""
        base = f"{d[0]}  {size_words(d[2])}"
        for words in (f"{base}  {d[1]}  · {d[3]}", f"{base}  · {d[3]}", f"{base}  {d[1]}", base):
            if len(words) <= room:
                return words
        return base

    def row_of(self, i):
        return self.top + 8 + i

    def draw_row(self, i, on=False):
        s, f = self.s, self.rows[i]
        r, c = self.row_of(i), s.left
        ground = SELECT if on else 0
        ink = ON_SELECT if on else TEXT
        s.at(r, c - 1, " " * (WIDTH + 2), ink, ground)
        s.at(r, c + 1, G[f.icon], ON_SELECT if on else ACCENT_TEXT, ground)
        s.at(r, c + 4, f.label, ink, ground)
        v = "◆" * len(f.value) if f.secret else f.value
        v = v[-(WIDTH - 19):]
        s.at(r, c + 16, v, ink if on else (STRONG if f.value else MUTED), ground)
        if on and not f.picker:
            s.at(r, c + 16 + len(v), " ", ink, ACCENT)
        if f.picker and on:
            s.at(r, c + WIDTH - 2, G["chevron"], ON_SELECT, ground)

    def draw_go(self, on=False):
        s = self.s
        r, c = self.row_of(len(self.rows)) + 1, s.left
        ground = SELECT if on else 0
        s.at(r, c - 1, " " * (WIDTH + 2), ON_SELECT if on else TEXT, ground)
        s.at(r, c + 1, G["download"], ON_SELECT if on else ACCENT_TEXT, ground)
        s.at(r, c + 4, "install", ON_SELECT if on else STRONG, ground)

    def draw_msg(self):
        s = self.s
        r = self.row_of(len(self.rows)) + 3
        s.clear_row(r, s.left - 1, WIDTH + 2)
        if self.msg:
            s.at(r, s.left, self.msg, ACCENT_TEXT)

    def draw(self):
        s = self.s
        s.clear()
        s.torii(self.top)
        s.heading(self.top + 6, "torii-small", "a new home")
        for i in range(len(self.rows)):
            self.draw_row(i, i == self.cur)
        self.draw_go(self.cur == len(self.rows))
        self.draw_msg()

    def move(self, to):
        was = self.cur
        self.cur = to % (len(self.rows) + 1)
        if was < len(self.rows):
            self.draw_row(was)
        else:
            self.draw_go()
        if self.cur < len(self.rows):
            self.draw_row(self.cur, True)
        else:
            self.draw_go(True)

    # ── pickers ──────────────────────────────────────────────────────────────
    def picker(self, title, icon, items, current, faint=None):
        """A list on a page of its own: type to filter, ↑ ↓, enter takes, esc leaves it as it was."""
        s = self.s
        q = ""
        cur = 0
        faint = faint or set()
        height = min(s.rows - 8, 16)
        top = max(0, (s.rows - height - 4) // 2)
        try:
            cur = items.index(current)
        except ValueError:
            cur = 0
        while True:
            shown = [x for x in items if q.lower() in x.lower()] if q else items
            cur = min(cur, max(len(shown) - 1, 0))
            first = max(0, min(cur - height // 2, max(len(shown) - height, 0)))
            s.clear()
            s.heading(top, icon, title)
            if len(items) > height:
                s.at(top + 2, s.left + 1, G["chevron"], ACCENT_TEXT)
                s.at(top + 2, s.left + 4, q if q else "type to filter", TEXT if q else FAINT)
                s.at(top + 2, s.left + 4 + len(q), " ", TEXT, ACCENT if q else 0)
                count = f"{len(shown)}"
                s.at(top + 2, s.left + WIDTH - len(count), count, MUTED)
            for i, x in enumerate(shown[first:first + height]):
                r = top + 4 + i
                on = first + i == cur
                ink = ON_SELECT if on else (FAINT if x in faint else TEXT)
                s.at(r, s.left - 1, " " * (WIDTH + 2), ink, SELECT if on else 0)
                s.at(r, s.left + 1, x[:WIDTH - 2], ink, SELECT if on else 0)
            if not shown:
                s.at(top + 4, s.left + 1, "nothing matches", FAINT)
            k = s.key(None)
            if k == "enter":
                if shown and shown[cur] not in faint:
                    return shown[cur]
            elif k == "esc":
                return None
            elif k == "up":
                cur = max(cur - 1, 0)
            elif k == "down":
                cur = min(cur + 1, max(len(shown) - 1, 0))
            elif k == "pgup":
                cur = max(cur - height, 0)
            elif k == "pgdn":
                cur = min(cur + height, max(len(shown) - 1, 0))
            elif k == "backspace":
                q = q[:-1]
                cur = 0
            elif k and len(k) == 1 and len(items) > height:
                q += k
                cur = 0

    def pick_disk(self):
        words = {self.disk_words(d): d for d in self.ds}
        small = {w for w, d in words.items() if gib(d[2]) < MIN_DISK_GIB}
        got = self.picker("disk", "drive", list(words), self.fields["disk"].value, small)
        if got:
            self.fields["disk"].value, self.disk = got, words[got][0]

    def pick_zone(self):
        got = self.picker("time zone", "globe", zones(), self.fields["zone"].value)
        if got:
            self.fields["zone"].value = got

    def pick_keys(self):
        got = self.picker("keyboard", "keyboard", keymaps(), self.fields["keys"].value)
        if got:
            self.fields["keys"].value = got
            run("loadkeys", got)

    # ── the loop ─────────────────────────────────────────────────────────────
    def first_problem(self):
        for i, f in enumerate(self.rows):
            p = validate(f, self.fields)
            if p:
                return i, p
        return None, ""

    def run(self):
        self.draw()
        while True:
            k = self.s.key(None)
            if k in ("", None):
                continue
            if k == "f2":
                self.pick_keys()
                self.draw()
                continue
            if k in ("up", "backtab"):
                self.msg = ""
                self.draw_msg()
                self.move(self.cur - 1)
                continue
            if k in ("down", "tab"):
                self.msg = ""
                self.draw_msg()
                self.move(self.cur + 1)
                continue
            on_go = self.cur == len(self.rows)
            f = None if on_go else self.rows[self.cur]
            if k == "enter":
                if on_go:
                    i, p = self.first_problem()
                    if i is not None:
                        self.msg = p
                        self.move(i)
                        self.draw_msg()
                        continue
                    if self.confirm():
                        return
                    self.draw()
                elif f.picker:
                    f.picker()
                    self.draw()
                else:
                    p = validate(f, self.fields)
                    self.msg = p if f.value or f.key == "again" else ""
                    self.draw_msg()
                    if not p:
                        self.move(self.cur + 1)
                continue
            if f is None or f.picker:
                continue
            if k == "backspace":
                f.value = f.value[:-1]
            elif len(k) == 1 and ord(k) >= 0x20 and len(f.value) < (256 if f.secret else 32):
                f.value += k
            else:
                continue
            self.msg = ""
            self.draw_msg()
            self.draw_row(self.cur, True)

    def confirm(self):
        s = self.s
        word = self.fields["disk"].value
        lines = wrap(f"everything on {word} will be erased.") + ["", "enter  install", "esc    back"]
        message_page(s, "drive", "this disk", lines)
        while True:
            k = s.key(None)
            if k == "enter":
                return True
            if k == "esc":
                return False


# ── what the kickstart reads ─────────────────────────────────────────────────
def write_answers(form):
    f = form.fields
    hashed = hash_password(f["password"].value)
    keys = f["keys"].value
    layout = keys.split("-")[0]
    if not os.path.isdir("/usr/share/X11/xkb/symbols") or not os.path.exists(f"/usr/share/X11/xkb/symbols/{layout}"):
        layout = "us"
    ks = [f"keyboard --vckeymap={keys} --xlayouts={layout}",
          f"timezone {f['zone'].value} --utc",
          f"network --bootproto=dhcp --device=link --activate --hostname={f['host'].value}",
          f"user --name={f['name'].value} --groups=wheel --iscrypted --password={hashed}",
          f"ignoredisk --only-use={form.disk}",
          f"clearpart --all --initlabel --disklabel=gpt --drives={form.disk}",
          f"bootloader --boot-drive={form.disk} --timeout=0 --append=\"@APPEND@\"", ""]
    fd = os.open("/tmp/answers.ks", os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="ascii") as w:
        w.write("\n".join(ks))
    g = form.geo
    env = {"FK_USER": f["name"].value, "FK_ZONE": f["zone"].value, "FK_LAYOUT": layout,
           "FK_CITY": g.get("city") or "", "FK_LAT": str(g.get("latitude") or ""),
           "FK_LON": str(g.get("longitude") or ""), "FK_GEO_ZONE": g.get("time_zone") or ""}
    with open("/tmp/answers.env", "w", encoding="utf-8") as w:
        for k, v in env.items():
            w.write(f"{k}={shell_quote(v)}\n")


def shell_quote(v):
    return "'" + v.replace("'", "'\\''") + "'"


def payload_ok():
    """The toolkit as it was built: checked before the disk is touched."""
    try:
        with open(os.path.join(HERE, "toolkit.sha256"), encoding="ascii") as f:
            want = f.read().split()[0]
        h = hashlib.sha256()
        with open(os.path.join(HERE, "toolkit.tar.xz"), "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    except OSError:
        return False
    return h.hexdigest() == want


def main():
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    s = Screen()
    with open("/proc/cmdline", encoding="utf-8") as f:
        if "fk.check" in f.read().split():
            check_stick(s)
    ds = checks(s)
    if not payload_ok():
        refuse(s, "cross", "this stick is damaged",
               "the files on it are not as they were built. write it again.")
    form = Form(s, ds, geo())
    form.run()
    write_answers(form)
    s.clear()
    s.close()
    # the one owner of the screen from here on (Omarchy's lesson): a daemon, its files closed
    # (pykickstart's warning: otherwise the installation appears hung)
    subprocess.Popen([sys.executable, os.path.join(HERE, "progress.py")],  # noqa: S603
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     close_fds=True, start_new_session=True)


if __name__ == "__main__":
    main()
