# lane-browser — T31a (the new browser) and T31 (downloads inside the bar's icon)

Started 18:11, 4 Nov. Due 21:30. Branch `lane-browser`, worktree `~/repos/fk-browser`.

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

## Status
- [x] Helium installed by dnf from the COPR (the installer's path: COPRS in lib/manifest.sh)
- [x] kawa-browser, install_widevine, verify/report/latency/check rows, tests moved
- [x] kawa-sharesound, portal hook, proof tool, test_sharesound (55)
- [ ] theme: seed colour, compact layout: rendered both moods; the toolbar's seam
- [ ] live install, notice on his page, then Brave removed
- [ ] his real Meet test (question on his page)
- [ ] T31: the fill in the icon, Helium's source, CLI downloads, proofs
- [ ] docs (Learn 17, README, PACKAGES, guide), full test areas

## What main must do to merge and apply
(filled in at the end)

## Open questions for the owner
- inbox 18:58: Widevine's licence.

## Sources
- helium.computer; github.com/imputnet/helium (patches/helium/core/component-updates.patch, services-prefs.patch, onboarding-page.patch, ui/layout/settings.patch, ui/toolbar-button-prefs.patch, webrtc-default-handling-policy.patch; flags.gn); copr.fedorainfracloud.org/coprs/imput/helium
- Chromium 156.0.8078.79: media/audio/pulse/pulse_loopback_manager.cc, audio_manager_pulse.cc, media/base/media_switches.cc, chrome/browser/media/webrtc/desktop_media_picker_controller.cc, chrome/browser/ui/views/desktop_capture/desktop_media_picker_views.cc, ui/gtk/gtk_color_mixers.cc
- aus5.mozilla.org update.xml (Widevine's address and SHA-512); the module's own LICENSE
