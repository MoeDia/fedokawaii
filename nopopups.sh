#!/usr/bin/env bash
# No more password pop-ups (owner, 4 Nov 21:42): while this PC is a test machine, dia may do everything
# (VMs, services, disks) without a password prompt. Temporary, like the round's sudo rule: removed at T62,
# never shipped in the ISO or the installer. Run as dia; sudo asks for your password once, in this terminal.
set +e
sudo tee /etc/polkit-1/rules.d/00-fedokawaii-round.rules >/dev/null <<'EOF'
// round 27 only (owner 4 Nov 2026): no password pop-ups for dia while the PC is a test machine.
// Remove at T62. Never in the ISO or the installer.
polkit.addRule(function(action, subject) { if (subject.user == "dia") { return polkit.Result.YES; } });
EOF
sudo chmod 644 /etc/polkit-1/rules.d/00-fedokawaii-round.rules
getent group libvirt >/dev/null && sudo usermod -aG libvirt "$(id -un)"
printf '\n## %s — open\nOWNER 21:42: no more password pop-ups. /etc/polkit-1/rules.d/00-fedokawaii-round.rules lets dia do everything without a password while this PC is a test machine (VMs included). Temporary like the sudo rule: remove it at T62 and NEVER ship it in the ISO or the installer.\n' "$(date '+%F %H:%M')" >> "$HOME/repos/fedokawaii/.claude/inbox.md"
pkcheck --action-id org.libvirt.unix.manage --process $$ >/dev/null 2>&1 && echo "OK: no more password pop-ups" || echo "rule written; if a pop-up still shows, log out and in once"
