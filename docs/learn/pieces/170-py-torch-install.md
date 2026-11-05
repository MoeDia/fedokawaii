---
id: py-torch-install
title: where things stand; install
part: python
chapter: 44
minutes: 3
needs: [py-network-practice]
optional: no
---

> **In this chapter**
>
> - install PyTorch for the RX 9060 XT
> - tensors on the card, and how much faster they are
> - the digits network again, in PyTorch, trained on the card

## 44.1 where things stand (October 2026)

| Piece | State on Fedora 44 |
|---|---|
| the card's driver | `amdgpu`, in the kernel: nothing to install |
| ROCm, AMD's computing stack | Fedora packages it (`rocm-*`, version 7.1); AMD's own list of supported systems does not include Fedora |
| PyTorch for ROCm | PyTorch's official wheels, `download.pytorch.org/whl/rocm7.2` (PyTorch 2.14), carry their own copy of ROCm 7.2 and include the RX 9060 XT (`gfx1200`, RDNA 4) — so Fedora's ROCm packages are not needed for PyTorch |
| btop | shows the card's load, memory, heat and watts while you train (through `rocm-smi`, installed) |

So: the PyTorch wheel brings everything; Fedora brings the driver. One check of access to the
card's compute device:

```text
$ ls -l /dev/kfd
crw-rw-rw-. 1 root render 235, 0 Oct 20 09:12 /dev/kfd
```

*(every user may open it. If yours shows `crw-rw----`, you need the `render` group: `sudo usermod
-aG render $USER`, then log out and in)*

The card comes in an 8 GB and a 16 GB model; `rocm-smi --showmeminfo vram` says which is yours.
Every project in this book fits in 8 GB.

## 44.2 install

```text
$ uv init dl && cd dl
```

Add these lines to `pyproject.toml`, so that uv fetches PyTorch from PyTorch's ROCm index and
everything else from the usual one:

```toml
[tool.uv.sources]
torch = [{ index = "pytorch-rocm" }]
pytorch-triton-rocm = [{ index = "pytorch-rocm" }]

[[tool.uv.index]]
name = "pytorch-rocm"
url = "https://download.pytorch.org/whl/rocm7.2"
explicit = true
```

```text
$ uv add torch scikit-learn safetensors
$ uv add --dev pytest
```

*(the ROCm wheel is several gigabytes: the first `uv add` takes a while; later projects reuse
uv's cache)*
