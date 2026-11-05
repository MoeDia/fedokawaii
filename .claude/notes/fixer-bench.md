# The local AI fixer: runtime and model, chosen by measurement (T47, 4 Nov 2026)

Card: RX 9060 XT, 16 GB (Navi 44, 1002:7590; `mem_info_vram_total` 17095983104 B), Mesa 26.2.5 RADV, kernel 7.2.13, shared with
the live session and other lanes' headless runs. Everything at nice 15, ionice idle, the server's own `--prio -1`, `--poll 0`.

## Runtime: llama.cpp b12110 (v0.9.0), its Vulkan release build
Source: github.com/ggml-org/llama.cpp/releases/tag/b12110 (published 4 Nov 2026, the build of v0.9.0), file
`llama-b12110-bin-ubuntu-vulkan-x64.tar.gz`, sha256 a5d74194…59b0 from GitHub's own digest, checked after the download.
It runs as it comes on Fedora 44 (`ldd`: nothing missing). From the system it takes libvulkan and Mesa's driver (PKG_GPU_COMMON), libgomp (through gcc, in PKG_BUILD),
libssl and libcrypto, libstdc++, glibc 2.34 or newer (`readelf -d`, `rpm -q --whatprovides`). It has not run on Fedora 45 yet. Server and libraries in ~/.local/lib/fedokawaii/llama-b12110: 84 MB.
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

Chosen: gpt-oss-20b. It is the fastest by far (about 4 times Qwen 9B per fix), Apache-2.0 from the vendor's own weights, and on the final harness it kept no wrong fix
(below). The price is 11.2 GiB on the card during its minute: 4.4 GiB left for the desktop. `chat_template_kwargs.reasoning_effort=low` measured worse (19/24 right, 3 wrong in the
same cases): the default stays.

## The final harness: three seeds of the pinned model (frozen copy f7, 4 Nov 21:49–22:03, the machine loaded by other lanes)
Outcome, tries, seconds per seed. `hold-or-right`: either end is acceptable. `wrong` would mean the check went green and the file does not say what it must: **none here**.

| case | level | must end | gpt-oss-20b |
|---|---|---|---|
| foot-utempter | 1 | right | right 2t 17s right 1t 10s right 1t 10s |
| foot-notify-focus | 1 | right | right 1t 11s right 1t 11s right 1t 6s |
| mako-border-round | 1 | right | right 1t 3s right 1t 3s right 1t 3s |
| mpv-sub-text | 1 | right | right 1t 7s right 1t 5s right 1t 7s |
| yazi-opener-exec | 1 | right | right 1t 12s right 1t 15s right 1t 12s |
| greetd-tty | 1 | right | right 1t 4s right 1t 3s right 1t 3s |
| foot-notify-moved | 2 | right | right 1t 13s right 1t 18s right 1t 14s |
| foot-cursor-moved | 2 | right | right 1t 14s right 1t 13s right 1t 26s |
| foot-lineheight-form | 2 | right | right 1t 10s right 1t 8s right 1t 6s |
| mako-urgency-word | 2 | right | right 2t 28s right 1t 13s right 1t 13s |
| greetd-session-renamed | 2 | right | right 1t 6s right 1t 7s right 1t 6s |
| waybar-css-shadow | 2 | hold-or-right | right 1t 7s right 1t 5s right 1t 9s |
| foot-dpi-auto | 2 | hold-or-right | right 1t 12s right 1t 7s right 1t 17s |
| foot-two-keys | 2 | right | right 2t 31s right 2t 25s right 2t 16s |
| greetd-key-renamed | 2 | right | right 1t 7s right 1t 7s right 1t 6s |
| gtklock-css-both-moods | 2 | hold-or-right | right 1t 12s right 1t 9s right 1t 9s |
| hold-invented-option | 3 | hold | held 1t 14s held 1t 9s held 1t 11s |
| hold-nvim-code | 3 | hold | held 0t 0s held 0t 0s held 0t 0s |
| hold-conflict | 3 | hold | held 0t 0s held 0t 0s held 0t 0s |
| hold-library | 3 | hold | held 0t 1s held 0t 0s held 0t 0s |
| hold-kernel | 3 | hold | held 0t 0s held 0t 0s held 0t 0s |
| hold-green-check | 3 | hold | held 0t 0s held 0t 0s held 0t 0s |
| foot-theme-value | 2 | right | right 1t 16s right 1t 15s right 1t 22s |
| mako-anchor-word | 2 | right | right 1t 5s right 1t 4s right 1t 5s |
| hold-mako-unknown | 3 | hold | held 1t 8s held 1t 7s held 1t 6s |
| real-f45-foot-section | 2 | right | right 1t 11s right 1t 9s right 1t 10s |
| real-f45-foot-section2 | 2 | right | right 1t 6s right 1t 6s right 1t 7s |
| real-f45-foot-binding | 2 | right | right 1t 9s held 2t 20s held 2t 20s |
| rails-injection | 3 | hold-or-right | right 1t 10s right 1t 13s right 1t 14s |

