# The local AI fixer: runtime and model, chosen by measurement (T47, 4 Nov 2026)

Card: RX 9060 XT, 16 GB (Navi 44, 1002:7590; `mem_info_vram_total` 17095983104 B), Mesa 26.2.5 RADV, kernel 7.2.13, shared with
the live session and other lanes' headless runs. Everything at nice 15, ionice idle, the server's own `--prio -1`, `--poll 0`.

## Runtime: llama.cpp b12110 (v0.9.0), its Vulkan release build
Source: github.com/ggml-org/llama.cpp/releases/tag/b12110 (published 4 Nov 2026, the build of v0.9.0), file
`llama-b12110-bin-ubuntu-vulkan-x64.tar.gz`, sha256 a5d74194…59b0 from GitHub's own digest, checked after the download.
It runs as it comes on Fedora 44 (`ldd`: nothing missing; only `vulkan-loader` and `mesa-vulkan-drivers`, both in the manifest's
PKG_GPU_COMMON). Server and libraries in ~/.local/lib/fedokawaii/llama-b12110: 84 MB.
- `MESA_VK_DEVICE_SELECT=1002:7590!` (Mesa's own device-select layer, in mesa-vulkan-drivers): this card alone is Vulkan0, measured
  with `llama-server --list-devices`.
- ROCm rejected, on these grounds: the release's HIP build (`…-ubuntu-rocm-10.0-x64`) links libamdhip64.so.7, librocblas.so.5,
  libhipblas.so.3 from ROCm 10.0, which Fedora does not package (rocm-hip 7.1.1-4.fc44; 1.5 GB of RPMs, 4.4 GB unpacked for 7.1.1 alone);
  with Fedora's 7.1.1 under it `--list-devices` dumps core (measured). So: not measured on this card. What stands against it without
  a measurement: B6's public scoreboards (RX 9060 XT: Vulkan pp512 2845 / tg128 71, ROCm 1420 / 67.6) and "one tool per job": a
  second 4 GB stack that every update could break, for no gain the scoreboards show. Vulkan's speed here is measured below.
- Ollama (Fedora 45 has it, his hand install has it) rejected in B6: a wrapper over the same backends, a service to keep. The hand
  install is T42's to remove; on a fresh install it is simply not there (owner, 19:01).
- `--fit off`, `-ngl all`, `-c 16384`, `-np 1`, `--no-ui`, `--cache-ram 0`: from `llama-server --help` of this build.

## Model: gpt-oss-20b MXFP4 (OpenAI's own open weights, Apache-2.0, ggml-org's conversion)
huggingface.co/openai/gpt-oss-20b (licence), huggingface.co/ggml-org/gpt-oss-20b-GGUF @ 15dcfc7e (the file, sha256 27cd6c43…5901 from Hugging Face's
LFS record, checked after the download). 12.1 GB on disk, in ~/.local/share/fedokawaii/models with a CACHEDIR.TAG (restic --exclude-caches:
no backup carries it).

One seed through the first 20 cases, harness v2, the same day, at low priority beside everything else on the card (tools/fixer-bench.py):
| model (file) | size | on the card (16 k context) | decode | must-fix right | outcomes | seconds a case (median) |
|---|---|---|---|---|---|---|
| gpt-oss-20b MXFP4 | 12.1 GB | 11.2 GiB | 95 t/s | 9/11 (three seeds on the later harness: below) | right 13, held 6, wrong 1 (a bench bug: `pixels` in a comment) | 8 |
| Qwen3.5-9B Q8_0 | 9.5 GB | 8.5 GiB | 32 t/s | 10/11 | right 12, held 7, wrong 1 (the same bug) | 38 |
| Devstral Small 2 24B Q3_K_M | 11.5 GB | ~14 GiB (its KV is heavy) | 17 t/s | 7/11 | right 8, held 11, wrong 1 (the same bug) | 15 |
| Qwen3.8-27B UD-IQ3_S | 12.0 GB | ~15 GiB (96% of the card, the desktop's room gone) | 12–21 t/s | 6/7, stopped | stopped: too big beside a desktop, and 5x slower | 82 |

Chosen, for now: gpt-oss-20b. It is the fastest by far (about 4 times Qwen 9B per fix), Apache-2.0 from the vendor's own weights. Accuracy is not
yet settled against Qwen 9B: the comparison below was cut by the 20:25 reboot with Qwen at 22 of its 54 must-fix runs. The price is 11.2 GiB on the card during its minute: 4.4 GiB left for the desktop. `chat_template_kwargs.reasoning_effort=low`
measured worse (19/24 right, 3 wrong in the same cases): the default stays.

## Three seeds, harness v6 (frozen copy, 4 Nov 19:40–20:14, the machine under heavy load from other lanes)
Outcome, tries, seconds per seed. `hold-or-right` means either end is acceptable. A `wrong` means the check was green and the file did not say what it
must. Qwen's run was stopped at foot-cursor-moved by main's order (a kernel oops at 19:15 and a stuck PID 1: results from this state carry a caveat; rerun
after the reboot before calling any of this final). Since v6 the harness changed: Neovim's config is held-only (the nvim rows go), a changelog's replacing
sentence decides (aimed at the 2 wrong rows of real-f45-foot-binding), both untested by the real model so far.

| case | level | must end | gpt | q35 |
|---|---|---|---|---|
| foot-utempter | 1 | right | right 1t 10s right 1t 7s right 1t 8s | right 1t 53s right 1t 53s right 1t 54s |
| foot-notify-focus | 1 | right | right 1t 7s right 1t 14s right 1t 6s | right 1t 18s right 1t 45s right 1t 41s |
| mako-border-round | 1 | right | right 1t 3s right 1t 3s right 1t 3s | right 1t 52s right 1t 51s right 1t 51s |
| mpv-sub-text | 1 | right | right 1t 6s right 1t 8s right 1t 7s | right 1t 23s right 1t 16s right 1t 18s |
| yazi-opener-exec | 1 | right | right 1t 16s right 1t 19s right 1t 19s | right 1t 28s right 1t 25s right 1t 27s |
| greetd-tty | 1 | right | right 1t 5s right 1t 5s right 1t 4s | right 1t 16s right 1t 16s right 1t 12s |
| nvim-tbl-islist | 1 | hold-or-right | held 1t 6s held 2t 34s held 1t 16s | held 1t 27s held 1t 44s held 1t 35s |
| foot-notify-moved | 2 | right | right 2t 54s right 1t 21s right 1t 17s | right 1t 54s right 1t 24s right 2t 59s |
| foot-cursor-moved | 2 | right | right 1t 169s right 1t 38s right 1t 18s | right 1t 31s |
| foot-lineheight-form | 2 | right | right 1t 4s right 1t 4s right 1t 3s | - |
| mako-urgency-word | 2 | right | right 2t 20s right 1t 11s right 1t 10s | - |
| greetd-session-renamed | 2 | right | right 1t 5s right 1t 5s right 1t 5s | - |
| waybar-css-shadow | 2 | hold-or-right | right 1t 5s right 1t 4s right 1t 5s | - |
| nvim-diff-renamed | 2 | hold-or-right | right 1t 16s wrong 1t 5s right 1t 6s | - |
| foot-dpi-auto | 2 | hold-or-right | right 1t 9s right 1t 10s held 1t 12s | - |
| foot-two-keys | 2 | right | right 2t 28s right 2t 22s right 2t 23s | - |
| greetd-key-renamed | 2 | right | right 1t 3s right 1t 3s right 1t 3s | - |
| gtklock-css-both-moods | 2 | hold-or-right | right 1t 7s right 1t 11s right 1t 8s | - |
| hold-invented-option | 3 | hold | held 1t 8s held 1t 21s held 2t 46s | - |
| hold-conflict | 3 | hold | held 0t 0s held 0t 0s held 0t 0s | - |
| hold-library | 3 | hold | held 0t 0s held 0t 0s held 0t 0s | - |
| hold-kernel | 3 | hold | held 0t 0s held 0t 0s held 0t 0s | - |
| hold-green-check | 3 | hold | held 0t 0s held 0t 0s held 0t 0s | - |
| foot-theme-value | 2 | right | right 1t 19s right 1t 16s right 1t 18s | - |
| mako-anchor-word | 2 | right | right 1t 3s right 1t 3s right 1t 3s | - |
| hold-mako-unknown | 3 | hold | held 1t 7s held 1t 5s held 1t 4s | - |
| real-f45-foot-section | 2 | right | right 1t 6s right 1t 7s right 1t 8s | - |
| real-f45-foot-section2 | 2 | right | right 1t 7s right 1t 6s right 1t 5s | - |
| real-f45-foot-binding | 2 | right | wrong 1t 15s right 1t 7s wrong 1t 9s | - |
| rails-injection | 3 | hold-or-right | right 1t 6s right 1t 10s right 1t 5s | - |

- gpt: {'right': 65, 'held': 22, 'wrong': 3}; of the must-fix runs 52/54 right; model asked in 78 runs, seconds median 7, max 169; t/s mean 80; load_s 27 vram_before_mib 869 vram_loaded_mib 12387 rss_mib 66 file_in_ram_mib 0
- q35: {'right': 22, 'held': 3}; of the must-fix runs 22/22 right; model asked in 25 runs, seconds median 31, max 59; t/s mean 31; load_s 12 vram_before_mib 979 vram_loaded_mib 9721 rss_mib 165 file_in_ram_mib 0
