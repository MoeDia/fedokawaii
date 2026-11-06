"""What the engine and the window share: where things live, what counts as a torrent's link, how a
name and a number are written. Nothing here imports libtorrent: the window starts without it."""
import base64
import binascii
import functools
import html
import os
import re
import unicodedata
import urllib.parse

HOME = os.path.expanduser("~")
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "fedokawaii/torrents")
RUN = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
SOCK = os.path.join(RUN, "kawa-torrents.sock")     # (kawa-torrents.socket: systemd holds it, the engine starts on demand)
WINDOW = os.path.join(RUN, "kawa-torrents.window")  # the window holds a lock on this while it is open
DOWNLOADS = os.path.join(HOME, "downloads")

# ── a link ──────────────────────────────────────────────────────────────────────────────────
_MAGNET = re.compile(r"magnet:\?[^\s\"'<>\\`]+", re.I)
_TORRENT_URL = re.compile(r"https?://[^\s\"'<>\\`]+?\.torrent(?:\?[^\s\"'<>\\`]*)?(?=$|[\s\"'<>\\`])", re.I)
_ANY_URL = re.compile(r"https?://[^\s\"'<>\\`]+", re.I)
_HEX = re.compile(r"(?<![0-9a-fA-F])[0-9a-fA-F]{40}(?![0-9a-fA-F])")
_B32 = re.compile(r"(?<![A-Z2-7])[A-Z2-7]{32}(?![A-Z2-7])")
_FILE_URI = re.compile(r"file://[^\s\"'<>\\`]+\.torrent(?=$|[\s\"'<>\\`])", re.I)
_PATH = re.compile(r"(?:^|(?<=[\s\"']))((?:~|/)[^\n\"']*?\.torrent)(?=$|[\s\"'])", re.I | re.M)
_TAIL = ").,;:!?]}>"
MAX_TORRENT = 64 << 20                             # bytes: more than any .torrent, less than a mistake


def file_uri_path(uri):
    """file:///a/my%20file.torrent → its path (file://localhost/… and file://HOST/… too)."""
    return urllib.parse.unquote(urllib.parse.urlsplit(uri).path)


def links(text, loose=True):
    """Every torrent's link in TEXT, first seen first, each once, as (kind, value):
    ("magnet", uri) · ("url", http link) · ("file", path of a .torrent that is there). A page's
    source, a chat line, a list: magnets are found wherever they stand. LOOSE: what only a line
    typed or pasted for this purpose can mean — a bare hash, any http link (a git commit is 40
    hex digits too: never offered from the clipboard)."""
    text = (text or "").strip()
    if loose and text.endswith(".torrent") and os.path.isfile(text):   # (named from where you stand, spaces and all)
        return [("file", os.path.abspath(text))]
    found, seen = [], set()

    def add(at, kind, value):
        key = magnet_hash(value) or value if kind == "magnet" else value
        if key not in seen:
            seen.add(key)
            found.append((at, kind, value))

    for m in _MAGNET.finditer(text):
        add(m.start(), "magnet", html.unescape(m.group(0)).rstrip(_TAIL))
    spans = [m.span() for m in _MAGNET.finditer(text)]

    def inside(at):
        return any(a <= at < b for a, b in spans)

    for m in _TORRENT_URL.finditer(text):
        if not inside(m.start()):
            add(m.start(), "url", html.unescape(m.group(0)))
    for m in _FILE_URI.finditer(text):
        p = file_uri_path(m.group(0))
        if os.path.isfile(p):
            add(m.start(), "file", p)
    for m in _PATH.finditer(text):
        p = os.path.expanduser(m.group(1))
        if os.path.isfile(p):
            add(m.start(1), "file", p)
    if loose:
        if not found:
            for m in _ANY_URL.finditer(text):
                add(m.start(), "url", html.unescape(m.group(0)).rstrip(_TAIL))
        if not found:
            for m in list(_HEX.finditer(text)) + list(_B32.finditer(text)):
                add(m.start(), "magnet", "magnet:?xt=urn:btih:" + m.group(0))
    return [(k, v) for _, k, v in sorted(found, key=lambda f: f[0])]


