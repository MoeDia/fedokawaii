#!/usr/bin/env bash
# tests/engine/test_configs.sh — the two system files that are settings, not scripts:
# prowlarr.container (the rootless Prowlarr quadlet) and tuned.conf (the performance profile).
# Each is read as its program reads it, and checked against what setup.sh, verify.sh and
# kawa-torrra expect of it: the same names, the same port, the same key.
. "$(dirname "$0")/lib.sh"
sandbox
Q=$REPO/system/prowlarr.container T=$REPO/system/tuned.conf

# systemd unit syntax: [Section] / Key=Value, keys may repeat; → "Section.Key=Value" lines
units() { awk '/^[[:space:]]*[#;]/ || /^[[:space:]]*$/ { next } /^\[/ { s = substr($0, 2, length($0) - 2); next }
               { k = $0; sub(/=.*/, "", k); v = $0; sub(/^[^=]*=/, "", v); print s "." k "=" v }' "$1"; }
val() { units "$Q" | sed -n "s/^$1=//p"; }

case_ "prowlarr.container: three sections, no [Install] (it runs only when wanted)"
eq "$(grep -o '^\[[A-Za-z]*\]' "$Q" | tr '\n' ' ')" "[Unit] [Container] [Service] "
case_ "every key is one Podman 5's quadlet knows, in its section"
known=" Image ContainerName UserNS User Group Tmpfs NoNewPrivileges Timezone PublishPort Volume Secret Environment "
known+="HealthCmd HealthInterval HealthRetries HealthTimeout HealthOnFailure HealthStartupCmd HealthStartupInterval HealthStartupRetries Notify "
while IFS= read -r l; do
  k=${l%%=*}
  case $k in
    Container.*) [[ $known == *" ${k#Container.}"[[:space:]]* ]] && _ok || _no "not a [Container] key: $k" ;;
    Unit.Description|Service.Restart|Service.RestartSec|Service.TimeoutStartSec) _ok ;;
    *) _no "unexpected key: $k" ;;
  esac
done < <(units "$Q")
case_ "the image setup pulls is the one named here (setup reads it from this file)"
eq "$(sed -n 's/^Image=//p' "$Q")" "lscr.io/linuxserver/prowlarr:latest"
grep -q "prowlarr_image() { sed -n 's/^Image=//p' \"\$REPO_DIR/system/prowlarr.container\"; }" "$REPO/setup.sh" && _ok || _no "setup.sh no longer reads the image from here"
case_ "Prowlarr answers on this computer only (127.0.0.1), on the port everything else uses"
eq "$(val Container.PublishPort)" "127.0.0.1:9696:9696"
grep -q '127.0.0.1:9696' "$REPO/system/kawa-torrra" && _ok || _no "kawa-torrra asks another port"
grep -q 'http://127.0.0.1:9696/ping' "$REPO/verify.sh" && _ok || _no "verify asks another port"
for k in HealthCmd HealthStartupCmd; do has "$(val Container.$k)" "http://127.0.0.1:9696/ping"; done
case_ "the API key: the podman secret setup makes, handed in as Prowlarr's own variable — never a file here"
eq "$(val Container.Secret)" "prowlarr-api-key,type=env,target=PROWLARR__AUTH__APIKEY"
grep -q 'podman secret create --replace prowlarr-api-key' "$REPO/setup.sh" && _ok || _no "setup.sh makes a secret of another name"
lacks "$(cat "$Q")" "PROWLARR__AUTH__APIKEY="
case_ "your files stay yours: uid 1000 inside is you (keep-id), no privileges to gain"
eq "$(val Container.UserNS)" "keep-id:uid=1000,gid=1000"; eq "$(val Container.User)" 1000; eq "$(val Container.Group)" 1000
eq "$(val Container.NoNewPrivileges)" true
eq "$(val Container.Volume)" "%h/.config/prowlarr:/config:Z"
case_ "started means answering: the start waits for health, and long enough for it"
eq "$(val Container.Notify)" healthy
i=$(val Container.HealthStartupInterval); n=$(val Container.HealthStartupRetries); t=$(val Service.TimeoutStartSec)
(( ${i%s} * n <= t )) && _ok || _no "health startup ${i}×$n outlasts TimeoutStartSec=$t"
case_ "a web page that asks for a login, and no data sent home"
has "$(val Container.Environment)" "PROWLARR__AUTH__METHOD=Forms"; has "$(val Container.Environment)" "PROWLARR__AUTH__REQUIRED=Enabled"
has "$(val Container.Environment)" "PROWLARR__LOG__ANALYTICSENABLED=False"

case_ "tuned.conf: read as tuned reads it (INI), the parent profile, the desktop's values"
out=$(python3 - "$T" <<'EOF'
import configparser, sys
c = configparser.ConfigParser(interpolation=None, strict=True)
c.read(sys.argv[1])
for s in c.sections():
    for k, v in c.items(s):
        print(f"{s}.{k}={v}")
EOF
); eq "$?" 0
has "$out" "main.include=throughput-performance"
has "$out" "sysctl.vm.swappiness=100"; has "$out" "sysctl.vm.page-cluster=0"; has "$out" "sysctl.vm.watermark_boost_factor=0"
has "$out" "vm.dirty_bytes=20%"; has "$out" "vm.dirty_background_bytes=10%"
case_ "tuned.conf: write-back starts before the limit (background below dirty)"
b=$(sed -n 's/^vm.dirty_background_bytes=\([0-9]*\)%$/\1/p' <<<"$out"); d=$(sed -n 's/^vm.dirty_bytes=\([0-9]*\)%$/\1/p' <<<"$out")
(( b < d )) && _ok || _no "background $b% ≥ dirty $d%"
case_ "tuned.conf: the dirty limits only in [vm] (a [sysctl] line would race the parent's)"
lacks "$(grep -A99 '^\[sysctl\]' "$T" | sed '/^\[vm\]/,$d')" "dirty"
case_ "the profile name setup applies and verify checks is this one's folder"
grep -q 'tuned/profiles/fedokawaii/tuned.conf' "$REPO/setup.sh" && _ok || _no "installed elsewhere"
grep -q 'tuned-adm profile fedokawaii' "$REPO/setup.sh" && _ok || _no "another profile applied"

done_
