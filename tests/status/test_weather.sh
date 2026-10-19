#!/usr/bin/env bash
# tests/status/test_weather.sh — kawa-weather: one Open-Meteo forecast for NIGHT_LIGHT's place
# (25.35:55.40), named WEATHER_CITY (Sharjah), kept in ~/.cache/kawa-weather.json and fetched
# again in the background once 30 minutes old; the bar's module, the one line, and the week's
# dropdown. curl is a stub answering fixtures/open-meteo.json (a forecast in Open-Meteo's
# shape, its dates moved to start on the place's today), or what a case needs (an error,
# garbage, offline, a timeout), and notes when it is done. The menu is fake_menu.
. "$(dirname "$0")/lib.sh"
CACHE=""
setup() {
  box; . "$HOME/.config/fedokawaii/icons.sh"
  CACHE=$HOME/.cache/kawa-weather.json
  forecast
  export MENU=$TMP/menu; mkdir -p "$MENU"
  stub kawa-menu 'exec bash '"$SD"'/fake_menu "$@"'
}
# forecast [JQ] — the fixture as curl will answer it, changed by JQ; the days start on the
# place's own today (Asia/Dubai, UTC+4), whatever this machine's clock zone
TODAY=""
forecast() {
  TODAY=$(date -u -d "@$((EPOCHSECONDS + 14400))" +%F)
  jq -c --arg t "$TODAY" '.daily.time = [range(7) as $i | ($t | strptime("%Y-%m-%d") | mktime) + $i * 86400
                          | strftime("%Y-%m-%d")] | '"${1:-.}" "$SD/fixtures/open-meteo.json" >"$TMP/answer"
  answer_file 0
}
# answer TEXT [STATUS] — curl prints TEXT instead, and exits STATUS
answer() { printf '%s\n' "$1" >"$TMP/answer"; answer_file "${2:-0}"; }
answer_file() { stub curl 'cat "$TMP/answer"; r='"$1"'; : >"$TMP/curl.done"; exit $r'; }
# fetched — wait for the background fetch's curl, then a moment for its write
fetched() { waitfor 5 test -e "$TMP/curl.done" || { _no "no fetch was started"; return 1; }; /bin/sleep 0.3; rm -f "$TMP/curl.done"; }
cached() { setup; kawa-weather >/dev/null; fetched; }      # a fresh, good cache
bar() { kawa-weather --bar; }
tip() { jq -r .tooltip <<<"$1"; }
# rows N — what menu opening N showed (fake_menu), args N — its arguments
rows() { cat "$MENU/rows.${1:-1}"; }
args() { tr '\n' ' ' <"$MENU/args.${1:-1}"; }
opened() { cat "$MENU/n" 2>/dev/null || echo 0; }
answers() { printf '%s\n' "$@" >"$MENU/answers"; }
row() { sed -n "$(($1 + 1))p" "$MENU/rows.1"; }             # row I of the first opening
URL='https://api.open-meteo.com/v1/forecast\?latitude=25.35&longitude=55.40&current=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_mean,apparent_temperature_mean&timezone=auto&forecast_days=7'

# ── first run, the cache ─────────────────────────────────────────────────────
case_ "first run (no cache): the city at once, never waiting for the network; the forecast fetched behind"
setup
eq "$(kawa-weather)" "Sharjah"
eq "$(bar)" '{"text":""}' "the bar: no module until the weather is known"
fetched
called "^curl -fsS --proto =https --max-time 8 $URL$"
eq "$(jq -r .place "$CACHE")" "25.35:55.40" "kept with the place it is for"
eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear" "now: 33.4° rounded, code 0 by day"
case_ "fresh cache (under 30 minutes): shown, no fetch"
reset_calls; kawa-weather >/dev/null; bar >/dev/null; /bin/sleep 0.3; not_called curl
case_ "stale cache (over 30 minutes): shown as it is, and fetched again behind"
touch -d '-31 minutes' "$CACHE"; forecast '.current.temperature_2m = 29.6'
eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear"
fetched; eq "$(kawa-weather)" "$ICON_SUN  Sharjah  30°  clear" "the new one once it came"
case_ "the cache of another place (NIGHT_LIGHT changed): never shown, fetched for the new one"
cached; sed -i 's/^NIGHT_LIGHT=.*/NIGHT_LIGHT="35.68:139.69"/' "$HOME/.config/fedokawaii/env"
eq "$(kawa-weather)" "Sharjah"; eq "$(bar)" '{"text":""}'
fetched; called 'latitude=35.68&longitude=139.69&'
eq "$(jq -r .place "$CACHE")" "35.68:139.69"
case_ "a corrupt or cut-short cache: not shown, fetched again"
for junk in '' '{' 'null' '[]' '<html><body>502 Bad Gateway' $'\x01\x02\xff\xfe' \
            '{"place":"25.35:55.40"}' '{"place":"25.35:55.40","current":{"temperature_2m":"hot"}}'; do
  setup; printf '%s\n' "$junk" >"$CACHE"
  eq "$(kawa-weather)" "Sharjah" "cache [$junk]"
  fetched; eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear" "fetched again after [$junk]"