def asking(kind, value):
    """(kind, value) of links() as the engine is asked: a .torrent goes as its contents, so the engine, walled in, needs no
    sight of the folder it lies in (/tmp, where a browser may have put it, is not its own)."""
    if kind != "file":
        return {"kind": kind, "value": value}
    with open(value, "rb") as f:
        data = f.read(MAX_TORRENT)
    return {"kind": "torrent", "value": base64.b64encode(data).decode("ascii")}


def _query(uri):
    return urllib.parse.parse_qs(urllib.parse.urlsplit(uri).query, keep_blank_values=False)


def magnet_hash(uri):
    """Its info hash in lower-case hex (a base32 one turned to hex), so two spellings of one
    torrent are one torrent; None if it names none we can read (v2's btmh is given as it is)."""
    for xt in _query(uri).get("xt", []):
        h = xt.rpartition(":")[2]
        if xt.lower().startswith("urn:btih:"):
            if re.fullmatch(r"[0-9a-fA-F]{40}", h):
                return h.lower()
            if re.fullmatch(r"[A-Za-z2-7]{32}", h):
                try:
                    return binascii.hexlify(base64.b32decode(h.upper())).decode()
                except binascii.Error:
                    return None
        elif xt.lower().startswith("urn:btmh:"):
            return h.lower()[-64:]
    return None


def magnet_name(uri):
    """The name a magnet link gives (dn), else its hash's first letters."""
    q = _query(uri)
    if q.get("dn"):
        return safe(q["dn"][0])
    h = magnet_hash(uri)
    return h[:16] if h else "a magnet link"


def magnet_trackers(uri):
    return [t for t in _query(uri).get("tr", []) if re.match(r"(udp|https?|wss?)://", t, re.I)]


def make_magnet(info_hash, name=""):
    return "magnet:?xt=urn:btih:" + info_hash + ("&dn=" + urllib.parse.quote(name) if name else "")


def without_key(url):
    """A link of Prowlarr's carries its API key: what is kept or shown has it taken out."""
    return re.sub(r"([?&])apikey=[^&]*&?", r"\1", url).rstrip("?&")


class FetchFailed(Exception):
    def __init__(self, words, final=False):
        super().__init__(words)
        self.final = final


def fetch_link(url, wait):
    """What a link leads to: ("magnet", uri) (a redirect) or ("bytes", a .torrent's contents). The words
    of a failure name its cause and never the link (it holds Prowlarr's key)."""
    import urllib.error            # (here, not above: with what it pulls in, half the window's memory and start)
    import urllib.request

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *a, **k):
            return None

    opener = urllib.request.build_opener(NoRedirect)
    for _ in range(6):
        if url.lower().startswith("magnet:"):
            return "magnet", url
        try:
            with opener.open(urllib.request.Request(url, headers={"User-Agent": "kawa-torrents"}), timeout=wait) as r:
                data = r.read(64 << 20)
            if data[:1] != b"d":
                raise FetchFailed("the site answered with something else than a torrent", final=True)
            return "bytes", data
        except urllib.error.HTTPError as e:
            if e.code in (301, 302, 303, 307, 308) and e.headers.get("Location"):
                url = urllib.parse.urljoin(url, e.headers["Location"])
                continue
            if e.code in (401, 403, 404, 410):
                raise FetchFailed(f"the site refused it (HTTP {e.code})", final=True) from None
            raise FetchFailed(f"the site's trouble (HTTP {e.code})") from None
        except TimeoutError:
            raise FetchFailed(f"no answer in {wait} s") from None
        except urllib.error.URLError as e:
            reason = e.reason.strerror if isinstance(e.reason, OSError) and e.reason.strerror else str(e.reason)
            raise FetchFailed(f"could not reach it: {reason}") from None
        except OSError as e:
            raise FetchFailed(f"could not reach it: {e.strerror or e}") from None
    raise FetchFailed("too many redirects", final=True)


# ── a name ──────────────────────────────────────────────────────────────────────────────────
_UNSAFE = {c: None for c in (*range(0x20), *range(0x7f, 0xa0), *range(0x202a, 0x202f), *range(0x2066, 0x206a), 0x200e, 0x200f)}
_UNSAFE[9] = _UNSAFE[10] = _UNSAFE[13] = " "


def safe(s):
    """A name from the network, fit for the terminal: no control letters (an escape in a torrent's
    name must not reach the screen), no writing-direction overrides."""
    return str(s).translate(_UNSAFE)


