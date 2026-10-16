#!/usr/bin/env bash
# tests/status/test_weather.sh — kawa-weather, the quick-settings title ("☼  Sharjah  31°C  Clear"):
# printed at once from ~/.cache/kawa-weather, refreshed from wttr.in in the background when
# older than 30 minutes. curl is a stub that answers what each case needs (a good line, an
# error page, garbage, offline, a timeout) and notes when it is done.
. "$(dirname "$0")/lib.sh"
CACHE() { cat "$HOME/.cache/kawa-weather" 2>/dev/null; }
setup() {
  box; . "$HOME/.config/fedokawaii/icons.sh"
  answer '+31°C  Clear'
}
# answer TEXT [STATUS] — what wttr.in (the curl stub) prints, and curl's exit status
answer() {
  printf '%s\n' "$1" >"$TMP/answer"
  stub curl 'cat "$TMP/answer"; r='"${2:-0}"'; : >"$TMP/curl.done"; exit $r'
  export TMP
}
# fetched — wait for the background refresh's curl, then a moment for its write
fetched() { waitfor 5 test -e "$TMP/curl.done" || { _no "no refresh was started"; return 1; }; /bin/sleep 0.3; rm -f "$TMP/curl.done"; }
# at HOUR CMD… — run CMD with the clock's local hour at HOUR (a TZ offset from UTC's hour now)
at() {
  local h u off r; h=$1; shift
  for _ in 1 2 3; do
    u=$(date -u +%H); off=$(( (10#$u - h + 36) % 24 - 12 ))   # TZ "X-3" is 3 h ahead of UTC
    r=$(TZ="KAW$( ((off >= 0)) && printf "+")$off" "$@")
    [[ $(date -u +%H) == "$u" ]] && { printf '%s\n' "$r"; return; }
  done
}
sky() { at 12 kawa-weather; }

# ── first run, the cache ─────────────────────────────────────────────────────
case_ "first run (no cache): the city at once, never waiting for the network; the weather fetched behind"
setup
s=$EPOCHREALTIME; out=$(sky); t=$(( ${EPOCHREALTIME/./} - ${s/./} ))
eq "$out" "$ICON_SUN  Sharjah"
fetched
eq "$(CACHE)" "Sharjah  31°C  Clear" "cached, the + taken off"
eq "$(sky)" "$ICON_SUN  Sharjah  31°C  Clear"
called "curl -fsS --proto =https --max-time 8 https://wttr.in/Sharjah\\?format=%t\\+\\+%C&m"
case_ "fresh cache (under 30 minutes): shown, no fetch"
reset_calls; sky >/dev/null; /bin/sleep 0.2; not_called curl
case_ "stale cache (over 30 minutes): shown as it is, and fetched again behind"
touch -d '-31 minutes' "$HOME/.cache/kawa-weather"; answer '+29°C  Partly cloudy'
eq "$(sky)" "$ICON_SUN  Sharjah  31°C  Clear"
fetched; eq "$(CACHE)" "Sharjah  29°C  Partly cloudy"
case_ "the cache of another city (the settings changed it): not shown, only the new city's name until it comes"
setup; echo 'Tokyo  12°C  Clear' >"$HOME/.cache/kawa-weather"
eq "$(sky)" "$ICON_SUN  Sharjah"
fetched; eq "$(CACHE)" "Sharjah  31°C  Clear"
case_ "a city whose name begins like the cached one's is still another city"
setup; echo 'Sharjah City  12°C  Clear' >"$HOME/.cache/kawa-weather"
eq "$(sky)" "$ICON_SUN  Sharjah"

case_ "a corrupt or cut-short cache: not shown, fetched again"
for junk in 'Sharjah  ' 'Sharjah  <html><body>502 Bad Gateway' $'Sharjah  \x01\x02\xff\xfe' 'Sharjah  31°C' 'Sharjah' ''; do
  setup; printf '%s\n' "$junk" >"$HOME/.cache/kawa-weather"
  eq "$(sky)" "$ICON_SUN  Sharjah" "cache [$junk]"
  fetched; eq "$(CACHE)" "Sharjah  31°C  Clear" "fetched again after [$junk]"
done
case_ "an empty cache file: fetched"
setup; : >"$HOME/.cache/kawa-weather"; sky >/dev/null; fetched; eq "$(CACHE)" "Sharjah  31°C  Clear"

# ── what wttr.in may answer ──────────────────────────────────────────────────
keeps() {   # keeps ANSWER [STATUS] — a cached good line survives this answer, and is shown
  setup; echo 'Sharjah  30°C  Sunny' >"$HOME/.cache/kawa-weather"; touch -d '-40 minutes' "$HOME/.cache/kawa-weather"
  answer "$1" "${2:-0}"
  sky >/dev/null; fetched
  eq "$(CACHE)" "Sharjah  30°C  Sunny" "after [${1:0:60}] (curl status ${2:-0})"
  eq "$(sky)" "$ICON_SUN  Sharjah  30°C  Sunny"
  fetched                                       # (still stale: fetched again — let it finish)
}
case_ "offline (curl: could not resolve host): the old weather stays"
keeps '' 6
case_ "a timeout (curl 28, after --max-time 8)"
keeps '' 28
case_ "an HTTP error (503, curl -f: 22)"
keeps '' 22
case_ "wttr.in: unknown location"
keeps 'Unknown location; please try ~25.35,55.40'
case_ "wttr.in out of queries: its notice and a whole report of another city (degrees in it)"
keeps "$(printf '%s\n' 'Sorry, we are running out of queries to the weather service at the moment.' \
  'Here is the weather report for the default city (just to show you what it looks like).' \
  'We will get new queries as soon as possible.' '' 'Weather report: Oymyakon' '' \
  '      \   /     Clear' '       .-.      -46(-53) °C' '    ― (   ) ―   ↓ 7 km/h')"
case_ "an HTML page (a captive portal, a proxy's error) with a degree sign in it"
keeps '<!DOCTYPE html><html><head><title>Hotel Wi-Fi</title></head><body>Welcome! Today 31°C</body></html>'
case_ "garbage: a very long line, binary, an empty answer"
keeps "+31°C  $(printf 'Clear%.0s' {1..60})"
keeps $'\x89PNG\r\n\x1a\n°'
keeps ''

case_ "good answers: below zero, zero, spaces at the end, a comma in the sky"
for a in '-5°C  Light snow:-5°C  Light snow' '+0°C  Freezing fog:0°C  Freezing fog' \
         '+31°C  Partly cloudy :31°C  Partly cloudy' '+18°C  Light rain, mist:18°C  Light rain, mist' \
         '+104°F  Sunny:104°F  Sunny'; do
  setup; answer "${a%%:*}"; sky >/dev/null; fetched
  eq "$(CACHE)" "Sharjah  ${a#*:}" "[${a%%:*}]"
done

# ── the sky ──────────────────────────────────────────────────────────────────
case_ "the icon is the sky's (wttr.in's words), the sun by day, the moon by night"
for c in 'Thundery outbreaks in nearby:STORM' 'Patchy light rain with thunder:STORM' 'Light sleet:SNOW' \
         'Moderate or heavy snow showers:SNOW' 'Blizzard:SNOW' 'Ice pellets:SNOW' 'Patchy rain nearby:RAIN' \
         'Light drizzle:RAIN' 'Light freezing rain:RAIN' 'Mist:FOG' 'Freezing fog:FOG' 'Haze:FOG' \
         'Dust:FOG' 'Sand:FOG' 'Partly cloudy:CLOUD' 'Overcast:CLOUD' 'Sunny:SUN' 'Clear:SUN'; do
  setup; echo "Sharjah  20°C  ${c%%:*}" >"$HOME/.cache/kawa-weather"
  v=ICON_${c#*:}; eq "$(sky)" "${!v}  Sharjah  20°C  ${c%%:*}" "${c%%:*}"
done
case_ "night: 18:00 to 05:59 the moon, 06:00 to 17:59 the sun"
setup; echo 'Sharjah  20°C  Clear' >"$HOME/.cache/kawa-weather"
for h in 0:MOON 5:MOON 6:SUN 17:SUN 18:MOON 23:MOON; do
  v=ICON_${h#*:}; eq "$(at "${h%:*}" kawa-weather)" "${!v}  Sharjah  20°C  Clear" "at ${h%:*}:00"
done
case_ "the city's own name never picks the icon (Nice, Snowdon, Rainbow Lake)"
setup; sed -i 's/^WEATHER_CITY=.*/WEATHER_CITY="Snowdon"/' "$HOME/.config/fedokawaii/env"
echo 'Snowdon  20°C  Clear' >"$HOME/.cache/kawa-weather"
eq "$(sky)" "$ICON_SUN  Snowdon  20°C  Clear"
case_ "Turkish locale: 'Ice pellets' is still snow (Turkish lowercases I to ı)"
setup; echo 'Sharjah  -2°C  Ice pellets' >"$HOME/.cache/kawa-weather"
if locale_ok tr_TR.UTF-8; then eq "$(LC_ALL=tr_TR.UTF-8 sky)" "$ICON_SNOW  Sharjah  -2°C  Ice pellets"
else skip "no tr_TR here"; fi

# ── city names ───────────────────────────────────────────────────────────────
city() { sed -i "s/^WEATHER_CITY=.*/WEATHER_CITY=\"$1\"/" "$HOME/.config/fedokawaii/env"; }
case_ "a city with spaces, an apostrophe, an accent, Arabic: sent URL-encoded, shown as written"
for c in "New York:New%20York" "St. John's:St.%20John%27s" "Saint-Étienne:Saint-%C3%89tienne" \
         "الشارقة:%D8%A7%D9%84%D8%B4%D8%A7%D8%B1%D9%82%D8%A9"; do
  setup; city "${c%%:*}"; reset_calls
  eq "$(sky)" "$ICON_SUN  ${c%%:*}"; fetched
  called "https://wttr.in/${c#*:}\\?format"
  eq "$(CACHE)" "${c%%:*}  31°C  Clear"; eq "$(sky)" "$ICON_SUN  ${c%%:*}  31°C  Clear"
done

# ── environment, misuse ──────────────────────────────────────────────────────
case_ "no env file (or one from before WEATHER_CITY): nothing to show, could not (1), no fetch"
setup; rm "$HOME/.config/fedokawaii/env"
out=$(kawa-weather 2>&1); r=$?
eq "$out" ""; eq "$r" 1; /bin/sleep 0.2; not_called curl
case_ "HOME with a space in it"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
eq "$(sky)" "$ICON_SUN  Sharjah"; fetched; eq "$(sky)" "$ICON_SUN  Sharjah  31°C  Clear"
case_ "no cache folder yet (~/.cache missing): created by nobody — the fetch still works"
setup; rm -rf "$HOME/.cache"
sky >/dev/null; fetched; eq "$(CACHE)" "Sharjah  31°C  Clear"
case_ "a slow network (curl takes 3 s): the title still comes at once"
setup; stub curl '/bin/sleep 3; echo "+31°C  Clear"; : >"$TMP/curl.done"'
s=$EPOCHREALTIME; sky >/dev/null; t=$(( ${EPOCHREALTIME/./} - ${s/./} ))
((t < 1000000)) && _ok || _no "took $t µs"
fetched; eq "$(CACHE)" "Sharjah  31°C  Clear" "… and the weather once it came"
case_ "--help (0); an argument (2)"
setup
out=$(kawa-weather --help); r=$?; eq "$r" 0; has "$out" "kawa-weather"
rc 2 kawa-weather Tokyo
/bin/sleep 0.2; not_called curl

case_ "wttr.in's longest conditions (43 letters) are weather too: stored, not refused as garbage"
for c in 'Moderate or heavy rain in area with thunder' 'Moderate or heavy snow in area with thunder'; do
  setup; answer "+24°C  $c"; sky >/dev/null; fetched
  eq "$(CACHE)" "Sharjah  24°C  $c" "$c"
done

done_