done

# ── what Open-Meteo, or the network, may answer ──────────────────────────────
keeps() {   # keeps WHY ANSWER [STATUS] — a good cache survives this answer; WHY is kept as the reason
  cached; touch -d '-40 minutes' "$CACHE"; answer "$2" "${3:-0}"
  kawa-weather >/dev/null; fetched
  eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear" "after [${2:0:60}] (curl status ${3:-0})"
  eq "$(cat "$HOME/.cache/kawa-weather.failed" 2>/dev/null)" "$1" "the reason"
  fetched                                       # (still stale: fetched again — let it finish)
}
case_ "offline (curl: could not resolve host, could not connect, a timeout): the forecast stays; offline noted"
keeps offline '' 6; keeps offline '' 7; keeps offline '' 28
case_ "an HTTP error (a 503, a 429; curl -f: 22): Open-Meteo's own"
keeps "Open-Meteo down" '' 22
case_ "an answer that is no forecast (a hotel Wi-Fi's login page, cut short, arrays out of step): no way out — offline"
keeps offline '{"error":true,"reason":"Latitude must be in range of -90 to 90°. Given: 125.35."}'
keeps offline '<!DOCTYPE html><html><head><title>Hotel Wi-Fi</title></head><body>Welcome!</body></html>'
keeps offline "$(head -c 300 "$SD/fixtures/open-meteo.json")"
keeps offline "$(jq -c '.daily.temperature_2m_mean |= .[:5]' "$SD/fixtures/open-meteo.json")"
keeps offline "$(jq -c '.daily.time[2] = "Wednesday"' "$SD/fixtures/open-meteo.json")"
keeps offline "$(jq -c '.current.is_day = "yes"' "$SD/fixtures/open-meteo.json")"
case_ "a good answer after a failed one: the reason goes"
setup; echo offline >"$HOME/.cache/kawa-weather.failed"
kawa-weather >/dev/null; fetched
[[ -e $HOME/.cache/kawa-weather.failed ]] && _no "the reason stayed" || _ok

# ── the bar ──────────────────────────────────────────────────────────────────
case_ "the bar: the sky's icon and the temperature now; the city and the sky in words as its tooltip"
cached; j=$(bar); json_lines "$j"
eq "$j" "$(jq -cn --arg t "$ICON_SUN 33°" '{text: $t, tooltip: "Sharjah · clear", class: "sky"}')"
case_ "the bar over an hour old (offline): its age in the tooltip, and a class to show it by"
touch -d '-3 hours' "$CACHE"; answer '' 6
j=$(bar); eq "$(tip "$j")" "Sharjah · clear · 3 h old"; eq "$(jq -c .class <<<"$j")" '["sky","stale"]'
fetched; eq "$(tip "$(bar)")" "Sharjah · clear · offline · 3 h old" "and why, once the fetch failed"
fetched
case_ "whole degrees, rounded half up: 29.5 → 30, -0.4 → 0 (never -0), -5.5 → -5, -5.6 → -6"
for t in 29.5:30 29.4:29 -0.4:0 -0.5:0 -5.5:-5 -5.6:-6 0:0; do
  setup; forecast ".current.temperature_2m = ${t%:*}"; kawa-weather >/dev/null; fetched
  eq "$(text_of "$(bar)")" "$ICON_SUN ${t#*:}°" "${t%:*}"