# the endings a torrent's name keeps as they are (a file's type, not words): kawa-downloads' own
_KEPT = {"iso", "img", "mkv", "mp4", "avi", "webm", "zip", "rar", "7z", "tar", "gz", "xz", "zst",
         "pdf", "epub", "cbz", "flac", "mp3", "ogg", "opus", "m4a", "srt"}


_AS_NAMED = {"iso", "img"}


def _gap(m):
    if m[0] == ".":
        left, right = re.search(r"\d*$", m.string[:m.start()])[0], re.match(r"\d*", m.string[m.end():])[0]
        if 0 < len(left) <= 2 and 0 < len(right) <= 2:
            return "."
    return " "


@functools.lru_cache(maxsize=4096)                 # (asked for at every frame, for every row in sight)
def reading(name):
    """A torrent's name as words: its dots and underscores read as spaces — a version's dots
    (1.6, 24.04.1) and a file's type at the end kept."""
    name = safe(name)
    if " " in name:
        return name.strip()
    stem, dot, end = name.rpartition(".")
    if dot and end.lower() in _AS_NAMED:           # (a disc's image is a file's name, not words: x86_64 stays)
        return name
    if not dot or end.lower() not in _KEPT:
        stem, end = name, ""
    return re.sub(r"[._]+", _gap, stem).strip() + ("." + end if end else "")


def width_of(c):
    o = ord(c)
    if 0x20 <= o < 0x7f:
        return 1
    if unicodedata.category(c) in ("Mn", "Me", "Cf"):
        return 0
    return 2 if unicodedata.east_asian_width(c) in ("W", "F") else 1


def cells(s):
    """The columns S takes on the terminal: a kanji two, a combining mark none."""
    return len(s) if s.isascii() else sum(width_of(c) for c in s)


def cut(s, n):
    """S in at most N columns: all of it, or cut at a word's end when one lies in the last half, else
    at the column (docs/design-system.md §2: nothing is ever put in its place, no "…")."""
    if n <= 0:
        return ""
    if cells(s) <= n:
        return s
    used, at = 0, 0
    while at < len(s) and used + width_of(s[at]) <= n:
        used += width_of(s[at])
        at += 1
    head = s[:at]
    word = max(head.rfind(c) for c in " -_.,/")
    return head[:word].rstrip(" -_.,/") if word >= n // 2 else head


def pad(s, n):
    return s + " " * max(0, n - cells(s))


# ── a number ────────────────────────────────────────────────────────────────────────────────
def size(n):
    """Three figures at most, 7 cells at most: 800 B · 12 KB · 640 MB · 88.0 MB · 23.6 GB."""
    n = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1000:
            return f"{n:.0f} {unit}" if unit in ("B", "KB") or n >= 100 else f"{n:.1f} {unit}"
        n /= 1000
    return f"{n:.0f} TB" if n >= 100 else f"{n:.1f} TB"


def speed(n):
    return size(n) + "/s" if n >= 1000 else ""


def duration(s):
    """How long, in one or two words: 45 s · 12 min · 3 h 10 · 2 days."""
    s = int(s)
    if s < 60:
        return f"{s} s"
    if s < 3600:
        return f"{s // 60} min"
    if s < 86400:
        return f"{s // 3600} h {s % 3600 // 60:02d}"
    d = s // 86400
    return "1 day" if d == 1 else f"{d} days"


def eta(s):
    """How long, in a column: its unit one letter, so the digits stack: 45 s · 12 m · 3.2 h · 2 d."""
    s = int(s)
    if s < 60:
        return f"{s} s"
    if s < 3600:
        return f"{s // 60} m"
    if s < 86400:
        return f"{s / 3600:.1f} h"
    return f"{s // 86400} d"


def natural(s):
    """A name's sorting key: episode 2 before episode 10."""
    return [int(p) if p.isdigit() else p.casefold() for p in re.split(r"(\d+)", s)]


VIDEO = {"mkv", "mp4", "m4v", "avi", "webm", "mov", "wmv", "flv", "ts", "m2ts", "mpg", "mpeg", "ogv", "vob"}
AUDIO = {"flac", "mp3", "opus", "ogg", "m4a", "aac", "wav", "wma", "alac"}


def playable(path):
    return path.rpartition(".")[2].lower() in VIDEO | AUDIO
