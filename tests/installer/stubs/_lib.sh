# shared by the fake Fedora's commands (tests/installer/stubs, installed as the fake machine's
# /usr/local/bin): their state and the call log live in /var/lib/fkh
FKH=/var/lib/fkh
fkh_log() { printf '%s[%s] %s\n' "$(id -un 2>/dev/null)" "${0##*/}" "$*" >>"$FKH/calls.log" 2>/dev/null || true; }
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
