#!/usr/bin/env bash
# tools/vm-inject/f45-checks.sh — what a new Fedora brings, checked in a harness VM that has run
# tools/vm-smoke.sh (the desktop installed): .claude/notes/f45-changes.md "What gets built" 2.
#   python   every Python program of ours (tracked *.py and python shebangs) compiled by the VM's
#            python3 with warnings as errors, and each module they import loaded with
#            DeprecationWarning as an error — a fresh interpreter a module
#   fonts    our families as fontconfig answers them (system/60-fedokawaii-pixel.conf, the home's
#            fonts.conf): Sumi UI and the icons themselves, Sumi Term and monospace → UDEV Gothic NF,
#            sans-serif → Noto Sans; Sumi UI drawn without smoothing
#   tty1     no kmscon on tty1 (setup resumes on tty1: its autologin is a getty's)
#   prowlarr started as a search in Torrents starts it (on demand: no [Install]), its /ping answering
#            within two minutes, stopped again
#   repos    no repository file of Fedora's (/usr/share/dnf5/repos.d, from 45 on) shadowed by a copy
#            of the same name in /etc/yum.repos.d — a copy there overrides the whole file
#            (Changes/RepoConfigsInUsr); a Fedora without /usr's folder: a named skip
# (The splash's frames need a restart and a screen dump: vm-smoke's own run, not here.)
#   bash tools/vm-inject/f45-checks.sh [VM] [REPO]   (VM f45; REPO this repository's working tree)
# Out: a line a check (ok · red · skip) on stdout, details in /dev/shm/r27/f45-checks/. Exit 0 no
# red · 1 a red · 2 the VM could not be reached.
# shellcheck disable=SC2016  # (the commands in single quotes are the VM's: its shell expands them)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:-f45} src=${2:-$(cd "$here/.." && pwd)}
out=/dev/shm/r27/f45-checks; rm -rf "$out"; mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
{ bash "$here/vm-snap.sh" "$vm" start && run --wait 600 && run --repo "$src"; } >"$out/start.log" 2>&1 \
  || { echo "f45-checks: the VM $vm could not be reached (start.log)" >&2; exit 2; }
red=0
say() { printf '%-9s %s\n' "$1" "$2" | tee -a "$out/summary"; [[ $1 == red ]] && red=1; return 0; }

# python — the list made here (git), the work done there
run 'python3 --version' >"$out/python-version" 2>&1
{ git -C "$src" ls-files '*.py'
  git -C "$src" ls-files bin system tools docs/build | while IFS= read -r f; do
    [[ $f == *.py ]] && continue
    head -c 64 "$src/$f" 2>/dev/null | head -n1 | grep -q '^#!.*python' && echo "$f"
  done; } | sort -u >"$out/py-files"
list=$(base64 -w0 <"$out/py-files")
run "cd ~/fedokawaii && echo $list | base64 -d >/tmp/py-files && python3 -I - /tmp/py-files" >"$out/python.txt" 2>&1 <<'PYCHECK'
import ast, subprocess, sys
files = [l.strip() for l in open(sys.argv[1]) if l.strip()]
bad, missing, mods = [], [], set()
for f in files:
    src = open(f, 'rb').read()
    r = subprocess.run([sys.executable, '-I', '-W', 'error', '-c',
                        'import sys; compile(open(sys.argv[1], "rb").read(), sys.argv[1], "exec")', f],
                       capture_output=True, text=True)
    if r.returncode:
        bad.append(f'compile {f}: {r.stderr.strip().splitlines()[-1] if r.stderr.strip() else r.returncode}')
        continue
    for n in ast.walk(ast.parse(src)):
        if isinstance(n, ast.Import):
            mods.update(a.name.split('.')[0] for a in n.names)
        elif isinstance(n, ast.ImportFrom) and n.module and not n.level:
            mods.add(n.module.split('.')[0])
ours = {f.rsplit('/', 1)[-1].removesuffix('.py') for f in files}
for m in sorted(mods - ours):
    r = subprocess.run([sys.executable, '-I', '-W', 'error::DeprecationWarning', '-c', f'import {m}'],
                       capture_output=True, text=True)
    last = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else str(r.returncode)
    if r.returncode and last.startswith('ModuleNotFoundError'):
        missing.append(m)          # (a build tool's library the desktop does not install: said, not red)
    elif r.returncode:
        bad.append(f'import {m}: {last}')
print(f'{len(files)} programs, {len(mods - ours)} modules' + (f' (not installed here: {" ".join(missing)})' if missing else ''))
print('\n'.join(bad))
sys.exit(1 if bad else 0)
PYCHECK
prc=$?
v=$(cat "$out/python-version"); n=$(sed -n 1p "$out/python.txt")
if ((prc == 0)); then say ok "python: $v — $n, compiled with -W error, imported with DeprecationWarning an error"
else say red "python: $v — $(sed -n 2p "$out/python.txt") ($out/python.txt)"; fi

# fonts — as dia, after the theme put them in
run 'for q in "Sumi UI" "Sumi Icons" "Sumi Icons Term" "Sumi Term" monospace sans-serif; do printf "%s\t%s\n" "$q" "$(fc-match -f "%{family[0]}" "$q")"; done; printf "aa\t%s\n" "$(fc-match -f "%{antialias}" "Sumi UI:pixelsize=14")"' >"$out/fonts.txt" 2>&1
want=$'Sumi UI\tSumi UI\nSumi Icons\tSumi Icons\nSumi Icons Term\tSumi Icons Term\nSumi Term\tUDEV Gothic NF\nmonospace\tUDEV Gothic NF\nsans-serif\tNoto Sans\naa\tFalse'
if [[ $(cat "$out/fonts.txt") == "$want" ]]; then say ok "fonts: every family as ours say (Sumi UI unsmoothed)"
else say red "fonts: $(diff <(printf '%s\n' "$want") "$out/fonts.txt" | grep '^>' | tr '\n' ' ')"; fi

# tty1
t=$(run 'pgrep -a kmscon; systemctl is-active kmsconvt@tty1.service 2>/dev/null; true' 2>&1)
if grep -q 'tty1\|^active' <<<"$t"; then say red "tty1: kmscon there — $t"; else say ok "tty1: no kmscon on it"; fi

# prowlarr — on demand, as kawa-prowlarr starts it (system/prowlarr.container: no [Install])
p=$(run 'systemctl --user start prowlarr.service || exit 1
  for i in $(seq 120); do curl -fsS -o /dev/null --max-time 2 http://127.0.0.1:9696/ping && { echo "up in ${i} s"; break; }; sleep 1; done
  systemctl --user stop prowlarr.service' 2>&1)
if [[ $p == "up in "* ]]; then say ok "prowlarr: started on demand, /ping $p, stopped"
else say red "prowlarr: ${p:-no answer within 120 s}"; fi

# repos
r=$(run 'd=/usr/share/dnf5/repos.d; [ -d $d ] && ls $d/*.repo >/dev/null 2>&1 || { echo skip; exit 0; }; for f in $d/*.repo; do [ -e /etc/yum.repos.d/${f##*/} ] && echo "${f##*/}"; done; true' 2>&1)
if [[ $r == skip ]]; then say skip "repos: no /usr/share/dnf5/repos.d on this Fedora (before 45)"
elif [[ -z $r ]]; then say ok "repos: Fedora's files from /usr, none shadowed in /etc"
else say red "repos: shadowed in /etc/yum.repos.d: $(tr '\n' ' ' <<<"$r")"; fi

bash "$here/vm-snap.sh" "$vm" stop >>"$out/start.log" 2>&1
exit "$red"
