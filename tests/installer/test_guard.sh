#!/usr/bin/env bash
# tests/installer/test_guard.sh — system/kawa-dnf-guard, as libdnf5's actions plugin runs it
# (JSON mode: its requests on stdout, dnf's replies on stdin — played here line by line):
# a transaction that removes a manifest package, or takes a library dwl's own wlroots needs
# with no wlroots rebuilt for it, is stopped before it runs; Fedora's rebuild, a relinkable
# library, a replaced (obsoleted) package, a new Python go through with a word; the toolkit's
# own runs and the move to a new Fedora are left to the toolkit; after a transaction its names
# are noted and the follow-up unit started.
. "$(dirname "$0")/../lib/harness.sh"
sandbox
G=$REPO/system/kawa-dnf-guard
ST=$TMP/state; mkdir -p "$ST" "$TMP/cache/fedora-x/packages"
export KAWA_STATE=$ST KAWA_OFFLINE_MARK=$TMP/system-update
printf '%s\n' greetd foot python3.13 dwl-needs-nothing >"$ST/manifest"
printf '%s\n' "wlroots 0.20" "libinput.so.10 libinput wlroots" "libxkbcommon.so.0 libxkbcommon build" "libgit2.so.1.9 libgit2 tool" >"$ST/needs"
# rpm: a downloaded package is a file of its provides; python3's installed version
stub rpm 'case " $* " in *" -qp "*) for f; do [ -f "$f" ] && cat "$f"; done ;; *python3*) printf 3.14.2 ;; esac'
pkgfile() { printf '%s\n' "${@:2}" >"$TMP/cache/fedora-x/packages/$1.rpm"; }
# tx "NAME ACTION DIRECTION VERSION" … → dnf's replies: the packages, then the cache folder
tx() {
  local l n a d v arr=()
  for l; do read -r n a d v <<<"$l"
    arr+=("$(jq -cn --arg n "$n" --arg a "$a" --arg d "$d" --arg v "$v" '{name: $n, arch: "x86_64", version: $v, release: "1.fc44", action: $a, direction: $d, location: ("Packages/x/" + $n + "-" + $v + ".rpm")}')")
  done
  jq -cn --argjson p "[$(IFS=,; echo "${arr[*]}")]" '{op: "reply", requested_op: "get", domain: "trans_packages", status: "OK", return: $p}'
  jq -cn --arg c "$TMP/cache" '{op: "reply", requested_op: "get", domain: "conf", status: "OK", return: [{key: "cachedir", value: $c}]}'
}
guard() { OUT=$(bash "$G" "$1" <"$TMP/replies" 2>"$TMP/err"); RC=$?; ERR=$(cat "$TMP/err"); }
stopped() { jq -r 'select(.op == "stop") | .args.message' <<<"$OUT" 2>/dev/null; }

case_ "pre: a manifest package removed — stopped before anything changes, its name and the way on said"
tx "greetd E OUT 0.10" "bash U IN 5.3" "bash O OUT 5.2" >"$TMP/replies"; guard pre
eq "$RC" 0; m=$(stopped); has "$m" "nothing was changed"; has "$m" "it removes greetd, which the desktop is built from"
has "$m" "dnf upgrade --exclude=NAME"
has "$(head -n1 <<<"$OUT")" '"domain":"trans_packages"' "the packages asked first"
case_ "pre: a manifest package replaced by another (obsoleted), or reinstalled — no removal"
tx "greetd O OUT 0.10" "greetd-ng I IN 1.0" "foot E OUT 1.20" "foot I IN 1.21" >"$TMP/replies"; guard pre
eq "$(stopped)" "" "stopped: $(stopped)"
case_ "pre: an old kernel removed by dnf's own limit — never stopped"
printf 'kernel-core\n' >>"$ST/manifest"
tx "kernel-core E OUT 6.17" "kernel-core I IN 6.19" >"$TMP/replies"; guard pre; eq "$(stopped)" ""

