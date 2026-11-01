#!/usr/bin/env bash
# tests/static/test_barreload.sh — the bar's style reloads without waybar's full reload (ledger
# r27-found-1): waybar 0.15's SIGUSR2 rebuilds every module and leaves children that never ran
# their command, unreaped, at every reload (3 → 8 → 9 after three, seen headless 1 Nov). So:
#   · config.jsonc asks waybar to reload its stylesheet itself ("reload_style_on_change": the
#     CSS provider only — the modules and their children stay as they are)
#   · nothing of the desktop, the installer or the Learn book sends SIGUSR2 to waybar
# The running proof (the same children before and after, no zombie): tools/bar-zombies.sh.
. "$(dirname "$0")/../lib/harness.sh"

case_ "the bar reloads its stylesheet by itself (reload_style_on_change), never all its modules"
v=$(python3 -I - "$REPO/configs/home/.config/waybar/config.jsonc" <<'EOF'
import json, re, sys
text = open(sys.argv[1], encoding="utf-8").read()
print(json.loads(re.sub(r"(?m)^\s*//.*$", "", text)).get("reload_style_on_change"))
EOF
)
eq "$v" True

case_ "no program, config, installer step or Learn page sends SIGUSR2 to waybar"
bad=$(grep -rnE '(pkill|killall|kill)[^|;&]*(USR2|SIGUSR2|-12\b)[^|;&]*waybar|signal +USR2 +waybar' \
  "$REPO/bin" "$REPO/lib" "$REPO/configs" "$REPO/system" "$REPO/tools" "$REPO/setup.sh" "$REPO/theme.sh" \
  "$REPO/fedokawaii.sh" "$REPO/verify.sh" "$REPO/docs/fedokawaii-learn.md" 2>/dev/null)
[[ -z $bad ]] && _ok || _no "$bad"

done_
