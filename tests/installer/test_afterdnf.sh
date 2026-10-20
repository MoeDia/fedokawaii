#!/usr/bin/env bash
# tests/installer/test_afterdnf.sh — setup.sh --after-dnf (fedokawaii-after-dnf.service, which
# the guard starts after a dnf transaction of yours) on a finished install in the fake machine:
# nothing noted, nothing done; the steps a transaction calls for (a new Python, a kernel), the
# record and the guard's records; a library under dwl's own wlroots changed by Fedora's rebuild
# (a soname bump) — the copy taken again; a dwl that no longer starts — rebuilt, and said when
# it still does not; the guard and its unit installed by repair.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
tk() { fkrun bash "$TK/setup.sh" "$@"; }
world built; releases
keep built

case_ "nothing noted: nothing done, at once"
reset_calls; tk --after-dnf; eq "$RC" 0; lacks "$OUT" "after dnf"; not_called 'dnf\]'

case_ "a transaction with a kernel and foot: dwl started headless, the boot images and foot's config checked, recorded"
back built; printf '%s\n' kernel-core foot >"$W/var/lib/fedokawaii/after-dnf"
reset_calls; tk --after-dnf
# (every step of its own went through — verify's verdict on the rest of the machine is its own)
lacks "$OUT" "not right yet"; [[ $RC == 0 || ( $RC == 3 && $OUT == *"verify finds something"* ) ]] && _ok || _no "exit $RC: $(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "after dnf · 2 package(s) changed"; has "$OUT" "the kernels' boot images"; has "$OUT" "foot's and fuzzel's configs"
lacks "$OUT" "dwl does not start"; lacks "$OUT" "torrra"
[[ -e $W/var/lib/fedokawaii/after-dnf ]] && _no "still noted" || _ok
grep -qE '^[0-9]+ (ok|checks)$' "$W/var/lib/fedokawaii/last-after-dnf" && _ok || _no "recorded: $(cat "$W/var/lib/fedokawaii/last-after-dnf")"
has "$(head -n1 "$W/var/lib/fedokawaii/needs")" "wlroots 0.20" "the guard's records written again"
has "$(cat "$W/var/lib/fedokawaii/manifest")" greetd
case_ "a new Python: torrra and Syncplay checked against it"
back built; printf '%s\n' python3 >"$W/var/lib/fedokawaii/after-dnf"
tk --after-dnf; has "$OUT" "torrra on its Python"; has "$OUT" "Syncplay on Fedora's Python"

case_ "Fedora's rebuild for a new libinput (a soname bump): dwl's own wlroots misses libinput.so.10 — taken again from Fedora's wlroots 0.20"
back built; echo libinput >"$W/var/lib/fedokawaii/after-dnf"
fkh ldd-missing "libwlroots-0.20.so libinput.so.10"
tk --after-dnf
has "$OUT" "dwl's own wlroots 0.20 misses a library — taken again from Fedora's rebuild"
[[ -s $W/usr/local/lib/fedokawaii-wlroots-0.20/lib/libwlroots-0.20.so && ! -e $W/usr/local/lib/fedokawaii-wlroots-0.20.before ]] && _ok || _no "the copy is not in place"
case_ "…and Fedora no longer has wlroots 0.20 to take it from: the copy left as it was, said"
back built; echo libinput >"$W/var/lib/fedokawaii/after-dnf"
fkh ldd-missing "libwlroots-0.20.so libinput.so.10"; fkh_del installed wlroots-devel
tk --after-dnf; eq "$RC" 3
has "$OUT" "this Fedora has no wlroots 0.20 to take it again from"
[[ -s $W/usr/local/lib/fedokawaii-wlroots-0.20/lib/libwlroots-0.20.so ]] && _ok || _no "the copy is gone"

case_ "dwl no longer starts (an ABI change behind the same library name): rebuilt; still not — said, recorded, exit 3"
back built; echo mesa-libgbm >"$W/var/lib/fedokawaii/after-dnf"; fkh dwl-crash
reset_calls; tk --after-dnf; eq "$RC" 3
has "$OUT" "dwl does not start"
# (the rebuild itself refuses a dwl that does not run — s_dwl — or it builds and still does not start)
[[ $OUT == *"dwl still does not start — the rescue screen says so at login"* || $OUT == *"installed dwl is not v0.9"* ]] && _ok || _no "the failed rebuild not said"
called 'git\] .*fetch'
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-after-dnf")" partial
fkrun bash "$TK/verify.sh"; has "$OUT" "✘ dwl starts (headless, once)"

case_ "a GTK the login screen asks for no longer loads (a typelib's version gone): said by name, never ok"
back built; echo gtk3 >"$W/var/lib/fedokawaii/after-dnf"; fkh gi-broken Gtk
tk --after-dnf; eq "$RC" 3; has "$OUT" "kawa-greet cannot load its GTK libraries"
eq "$(cut -d' ' -f2 "$W/var/lib/fedokawaii/last-after-dnf")" partial

case_ "repair puts the guard in place: the hook, its actions (JSON mode), its unit enabled, its records"
back built; rm -f "$W/usr/local/sbin/kawa-dnf-guard" "$W/etc/dnf/libdnf5-plugins/actions.d/fedokawaii-guard.actions" "$W/var/lib/fedokawaii/needs"
fkh_del units "enabled fedokawaii-after-dnf.service"
fkrun bash "$TK/verify.sh"; has "$OUT" "✘ dnf's guard: before and after every transaction"
tk --repair
cmp -s "$REPO/system/kawa-dnf-guard" "$W/usr/local/sbin/kawa-dnf-guard" && _ok || _no "the guard not installed"
grep -qx "pre_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard pre" "$W/etc/dnf/libdnf5-plugins/actions.d/fedokawaii-guard.actions" && _ok || _no "no pre action"
grep -qx "enabled fedokawaii-after-dnf.service" "$FKH/units" && _ok || _no "the unit not enabled"
grep -q "ExecStart=/usr/bin/bash /usr/local/lib/fedokawaii/setup.sh --after-dnf" "$W/etc/systemd/system/fedokawaii-after-dnf.service" && _ok || _no "the unit's command"
lacks "$OUT" "✘ line"; lacks "$OUT" "still needs you: system services"
done_
