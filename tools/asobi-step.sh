#!/usr/bin/env bash
# tools/asobi-step.sh — setup.sh's s_asobi alone, from this tree, on this machine (nothing else of
# the installer runs): for working on the play world without a whole apply.
#   sudo bash tools/asobi-step.sh [FUNCTION…]    default: s_asobi; else lib/asobi.sh's own, in turn
set -u
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 2; }
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd) STATE_DIR=/var/lib/fedokawaii LOG_FILE=/var/log/fedokawaii-asobi-step.log
export REPO_DIR STATE_DIR LOG_FILE
touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/manifest.sh"
source "$REPO_DIR/lib/upstream.sh"
source "$REPO_DIR/lib/asobi.sh"
TARGET_USER=$(head -n1 "$STATE_DIR/user" | tr -d '[:space:]')
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER") TARGET_GID=$(id -g "$TARGET_USER")
export TARGET_USER TARGET_HOME TARGET_UID TARGET_GID
(($#)) || set -- s_asobi
for f; do "$f" || { echo "$f failed" >&2; exit 1; }; done
