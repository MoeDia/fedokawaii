#!/usr/bin/env bash
# tests/engine/test_greeter.sh — kawa-greet, the login screen (greetd runs it in cage, as its
# own user). Its window needs a screen, so GTK is a stand-in here (a small fake "gi" module:
# widgets that do nothing); what is tested is everything else — the conversation with greetd
# over its socket (a fake greetd, speaking greetd's real protocol: a 4-byte length in the
# machine's byte order, then JSON), what it says on a wrong password, and which theme it wears.
. "$(dirname "$0")/lib.sh"
need_py() { command -v python3 >/dev/null || { echo "test_greeter: skipped — needs python3"; exit 0; }; }
need_py

sandbox
G=$TMP/greet; mkdir -p "$G/gi/repository"
# the stand-in GTK: any widget, any call, any attribute — all do nothing
cat >"$G/gi/__init__.py" <<'EOF'
def require_version(*a): pass
EOF
cat >"$G/gi/repository/__init__.py" <<'EOF'
class _Any:
    def __init__(self, *a, **k): pass
    def __call__(self, *a, **k): return _Any()
    def __getattr__(self, n): return _Any()
    def __mro_entries__(self, bases): return (object,)
Gtk = _Any(); GLib = _Any(); Gio = _Any()
class Gdk:                                     # (the keys and the event kind it compares)
    KEY_Return, KEY_KP_Enter, KEY_ISO_Enter, KEY_a = 0xff0d, 0xff8d, 0xfe34, 0x61
    class EventType: KEY_PRESS, KEY_RELEASE, BUTTON_PRESS = 8, 9, 4
EOF
# drive.py THEME_FILE SCRIPT… — kawa-greet loaded as a module (its main() not run), its
# Greeter's login logic run against fake_greetd answers; prints what was said and asked
cat >"$G/drive.py" <<'EOF'
import importlib.machinery, importlib.util, json, os, socket, struct, sys, threading
sys.dont_write_bytecode = True               # (-I ignores PYTHONDONTWRITEBYTECODE: no __pycache__ in the repo)
sys.path.insert(0, os.path.dirname(__file__))
loader = importlib.machinery.SourceFileLoader("kawa_greet", sys.argv[1])
spec = importlib.util.spec_from_loader("kawa_greet", loader)
kg = importlib.util.module_from_spec(spec); loader.exec_module(kg)
kg.THEME_FILE = sys.argv[2]
mode = sys.argv[3]
if mode == "theme":
    print(kg.theme()); sys.exit(0)
if mode == "guard":                            # the wake guard and the empty Enter, step by step
    import time, types
    w = kg.Greeter.__new__(kg.Greeter); w.asleep, w.woke = False, 0.0
    class Entry:
        text = ""
        def has_focus(self): return True
        def get_text(self): return self.text
    w.entry = Entry(); run = []
    kg.subprocess = types.SimpleNamespace(Popen=run.append)
    key = lambda k, t=kg.Gdk.EventType.KEY_PRESS: types.SimpleNamespace(type=t, keyval=k)
    sig = lambda v: w.sleeping(None, None, None, None, None, types.SimpleNamespace(unpack=lambda: (v,)))
    out = []
    out.append(("awake a", w.input(None, key(kg.Gdk.KEY_a))))
    out.append(("empty enter", w.input(None, key(kg.Gdk.KEY_Return))))
    w.entry.text = "pw"; out.append(("enter with a password", w.input(None, key(kg.Gdk.KEY_Return))))
    sig(True); out.append(("asleep enter", w.input(None, key(kg.Gdk.KEY_Return))))
    w.power(None, "poweroff"); out.append(("asleep power off ran", bool(run)))
    sig(False); out.append(("just woke enter", w.input(None, key(kg.Gdk.KEY_Return))))
    out.append(("just woke release", w.input(None, key(kg.Gdk.KEY_Return, kg.Gdk.EventType.KEY_RELEASE))))
    w.power(None, "suspend"); out.append(("just woke sleep ran", bool(run)))
    w.woke = time.monotonic() - kg.GUARD - 0.1
    out.append(("2 s later enter", w.input(None, key(kg.Gdk.KEY_Return))))
    w.power(None, "suspend"); out.append(("2 s later sleep ran", run))
    print(" | ".join(f"{a}: {b}" for a, b in out)); sys.exit(0)
