# shellcheck shell=sh
# /etc/profile.d/kawa-torrra.sh — in bash, `torrra` runs through kawa-torrra, which hands it
# the Prowlarr key from ~/.config/fedokawai/secrets.sh (torrra on its own would look for it
# in its config file). Installed by fedokawai's setup.sh.
if [ -n "${BASH_VERSION:-}" ]; then torrra() { kawa-torrra "$@"; }; fi
