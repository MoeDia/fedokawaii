#!/usr/bin/env bash
# tests/installer/test_iso_tools.sh — the installer ISO's parts that need no boot (a boot is
# tools/vm-iso-test.sh's): every input pinned, the boot menu's two lines, the console font's numbers
# (the blank where the console erases with it), the screen reader reading its own font, the disks an
# install is offered (never a USB drive, no default among several), the answers the kickstart gets, the
# kickstart strictly parsed, what the VM tool refuses.
export FK_PURE=1
. "$(dirname "$0")/lib.sh"

skip() { printf '  - skipped: %s\n' "$*"; }
sandbox
A=$TMP/art
SOURCE_DATE_EPOCH=1 python3 -B "$REPO/tools/build-iso-art.py" "$A" >/dev/null && _ok || _no "the pictures"

case_ "the inputs: every one pinned by its sha256; the release is a number"
(
  # shellcheck source=iso/inputs.sh disable=SC1091
  . "$REPO/iso/inputs.sh"
  [[ $ISO_RELEASE =~ ^[0-9]+$ ]] && [[ $ISO_NETINST_SHA256 =~ ^[0-9a-f]{64}$ ]] && [[ $ISO_NETINST == *"-$ISO_RELEASE-"* ]] || exit 1
  ((${#ISO_RPMS[@]} >= 5)) || exit 1
  for r in "${ISO_RPMS[@]}"; do [[ $r =~ ^[a-zA-Z0-9._+-]+\.rpm\ [0-9a-f]{64}$ ]] || exit 1; done
) && _ok || _no "an input is not pinned"

case_ "the menu: three lines (GRUB's list is never shorter), the same args but for the check; no nomodeset, which would reach the installed system"
g=$REPO/iso/grub.cfg
eq "$(grep -c '^menuentry' "$g")" 3
lacks "$(cat "$g")" nomodeset
lacks "$(cat "$g")" rd.live.check "the check runs on our screen: %pre"
has "$(grep -c 'initrd /images/pxeboot/initrd.img /images/pxeboot/fedokawaii-boot.img' "$g")" 2 "loaded before the menu, once again for the check"
has "$(cat "$REPO/tools/build-iso.sh")" "console=tty1" "any other console forces Plymouth's details (and the status lines)"
has "$(cat "$REPO/tools/build-iso.sh")" 's|^RELEASE = .*|RELEASE = ' "the release: one truth, iso/inputs.sh"
has "$(cat "$REPO/tools/build-iso.sh")" '${ROUND_ONLY[@]/#/:(exclude)}' "the round's notes never ship"
has "$(cat "$REPO/setup.sh")" 'for b in "${ROUND_ONLY[@]}"; do rm -rf' "nor by a toolkit a clone of a release makes"
for f in .claude CLAUDE.md tools/start.sh; do has "$(sed -n '/^ROUND_ONLY=(/,/)$/p' "$REPO/lib/common.sh")" "$f"; done
for c in fkinstall fkcheck fkoff; do [[ -s $A/grub/icons/$c.png ]] && _ok || _no "no words for $c"; done

case_ "the console font: 256 glyphs, ASCII on its own numbers, the blank where the console erases"
python3 -I -B - "$A/console/sumi-console.psf" <<'PY' && _ok || _no "the font"
import struct, sys
b = open(sys.argv[1], "rb").read()
h = struct.unpack("<4B7I", b[:32])
size, n, per, height, width = h[5], h[7], h[8], h[9], h[10]
assert (n, width, height) == (256, 14, 28), (n, width, height)
glyph = lambda i: b[size + i * per:size + (i + 1) * per]
table = b[size + n * per:].split(b"\xff")
assert not any(glyph(0x20)), "glyph 0x20 is not blank"
for c in range(0x21, 0x7f):
    assert table[c].decode("utf-8")[0] == chr(c), chr(c)
assert any(glyph(ord("A"))), "A is empty"
PY

case_ "the screen reader: a screen drawn in the font reads back, exactly; another picture reads as not ours"
python3 -I -B - "$A/console/sumi-console.psf" "$TMP/shot.png" <<'PY'
import struct, sys
from PIL import Image
b = open(sys.argv[1], "rb").read()
h = struct.unpack("<4B7I", b[:32])
size, n, per, H, W = h[5], h[7], h[8], h[9], h[10]
im = Image.new("RGB", (1920, 1080), (24, 23, 21))
px = im.load()
def put(col, row, ch, ink):
    g = b[size + ord(ch) * per:size + (ord(ch) + 1) * per]
    for y in range(H):
        v = int.from_bytes(g[y * 2:y * 2 + 2], "big")
        for x in range(W):
            if v & (0x8000 >> x):
                px[col * W + x, row * H + y] = ink
for i, c in enumerate("will be erased"):
    put(40 + i, 5, c, (231, 207, 161))
im.save(sys.argv[2])
PY
out=$(python3 -I -B "$REPO/tools/iso-shot.py" "$TMP/shot.png" "$A/console/sumi-console.psf"); has "$out" "will be erased"
python3 -I -B "$REPO/tools/iso-shot.py" "$TMP/shot.png" "$A/console/sumi-console.psf" "will be erased"; eq "$?" 0
python3 -I -B "$REPO/tools/iso-shot.py" "$TMP/shot.png" "$A/console/sumi-console.psf" "the login"; eq "$?" 1

# the questions' own code, its programs stood in for: lsblk says what is there
cat >"$TMP/q.py" <<'PY'
import importlib.util, json, os, sys, types
A, repo, case = sys.argv[1:4]
sys.dont_write_bytecode = True
sys.path[:0] = [os.path.join(A, "console"), os.path.join(repo, "iso/screens")]
import console
spec = importlib.util.spec_from_file_location("q", os.path.join(repo, "iso/screens/questions.py"))
q = importlib.util.module_from_spec(spec)
spec.loader.exec_module(q)
G = 1000 ** 3
def dev(name, size, tran=None, rm=False, ro=False, model="M", kind="disk", kids=()):
    return dict(name=name, model=model, size=size * G, type=kind, ro=ro, rm=rm, tran=tran, fstype=None, children=list(kids))
LS = {"blockdevices": [
    dev("sda", 2000, "usb", model="backup drive", kids=[dict(fstype="exfat")]),
    dev("sdb", 32, "usb", rm=True, model="the stick"),
    dev("mmcblk0", 64, rm=True, model="card"),
    dev("nvme0n1", 1000, "nvme", model="Lexar", kids=[dict(fstype="vfat"), dict(fstype="btrfs")]),
    dev("nvme1n1", 500, "nvme", model="Samsung"),
    dev("vdb", 20, None, model="small"),
    dev("sr0", 1, "sata", kind="rom"),
    dev("zram0", 8, None), dev("loop0", 1, None, kind="loop")]}
def fake_run(*cmd, timeout=None):
    out = ""
    if cmd[:2] == ("blkid", "-L"):
        out = "/dev/sdb1\n"
    elif cmd[0] == "lsblk" and "PKNAME" in cmd:
        out = "sdb\n"
    elif cmd[0] == "lsblk":
        out = json.dumps(LS)
    return types.SimpleNamespace(stdout=out, returncode=0)
q.run = fake_run
names = lambda ds: [d[0] for d in ds]
if case == "disks":
    ds = q.disks()
    assert names(ds) == ["nvme0n1", "nvme1n1", "vdb"], names(ds)
    assert ds[0][3] == "btrfs, vfat" and ds[1][3] == "empty", ds
elif case == "form":
    class S:
        rows, cols, head = 38, 137, 11
    f = q.Form(S(), q.disks(), {"time_zone": "Asia/Dubai"})
    assert f.disk == "", "a default among several: " + f.disk
    assert q.validate(f.fields["disk"], f.fields) == "choose the disk"
    LS["blockdevices"] = [d for d in LS["blockdevices"] if d["name"] != "nvme1n1"]
    f = q.Form(S(), q.disks(), {})
    assert f.disk == "nvme0n1", "the one that fits: " + f.disk
    assert "btrfs, vfat" in f.fields["disk"].value, f.fields["disk"].value
elif case == "names":
    F = types.SimpleNamespace
    fields = {"password": F(value="x")}
    bad = [("name", ""), ("name", "Dia"), ("name", "1x"), ("name", "root"), ("name", "a b"), ("name", "x;y"),
           ("password", ""), ("again", "y"), ("host", "-x"), ("host", "a_b"), ("host", "A")]
    for key, v in bad:
        assert q.validate(F(key=key, value=v), fields), (key, v)
    good = [("name", "dia"), ("name", "_x"), ("password", "x"), ("again", "x"), ("host", "fedokawaii"), ("host", "a-1")]
    for key, v in good:
        assert not q.validate(F(key=key, value=v), fields), (key, v)
elif case == "clear":
    calls = []
    def rec_run(*cmd, timeout=None):
        calls.append(cmd)
        out = ""
        if cmd[0] == "lsblk":
            out = "/dev/nvme0n1 disk\n" if ("blockdev", "--rereadpt", "/dev/nvme0n1") in calls else "/dev/nvme0n1 disk\n/dev/nvme0n1p1 part\n/dev/nvme0n1p2 part\n/dev/mapper/vg-root lvm\n/dev/nvme0n1p3 part\n/dev/md127 raid1\n"
            if "NAME" in cmd and "NAME,TYPE" not in cmd:
                out = "".join(line.split()[0] + "\n" for line in out.splitlines())
        return types.SimpleNamespace(stdout=out, returncode=0)
    q.run = rec_run
    q.ERASED = sys.argv[4] + "/erased"
    q.clear_disk(None, "nvme0n1")
    wiped = [c[-1] for c in calls if c[0] == "wipefs" and c[1] == "-a"]
    assert wiped == ["/dev/nvme0n1p3", "/dev/nvme0n1p2", "/dev/nvme0n1p1", "/dev/nvme0n1"], wiped
    assert ("blockdev", "--rereadpt", "/dev/nvme0n1") in calls, calls
    assert ("dmsetup", "remove", "--retry", "/dev/mapper/vg-root") in calls and ("mdadm", "--stop", "/dev/md127") in calls, calls
    assert calls.index(("mdadm", "--stop", "/dev/md127")) < calls.index(("wipefs", "-a", "-f", "/dev/nvme0n1p3")), calls
elif case == "before":
    # the mirrors: the metalink server answering is not enough; one reset connection is no refusal
    good = '<url protocol="https" type="https" location="DE" preference="100">https://m1.example/f/repodata/repomd.xml</url>'
    bad = '<url protocol="rsync" type="rsync">rsync://m2.example/f/repodata/repomd.xml</url>'
    q.time = types.SimpleNamespace(sleep=lambda _: None, monotonic=lambda: 0.0)
    def world(metalink, repomd):
        def fake(*cmd, timeout=None):
            url = cmd[-1]
            if "metalink" in url:
                return types.SimpleNamespace(stdout=metalink.pop(0) if len(metalink) > 1 else metalink[0], returncode=0)
            return types.SimpleNamespace(stdout=repomd, returncode=0 if repomd else 22)
        q.run = fake
    world([good], "<?xml?><repomd>")
    assert q.metadata_answers("fedora-45")
    world([good], "")
    assert not q.metadata_answers("fedora-45"), "a mirror that serves nothing"
    world([good], "<html>a captive portal</html>")
    assert not q.metadata_answers("fedora-45"), "a page that is not metadata"
    world([bad], "<repomd>")
    assert not q.metadata_answers("fedora-45"), "only a mirror we do not read"
    world(["", good], "<repomd>")
    assert q.metadata_answers("fedora-45"), "the second try"
elif case == "order":
    # the disk is the last thing: every file of the stick, the mirrors, then the erase
    import inspect
    src = inspect.getsource(q.main)
    assert src.index("write_answers(form)") < src.index("if not asked:") < src.index("before_the_disk(s)") < src.index("progress.py") < src.index("clear_disk(s, form.disk)"), src
    assert "stop_progress" in inspect.getsource(q.refuse)
    assert '"hg-0", "checking this stick"' in inspect.getsource(q.check_stick) and "fk-sums" in inspect.getsource(q.check_stick)
elif case == "answers":
    os.chdir(sys.argv[4])
    class S:
        rows, cols, head = 38, 137, 11
    f = q.Form(S(), q.disks(), {"time_zone": "Asia/Dubai", "city": "O'Fallon", "latitude": 1.5, "longitude": 2})
    f.disk = "nvme0n1"
    f.fields["name"].value, f.fields["password"].value, f.fields["again"].value = "dia", "secret word", "secret word"
    real = q.open if hasattr(q, "open") else open
    os_open, tmpdir = os.open, sys.argv[4]
    q.os = types.SimpleNamespace(**{k: getattr(os, k) for k in dir(os) if not k.startswith("__")})
    q.os.open = lambda p, *a, **k: os_open(p.replace("/tmp", tmpdir), *a, **k)
    q.open = lambda p, *a, **k: real(p.replace("/tmp", tmpdir), *a, **k)
    q.write_answers(f)
PY
case_ "the disks: inside the PC only; never a USB drive, a stick, a card, this ISO; what each holds"
python3 -I -B "$TMP/q.py" "$A" "$REPO" disks && _ok || _no "the disks"
case_ "the form: no default among several disks, the one that fits when one does"
python3 -I -B "$TMP/q.py" "$A" "$REPO" form && _ok || _no "the form"
case_ "before the erase: every file of the stick, a mirror that serves metadata for both repositories; the disk last"
python3 -I -B "$TMP/q.py" "$A" "$REPO" before && _ok || _no "the mirrors"
python3 -I -B "$TMP/q.py" "$A" "$REPO" order && _ok || _no "the order"
case_ "the words of a name, a password, this PC's name"
python3 -I -B "$TMP/q.py" "$A" "$REPO" names && _ok || _no "the names"
case_ "what the kickstart reads: the hash and no password, this disk alone cleared, the file root's"
mkdir "$TMP/t"
if python3 -I -B "$TMP/q.py" "$A" "$REPO" answers "$TMP/t" 2>"$TMP/err"; then
  a=$(cat "$TMP/t/answers.ks")
  has "$a" 'user --name=dia --groups=wheel --iscrypted --password=$y$'
  lacks "$a" "secret word"
  has "$a" "ignoredisk --only-use=nvme0n1"
  has "$a" "clearpart --all --initlabel --disklabel=gpt --drives=nvme0n1"
  eq "$(stat -c %a "$TMP/t/answers.ks")" 600
  e=$(cat "$TMP/t/answers.env"); has "$e" "FK_USER='dia'"; has "$e" "FK_CITY='O'\\''Fallon'"
else _no "the answers: $(tail -n3 "$TMP/err")"; fi

case_ "the base system's progress: Anaconda's own lines, as they came in a real run, make the meter"
python3 -I -B - "$A" "$REPO" <<'PY' && _ok || _no "the progress"
import os, sys
sys.dont_write_bytecode = True
sys.path[:0] = [os.path.join(sys.argv[1], "console"), os.path.join(sys.argv[2], "iso/screens")]
import progress
s = progress.State()
says = lambda t: s.read("14:08:53,492 INFO anaconda:" + t)
says("Creating btrfs on /dev/vda3")
assert (s.word, s.count, s.percent) == ("the disk", "", 0), vars(s)
says("Downloading packages")
says("Downloading 427 RPMs, 305.17 MiB / 615.03 MiB (49%) done.")
assert s.word == "the packages" and s.count == "305 MB of 615 MB" and 19 < s.percent < 20, vars(s)
says("Installing NetworkManager.x86_64 (340/427)")
assert s.count == "340 of 427" and 79 < s.percent < 80, vars(s)
says("Configuring filesystem.x86_64")
assert s.count == "340 of 427", vars(s)
says("Running post-installation scripts")
assert s.word == "the toolkit" and s.percent >= 90, vars(s)
s.read("14:08:53,492 WARNING something else: Downloading 1 RPMs, 2 MiB / 4 MiB (50%) done.")
assert s.word == "the toolkit", vars(s)
PY

case_ "the kickstart's updates repository: a name of its own (Anaconda's dnf_manager.add_repository never enables again the system's \"updates\" it has just disabled: every package would come from the release tree)"
has "$(cat "$REPO/iso/ks.cfg")" 'repo --name=fk-updates --metalink='
lacks "$(cat "$REPO/iso/ks.cfg")" 'repo --name=updates'
has "$(cat "$REPO/iso/ks.cfg")" 'updates-released-f@RELEASE@'
lacks "$(cat "$REPO/iso/ks.cfg")" 'updates-testing'
lacks "$(cat "$REPO/iso/ks.cfg")" 'rawhide'

case_ "the kickstart: strictly parsed by pykickstart as this release's handler, the answers in"
if python3 -c 'import pykickstart' 2>/dev/null; then
  sed -e 's/@RELEASE@/45/g' -e "s|^%include /tmp/answers.ks|keyboard --vckeymap=us --xlayouts=us\ntimezone Asia/Dubai --utc\nnetwork --bootproto=dhcp --device=link --activate --hostname=fedokawaii\nuser --name=dia --groups=wheel --iscrypted --password=\$y\$x\nignoredisk --only-use=vda\nclearpart --all --initlabel --disklabel=gpt --drives=vda\nbootloader --boot-drive=vda --timeout=0|" "$REPO/iso/ks.cfg" >"$TMP/ks.cfg"
  python3 - "$TMP/ks.cfg" <<'PY' && _ok || _no "the kickstart does not parse"
import sys
from pykickstart.parser import KickstartParser
from pykickstart.version import returnClassForVersion, makeVersion
try:
    h = makeVersion("F45")
except Exception:
    h = returnClassForVersion()()
KickstartParser(h, errorsAreFatal=True, followIncludes=False).readKickstart(sys.argv[1])
PY
else skip "pykickstart is not here"; fi
lacks "$(cat "$REPO/iso/ks.cfg")" sshpw "no back door in the product"

case_ "what happens to the chosen disk: every partition blank, the deepest first, the disk last; nothing else"
python3 -I -B "$TMP/q.py" "$A" "$REPO" clear "$TMP" && _ok || _no "the wipe"

case_ "the first start: nothing of the installer stays, and no console=tty1 on the installed system"
p=$(cat "$REPO/iso/screens/post.sh")
has "$p" 'remove-args="console=tty1"'
has "$(cat "$REPO/iso/screens/first_boot.py")" "shutil.rmtree(DROPIN"
has "$(cat "$REPO/iso/screens/first_boot.py")" "shutil.rmtree(HERE"
bash -n "$REPO/iso/screens/post.sh" && _ok || _no "post.sh"

case_ "the VM's tool: only its own VMs, no device to be given, a VM only with memory to spare"
out=$(bash "$REPO/tools/vm-iso-test.sh" create fk-f45 /nonexistent 2>&1); eq "$?" 2 "$out"
out=$(bash "$REPO/tools/vm-iso-test.sh" destroy fk-f45 2>&1); eq "$?" 2 "$out"
has "$(cat "$REPO/tools/vm-iso-test.sh")" "mem_guard"
lacks "$(grep -n 'source file\|source dev' "$REPO/tools/vm-iso-test.sh")" "/dev/"

case_ "the builder: a file that is not the pinned one is refused"
has "$(cat "$REPO/tools/build-iso.sh")" 'is not the pinned file'
has "$(cat "$REPO/tools/build-iso.sh")" 'anaconda.service.d' "Anaconda's second copy never asks again"
has "$(cat "$REPO/iso/grub.cfg")" 'gfxmode=1920x1080,auto' "no EDID from a firmware: 800x600 otherwise"

done_
