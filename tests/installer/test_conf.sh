#!/usr/bin/env bash
# tests/installer/test_conf.sh — fedokawaii.conf as a person edits it, on Linux or on Windows:
# quotes, spaces, an empty value, a name mistyped or in small letters, a line copied twice,
# Windows line ends and byte-order mark, the file missing. lib/common.sh reads it
# (read_conf · conf_report · load_conf); every problem must be one plain line that names
# the setting and says what to write instead — and a valid file must read exactly as meant.
# (What setup.sh, theme.sh, check.sh and verify.sh then do with such a file: test_conf_scripts.sh)
FK_PURE=1 . "$(dirname "$0")/lib.sh"
sandbox
CONF=$REPO/fedokawaii.conf
# variant SED… — the shipped file, changed by sed expressions, as $TMP/c.conf
variant() { sed "$@" "$CONF" >"$TMP/c.conf"; }
# problems [FILE] — what lib/common.sh says of it (one line each; empty = valid)
problems() { ( LOG_FILE=/dev/null; . "$REPO/lib/common.sh"; conf_problems "${1:-$TMP/c.conf}" ); }
# value KEY [FILE] — what a setting reads as
value() { ( LOG_FILE=/dev/null; . "$REPO/lib/common.sh"; read_conf "${2:-$TMP/c.conf}"; printf '%s' "${!1}" ); }
lines() { grep -c . <<<"$1"; }

# ── a file that is right ─────────────────────────────────────────────────────
case_ "the shipped file is valid, and reads as written"
eq "$(problems "$CONF")" ""
eq "$(value GPU "$CONF")" auto; eq "$(value MONITOR_HZ "$CONF")" 144; eq "$(value USERNAME "$CONF")" ""
eq "$(value DWL_COMMIT "$CONF")" "$DWL_COMMIT"

case_ "single quotes, no quotes, a comment straight after, spaces and tabs around: all the same value"
variant -e "s/^GPU=.*/GPU='amd'/" -e 's/^STEAM=.*/STEAM=no/' -e 's/^THEME=.*/   THEME="light"#mine/' -e 's/^SSH_SERVER=.*/SSH_SERVER="yes"	  	/'
eq "$(problems)" ""
eq "$(value GPU)" amd; eq "$(value STEAM)" no; eq "$(value THEME)" light; eq "$(value SSH_SERVER)" yes

case_ "a city with spaces, an apostrophe or in Arabic or Japanese script: valid"
for c in "New York" "N'Djamena" "St. John's" "الشارقة" "東京" "São Paulo"; do
  variant -e "s|^WEATHER_CITY=.*|WEATHER_CITY=\"$c\"|"
  eq "$(problems)" "" "city $c"; eq "$(value WEATHER_CITY)" "$c"
done

case_ "a value holding \$(…), backticks or ; is read as text, never run, and refused"
variant -e 's|^WEATHER_CITY=.*|WEATHER_CITY="$(touch '"$TMP"'/ran)`touch '"$TMP"'/ran2`; touch '"$TMP"'/ran3"|'
p=$(problems)
has "$p" "WEATHER_CITY must be a plain city name"
[[ ! -e $TMP/ran && ! -e $TMP/ran2 && ! -e $TMP/ran3 ]] && _ok || _no "a value was run as a command"

case_ "Windows line ends (CRLF): every value as on Linux, no problem"
sed 's/$/\r/' "$CONF" >"$TMP/c.conf"
eq "$(problems)" ""
eq "$(value GPU)" auto; eq "$(value TFC_COMMIT)" "$TFC_COMMIT"; eq "$(value WEATHER_CITY)" Sharjah

case_ "a UTF-8 byte-order mark (Notepad, some Windows editors): read as if it were not there"
{ printf '\xef\xbb\xbf'; cat "$CONF"; } >"$TMP/c.conf"
eq "$(problems)" ""
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$CONF"; } >"$TMP/c.conf"
eq "$(problems)" "" "BOM and CRLF together"
{ printf '\xef\xbb\xbfGPU="intel"\n'; grep -v '^GPU=' "$CONF"; } >"$TMP/c.conf"
eq "$(problems)" "" "a setting on the first line, after the mark"; eq "$(value GPU)" intel

case_ "no newline at the end of the last line: that line still counts"
variant -e 's/^TFC_COMMIT=.*/TFC_COMMIT="'"$TFC_COMMIT"'"/'; printf 'THEME="light"' >>"$TMP/c.conf"
sed -i '0,/^THEME=/{/^THEME=/d}' "$TMP/c.conf"
eq "$(problems)" ""; eq "$(value THEME)" light