done
case_ "the sky: every WMO code Open-Meteo sends, its icon and words; the moon for a clear night"
setup; kawa-weather >/dev/null; fetched
for c in 0:1:SUN:clear 1:1:SUN:'mostly clear' 0:0:MOON:clear 1:0:MOON:'mostly clear' 2:0:CLOUD:'partly cloudy' \
         3:1:CLOUD:overcast 45:1:FOG:fog 48:1:FOG:'rime fog' 51:1:RAIN:'light drizzle' 53:1:RAIN:drizzle \
         55:1:RAIN:'heavy drizzle' 56:1:RAIN:'freezing drizzle' 57:1:RAIN:'freezing drizzle' 61:1:RAIN:'light rain' \
         63:1:RAIN:rain 65:1:RAIN:'heavy rain' 66:1:RAIN:'freezing rain' 67:1:RAIN:'freezing rain' \
         71:1:SNOW:'light snow' 73:1:SNOW:snow 75:1:SNOW:'heavy snow' 77:1:SNOW:'snow grains' \
         80:1:RAIN:'light showers' 81:1:RAIN:showers 82:1:RAIN:'heavy showers' 85:1:SNOW:'snow showers' \
         86:1:SNOW:'snow showers' 95:1:STORM:thunderstorm 96:1:STORM:'thunderstorm, hail' 99:1:STORM:'thunderstorm, hail'; do
  IFS=: read -r code day ic words <<<"$c"
  jq -c --argjson c "$code" --argjson d "$day" '.current.weather_code = $c | .current.is_day = $d' "$CACHE" >"$CACHE.x" && mv "$CACHE.x" "$CACHE"
  v=ICON_$ic; eq "$(kawa-weather)" "${!v}  Sharjah  33°  $words" "code $code, is_day $day"
done
case_ "a code that is no WMO code: no icon is made up — the module waits for a forecast it can draw"
jq -c '.current.weather_code = 42' "$CACHE" >"$CACHE.x" && mv "$CACHE.x" "$CACHE"
eq "$(bar)" '{"text":""}'; eq "$(kawa-weather)" "Sharjah"

# ── the menu ─────────────────────────────────────────────────────────────────
# kawa-menu's lines: TAB-separated parts, laid out by it — "part KANJI NAME", "row GLYPH NAME
# DETAIL VALUE", "off GLYPH NAME" (faint, not a choice)
T=$'\t'
wd() { LC_ALL=C date -u -d "$TODAY +$1 day" '+%a %-d'; }
case_ "the menu: a dropdown under the bar — the heading (天, the city), then today and the six days after it"
cached; answers esc
rc 0 kawa-weather --menu
eq "$(opened)" 1
eq "$(args)" "--drop --index --select 1 --title  " "under the bar, today first for the keys, no title while fresh"
eq "$(row 0)" "part${T}天${T}Sharjah" "the heading: the seal, the city"
eq "$(grep -c . <<<"$(rows)")" 8
eq "$(row 1)" "row${T}$ICON_SUN${T}$(wd 0)${T}scorching${T}31°" "today: clear, feels 38.4 → scorching, a mean of 31.2"
eq "$(row 2)" "row${T}$ICON_SUN${T}$(wd 1)${T}hot${T}31°" "mostly clear, 36.2 → hot, 30.8"
eq "$(row 3)" "row${T}$ICON_CLOUD${T}$(wd 2)${T}hot${T}30°" "partly cloudy, 33.0 → hot"
eq "$(row 4)" "row${T}$ICON_CLOUD${T}$(wd 3)${T}warm${T}29°" "overcast, 30.9 → warm"
eq "$(row 5)" "row${T}$ICON_FOG${T}$(wd 4)${T}warm${T}29°" "fog, 28.7 → warm, 28.6 → 29"
eq "$(row 6)" "row${T}$ICON_RAIN${T}$(wd 5)${T}mild${T}26°" "light rain, 25.1 → mild"
eq "$(row 7)" "row${T}$ICON_STORM${T}$(wd 6)${T}warm${T}28°" "thunderstorm, 27.9 → warm"
case_ "no padding of its own: every field plain, the layout kawa-menu's"
lacks "$(rows)" "  "; lacks "$(rows)" "–"
case_ "a day chosen (Enter, a click): the menu closes, nothing else happens"
cached; reset_calls; answers 3
rc 0 kawa-weather --menu; eq "$(opened)" 1
eq "$(grep -v '^kawa-menu ' "$CALLS")" "" "nothing but the menu was run"
case_ "the heading chosen: the menu again (as every menu)"
cached; answers 0 esc
rc 0 kawa-weather --menu; eq "$(opened)" 2; has "$(args 2)" "--select 1 "
case_ "Esc, a click outside, the bar's click again: closed"
cached; answers esc; rc 0 kawa-weather --menu; eq "$(opened)" 1

