#!/usr/bin/env bash
# tools/vm-inject/probation.sh — the start after an update that brought a kernel (update-design.md
# §4.3, T45 (f)), in the harness VM from "built": the button's run on the VM's real pending updates
# (they bring a newer kernel), the desktop started at every start (greetd's initial session: no
# password anywhere), then a restart and one of
#   fail  the new kernel unable to start (its boot image an empty archive: no root, a panic, and
#         the trial's panic=10 restarts) — GRUB tries it three times, then takes the one before;
#         there the desktop runs two minutes, Fedora's timer marks the start good, and
#         fedokawaii-boot-good holds the new kernel, takes it out, makes the one before the default
#   pass  the new kernel starts: the desktop marks it good — its trial over (the counting off, its
#         arguments out, the watchdog off), the update's snapshot back to snapper's cleanup
#   bash tools/vm-inject/probation.sh VM [REPO] [fail|pass]…   (REPO this repository)
# Out: a line a case on stdout, everything in /dev/shm/r27/probation-VM/. Exit 0 every case held ·
# 1 one did not · 2 the VM could not run.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
vm=${1:?VM} src=${2:-$(cd "$here/.." && pwd)}; shift 2 2>/dev/null || shift $#
cases=("$@"); ((${#cases[@]})) || cases=(fail pass)
out=/dev/shm/r27/probation-$vm; rm -rf "$out"; mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$vm" "$@"; }
bad=0
for c in "${cases[@]}"; do
  log=$out/$c.log; : >"$log"
  { bash "$here/vm-snap.sh" "$vm" revert built && bash "$here/vm-snap.sh" "$vm" start && run --wait 600; } >>"$log" 2>&1 \
    || { echo "probation: the VM did not start" >&2; exit 2; }
  # (applied as the PC is before a press: the toolkit, the theme, our builds — the desktop check green)
  { run --apply "$src"
    # (the desktop at every start, as him: greetd's initial session, left in place for the whole case)
    run 'printf "\n[initial_session]\ncommand = \"/usr/local/bin/start-dwl\"\nuser = \"dia\"\n" | sudo tee -a /etc/greetd/fedokawaii.toml >/dev/null'
  } >>"$log" 2>&1 || { echo "probation: the toolkit could not go in" >&2; exit 2; }
  old=$(run 'uname -r')
  run 'sudo bash /usr/local/lib/fedokawaii/setup.sh --update >/tmp/update.log 2>&1; echo "rc=$?"; sed "s/\x1b\[[0-9;]*m//g" /tmp/update.log | tail -n 25' >>"$log" 2>&1
  # (a green run never says the desktop does not start: else its check after the update saw nothing)
  if run 'grep -q "the desktop does not start" /tmp/update.log'; then
    printf '%-5s the desktop check was red in the update itself — its after-check blind\n' "$c"; bad=1; continue
  fi
  new=$(run 'sudo cut -d" " -f2 /var/lib/fedokawaii/update/probation | tail -n1')
  snap=$(run 'sudo cut -d" " -f1 /var/lib/fedokawaii/update/probation | tail -n1')
  armed=$(run 'sudo grub2-editenv - list | grep -E "^boot_(counter|success|indeterminate)=" | sort | tr "\n" " "; sudo grubby --info=/boot/vmlinuz-'"$new"' 2>/dev/null | grep -c "rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10"; sudo cat /etc/systemd/system.conf.d/90-fedokawaii-probation.conf 2>/dev/null | grep -c RuntimeWatchdogSec')
  printf 'old %s · new %s · armed: %s\n' "$old" "$new" "$armed" >>"$log"
  if [[ ! $new =~ ^[0-9] || $new == "$old" ]]; then
    printf '%-5s no kernel came with the update (old %s, new %s) — nothing to prove\n' "$c" "$old" "${new:-?}"; bad=1; continue
  fi
  if [[ $c == fail ]]; then   # (an archive with nothing in it: the kernel unpacks it, finds no /init and no root)
    run "printf '' | cpio -o -H newc 2>/dev/null >/tmp/empty.img && sudo cp /tmp/empty.img /boot/initramfs-$new.img && sync" >>"$log" 2>&1
  fi
  s=$SECONDS
  run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 30
  # (three tries of about 20 s, the start, two minutes of desktop, the mark: within ten minutes)
  run --wait 900 >>"$log" 2>&1 || { printf '%-5s the VM did not come back\n' "$c"; bad=1; continue; }
  for _ in $(seq 60); do run 'sudo test -e /var/lib/fedokawaii/update/probation' || break; sleep 10; done
  up=$((SECONDS - s))
  st=$(run 'echo "running $(uname -r)"; e=$(sudo grub2-editenv - list); sed -n "s/^boot_counter=/counter /p" <<<"$e"; grep -q "^boot_counter=" <<<"$e" || echo "counter off"
            sudo test -e /var/lib/fedokawaii/update/probation && echo "probation open" || echo "probation closed"
            echo "default $(sudo grubby --default-kernel)"; rpm -q kernel-core | tr "\n" " "; echo
            sudo grep "^kernel-core " /var/lib/fedokawaii/update/holds 2>/dev/null || echo "no hold"
            echo "trial args $(sudo grubby --info=ALL | grep -c "rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10")"
            sudo test -e /etc/systemd/system.conf.d/90-fedokawaii-probation.conf && echo "watchdog on" || echo "watchdog off"
            echo "snapshot '"$snap"' $(sudo snapper -c root list --columns number,cleanup | awk -v n='"$snap"' "\$1 == n { print \$3 }")"
            sudo journalctl -b -u fedokawaii-boot-good.service --no-pager -o cat | tail -n 8' 2>&1)
  printf '%s\n' "$st" >>"$log"
  ok=1
  grep -qx 'probation closed' <<<"$st" && grep -qx 'counter off' <<<"$st" && grep -qx 'watchdog off' <<<"$st" && grep -qx 'trial args 0' <<<"$st" \
    && grep -qx "snapshot $snap number" <<<"$st" || ok=0
  if [[ $c == fail ]]; then
    grep -qx "running $old" <<<"$st" && grep -qx "default /boot/vmlinuz-$old" <<<"$st" && grep -q "^kernel-core ${new%.*} .* did not reach the desktop in three starts$" <<<"$st" \
      && ! grep -q "kernel-core-$new" <<<"$st" || ok=0
  else
    grep -qx "running $new" <<<"$st" && grep -qx 'no hold' <<<"$st" || ok=0
  fi
  ((ok)) || bad=1
  printf '%-5s %s in %s s after the restart · %s\n' "$c" "$( ((ok)) && echo held || echo BROKEN)" "$up" "$(grep -E '^(running|default|counter|probation)' <<<"$st" | tr '\n' ' ')"
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
done
exit "$bad"