case_ "an empty USERNAME means whoever ran sudo: valid"
variant -e 's/^USERNAME=.*/USERNAME=""/'; eq "$(problems)" ""

# ── what a person gets wrong, and the one line that says so ───────────────────
case_ "the file missing: one line that says so (not a list of every setting)"
p=$(problems "$TMP/none.conf")
eq "$(lines "$p")" 1; has "$p" "cannot read $TMP/none.conf"

case_ "spaces around = : named, with the line to write"
variant -e 's/^GPU=.*/GPU = "amd"/'
p=$(problems)
eq "$(lines "$p")" 1 "one line, not a second 'GPU must be…' about an empty value"
has "$p" 'GPU has spaces around' ; has "$p" 'GPU="amd"'

case_ "a value with spaces and no quotes: told to quote it"
variant -e 's/^WEATHER_CITY=.*/WEATHER_CITY=New York/'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'WEATHER_CITY'; has "$p" 'WEATHER_CITY="New York"'

case_ "a name in small letters: told it is GPU"
variant -e 's/^GPU=/gpu=/'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'gpu'; has "$p" 'GPU'

case_ "export in front (shell habit): told to leave it out"
variant -e 's/^GPU=/export GPU=/'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'GPU'; has "$p" 'export'

case_ "a quote never closed: said, with the line"
variant -e 's/^GPU=.*/GPU="amd/'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'GPU has a quote that is not closed'

case_ "curly quotes (a word processor, a phone's keyboard): said, with straight ones to use"
variant -e 's/^GPU=.*/GPU=“amd”/'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'GPU has curly quotes'; has "$p" 'GPU="amd"'

case_ "a mistyped name: that it is not a setting, and which one is then missing"
variant -e 's/^GPU=/GUP=/'
p=$(problems)
eq "$(lines "$p")" 2; has "$p" 'GUP is not a setting of fedokawaii.conf'; has "$p" 'GPU is missing'
lacks "$p" "is '')" "no message about an empty value"

case_ "a line deleted: the setting is missing (not 'must be… (is '')')"
variant -e '/^THEME=/d'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'THEME is missing'
variant -e '/^USERNAME=/d'
eq "$(problems)" "" "USERNAME may go: it defaults to whoever ran sudo"

case_ "the same setting twice: said, with both lines (the one edited may not be the one that counts)"
variant -e '$a GPU="intel"'
p=$(problems)
eq "$(lines "$p")" 1; has "$p" 'GPU is set twice'; has "$p" "line 4"

case_ "an empty value where one is needed: the rule for it"
variant -e 's/^MONITOR_HZ=.*/MONITOR_HZ=""/'
has "$(problems)" "MONITOR_HZ must be a number 30–540 (is '')"

case_ "wrong values: each named with what it must be"
variant -e 's/^GPU=.*/GPU="nvidia"/' -e 's/^MONITOR_HZ=.*/MONITOR_HZ="1000"/' -e 's/^TIMEZONE=.*/TIMEZONE="Asia\/Nowhere"/' \
        -e 's/^NIGHT_LIGHT=.*/NIGHT_LIGHT="25,35:55,40"/' -e 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="11"/' -e 's/^DNF_PARALLEL=.*/DNF_PARALLEL="0"/'
p=$(problems)
has "$p" "GPU must be auto, amd or intel (is 'nvidia')"; has "$p" "MONITOR_HZ must be a number 30–540 (is '1000')"
has "$p" "TIMEZONE 'Asia/Nowhere' is not a known zone"; has "$p" "NIGHT_LIGHT must be latitude:longitude"
has "$p" "BOOT_MENU_SECONDS must be 0–10"; has "$p" "DNF_PARALLEL must be 1–20"
eq "$(lines "$p")" 6

case_ "BACKUP_TARGET: empty (none yet), a drive's name — with spaces, in Arabic — a folder's path, a restic address: valid"
eq "$(value BACKUP_TARGET "$CONF")" ""; eq "$(value BACKUP_REMIND_DAYS "$CONF")" 7
for t in KINGSTON "WD Elements 25A2" "نسخة احتياطية" /mnt/backup "/run/media/you/My Passport" "sftp:you@nas:/backups/desktop" \
         "rclone:gdrive:fedokawaii" "s3:s3.amazonaws.com/my-bucket" "rest:https://nas:8000/"; do
  variant -e "s|^BACKUP_TARGET=.*|BACKUP_TARGET=\"$t\"|"
  eq "$(problems)" "" "BACKUP_TARGET=$t"; eq "$(value BACKUP_TARGET)" "$t"