case_ "how a day feels: one scale, its bounds (the mean apparent temperature, whole degrees)"
for f in -20:freezing 3.4:freezing 3.5:cold 13:cold 13.6:cool 19:cool 20:mild 25.4:mild 26:warm 31:warm \
         32:hot 37.4:hot 37.5:scorching 52:scorching; do
  setup; forecast ".daily.apparent_temperature_mean[0] = ${f%:*}"; kawa-weather >/dev/null; fetched
  answers esc; kawa-weather --menu
  eq "$(cut -f4 <<<"$(row 1)")" "${f#*:}" "feels ${f%:*}"
done
case_ "the mean, not the feel, is the value: -5.6 → -6°, 105 → 105°"
setup; forecast '.daily.temperature_2m_mean[0] = -5.6 | .daily.temperature_2m_mean[1] = 105'; kawa-weather >/dev/null; fetched
answers esc; kawa-weather --menu
eq "$(cut -f5 <<<"$(row 1)")" "-6°"; eq "$(cut -f5 <<<"$(row 2)")" "105°"

case_ "a cache from yesterday (offline since): today first, the day gone left out — and its age said"
setup; forecast '.daily.time |= map(strptime("%Y-%m-%d") | mktime - 86400 | strftime("%Y-%m-%d"))'
kawa-weather >/dev/null; fetched; touch -d '-26 hours' "$CACHE"; echo offline >"$HOME/.cache/kawa-weather.failed"
answer '' 6; answers esc; kawa-weather --menu
has "$(args)" "--select 1 --title offline · 1 day old " "said plainly, in the quiet line above the heading"
eq "$(row 0)" "part${T}天${T}Sharjah"; eq "$(grep -c . <<<"$(rows)")" 7 "the heading and six days"
eq "$(cut -f3-4 <<<"$(row 1)")" "$(wd 0)${T}hot" "today first: yesterday's second day"
fetched
case_ "over an hour old, the last fetch not failed (still on its way): only its age"
cached; touch -d '-3 hours' "$CACHE"; answers esc
stub curl '/bin/sleep 1; : >"$TMP/curl.done"; exit 6'
kawa-weather --menu; has "$(args)" "--title 3 h old "
fetched
case_ "nothing cached, offline: the heading and one faint row of why, nothing to choose, no days made up"
setup; echo offline >"$HOME/.cache/kawa-weather.failed"; answer '' 6; answers esc
kawa-weather --menu
eq "$(rows)" "part${T}天${T}Sharjah"$'\n'"off${T}$ICON_OFFLINE${T}offline"
eq "$(args)" "--drop --index --title  " "no cursor to place"
fetched
case_ "nothing cached, Open-Meteo down: that, said"
setup; echo "Open-Meteo down" >"$HOME/.cache/kawa-weather.failed"; answer '' 22; answers esc
kawa-weather --menu; eq "$(row 1)" "off${T}$ICON_OFFLINE${T}Open-Meteo down"
fetched
case_ "nothing cached, the first fetch still going: said so"
setup; stub curl '/bin/sleep 1; cat "$TMP/answer"; : >"$TMP/curl.done"'; answers esc
kawa-weather --menu; eq "$(row 1)" "off${T}$ICON_HOURGLASS${T}the forecast is coming"
fetched
case_ "a day Open-Meteo has no numbers for yet, or no WMO code: left out, never guessed"
setup; forecast '.daily.temperature_2m_mean[6] = null | .daily.weather_code[5] = 42'; kawa-weather >/dev/null; fetched
answers esc; kawa-weather --menu
eq "$(grep -c . <<<"$(rows)")" 6; lacks "$(rows)" "${T}$(wd 5)${T}"; lacks "$(rows)" "${T}$(wd 6)${T}"
case_ "the place's own today, whatever this machine's clock zone says (UTC−12 here)"
cached; answers esc; TZ=Etc/GMT+12 kawa-weather --menu
eq "$(cut -f3 <<<"$(row 1)")" "$(wd 0)"
case_ "English weekdays in any locale"
cached; answers esc
if locale_ok de_DE.UTF-8; then LC_ALL=de_DE.UTF-8 kawa-weather --menu; eq "$(cut -f3 <<<"$(row 1)")" "$(wd 0)"
else skip "no de_DE here"; fi

