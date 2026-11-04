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
