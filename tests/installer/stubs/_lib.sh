# shared by the fake Fedora's commands (tests/installer/stubs, installed as the fake machine's
# /usr/local/bin): their state and the call log live in /var/lib/fkh
FKH=/var/lib/fkh
fkh_log() { printf '%s[%s] %s\n' "$(id -un 2>/dev/null)" "${0##*/}" "$*" >>"$FKH/calls.log" 2>/dev/null || true; fkh_cut; }
# fkh_cut — $FKH/cut-at = N (and $FKH/cut-sig: KILL, the default — a power cut — or INT, a
# Ctrl+C): at the Nth stub call the setup.sh this call runs under is stopped with its whole
# process group, the stub with it. Only the run this stub belongs to: its own ancestor
fkh_cut() {
  [[ -f $FKH/cut-at ]] || return 0
  local n p=$$ sig pg
  n=$(( $(cat "$FKH/cut-count" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$FKH/cut-count"
  ((n == $(cat "$FKH/cut-at"))) || return 0
  rm -f "$FKH/cut-at"; sig=$(cat "$FKH/cut-sig" 2>/dev/null || echo KILL)
  while ((p > 1)); do
    if tr '\0' ' ' <"/proc/$p/cmdline" 2>/dev/null | grep -q 'setup\.sh'; then
      echo "cut at stub call $n (${0##*/}) by SIG$sig" >>"$FKH/cut.log"
      if [[ $sig == KILL ]]; then pg=$(awk '{ print $5 }' "/proc/$p/stat"); kill -KILL -- "-$pg"
      else kill -"$sig" "$p"; sleep 2; fi
      return 0
    fi
    p=$(awk '{ print $4 }' "/proc/$p/stat" 2>/dev/null) || return 0
  done
}
net_on() { [[ $(cat "$FKH/net" 2>/dev/null) != off ]]; }
has() { [[ -f $FKH/$1 ]] && grep -qxF -- "$2" "$FKH/$1"; }
add() { has "$1" "$2" || printf '%s\n' "$2" >>"$FKH/$1"; }
del() { [[ -f $FKH/$1 ]] && { grep -vxF -- "$2" "$FKH/$1" >"$FKH/$1.n" || true; cat "$FKH/$1.n" >"$FKH/$1"; rm -f "$FKH/$1.n"; }; return 0; }
provider() {  # provider CAP → installed package providing it, or empty
  local c=$1 p
  p=$(awk -v c="$c" '$1 == c { print $2; exit }' "$FKH/provides" 2>/dev/null)
  if [[ -n $p ]] && has installed "$p"; then echo "$p"; return 0; fi
  if has installed "$c"; then echo "$c"; return 0; fi
  return 1
}
# rc NAME DEFAULT — a forced exit status for this command (file $FKH/rc-NAME), else DEFAULT
rcfor() { cat "$FKH/rc-$1" 2>/dev/null || echo "${2:-0}"; }
# countdown NAME — 0 while $FKH/fail-NAME still holds a number > 0 (decremented): fails N times
countdown() { local n; n=$(cat "$FKH/fail-$1" 2>/dev/null) || return 1; ((n > 0)) || return 1; echo $((n - 1)) >"$FKH/fail-$1"; return 0; }
# fake_syncplay_source DIR — what a clone of Syncplay's v1.7.6 tag holds, as far as the desktop
# looks: its syncplay/ folder, whose client and server load Twisted's TLS, certifi, pem and
# pyOpenSSL (the fake machine's own, tests/installer/lib.sh), and which says its version
fake_syncplay_source() {
  mkdir -p "$1/syncplay"
  printf "version = '%s'\nmilestone = 'Yoitsu'\n" "$(cat "$FKH/syncplay-version" 2>/dev/null || echo 1.7.6)" >"$1/syncplay/__init__.py"
  printf 'import twisted.internet.ssl, certifi, pem\n' >"$1/syncplay/client.py"
  printf 'import OpenSSL\n' >"$1/syncplay/server.py"
  printf '%s\n' 'import sys' 'def main():' '    if "--version" in sys.argv:' \
    '        print("You'"'"'re using Syncplay version 1.7.6 (Yoitsu)")' '        return' \
    '    print("syncplay (fake):", " ".join(sys.argv[1:]))' >"$1/syncplay/ep_client.py"
  printf '%s\n' 'def main():' '    print("syncplay-server (fake)")' >"$1/syncplay/ep_server.py"
}
# fake_lpf_era — a machine from before Spotify became its web player: lpf built Spotify's app
# here (lpf-spotify-client, the recipe, and spotify-client, the app: yours; lpf with them),
# with lpf's build account pkg-build (its home /var/lib/lpf, the build's state and log). None of
# the three is needed by anything ($FKH/orphans): marked as a dependency, dnf's clean-up takes it
fake_lpf_era() {
  grep -q '^pkg-build:' /etc/passwd || { echo 'pkg-build:x:975:975:lpf local package build user:/var/lib/lpf:/sbin/nologin' >>/etc/passwd; echo 'pkg-build:x:975:' >>/etc/group; }
  mkdir -p /usr/share/lpf/packages/spotify-client /var/lib/lpf/packages/spotify-client /var/lib/lpf/log /etc/sudoers.d
  echo OK >/var/lib/lpf/packages/spotify-client/state; echo 'spotify-client: build completed' >/var/lib/lpf/log/spotify-client.log
  printf 'pkg-build ALL=(root) NOPASSWD: /usr/share/lpf/scripts/lpf-sudo-builddep\n' >/etc/sudoers.d/pkg-build
  chown -R 975:975 /var/lib/lpf
  local p; for p in lpf lpf-spotify-client spotify-client; do add installed "$p"; add orphans "$p"; done
  for p in lpf-spotify-client spotify-client; do grep -q "^$p " "$FKH/userinstalled" 2>/dev/null || echo "$p User" >>"$FKH/userinstalled"; done
}
# fake_blesh_source DIR — what ble.sh's pinned commit holds, as far as the desktop looks: its
# make file and main source (ble.pp), whose build the fake make knows
fake_blesh_source() { mkdir -p "$1"; echo '# ble.sh (fake source)' >"$1/ble.pp"; echo 'install:' >"$1/GNUmakefile"; }
# fake_blesh_install DIR — what ble.sh's build installs there: its ble.sh, which says its
# version ($FKH/blesh-version, else the pinned commit's)
fake_blesh_install() {
  mkdir -p "$1/lib" "$1/contrib/integration"
  printf '#!/bin/bash\n# ble.sh (fake)\n[[ $1 == --version ]] && echo "ble.sh (Bash Line Editor), version %s"\n' \
    "$(cat "$FKH/blesh-version" 2>/dev/null || echo 0.4.0-devel4+d81fd54)" >"$1/ble.sh"
}