# ── city names ───────────────────────────────────────────────────────────────
city() { sed -i "s/^WEATHER_CITY=.*/WEATHER_CITY=\"$1\"/" "$HOME/.config/fedokawaii/env"; }
case_ "the city only names the place: a new name keeps the forecast (the place is NIGHT_LIGHT's)"
cached; city "St. John's"; reset_calls
eq "$(kawa-weather)" "$ICON_SUN  St. John's  33°  clear"; /bin/sleep 0.2; not_called curl
eq "$(tip "$(bar)")" "St. John's · clear"
case_ "a city with an accent, in Arabic: the heading as written (fedokawaii.conf's own spelling)"
for c in "Saint-Étienne" "الشارقة" "St. John's"; do
  cached; city "$c"; answers esc; kawa-weather --menu
  eq "$(row 0)" "part${T}天${T}$c" "$c"
done

# ── environment, misuse ──────────────────────────────────────────────────────
case_ "no env file (a broken install): said, could not (1), no fetch"
setup; rm "$HOME/.config/fedokawaii/env"
out=$(kawa-weather 2>&1); r=$?
has "$out" "fedokawaii/env"; eq "$r" 1; /bin/sleep 0.2; not_called curl
case_ "NIGHT_LIGHT not a latitude:longitude: said, could not (1); the bar shows nothing; no fetch"
setup; sed -i 's/^NIGHT_LIGHT=.*/NIGHT_LIGHT=""/' "$HOME/.config/fedokawaii/env"
out=$(kawa-weather 2>&1); r=$?; eq "$r" 1; has "$out" "NIGHT_LIGHT"
eq "$(bar 2>/dev/null)" '{"text":""}'; /bin/sleep 0.2; not_called curl
case_ "HOME with a space in it"
setup; mv "$HOME" "$TMP/my home"; export HOME="$TMP/my home"
eq "$(kawa-weather)" "Sharjah"; fetched; eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear"
case_ "no ~/.cache yet: made, and the forecast kept"
setup; rm -rf "$HOME/.cache"
kawa-weather >/dev/null; fetched; eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear"
case_ "XDG_CACHE_HOME elsewhere: the forecast kept there"
setup; export XDG_CACHE_HOME=$TMP/xc
kawa-weather >/dev/null; fetched; [[ -s $TMP/xc/kawa-weather.json ]] && _ok || _no "not in XDG_CACHE_HOME"
export XDG_CACHE_HOME=$HOME/.cache
case_ "a slow network (curl takes 3 s): the bar and the menu still come at once"
setup; stub curl '/bin/sleep 3; cat "$TMP/answer"; : >"$TMP/curl.done"'; answers esc
s=$EPOCHREALTIME; bar >/dev/null; kawa-weather --menu; t=$(( ${EPOCHREALTIME/./} - ${s/./} ))
((t < 1000000)) && _ok || _no "took $t µs"
fetched; eq "$(kawa-weather)" "$ICON_SUN  Sharjah  33°  clear" "… and the weather once it came"
case_ "the bar and the menu at the same moment: one fetch"
setup; stub curl '/bin/sleep 1; cat "$TMP/answer"; : >"$TMP/curl.done"'; answers esc
bar >/dev/null; kawa-weather --menu; kawa-weather >/dev/null
fetched; /bin/sleep 0.3; eq "$(grep -c '^curl ' "$CALLS")" 1
case_ "--help (0); an argument, the old --forecast (2)"
setup
out=$(kawa-weather --help); r=$?; eq "$r" 0; has "$out" "kawa-weather --menu"
rc 2 kawa-weather Tokyo; rc 2 kawa-weather --forecast; rc 2 kawa-weather --bar extra
/bin/sleep 0.2; not_called curl

done_