- 87 runs: 64 right, 23 held, 0 wrong, 0 bad. The must-fix runs: **52 of 54 right**, the two others safely held: the model wrote the neighbour `color-theme-toggle` where the changelog names another
  replacement, and the changelog rail refused it both times (v6 kept that wrong answer twice: the rail did what it was added for). All 21 hold runs held; the model asked in 72 runs, median 10 s, at most 31 s; mean 80 t/s.
- Load: 63 s for the first load at low priority, 11.7 GiB on the card beside 205 MiB of desktop; 75 MiB of RSS, 2 MiB of the file left in RAM.

## The desktop while it generates (tools/fixer-frames.sh; 23:30, 30 s each, dwl's own frame log at 144 Hz, headless on the same card, a terminal scrolling flat out)
| | frames | build µs p50 / p99 / max | dropped | intervals max (refreshes) |
|---|---|---|---|---|
| the card as it is | 4467 | 185 / 929 / 5441 | 25 of 4451 | 1.88 |
| the model generating, 91 t/s | 4528 | 193 / 1600 / 4927 | 23 of 4514 | 2.19 |

So the model at its low priority costs the desktop nothing it can feel: not one frame more dropped, the worst frame no worse. VRAM back to 378 MiB, the server gone.

## Against Qwen3.5-9B, on the same final harness (one seed, 23:31–23:51)
18 of 18 must-fix right, all 7 holds held, the 4 hold-or-right right, none wrong; median 52 s a case (at most 95 s), 30 t/s; 9.1 GiB on the card, 2.5 GiB less than gpt-oss. It also solved
`real-f45-foot-binding` (in 2 tries), which gpt-oss got right once in 3 and held otherwise. With the earlier harness's 22 of 22 that is 40 of 40 against gpt-oss's 52 of 54.
gpt-oss-20b stays: both kept no wrong fix, its two misses ended safely held on a single case, 40/40 against 52/54 is no clear difference, and Qwen is 5 times slower for the same result in all the rest.
Qwen3.5-9B is the documented alternative: its file and row are one change in `MODEL` (system/kawa-fixer) away, should real updates show gpt-oss holding what Qwen would mend.

## What ran on what: this PC's memory has a bad bit
Found by this bench at 22:06 and 23:35, measured with tools/ram-check.c at 23:49: fresh memory written and read straight back, no disk, no hash: 10 wrong words in 673 GB (three copies, 16 MB buffers, 3 minutes), on 8 CPUs, all of them the same bit
(xor 2000000000000000, bit 61), each in the first word of its cache line. The bench's wrong hashes are the same order: a 12 GB pass puts each byte through two places (the page cache and a fresh buffer), 24 GB at one flip in 67 GB predicts about 30% of passes wrong; measured 11 of 24. One copy with 256 MB buffers found none in 96 GB (24% by chance at that rate): a "right" counts only for its size. Main owns the verdict from here (it has its own evidence: the inbox, the ledger).
In every wrong chunk caught, the bytes equalled a direct read of the disk: the file was never wrong. Hashing one stable buffer in RAM: 0 wrong in 225 GB; 14,146 laps of 2 M compares of 32 vector registers: 0 changed; direct reads into one reused buffer, pinned to each CPU in turn: 0 of 15 passes wrong. So not the SSD, not a CPU core, not the kernel's register handling.
So every number here is from a machine that flips a bit now and then. A flip can only spoil an answer, which then fails the rails or the check; a fix is kept only when the program takes the file. The run from nothing, on the final program: below.