done
case_ "BACKUP_TARGET holding \$( ), backticks, ;, | or a quote (it reaches a shell file, env): refused as text, never run"
for t in '$(touch '"$TMP"'/ran)' '`id`' 'KINGSTON; rm -rf ~' 'a|b' "it's" '-rf' 'x&y' 'a\b' '~/backups'; do
  variant -e '/^BACKUP_TARGET=/d'; printf 'BACKUP_TARGET="%s"\n' "$t" >>"$TMP/c.conf"
  p=$(problems); has "$p" "BACKUP_TARGET must be a drive's name, a folder's path or a restic address" "BACKUP_TARGET=$t"
  eq "$(lines "$p")" 1 "BACKUP_TARGET=$t: one line"
done
[[ ! -e $TMP/ran ]] && _ok || _no "a BACKUP_TARGET was run as a command"
case_ "BACKUP_REMIND_DAYS: 0 (off) to 365; anything else named with its rule"
for d in 0 1 7 30 365; do variant -e "s|^BACKUP_REMIND_DAYS=.*|BACKUP_REMIND_DAYS=\"$d\"|"; eq "$(problems)" "" "BACKUP_REMIND_DAYS=$d"; done
for d in 366 -1 7.5 soon "" 08 007; do
  variant -e "s|^BACKUP_REMIND_DAYS=.*|BACKUP_REMIND_DAYS=\"$d\"|"
  has "$(problems)" "BACKUP_REMIND_DAYS must be 0–365 (0 = no reminder) (is '$d')" "BACKUP_REMIND_DAYS=$d"
done
case_ "a number with a leading zero (08, 0144: bash would read it as octal, or refuse it): named"
variant -e 's/^MONITOR_HZ=.*/MONITOR_HZ="0144"/' -e 's/^DNF_PARALLEL=.*/DNF_PARALLEL="08"/'
p=$(problems); has "$p" "MONITOR_HZ must be a number 30–540 (is '0144')"; has "$p" "DNF_PARALLEL must be 1–20, dnf5's maximum (is '08')"
case_ "the backup lines deleted (a fedokawaii.conf from before them): each named as missing"
variant -e '/^BACKUP_TARGET=/d' -e '/^BACKUP_REMIND_DAYS=/d'
p=$(problems); eq "$(lines "$p")" 2; has "$p" 'BACKUP_TARGET is missing'; has "$p" 'BACKUP_REMIND_DAYS is missing'

case_ "a time zone that walks out of the zone folder (../): refused"
variant -e 's|^TIMEZONE=.*|TIMEZONE="../../etc/passwd"|'; has "$(problems)" "TIMEZONE"

case_ "USERNAME: a user that does not exist, root, a name starting with - or a number: refused"
for u in nosuchuser-kawa root -u 0 123 "a b"; do
  variant -e "s|^USERNAME=.*|USERNAME=\"$u\"|"
  has "$(problems)" "USERNAME" "USERNAME=$u"
done
variant -e "s|^USERNAME=.*|USERNAME=\"$(id -un)\"|"
if [[ $(id -un) != root ]]; then eq "$(problems)" "" "an existing user"; else _ok; fi

case_ "an unknown setting (from an older or newer copy): named"
variant -e '$a FOO_BAR="1"'
has "$(problems)" 'FOO_BAR is not a setting of fedokawaii.conf'

case_ "a line that is not a setting at all: shown (cut to 60 characters)"
variant -e '$a this line is just text someone typed into the file by mistake while reading it'
p=$(problems)
has "$p" 'not a setting'; has "$p" 'this line is just text'
lacks "$p" 'while reading it' "a long line is cut"

case_ "load_conf: stops with every problem listed, indented, on stderr (exit 1)"
variant -e 's/^GPU=.*/GPU="nvidia"/' -e 's/^STEAM=.*/STEAM="maybe"/'
mkdir -p "$TMP/r"; cp "$TMP/c.conf" "$TMP/r/fedokawaii.conf"
out=$( ( LOG_FILE=/dev/null; . "$REPO/lib/common.sh"; load_conf "$TMP/r" ) 2>&1 >/dev/null ); r=$?
eq "$r" 1
has "$out" "fedokawaii.conf:"; has "$out" "    GPU must be auto, amd or intel (is 'nvidia')"; has "$out" "    STEAM must be yes or no"

case_ "USERNAME with a leading digit (Fedora's installer allows it): judged by whether the user exists, not refused by its shape"
variant -e 's|^USERNAME=.*|USERNAME="1fluvia"|'; has "$(problems)" "USERNAME '1fluvia' does not exist"
lacks "$(problems)" "is not a user name"

done_