answers = json.loads(sys.argv[4])          # the fake greetd's answer to each request, in turn
a, b = socket.socketpair()
log = []
def greetd():
    for ans in answers:
        n = struct.unpack("=I", b.recv(4, socket.MSG_WAITALL))[0]
        req = json.loads(b.recv(n, socket.MSG_WAITALL).decode())
        log.append(req)
        data = json.dumps(ans).encode()
        b.sendall(struct.pack("=I", len(data)) + data)
t = threading.Thread(target=greetd, daemon=True); t.start()
g = kg.Greetd.__new__(kg.Greetd); g.sock = a
w = kg.Greeter.__new__(kg.Greeter); w.greetd = g; w.user = "kawau"
said = []; w.say = said.append
ok = w.run_pam(sys.argv[5])
t.join(2)
print(json.dumps({"ok": ok, "said": said, "asked": log}, ensure_ascii=False))
EOF
drive() { python3 -I "$G/drive.py" "$REPO/system/kawa-greet" "$TMP/theme" pam "$1" "$2"; }
field() { python3 -I -c 'import json, sys; print(json.dumps(json.load(sys.stdin)[sys.argv[1]], ensure_ascii=False))' "$1"; }
SECRET='{"type":"auth_message","auth_message_type":"secret","auth_message":"Password: "}'
OK='{"type":"success"}'

case_ "the right password: a session for you (no name to type), then the desktop starts"
out=$(drive "[$SECRET,$OK,$OK]" 'r1ght pass')
eq "$(field ok <<<"$out")" true
eq "$(field asked <<<"$out")" '[{"type": "create_session", "username": "kawau"}, {"type": "post_auth_message_response", "response": "r1ght pass"}, {"type": "start_session", "cmd": ["/usr/local/bin/start-dwl"], "env": []}]'
eq "$(field said <<<"$out")" '[]'

case_ "a wrong password: the session cancelled (the next try starts afresh), said in the desktop's words"
out=$(drive "[$SECRET,{\"type\":\"error\",\"error_type\":\"auth_error\",\"description\":\"pam_authenticate: AUTH_ERR\"},$OK]" wrong)
eq "$(field ok <<<"$out")" false
has "$(field asked <<<"$out")" '{"type": "cancel_session"}'
eq "$(field said <<<"$out")" '["ちがう · wrong password"]'

case_ "a password with Arabic or Japanese letters: its length counted in bytes, as greetd reads it"
out=$(drive "[$SECRET,$OK,$OK]" 'كلمة·パス')
eq "$(field ok <<<"$out")" true
has "$(field asked <<<"$out")" '"response": "كلمة·パス"'

case_ "a note from the system on the way (PAM info: an expiring password): shown, acknowledged, then the password"
out=$(drive "[{\"type\":\"auth_message\",\"auth_message_type\":\"info\",\"auth_message\":\"Your password expires in 3 days\n\"},$SECRET,$OK,$OK]" pw)
eq "$(field ok <<<"$out")" true
eq "$(field said <<<"$out")" '["Your password expires in 3 days"]'
has "$(field asked <<<"$out")" '{"type": "post_auth_message_response"}, {"type": "post_auth_message_response", "response": "pw"}'

case_ "the desktop cannot start (greetd refuses the session): cancelled, and why is said"
out=$(drive "[$SECRET,$OK,{\"type\":\"error\",\"error_type\":\"error\",\"description\":\"could not start\"},$OK]" pw)
eq "$(field ok <<<"$out")" false
eq "$(field said <<<"$out")" '["could not start"]'
has "$(field asked <<<"$out")" '{"type": "cancel_session"}'

case_ "its theme: the one you last had (kawa-theme notes it); before your first login, dark"
th() { python3 -I "$G/drive.py" "$REPO/system/kawa-greet" "$TMP/theme" theme; }
rm -f "$TMP/theme"; eq "$(th)" dark
echo light >"$TMP/theme"; eq "$(th)" light
echo dark >"$TMP/theme"; eq "$(th)" dark
echo '../../etc' >"$TMP/theme"; eq "$(th)" dark "a name that is not a theme: dark, never a path"

case_ "the wake guard: asleep, and 2 s after waking, keys and clicks only wake; an empty Enter is never a try"
eq "$(python3 -I "$G/drive.py" "$REPO/system/kawa-greet" "$TMP/theme" guard)" \
  "awake a: False | empty enter: True | enter with a password: False | asleep enter: True | asleep power off ran: False | just woke enter: True | just woke release: True | just woke sleep ran: False | 2 s later enter: False | 2 s later sleep ran: [['systemctl', 'suspend']]"
