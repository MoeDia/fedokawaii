#!/usr/bin/bash
# iso/screens/post.sh — the kickstart's %post, outside the chroot: the toolkit, its record of who and
# what was chosen, the first start's setup and the first start's look. Nothing here asks; a failure
# ends in %onerror's screen.
set -Eeuo pipefail
S=/usr/share/fedokawaii-iso
R=/mnt/sysimage
T=$R/usr/local/lib/fedokawaii
STATE=$R/var/lib/fedokawaii
# shellcheck disable=SC1091
source /tmp/answers.env

# the toolkit: what setup would have made from a clone, root's own
mkdir -p "$T"
tar -xJf "$S/toolkit.tar.xz" -C "$T" --no-same-owner
chown -R root:root "$T"
chmod -R u=rwX,go=rX "$T"

# what was chosen goes in the toolkit's settings (setup and theme read them): fedokawaii.conf
conf() { sed -i -E "s|^$1=\"[^\"]*\"|$1=\"$2\"|" "$T/fedokawaii.conf"; }
conf USERNAME "$FK_USER"
conf TIMEZONE "$FK_ZONE"
# the desktop's keyboard: the owner's two on the US keyboard; another's, then US to fall back on
[[ $FK_LAYOUT == us ]] || conf KB_LAYOUTS "$FK_LAYOUT,us"
# where you are, for the weather and the night light: only what Fedora's GeoIP says of the zone chosen
if [[ $FK_ZONE == "$FK_GEO_ZONE" && -n $FK_LAT && -n $FK_LON ]]; then
  conf NIGHT_LIGHT "$FK_LAT:$FK_LON"
  [[ $FK_CITY =~ ^[[:alnum:]\ .\'-]+$ ]] && conf WEATHER_CITY "$FK_CITY"
fi

# setup's records: who, with the theme, from phase 1
mkdir -p "$STATE"
printf '%s\n' "$FK_USER" >"$STATE/user"
: >"$STATE/with-theme"

# the first start's look: the splash in the installed boot image, before theme.sh's turn comes
mkdir -p "$R/usr/share/plymouth/themes/sumi"
cp "$T"/system/plymouth/sumi/* "$R/usr/share/plymouth/themes/sumi/"
chroot "$R" plymouth-set-default-theme sumi
for k in "$R"/usr/lib/modules/*; do
  [[ -f $k/vmlinuz ]] && chroot "$R" dracut -f --kver "${k##*/}"
done
# (console=tty2 kept Anaconda's words off our screen: not for the installed system)
chroot "$R" grubby --update-kernel=ALL --remove-args="console=tty2"
sed -i -E 's/ ?console=tty2//' "$R/etc/default/grub"

# the first start's screen, as the resume unit (setup.sh's own unit: the same text it writes at each
# of its reboots, ExecStart here replaced by the screen), and its files: gone at the end (first_boot.py)
mkdir -p "$STATE/first-boot"
cp "$S"/console.py "$S"/first_boot.py "$S"/glyphs.py "$S"/sumi-console.psf "$STATE/first-boot/"
cat >"$R/etc/systemd/system/fedokawaii-resume.service" <<'EOF'
[Unit]
Description=Fedokawaii setup — resume after reboot
After=network-online.target systemd-user-sessions.service
Wants=network-online.target
# (greetd too: enabled near the very end, it must not take tty1 from a run that resumes there)
Conflicts=getty@tty1.service kmsconvt@tty1.service greetd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /usr/local/lib/fedokawaii/setup.sh --resume
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TimeoutStartSec=0
Environment=TERM=linux

[Install]
WantedBy=multi-user.target
EOF
mkdir -p "$R/etc/systemd/system/fedokawaii-resume.service.d"
cat >"$R/etc/systemd/system/fedokawaii-resume.service.d/first-boot.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/python3 /var/lib/fedokawaii/first-boot/first_boot.py
EOF
chroot "$R" systemctl enable fedokawaii-resume.service
chroot "$R" restorecon -RF /usr/local/lib/fedokawaii /var/lib/fedokawaii /etc/systemd/system/fedokawaii-resume.service /etc/systemd/system/fedokawaii-resume.service.d /usr/share/plymouth/themes/sumi
