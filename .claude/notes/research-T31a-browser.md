# T31a: the browser after Brave. Survey from official sources (lane-research2, 4 Nov 2026)

Paper only: nothing installed, nothing run, nothing on the owner's screen. Two packages were unpacked in
`/dev/shm` to read their files and strings (never executed), then deleted. Times are UTC. `lane-browser` builds on
this and runs the trial on this PC (section 5).

## 1. Verdict: one recommendation, one question

**Helium.** Of everything surveyed, it is the only one that is unusual by design, minimal, on Chromium stable, and
on a Fedora channel the update button can own (the official COPR, which `setup.sh`'s `copr:*` case already handles),
with an ad blocker inside and nothing to install. Its missing password manager costs him nothing (**0** saved logins,
measured), and the owner's decision of 18:09 (a fresh install, nothing migrated) removes the last reason to stay close
to Brave. `lane-browser` has taken it (f983fb6, `helium-bin` 0.20.3.1) and reports native Wayland, hardware video on
his card and a loading Widevine: its results, not repeated here.

**What it costs, plainly:** security updates about 1.3 days behind Chromium where Brave is 8 hours (section 3); a
"beta" label and 547 open issues and PRs; no Widevine of its own.

**The question for the owner, the only one: Widevine.** Spotify's web player needs it. The module can be fetched
from Google's server, but its licence says "You may not use, modify, sell, or otherwise distribute the Software
without a separate license agreement with Google". `lane-browser` has already asked him on his page, so **it must not
be asked twice**; section 4 has the facts behind the answer, including alternatives that question does not list.

**Fallbacks:** Vivaldi, whose own binary supports Widevine, if he refuses the fetch and still wants Spotify in a
browser, provided it runs natively on Wayland here, which its own volunteers have said is unsupported. Trivalent if both
fail: the fastest security updates of all, at the price of switching off much of what it stands for.

Everything else surveyed fails on a stated requirement (section 3).

## 2. What the desktop actually needs (read from the repo and his profile, not from taste)

| Need | Evidence | Gate in the trial |
|---|---|---|
| Widevine | `configs/home/.local/share/applications/spotify.desktop`: `--app=https://open.spotify.com`; `bin/brave-origin:50`: "Spotify's web player plays nothing without it" | EME answers, then Spotify plays once he has logged in himself |
| VA-API decode and encode | `bin/brave-origin:38` (`AcceleratedVideoEncoder`, `AcceleratedVideoDecodeLinuxGL`, `…ZeroCopyGL`) | `chrome://media-internals` names the decoder (not `Dav1d`/`Vpx`/`FFmpeg`) on both GPUs (T33 moves the desktop to the iGPU) |
| Screen share with sound, through the portal | same line: `PulseaudioLoopbackForScreenShare`; the wrapper's comments name Meet and Discord calls, and no Discord package is installed, so these calls run in the browser | a share in a call: `chrome://webrtc-internals` shows `ExternalEncoder` and sound arrives |
| The mic level left alone | `bin/brave-origin:39` `WebRtcAllowInputVolumeAdjustment` off | level unmoved during a call |
| Web apps | `spotify.desktop`, `whatsapp.desktop` use `--app=` | own window, own `app_id`, MPRIS reaches `bin/kawa-nowplaying` |
| Native Wayland at 144 Hz | the design rules; dwl frame log | `chrome://gpu` says Wayland; frame log clean |
| Downloads the bar can read | `bin/kawa-downloads` | `.crdownload` or its equivalent, T31's percent |
| An update path through the one button | `setup.sh:2833-2846` treats third-party repos separately | a signed dnf repo with `gpgcheck=1` |

**His profile today** (`~/.config/BraveSoftware/Brave-Origin`, read-only, counts only, 4 Nov):
one profile (`Default`), **0 saved logins** and 0 never-save entries (`Login Data`, opened read-only, row counts
only), **no `Bookmarks` file**, **no third-party extension** (only Brave's own and the PDF viewer), no flags, no
theme, 309 MB. So little was left to migrate, and the owner decided at 18:09 that nothing moves: a clean profile. His
ad blocking was Brave Shields, so the successor must block ads with nothing installed.

## 3. Candidates (each checked 4 Nov 2026)

| Browser | Today | Base | Upkeep | Fedora channel | Widevine | Verdict |
|---|---|---|---|---|---|---|
| **Helium** | 0.20.3.1 (30 Oct), "in beta" | Chromium stable, via ungoogled-chromium | 22k stars, very active, 547 open issues and PRs | official COPR `imput/helium`, `helium-bin`, F44 and F45 chroots | **no** (official); loadable, see section 4 | **Trial 1** |
| **Vivaldi** | 8.2.4133.96 (28 Oct); 8.3 at RC 3 | 152 ESR with backports (8.2); 156 ESR (8.3 RC) | company, stable channel, 5 minor updates in 15 days | official signed repo | yes per the binary's strings; proof in trial | **Trial 2** |
| Brave Origin | 1.98.63 (30 Oct) | Chromium 156 | company | official signed repo | yes | **Baseline** |
| **Trivalent** | 157.0.8103.38 (4 Nov) | Chromium stable | small team (2 main authors), very fast | signed repo, `repo_gpgcheck=1`; installation outside secureblue is "unsupported" | available, off by default | **Reserve**: see below |
| ungoogled-chromium | 156.0.8078.79 | Chromium stable | active volunteers | portable tarball; the Fedora packaging repo's last GitHub release is 2023 | manual copy | Out: plain Chromium look (his "not plain"), slowest of the live forks, no ad blocker |
| Thorium | M156 "beta" by a helper (11 Oct) | behind | **maintainer has no time**: a collaborator "temporarily took over" | none on GitHub for this release | yes | Out: maintenance |
| Cromite | v153 (15 Sep) | **four milestones behind** | Android first | tarball only; Linux auto-update still "working in progress" | not checked | Out: seven weeks of missed fixes |
| qutebrowser | 3.7.0 in Fedora | QtWebEngine 6.11: **Chromium 140**, security patches up to 155 | active | Fedora itself | "differ wildly between Qt versions" | Out, with regret: the most keyboard-first of all, but its changelog names a flicker workaround for "Qt 6.11.0, AMD graphics and Wayland" (his hardware) and a crash on Google Mail and Meet (he uses Meet); its FAQ describes only Greasemonkey scripts, no extension support; stability is his first word |
| Fedora Chromium | 156.0.8078.79 | Chromium stable | Fedora | Fedora | no | Out: he said not plain Chromium |
| Edge, Opera, Opera GX | | | | | | Not surveyed further: not "less common", against "private and minimal" |
| Dia, Aside, Ardia, Tabbit, Genspark | | | | | | No Linux build per flaviocopes.com's 2026 survey (secondary source, not re-verified per browser). The same source: Arc sunsets on 22 Dec 2026, ChatGPT Atlas retired |
| BrowserOS | active, AGPL | | | | | Out: an AI agent browser, not what he asked for |
| Iridium | 2026.08.151.2 (13 Aug) | Chromium 151, stable is 156 and 157 | privacy patches, reproducible | "only available as source code tarballs" | | Out: no binary to install, and behind |
| Slimjet | 51.0.2.0 (30 Oct) | not stated on its page | company | `.deb`; for Fedora a `tar.xz` whose wrapper needs admin once; no repo | not checked | Out: no channel the update button can own |
| Wavebox | | "built on Chromium", no version on its page | company | official RPM repository | not checked | Out: "the #1 browser for multi-client sign-in and workflows", a paid-for work tool, not a minimal one |
| Naver Whale | | Chromium | a Korean portal | **not verified**: whale.naver.com refused my fetch; secondary sources show only a `.deb` | not checked | Out: no Fedora channel found |
| Ulaa | | Chromium | Zoho | **not verified**: ulaa.com lists Linux but names no format and two download URLs returned 404; in an undated Zoho thread a Fedora user asks for an RPM | not checked | Dropped rather than guessed |

### Measured: delay behind Chromium stable on Linux

Chromium's first-served time is from Google's Version History API; forks are from their RPM metadata build times
or GitHub's release times. Worst case matters more than median for a browser.

| Channel | Updates | Median | Worst |
|---|---|---|---|
| Brave Origin (dnf repo) | 6 | 7.6 h | 12.0 h |
| Trivalent (dnf repo) | 7 | 6.7 h | 24.8 h |
| Helium (GitHub) | 25 | 24.8 h | 83.5 h |
| Helium (**COPR rpm: what he would get**) | 6 | 30.4 h | 48.6 h |
| ungoogled-chromium (portable) | 12 | 44.5 h | 132 h |
| Vivaldi 8.2 stable | see below | | |

Brave's mapping of package to Chromium version is inferred from dates, with one checked: its release "v1.98.63
(Chromium 156.0.8078.80)". Helium's and Trivalent's come from their own changelogs and tags.

Vivaldi is not comparable by this measure: it rides ESR and backports. Its build of 28 Oct 09:12 carries fixes from
156.0.8078.73 (blog, "Minor update (14)"), 12.8 h after Chromium. But as of 4 Nov 13:28 its repo's newest stable is
**still that build**, so whatever 156.0.8078.79 (29 Oct) fixed was at least 5.7 days late at that moment. This is one
observation just before its 8.3 release, not a measured habit.

**Plain conclusion:** moving from Brave to Helium is a real security step down: about 1.3 days typical against about
8 hours; the worst seen is 3.5 days on GitHub (25 updates), and the COPR comes later still, against 12 hours for Brave.
It is defensible on a desktop, and the owner should see it stated. For the update button it means the repo can lag;
the button should never block on it.

### Helium: what its source says

From `imputnet/helium` and `imputnet/helium-linux` at 0.20.3.1:
- **Built with** `use_vaapi=true`, `rtc_use_pipewire=true`, `proprietary_codecs=true`, `ffmpeg_branding="Chrome"`
  (`flags.linux.gn`). The binary contains the feature names the wrapper uses except `WebRTCPipeWireCapturer`, which
  is absent from Helium and Vivaldi and also from Brave 1.98.63 itself (`strings`: 0 hits; GitHub code search on
  Chromium: 0, though that index may be partial). Brave's binary holds `BaseCapturerPipeWire` as the capturer. **That
  flag is already dead today**, so drop it from the wrapper and prove sharing still goes through the portal.
- **Password manager** switched off by `core/disable-password-manager.patch`, a policy handler that forces
  `kCredentialsEnableService` and `kCredentialsEnablePasskeys` to false whatever the settings say. The site: "Helium
  does not include a built-in password manager." Cost to him today: none (0 saved logins). Later he would need an
  extension.
- **Widevine** "does not support", site's words; the maintainers on 4 Oct 2026: "widevine is not supported at the
  moment" (issue 2643); the request is open (issue 116). The reason they give is licensing cost.
- **uBlock Origin ships inside** as a component, a Helium fork (`core/ublock-*`), replacing Shields with nothing to
  install. Extensions are fetched through Helium's anonymising proxy (`core/proxy-extension-downloads.patch`).
- **Fits him**: the site lists four layouts, a Frameless mode, customisable toolbars and colour themes, vertical
  tabs, split view, MRU tab cycling, custom key bindings (`core/custom-keyboard-shortcuts.patch`).
- **Update**: "Helium updates automatically on macOS and Windows"; on Linux, the COPR, so the one button owns it.
- **Risks to test**: issue `helium-linux#359` (open) "Bubbles (extension install / permission prompts) don't receive
  clicks on niri (Wayland)": another non-GNOME, non-KDE compositor, so test dwl for this first; `#222`
  "UI becomes unstable under wayland (KDE)"; 25 Wayland-matching open issues in that repo; the label "beta".
- **Files**: 410 MB installed against Brave's 459 MB (repo metadata); `net.imput.helium` is its identifier. Its
  `.desktop` has no `StartupWMClass` line. Its RPM lives in `/opt/helium`.

### Vivaldi: what its package and pages say

- **Theming is unmatched** and this is the case for it: a theme editor, theme by OS or schedule, and a real UI CSS
  hook (`vivaldi://experiments` → "Allow for using CSS modifications", then Settings > Appearance > Custom UI
  Modifications: tip 9 on vivaldi.com, which frames it as community work, unsupported). The UI is HTML and JS in
  `/opt/vivaldi/resources/vivaldi` (54 MB, `bundle.js`, `main.html`), so our fonts, spacing and icons could reach
  every pixel of the chrome, which no other candidate allows. It is also the weight: the trial must measure RAM.
- **Wayland is its weak point.** Forum moderators and volunteers say native Wayland is unsupported and XWayland is
  the default (threads from 2023 to 2025, not official pages; nothing newer found). Chromium's own logic
  (`ui/linux/display_server_utils.cc`) would pick Wayland here, so test it, on 8.3 if it has shipped.
- **H.264 and AAC come from a side door**: the package ships a `libffmpeg.so`, and `/opt/vivaldi/update-ffmpeg` plus
  `/etc/cron.daily/vivaldi` fetch a replacement from an Electron release on GitHub (its own script's URL, read in the
  package). That runs outside the update button and must be brought under it if Vivaldi wins.
- **Files**: 476 MB installed (repo metadata). RPM signed (RSA/SHA512, key `1256c34716bd9233`).
  `StartupWMClass=vivaldi`.

### Trivalent: what its source says (the reserve, and why not higher)

From `secureblue/Trivalent` at `live` (spec, `build/install/`, patches, and its own FAQ page,
`patches/trivalent/ugc/trivalent-faq-page.patch`):
- **The best security record here**: median 6.7 h, level with Brave, and the only one already on Chromium 157 on
  4 Nov. RPMs are built for Fedora, with `rtc_link_pipewire=true`. Hardware video is on by default on x86_64
  (`linux/configure-gpu-features.patch` enables the encoder with VA-API; decode is on upstream; `use_vaapi=false`
  in the spec is for aarch64 only).
- **Its needs are reachable by configuration**: its FAQ says Spotify and Netflix DRM "is available in Trivalent,
  however it is disabled by default". Issue 369 (open) reports the CDM then needs a manual update in
  `chrome://components`.
- **The cost is its purpose.** Off by default, each to be turned back on by us: JavaScript JIT (FAQ: "disabled by
  default"; a per-site setting that its FAQ says does not reach iframes, an upstream bug), the HTTP disk cache
  (`kDiskCacheDir` is `/dev/null`), the GPU shader caches, the spare renderer, WebGL (`kDisable3DAPIs`), extensions.
  For someone whose rule is that performance and RAM are paramount, every one of those is a fight with the browser.
- **YouTube ads are not blocked**: its FAQ says the built-in filter "can't reliably intercept" them and points to
  uBlock Origin Lite, which needs the extensions toggle. Brave Shields handles this for him today (not re-measured).
- **The wrapper filters flags**: `build/install/trivalent.sh` drops every switch not on its allow-list unless
  `ALLOW_UNSAFE_FLAGS=true`, so `--enable-features` and `--password-store` from our wrapper would vanish silently;
  they belong in `/etc/trivalent/trivalent.conf.d/*.conf`. `--app` is allowed. It launches through `bwrap`.
- **Look**: stock Chromium (`linux/classic-theme-by-default.patch`), which runs into his "not plain".
- **Support**: "Official support is only provided via secureblue."

## 4. Widevine on Helium: how, and the licence

- Helium's source keeps the Widevine component registered (`core/component-updates.patch`: allow-list of CRLSet and
  WidevineCdm) and its binary has the string `latest-component-updated-widevine-cdm`, the hint file Chromium reads.
- Community report on issue 116 (Dec 2025, not official): writing
  `~/.config/net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm` as a JSON `Path` made it load, for both
  AppImage and tarball. A macOS report (issue 2643) says such files got deleted, so the trial restarts the browser
  several times and checks.
- **The CDM can be fetched.** Mozilla's update service answers
  `https://aus5.mozilla.org/update/3/GMP/144.0/20251001000000/Linux_x86_64-gcc3/en-US/release/Linux/default/default/update.xml`
  with `gmp-widevinecdm`: a URL on Google's own `edgedl.me.gvt1.com/.../chrome_component/` with a sha512, version
  **4.10.3112.0**, the same version Brave holds today (21 MB). `lane-browser` built that (`lib/upstream.sh`: host and
  SHA-512 checked, kept out of the repo and the ISO). If the service changes, Spotify stops, so verify should test EME
  and say so plainly.

**The licence, read in full from Brave's copy (`WidevineCdm/4.10.3112.0/LICENSE`, 473 bytes):** "Google LLC and its
affiliates ("Google") own all legal right, title and interest in and to the content decryption module software
("Software") and related documentation, including any intellectual property rights in the Software. You may not use,
modify, sell, or otherwise distribute the Software without a separate license agreement with Google. The Software is
not open source software." **Correction:** an earlier version of this digest called the fetch "this user's own act", as
if that eased it. The sentence makes no such exception, and the file coming from Google's own server does not change
it. This is my reading, not legal advice, and it is why the choice is his.

**The ways to have Spotify, checked:**

| Way | Facts | Cost |
|---|---|---|
| Fetch the CDM for this PC (as built) | above | The licence sentence |
| Spotify's own Linux app | Spotify offers a snap and a Debian package, no RPM, and "it is currently not a platform that we actively support". RPM Fusion's `lpf-spotify-client` (1.3.4.258, pushed 13 Oct) builds it locally from that package | **The only route with no licence question.** A GUI window and one more package; `lpf`'s unattended install is untested here |
| A TUI: `ncspot` | Fits "TUI over GUI". "Only works with a Spotify premium account"; it uses librespot, whose README says "Using this code to connect to Spotify's API is probably forbidden by them" | Premium, and no cleaner on terms |
| Vivaldi instead of Helium | Section 3 | The whole pick changes for one web app |

**If he asks me:** the official app is the clean answer and leaves the browser as it is. The fetch is the smoother one,
and it is what stands if he says nothing, because `lane-browser` told him so. His call either way.

## 5. The trial (`lane-browser`'s; plan T31a's "try the top 2-3")

Fence every run: own `--user-data-dir` in `/dev/shm`, headless dwl per CLAUDE.md, own `XDG_RUNTIME_DIR`, a dead D-Bus
(memory `probes-cut-off-session`), and never his profile. Install nothing system-wide for the trial: unpack the
tarball or RPM to a scratch folder. **Hard gates first; a candidate failing one is out, before any timing:**

1. Native Wayland: `chrome://gpu`, and no Xwayland client in dwl's list.
2. VA-API: `chrome://media-internals` decoder name for H.264, VP9 and AV1, on the RX and on the iGPU.
3. Widevine: `navigator.requestMediaKeySystemAccess('com.widevine.alpha', …)` resolves, a public DRM demo plays,
   and it survives 5 restarts. Spotify proper waits for his own login: never typed by us.
4. `--app=` windows: `app_id`, title, and MPRIS as `kawa-nowplaying` reads it.
5. Bubbles and menus take clicks on dwl (`helium-linux#359`), and popups over a floating window.
6. Copying 5 MB between it and foot (T17c's matrix).
7. Sharing (owner, 18:07): the entire screen shares the system's sound, a tab shares the tab's, in Meet, the Discord site and any web app.

**Then the numbers, 10 runs each, median and worst, against Brave:** cold start (evict its files first, by `vmtouch -e`
or a reboot) and warm start, by the first commit of its surface in dwl's frame log; RSS and PSS with the same 10 tabs; frame times at 144 Hz in dwl while
scrolling and with a 1080p60 video; idle wake-ups. Judge stutter from dwl's own log, never wf-recorder (CLAUDE.md).

**Ledger the numbers with this file as the source.** Nothing migrates (owner, 18:09). Brave Origin's app goes once
Helium is proven; its old profile folder stays, since he wipes the PC later.

## 6. The swap (done in `lane-browser`, f983fb6; a list for its review)

- The seam: `bin/brave-origin` became a neutral `bin/kawa-browser`, so the next browser costs one file.
- 48 repo paths named Brave on 4 Nov (`git grep -il brave -- bin configs lib setup.sh theme.sh system tools`), including
  `bin/kawa-downloads`, `kawa-nowplaying`, `kawa-tidy`, `kawa-theme`, `kawa-share`, the pipewire and portal configs,
  `mimeapps.list`, the GTK themes, `dconf` and `fedokawaii-latency`.
- Memory `manifest-addition-checklist`: `packages.evidence`, `PACKAGES.md`, `programs.txt`, `(not-)launched.txt`,
  `check-packages`, `test_launcher`.
- The dead `WebRTCPipeWireCapturer` flag goes.

## 7. What this digest could not settle

- Whether Widevine on Helium survives restarts on dwl and Fedora 44: `lane-browser` reports it loading; survival is its gate 3.
- Vivaldi's native Wayland state on 8.2 and 8.3: only old forum statements.
- Real speed and RAM: nothing here is a measurement of a running browser.
- Chromium's own doc (`docs/gpu/vaapi.md`) says "VA-API on Linux is not supported, but it can be enabled" with the
  flags we use, so a Chromium update can break it on any candidate. Verify should watch it.
- Its `docs/ozone_overview.md` still says X11 is the default; the code quoted above shows otherwise on `main`. The
  code wins, but the base each browser ships may predate it. Hence gate 1.

## Sources

Commands (4 Nov 2026): `rpm -q`, `lsusb`, reads of `~/.config/BraveSoftware/Brave-Origin` (its Widevine `LICENSE` too), `strings` and `readelf` on
packages unpacked in `/dev/shm`, `gh api` as cited.
- Chromium stable history: https://versionhistory.googleapis.com/v1/chrome/platforms/linux/channels/stable/versions/all/releases
- Chromium code and docs (GitHub mirror): `ui/linux/display_server_utils.cc`, `docs/gpu/vaapi.md`, `docs/ozone_overview.md` at https://github.com/chromium/chromium
- Helium: https://helium.computer , https://github.com/imputnet/helium , https://github.com/imputnet/helium-linux , COPR https://copr.fedorainfracloud.org/coprs/imput/helium/ ; issues helium#116, #2389, #2411, #2643; helium-linux#222, #331, #359
- Trivalent: https://github.com/secureblue/Trivalent (`build/trivalent.spec`, `build/install/trivalent.conf`, `build/install/trivalent.sh`, `patches/trivalent/`, issues 125 and 369), https://secureblue.dev/faq , https://repo.secureblue.dev/secureblue.repo
- Vivaldi: https://vivaldi.com/blog/desktop/ , https://vivaldi.com/blog/desktop/minor-update-fourteen-8-2/ , https://vivaldi.com/blog/desktop/8-3-rc-3/ , https://vivaldi.com/blog/tips/tip-9/ , https://repo.vivaldi.com/stable/vivaldi-fedora.repo ; forum (volunteers, not official): https://forum.vivaldi.net/topic/114002 , https://forum.vivaldi.net/topic/95521
- Thorium: https://github.com/Alex313031/thorium (release M156.0.8078.28's own text)
- Cromite: https://github.com/uazo/cromite
- ungoogled-chromium: https://github.com/ungoogled-software/ungoogled-chromium , https://github.com/ungoogled-software/ungoogled-chromium-portablelinux , https://github.com/ungoogled-software/ungoogled-chromium-fedora , https://ungoogled-software.github.io/ungoogled-chromium-wiki/faq
- qutebrowser: https://qutebrowser.org/doc/faq.html , `doc/changelog.asciidoc` at https://github.com/qutebrowser/qutebrowser ; Qt's base: https://github.com/qt/qtwebengine (branch 6.11, `CHROMIUM_VERSION`)
- Brave: https://github.com/brave/brave-browser/releases
- Iridium: https://iridiumbrowser.de/
- Slimjet: https://www.slimjet.com/en/dlpage.php
- Wavebox: https://hub.wavebox.io/download-wavebox , https://wavebox.io/
- Whale, secondary: https://aur.archlinux.org/packages/naver-whale-stable
- Ulaa: https://ulaa.com/ ; undated thread: https://help.zoho.com/portal/en/community/topic/ulaa-browser?page=2
- Spotify: https://www.spotify.com/us/download/linux/ ; https://github.com/rpmfusion/lpf-spotify-client ; https://github.com/hrkfdn/ncspot ; https://github.com/librespot-org/librespot (README, "Disclaimer")
- Widevine pointer: https://aus5.mozilla.org/ (the URL in section 4)
- The list of Mac and Windows only browsers (secondary): https://flaviocopes.com/alternative-browsers/
