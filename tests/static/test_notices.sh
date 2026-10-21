#!/usr/bin/env bash
# tests/static/test_notices.sh — every notice of the desktop is laid out alike: the app
# (-a desktop · drives · backup · torrra · notices, the names mako's sections go by), the icon (a Sumi
# Icons glyph — or a kanji seal, as the snapshot's 史 —, two spaces, then the title — or the picture itself with -i), a title in lower
# case (a name stays as it is spelled: Steam, Bluetooth, Prowlarr), "--" before it, so a
# title can never be read as an option; something missing that repair puts back is critical.
# And mako: a click takes a card away at once, the whole card.
. "$(dirname "$0")/../lib/harness.sh"

out=$(python3 -I - "$REPO" <<'EOF'
import re, sys, pathlib
root = pathlib.Path(sys.argv[1])
files = [p for d in ("bin", "system", "configs") for p in (root / d).rglob("*") if p.is_file()]
files = [p for p in files if p.name != "fedokawaii-report" and p.suffix not in (".png", ".ttf", ".otf", ".pdf")]
APPS = {"desktop", "drives", "backup", "torrra", "downloads", "notices"}
NAMES = {"Steam", "Bluetooth", "Prowlarr"}
ICON = re.compile(r'^"(\$ICON_[A-Z_]+|\$\{ICON_[A-Z_]+:-[^}]*\}|\$SEAL|\$ICON|\$\(\. [^)]*ICON_[A-Z_]+"?\)|[一-鿿])  ')
bad = []
for p in files:
    try: lines = p.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError: continue
    for n, l in enumerate(lines, 1):
        code = l.split(" #")[0] if not l.lstrip().startswith("#") else ""
        m = re.search(r'notify-send\s+(.*)', code)
        if not m or "command -v" in code: continue
        where = f"{p.relative_to(root)}:{n}"
        args = m.group(1)
        if args.startswith('-a osd -c osd '): continue          # (kawa-osd: the level display, a category of its own)
        if args.startswith('"${a[@]}"'):                         # a helper's: its array names the app
            body = "\n".join(lines[max(0, n - 6):n])
            am = re.search(r'local a=\(-a (\w+)', body)
            if not am or am.group(1) not in APPS: bad.append(f"{where}: the helper's array names no known app")
            if " -- " not in args: bad.append(f"{where}: no -- before the title")
            continue
        am = re.match(r'-a (\w+)', args)
        if not am or am.group(1) not in APPS:
            bad.append(f"{where}: -a first, one of {sorted(APPS)}: {args[:60]}"); continue
        if " -- " not in args:
            bad.append(f"{where}: no -- before the title: {args[:60]}"); continue
        summ = args.split(" -- ", 1)[1]
        if summ.startswith('"$title"') and " -i " in args: continue   # (the screenshot: its picture is the icon)
        if summ.startswith('"$2"') and "-A default" in args: continue   # (kawa-drives' notice-open: handed one, laid out by its caller)
        im = ICON.match(summ)
        if not im:
            bad.append(f"{where}: the title has no icon (\"$ICON_…  title\"): {summ[:50]}"); continue
        title = summ[im.end():]
        w = re.match(r'([A-Za-z][\w+]*)', title)
        if w and w.group(1)[0].isupper() and w.group(1) not in NAMES:
            bad.append(f"{where}: the title in lower case, not \"{w.group(1)}\"")
        if "fedokawaii repair puts it back" in code and "-u critical" not in args and "is not installed" not in code:
            bad.append(f"{where}: something missing is critical (-u critical)")
print("\n".join(bad))
EOF
)
case_ "every notify-send: -a a known app, --, an icon (or a kanji seal) and two spaces, a title in lower case, critical when repair is needed"
while IFS= read -r l; do [[ -n $l ]] && _no "$l"; done <<<"$out"
eq "$out" ""
has "$(cat "$REPO/configs/home/.config/dwl/autostart.sh")" 'notify-send -a desktop -u critical -- "史  a snapshot"' "the snapshot's notice: 史 (history), kept until dismissed"

case_ "the python notices (torrra's, the downloads') laid out the same: -a, --, the icon and two spaces"
has "$(cat "$REPO/system/kawa-torrra")" '"notify-send", "-a", "torrra", "-u", urgency, "--", icon + "  torrra", msg'
has "$(cat "$REPO/bin/kawa-downloads")" '"notify-send", "-a", "downloads", "-A", "default=open", "--",
                        f"{ic['"'"'download'"'"']}  {name}", body]'

case_ "mako: a click takes the whole card at once; only a repeat folds; the drives' click runs its action"
m=$(cat "$REPO/configs/home/.config/mako/config")
has "$m" $'\non-button-left=dismiss-group\n'
has "$m" $'\ngroup-by=app-name,summary,body\n'
has "$(sed -n '/^\[app-name=drives\]$/,/^$/p' <<<"$m")" "on-button-left=invoke-default-action"
has "$(sed -n '/^\[app-name=downloads\]$/,/^$/p' <<<"$m")" "on-button-left=invoke-default-action"
has "$(sed -n '/^\[app-name=notices\]$/,/^$/p' <<<"$m")" "on-button-left=invoke-default-action"
eq "$(grep -c '^on-button-left=' <<<"$m")" 4 "four: everyone's, the drives', the downloads' and the held notices' (kawa-hush)"
done_