case_ "three keys under the rule — sleep, restart, power off — as on the lock screen (kawa-lockmod)"
grep -qF '(("眠 sleep", "suspend"), ("再 restart", "reboot"), ("電 power off", "poweroff"))' "$REPO/system/kawa-greet" && _ok || _no "the greeter's keys"
grep -qF '{ "眠 sleep", "suspend" }, { "再 restart", "reboot" }, { "電 power off", "poweroff" }' "$REPO/src/kawa-lockmod/kawa-lockmod.c" && _ok || _no "the lock screen's keys differ from the greeter's"
grep -qF '"PrepareForSleep"' "$REPO/system/kawa-greet" && _ok || _no "the greeter does not hear of a sleep"

case_ "its flavour, the lock screen's too: the weekday in kanji, a stamped seal, the season's and the hour's line — the same sixteen lines in both"
lines() { grep -oE '"[春夏秋冬]の[朝昼夕夜]", "[^"]*"' "$1"; }
eq "$(lines "$REPO/system/kawa-greet" | wc -l)" 16
eq "$(lines "$REPO/system/kawa-greet")" "$(lines "$REPO/src/kawa-lockmod/kawa-lockmod.c")" "kawa-greet's and kawa-lockmod's"
eq "$(python3 -I -c 'import sys, importlib.machinery as m, importlib.util as u, time
sys.path.insert(0, sys.argv[2]); sys.dont_write_bytecode = True
l = m.SourceFileLoader("kg", sys.argv[1]); g = u.module_from_spec(u.spec_from_loader("kg", l)); l.exec_module(g)
t = lambda mon, h: time.struct_time((2026, mon, 1, h, 0, 0, 0, 1, 0))
print(g.verse(t(10, 23))[0], g.verse(t(3, 5))[0], g.verse(t(7, 12))[0], g.verse(t(1, 18))[0], g.verse(t(12, 4))[0], g.WEEKDAYS[1])' "$REPO/system/kawa-greet" "$G")" \
  "秋の夜 春の朝 夏の昼 冬の夕 冬の夜 火曜日"
grep -q 'label="門", name="stamp"' "$REPO/system/kawa-greet" && _ok || _no "the login's stamped seal"
grep -q '"錠"' "$REPO/src/kawa-lockmod/kawa-lockmod.c" && _ok || _no "the lock's stamped seal"
for id in weekday stamp verse-kanji verse; do
  for t in dark light; do grep -q "#$id " "$REPO/configs/home/.config/fedokawaii/themes/$t/gtklock.css" && _ok || _no "$t gtklock.css has no #$id"; done
done

case_ "kawa-theme notes the theme for it, where setup gave you a folder"
grep -q '/var/lib/fedokawaii-greeter/theme' "$REPO/bin/kawa-theme" && _ok || _no "kawa-theme does not write the greeter's theme"

case_ "setup's greetd settings and verify's check agree (cage on the desktop's card, kawa-greet, your name)"
grep -qF 'command = "env \$(/usr/local/bin/start-dwl --gpu) \\"XCURSOR_THEME=Sumi-\$(cat /var/lib/fedokawaii-greeter/theme)\\" systemd-cat -t kawa-greet cage -d -s -- /usr/local/bin/kawa-greet $TARGET_USER"' "$REPO/setup.sh" && _ok || _no "setup.sh's greetd command changed"
grep -qF 'command = \"env \$(/usr/local/bin/start-dwl --gpu) \\\"XCURSOR_THEME=Sumi-\$(cat /var/lib/fedokawaii-greeter/theme)\\\" systemd-cat -t kawa-greet cage -d -s -- /usr/local/bin/kawa-greet $TARGET_USER\"' "$REPO/verify.sh" && _ok || _no "verify.sh's check does not match setup's line"

case_ "its look: every file it loads is one setup installs (both themes)"
for f in gtklock.css padlock.png seal-1.png seal-7.png; do
  for t in dark light; do
    case $f in *.css) src=$REPO/configs/home/.config/fedokawaii/themes/$t/$f ;; *) src=$REPO/configs/home/.local/share/fedokawaii/$t/$f ;; esac
    [[ -s $src ]] && _ok || _no "no $src"
  done
done
grep -q 'f"{art}/seal-{time.strftime(.%u.)}.png"' "$REPO/system/kawa-greet" && _ok || _no "the seal's file name changed"

done_
