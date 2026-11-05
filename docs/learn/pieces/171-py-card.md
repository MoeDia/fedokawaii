---
id: py-card
title: is the card there?
part: python
chapter: 44
minutes: 4
needs: [py-torch-install]
optional: no
---

## 44.3 is the card there?

```python
# gpu.py — PyTorch sees the card, and how much faster it is
import time
import torch

print(torch.__version__, "· HIP", torch.version.hip)
print(torch.cuda.is_available(), torch.cuda.get_device_name(0))

def bench(device: str) -> float:
    a = torch.randn(4096, 4096, device=device)
    b = torch.randn(4096, 4096, device=device)
    a @ b                                            # (a first run warms it up)
    torch.cuda.synchronize()
    t = time.perf_counter()
    for _ in range(10):
        a @ b
    torch.cuda.synchronize()                         # (the card works on its own: wait for it)
    return (time.perf_counter() - t) / 10

cpu, gpu = bench("cpu"), bench("cuda")
print(f"4096×4096 matrix product: processor {cpu * 1000:.0f} ms, card {gpu * 1000:.1f} ms")
```

```text
$ uv run gpu.py
2.14.1+rocm7.2 · HIP 7.2.53211
True AMD Radeon RX 9060 XT
4096×4096 matrix product: processor 310 ms, card 9.8 ms
```

*(for example: your numbers will differ)*

> **Word — "cuda" on an AMD card.** PyTorch calls every graphics card `cuda`, NVIDIA's name; on
> ROCm the same calls go to AMD's HIP. So `device="cuda"` and `torch.cuda` are right here, and
> every tutorial written for NVIDIA works unchanged.
