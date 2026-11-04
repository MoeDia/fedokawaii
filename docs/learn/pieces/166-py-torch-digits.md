---
id: py-torch-digits
title: the digits network, in PyTorch
part: python
chapter: 44
minutes: 6
needs: [py-card]
optional: no
---

## 44.4 the digits network, in PyTorch

What took 20 lines of calculus in chapter 43 is three here: PyTorch's **autograd** computes
every gradient by itself.

```python
# digits.py — the digits network in PyTorch, trained on the card, saved for Rust (chapter 64)
import torch
import torch.nn as nn
import torch.nn.functional as F
from safetensors.torch import save_file
from sklearn.datasets import load_digits

torch.manual_seed(0)
DEVICE = "cuda"

d = load_digits()
X = torch.tensor(d.data / 16.0, dtype=torch.float32)
y = torch.tensor(d.target, dtype=torch.int64)
Xtr, ytr, Xte, yte = X[:1500].to(DEVICE), y[:1500].to(DEVICE), X[1500:], y[1500:]

class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(64, 64)
        self.fc2 = nn.Linear(64, 10)

    def forward(self, x):
        return self.fc2(F.relu(self.fc1(x)))

model = Net().to(DEVICE)
opt = torch.optim.Adam(model.parameters(), lr=1e-2)

for epoch in range(201):
    loss = F.cross_entropy(model(Xtr), ytr)          # forward
    opt.zero_grad()
    loss.backward()                                  # backward: every gradient
    opt.step()                                       # update
    if epoch % 50 == 0:
        with torch.no_grad():
            acc = (model(Xte.to(DEVICE)).argmax(1).cpu() == yte).float().mean()
        print(f"epoch {epoch:3d}  loss {loss.item():.3f}  test accuracy {acc:.3f}")

save_file({k: v.cpu() for k, v in model.state_dict().items()}, "digits.safetensors")
save_file({"x": Xte, "y": yte}, "test.safetensors")
```

```text
$ uv run digits.py
epoch   0  loss 2.312  test accuracy 0.391
epoch  50  loss 0.089  test accuracy 0.912
epoch 100  loss 0.014  test accuracy 0.922
epoch 150  loss 0.005  test accuracy 0.919
epoch 200  loss 0.003  test accuracy 0.919
```

*(for example)* The training loss keeps falling while the test accuracy stops rising: the
network has started to memorise rather than learn — **overfitting**. Exercise 44.3 fights it.
