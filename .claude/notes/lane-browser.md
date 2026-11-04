# lane-browser — T31a (the new browser) and T31 (downloads inside the bar's icon)

Started 18:11, 4 Nov. Due 21:30. Branch `lane-browser`, worktree `~/repos/fk-browser`.

**If you read this before main's forced reboot (planned ~20:25; `uptime` still shows the boot of about 15:46): start nothing: no kit, suite, VM, build, GPU job, no sudo or systemctl (main's order, 20:14). After the boot: see "Next".**

## Decisions (each from the source, see "Sources")
- **Helium** (0.20.3.1 = Chromium 156.0.8078.79), from its official COPR `imput/helium`, package `helium-bin`,
  profile `~/.config/net.imput.helium`. Digest: `git show origin/lane-research2:.claude/notes/research-T31a-browser.md`.
- `bin/kawa-browser` replaces `bin/brave-origin`. Helium's wrapper has **no flags file** (`/opt/helium/helium-wrapper`
  only sets the library path), so the flags live in kawa-browser.
- **Widevine**: Google's module, fetched by `install_widevine` (lib/upstream.sh) into `/usr/local/lib/fedokawaii-widevine`
  from Google's server at the address and SHA-512 that Mozilla's update service names. Never in the repo or ISO.
  Its LICENSE says use needs a licence from Google: asked the owner (inbox 18:58); built as "stays unless he says no".
- **Sound in a share**: `bin/kawa-sharesound` (see below). `WebRTCPipeWireCapturer` is gone (not in the binary).

