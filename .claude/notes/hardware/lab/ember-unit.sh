#!/bin/bash
# the service until main's apply: a temporary unit and binary in /run (gone at a reboot, no strays),
# with the repo's unit file; the real kawa-rgb.service, when it starts, stops it. argv: start|stop|gone
case $1 in
  start) sudo -n systemctl stop r27-kawa-rgb.service 2>/dev/null
         sudo -n rm -f /usr/local/bin/kawa-rgb-try
         sudo -n install -m 0755 /dev/shm/r27-lane-hardware/build/kawa-rgb /run/kawa-rgb-try
         sudo -n chcon -t bin_t /run/kawa-rgb-try 2>/dev/null
         sed -e 's|^ExecStart=.*|ExecStart=/run/kawa-rgb-try run|' -e 's|^\[Unit\]|[Unit]\nConflicts=kawa-rgb.service|' /home/dia/repos/fk-hardware/configs/system/etc/systemd/system/kawa-rgb.service | sudo -n tee /run/systemd/system/r27-kawa-rgb.service >/dev/null
         sudo -n systemctl daemon-reload
         sudo -n systemctl start r27-kawa-rgb.service ;;
  stop) sudo -n systemctl stop r27-kawa-rgb.service ;;
  gone) sudo -n systemctl stop r27-kawa-rgb.service; sudo -n rm -f /run/systemd/system/r27-kawa-rgb.service /run/kawa-rgb-try /usr/local/bin/kawa-rgb-try; sudo -n systemctl daemon-reload ;;
esac