case_ "pre: libinput.so.10 gone (its successor .so.11), wlroots 0.20 not rebuilt — stopped: the desktop would not start"
pkgfile libinput-1.30 "libinput.so.11()(64bit)" "libinput = 1.30"
tx "libinput U IN 1.30" "libinput O OUT 1.29" >"$TMP/replies"; guard pre
m=$(stopped); has "$m" "it takes libinput.so.10 (from libinput), which dwl's own wlroots 0.20 needs"; has "$m" "would not start"
case_ "pre: …the same with Fedora's wlroots 0.20 rebuilt in it — through, the copy taken again right after"
pkgfile wlroots0.20-0.20.2 "libwlroots-0.20.so()(64bit)"
tx "libinput U IN 1.30" "libinput O OUT 1.29" "wlroots0.20 U IN 0.20.2" "wlroots0.20 O OUT 0.20.1" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; has "$ERR" "dwl's own wlroots 0.20 is taken again from Fedora's rebuild"
case_ "pre: …a newer wlroots (0.21) does not count as the rebuild"
rm -f "$TMP/cache/fedora-x/packages/wlroots0.20-0.20.2.rpm"; pkgfile wlroots-0.21.0 "libwlroots-0.21.so()(64bit)"
tx "libinput U IN 1.30" "libinput O OUT 1.29" "wlroots U IN 0.21.0" "wlroots O OUT 0.20.2" >"$TMP/replies"; guard pre
has "$(stopped)" "libinput.so.10"
case_ "pre: libinput upgraded keeping its name (a rebuild of the same .so.10) — through, nothing said"
pkgfile libinput-1.29.2 "libinput.so.10()(64bit)"
tx "libinput U IN 1.29.2" "libinput O OUT 1.29" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; eq "$ERR" ""
case_ "pre: …a library only dwl itself and the helpers load (relinked from source) — through, the rebuild said"
pkgfile libxkbcommon-2.0 "libxkbcommon.so.1()(64bit)"
tx "libxkbcommon U IN 2.0" "libxkbcommon O OUT 1.13" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; has "$ERR" "libxkbcommon.so.0 changes: dwl and the desktop's helpers are rebuilt for it"
case_ "pre: …a library a release tool loads — through, said"
pkgfile libgit2-1.10 "libgit2.so.1.10()(64bit)"
tx "libgit2 U IN 1.10" "libgit2 O OUT 1.9" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; has "$ERR" "a release tool loads it"
case_ "pre: …the library moved to a package of another name in the same transaction — through"
pkgfile libinput10-compat-1.29 "libinput.so.10()(64bit)"
tx "libinput U IN 1.30" "libinput O OUT 1.29" "libinput10-compat I IN 1.29" >"$TMP/replies"; guard pre
eq "$(stopped)" ""
case_ "pre: the new package not found on disk — not stopped (cannot tell), said: the checks after it tell"
tx "libinput U IN 1.31" "libinput O OUT 1.29" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; has "$ERR" "could not read the new libinput"

case_ "pre: Python 3.14 → 3.15 — through, said; a 3.14 bugfix release says nothing"
tx "python3 U IN 3.15.0" "python3 O OUT 3.14.2" >"$TMP/replies"; guard pre
eq "$(stopped)" ""; has "$ERR" "Python 3.14 → 3.15"
tx "python3 U IN 3.14.3" "python3 O OUT 3.14.2" >"$TMP/replies"; guard pre; lacks "$ERR" "Python"

case_ "pre: the toolkit's own run (it holds the lock) removes on purpose — the library rule still holds"
: >"$ST/lock"; ( exec 9>"$ST/lock"; flock 9; touch "$TMP/held"; sleep 5 ) & L=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -e $TMP/held ]] && break; sleep 0.2; done
tx "greetd E OUT 0.10" >"$TMP/replies"; guard pre; eq "$(stopped)" "" "a manifest removal stopped in the toolkit's run"
tx "libinput U IN 1.30" "libinput O OUT 1.29" >"$TMP/replies"; guard pre; has "$(stopped)" "libinput.so.10"
case_ "post: in the toolkit's run — nothing noted, nothing started (the toolkit follows up itself)"
reset_calls; tx "foot U IN 1.21" >"$TMP/replies"; guard post
[[ -e $ST/after-dnf ]] && _no "noted" || _ok; not_called '^systemctl'
kill "$L" 2>/dev/null; wait "$L" 2>/dev/null

case_ "post: the names noted (to the ones before), the follow-up started without waiting"
reset_calls; stub systemctl
tx "foot U IN 1.21" "foot O OUT 1.20" "libinput U IN 1.30" >"$TMP/replies"; guard post
eq "$RC" 0; eq "$(cat "$ST/after-dnf")" "$(printf '%s\n' foot libinput)"
called '^systemctl start --no-block fedokawaii-after-dnf.service$'
tx "mpv U IN 0.41" >"$TMP/replies"; guard post; eq "$(grep -c . "$ST/after-dnf")" 3 "a second transaction adds its names"
case_ "the move to a new Fedora (its offline transaction): no removal stopped; after it, noted for the next start only"
: >"$KAWA_OFFLINE_MARK"; rm -f "$ST/after-dnf"; reset_calls
tx "greetd E OUT 0.10" >"$TMP/replies"; guard pre; eq "$(stopped)" ""
tx "greetd O OUT 0.10" >"$TMP/replies"; guard post; eq "$(cat "$ST/after-dnf")" greetd; not_called '^systemctl'
rm -f "$KAWA_OFFLINE_MARK"

case_ "dnf answers with an error, or the guard is misused — the transaction never held"
printf '%s\n' '{"op":"reply","requested_op":"get","domain":"trans_packages","status":"ERROR","message":"x"}' >"$TMP/replies"; guard pre
eq "$RC" 0; eq "$(stopped)" ""; has "$ERR" "not checked"
rc 2 bash "$G" sideways

case_ "the actions file: both callbacks in JSON mode, never raise_error (a failing guard holds nothing)"
a=$(sed -n "/write_file \"\$GUARD_ACTIONS\" <<'EOF'/,/^EOF/p" "$REPO/lib/guard.sh")
has "$a" "pre_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard pre"
has "$a" "post_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard post"
lacks "$(grep -v '^#' <<<"$a")" "raise_error"
done_