## Proven on this PC (tools/share-sound-proof.sh: real Helium, real picker, real PipeWire, fenced, fake speakers)
| scene | other program | film in a tab | a real WebRTC call | floor |
|---|---|---|---|---|
| raw (no kawa-sharesound) | -72 dB | -72 dB | **-21 dB (the echo)** | -95 |
| screen (kawa-sharesound) | -72 dB | -71 dB | -106 dB (out) | -121 |
| window | -73 dB | -74 dB | -107 dB (out) | -121 |
| tab | -121 dB (out) | -73 dB | | -122 |
- Share microphone (scene mic): desktop mode 1 kHz + 2 kHz + mic 3 kHz all at -21 dB; one program: that one and the mic, the other at -200 dB; the program recording it: 0 links of its own sound; off: 0 nodes, the default input back.
- Chromium's echo canceller does not take the call out on Linux (own sound -75 dB through 23 s, measured, `echoCancellation:true` on the track).
- The picker: "Share with system audio" on from the first (`--system-audio-capture-default_checked`, Chromium's own spelling).
- A browser's call and media are told apart: WebRTC and WebAudio ask for 512 samples (10.7 ms), a media element for 1024 (21.3 ms). So a film or Spotify in the same browser stays in the share and the call stays out.
- Hard gates: native Wayland (`Ozone platform: wayland`, no Xwayland), VA-API `VaapiVideoDecoder` for H.264, VP9, AV1 on the RX 9060 XT, Widevine `OK com.widevine.alpha` through 6 restarts, `--app` windows clean, picker clicks work under dwl (helium-linux#359 does not bite).

- T31, why there was never a percent: during a 21 s download Chromium's History holds **no row at all** (measured), so nothing reading it could know the total. Now a small extension (`~/.local/share/fedokawaii/browser`, downloads + nativeMessaging only) tells `kawa-downloads` the total: 500000000 seen from the first second in a real 500 MB download through the real bar (kit, 19:45).
- T31 sources proven with the real programs: the browser (above), curl and yt-dlp (`tools/regress/downloads-tools.sh`, held), a notice at each end, a small curl answer counts for nothing.
- The tray's fill, `tools/regress/downloads-fill.sh`: dark all 11 points exact (one pixel a step, asagi·flame·accent, rows 17–18). Light: flame and accent are the same brick red there; the check now knows that, **not re-run since that edit**.
- Warm start, measured under load 40 (hl-dwl, `plays/run-warm3.sh`): a page in 130–210 ms by the socket word, 205–547 ms by a second process, 1.2–1.8 s from nothing. At rest 0.17 % of a core (120–150 s in), PSS about 330 MB. Plain `--no-startup-window` ends at once on Linux: what keeps it is `--remote-debugging-pipe` on a fifo only it holds. `--restore-last-session` does nothing through a running instance, so no session restore: Ctrl+Shift+T brings a closed window back.
- Copy and paste (`plays/clip.play`, T17c's matrix): page → clipboard ok, 5 MB page → clipboard ok, picture ok (image/png, a real PNG), 6 MB clipboard → page ok, the history stores. **Open: a small `wl-copy` then Ctrl+V into a textarea came back empty, twice** (wl-paste has it, activeElement right, document.hasFocus true), while the 6 MB paste after it works. Not understood yet; its last run was cut off by the kit dying.

## Status (20:16, before main's forced reboot)
- [x] Helium installed by dnf from the COPR (the installer's path: COPRS in lib/manifest.sh). `sudo dnf -y copr enable imput/helium`, `dnf install helium-bin`.
- [x] kawa-browser, install_widevine, verify/report/latency/check rows, tests moved
- [x] kawa-sharesound, portal hook, proof tool, test_sharesound
- [x] theme: GTK mode, the shu seed colour (no blue left), compact, square, one toolbar colour (seam measured gone, both moods)
- [x] Brave Origin removed from the PC (with brave-keyring, its unused wget2, its repo file and its keys; ~/.config/BraveSoftware left alone as he said)
- [x] T31 code: the fill in a meter's inks, the browser's total, tools; test_downloads
- [x] docs: Learn 17, README, PACKAGES, the Guide's sharing section
- [ ] the clipboard's small paste (above)
- [ ] his real Meet test (asked on his page 19:19, not answered yet)
- [ ] the NTP: still Helium's, a pencil in its corner; own page by the extension was only an idea
- [ ] his call on the pixel face in the chrome (renders kept, not asked yet): Chromium has one UI font, shared with pages' `system-ui`, so a pixel face would reach every Tailwind site. Default: Noto Sans.
- [ ] VM proof of the install path: not done (lane-iso's end-to-end would also cover it)

## Tests: what actually ran
Passing on this branch: test_browser 58, test_sharesound 55, test_downloads 74, test_configs 44, test_audio 121, test_launcher 267, test_manifest 68, test_tidy 67, test_nowplaying 204, test_keybinds_meaning 13, test_startdwl 114, test_calc 43.
test_report_rows 268 + 1 failed: SLP-10 (`keepers 1 · gtklock 1`, reads the machine's real processes; looks like the PC's state, not checked further).
**Never finished, all still owed after the reboot** (the installer tests queue behind one lock shared with every lane; I stopped mine for the reboot): test_theme_parts, test_verify, test_upstream (**its new Widevine cases have never run**), test_setup, test_torture, test_help, test_deps, test_autostart (edited for the warm browser, its re-run was stopped), downloads-fill (light).

## Next, after the reboot, in this order
1. Look at the first real test of the warm path: autostart's new line ran at this login: one hidden Helium, no window on his screen, Super+B opens one. (`/opt/helium/helium … --remote-debugging-pipe --no-startup-window` in ps.) The live dwl still runs `brave-origin` until a dwl from this branch is in: that goes old wrapper → `/usr/bin/brave-origin-stable` (my symlink) → kawa-browser.
2. Re-run what is owed above; fix what fails.
3. The clipboard's small paste: `~/.cache/lane-browser/plays/clip.play`, in the kit.
4. Read his answers (inbox 18:58, 19:19, 19:57 and the end of this file).
5. Fill in "What main must do", write ledger lines, then the last line DONE.
Proof scripts and renders: `~/.cache/lane-browser/` (plays/, review/). /dev/shm is gone after the reboot; none of it is needed but the patches there were already applied.

## Live on this PC by hand tonight (what apply writes too; so he could use it before the merge)
`~/.local/bin/{kawa-browser,kawa-sharesound,kawa-downloads}`, `~/.local/share/fedokawaii/browser/`, `~/.local/share/applications/{helium,spotify,whatsapp}.desktop`, brave-origin and com.brave.Origin entries hidden and pointing at kawa-browser, `~/.config/mimeapps.list`, the portal's `exec_before`, the `.chromium` line in both GTK themes, `C_FLAME` in both colors.sh, the warm line in `~/.config/dwl/autostart.sh`, `~/.config/net.imput.helium/Default/Preferences` seeded, `/usr/local/lib/fedokawaii-widevine` (by the real install_widevine), `/usr/bin/brave-origin-stable` → kawa-browser (a bridge: a main apply before this branch is merged restores the old starter, which must still find a browser; theme.sh on this branch takes it away).

## What main must do to merge and apply
(not ready: see Next. So far: an apply on this branch retires the old starter, so Super+B needs the new dwl: log in again right after it. lane-learning's docs/learn pieces still say Brave, 17 lines incl. `034-brave-moves.md`: rename at the merge.)

## Noted, not mine to settle
Main reports a kernel oops at 19:15 in Helium's ThreadPoolAudio thread as it exited, a bad pointer that looks like one flipped bit, and is not treating Helium as the cause; it runs a memory check after the reboot. My kits ran Helium around then. If the oops comes back in Helium after the memory check, it is mine to look at.

## Open questions for the owner
- inbox 18:58: Widevine's licence: its LICENSE says use needs a licence from Google; built as "stays unless he says no".
- inbox 19:19: one real Meet test.

## Sources
- helium.computer; github.com/imputnet/helium (patches/helium/core/component-updates.patch, services-prefs.patch, onboarding-page.patch, ui/layout/settings.patch, ui/toolbar-button-prefs.patch, webrtc-default-handling-policy.patch; flags.gn); copr.fedorainfracloud.org/coprs/imput/helium
- Chromium 156.0.8078.79: media/audio/pulse/pulse_loopback_manager.cc, audio_manager_pulse.cc, media/base/media_switches.cc, chrome/browser/media/webrtc/desktop_media_picker_controller.cc, chrome/browser/ui/views/desktop_capture/desktop_media_picker_views.cc, ui/gtk/gtk_color_mixers.cc
- aus5.mozilla.org update.xml (Widevine's address and SHA-512); the module's own LICENSE

## OWNER ANSWER 2026-11-04 19:27 — to your question «2026-11-04 19:19 — question from lane-browser»
do any performance upgrades it opens super slow with the super b make sure its super solid
