---
id: py-transformer
title: the ideas, and the model
part: python
chapter: 45
minutes: 15
needs: [py-torch-practice]
optional: no
---

> **In this chapter**
>
> - text as numbers: a character tokenizer
> - attention, the idea behind every large language model
> - train a 3-million-parameter model on the handbook, and let it write

A large language model does one thing: given some text, predict the next piece. Do that well
enough, one piece at a time, and it writes. This chapter builds the same machine — a
**transformer** — at a size your card trains in minutes, on a text you know: the full handbook
in your working copy, almost a million characters about this desktop.

## 45.1 the ideas, in plain words

| Idea | Means |
|---|---|
| **token** | a piece of text the model reads as one number. Here, one character; large models use pieces of words |
| **embedding** | each token's number turned into a vector of 256 numbers the model learns |
| **attention** | each position looks back at every earlier position and takes what it needs from them: in *the cat sat on its mat*, *its* looks at *cat* |
| **causal** | a position may look back, never forward: it must not see the answer it is predicting |
| **block** | attention, then a small network on each position, each added to what was there (a *residual*) |
| **logits** | a score for every possible next token; softmax makes them probabilities |
| **temperature** | how adventurous sampling is: low repeats the likeliest, high takes risks |

## 45.2 the model

```python
# chargpt.py — a character-level transformer: python chargpt.py TEXTFILE
import sys
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F

torch.manual_seed(0)
DEVICE = "cuda"
BLOCK, BATCH, D, HEADS, LAYERS = 128, 64, 256, 4, 4

text = Path(sys.argv[1]).read_text(encoding="utf-8")
chars = sorted(set(text))
stoi = {c: i for i, c in enumerate(chars)}
data = torch.tensor([stoi[c] for c in text], dtype=torch.long)
cut = int(0.9 * len(data))
train, val = data[:cut], data[cut:]

def batch(part: torch.Tensor):
    """BATCH random stretches of BLOCK characters, and the same shifted by one: the answers"""
    i = torch.randint(len(part) - BLOCK - 1, (BATCH,))
    x = torch.stack([part[j:j + BLOCK] for j in i])
    y = torch.stack([part[j + 1:j + BLOCK + 1] for j in i])
    return x.to(DEVICE), y.to(DEVICE)

```

The model: a stack of blocks, each attention then a small network:

```python
class Block(nn.Module):
    def __init__(self):
        super().__init__()
        self.ln1, self.ln2 = nn.LayerNorm(D), nn.LayerNorm(D)
        self.qkv = nn.Linear(D, 3 * D)
        self.proj = nn.Linear(D, D)
        self.mlp = nn.Sequential(nn.Linear(D, 4 * D), nn.GELU(), nn.Linear(4 * D, D))

    def forward(self, x):
        B, T, _ = x.shape
        q, k, v = self.qkv(self.ln1(x)).split(D, dim=2)
        q, k, v = (t.view(B, T, HEADS, D // HEADS).transpose(1, 2) for t in (q, k, v))
        a = F.scaled_dot_product_attention(q, k, v, is_causal=True)   # attention
        x = x + self.proj(a.transpose(1, 2).reshape(B, T, D))
        return x + self.mlp(self.ln2(x))

class CharGPT(nn.Module):
    def __init__(self, vocab: int):
        super().__init__()
        self.tok = nn.Embedding(vocab, D)
        self.pos = nn.Embedding(BLOCK, D)
        self.blocks = nn.Sequential(*[Block() for _ in range(LAYERS)])
        self.ln = nn.LayerNorm(D)
        self.head = nn.Linear(D, vocab)

    def forward(self, idx):
        x = self.tok(idx) + self.pos(torch.arange(idx.shape[1], device=idx.device))
        return self.head(self.ln(self.blocks(x)))

    @torch.no_grad()
    def generate(self, idx, n: int, temperature: float = 0.8):
        for _ in range(n):
            logits = self(idx[:, -BLOCK:])[:, -1] / temperature
            idx = torch.cat([idx, torch.multinomial(F.softmax(logits, dim=-1), 1)], dim=1)
        return idx

```

The training, and a sample of what it learnt:

```python
def loss_on(x, y):
    return F.cross_entropy(model(x).view(-1, len(chars)), y.view(-1))

model = CharGPT(len(chars)).to(DEVICE)
print(f"{len(text):,} characters, {len(chars)} different; "
      f"{sum(p.numel() for p in model.parameters()):,} parameters")
opt = torch.optim.AdamW(model.parameters(), lr=3e-4)

for step in range(5001):
    loss = loss_on(*batch(train))
    opt.zero_grad(set_to_none=True)
    loss.backward()
    opt.step()
    if step % 500 == 0:
        with torch.no_grad():
            print(f"step {step:5d}  train {loss.item():.3f}  val {loss_on(*batch(val)).item():.3f}")

torch.save(model.state_dict(), "chargpt.pt")
start = torch.tensor([[stoi["#"]]], device=DEVICE)
print("".join(chars[i] for i in model.generate(start, 600)[0].tolist()))
```

```text
$ uv run chargpt.py ~/dojo/fedokawaii/docs/fedokawaii-guide.md
962,051 characters, 246 different; 3,318,518 parameters
step     0  train 5.663  val 5.661
step   500  train 2.012  val 2.087
step  1000  train 1.563  val 1.684
…
step  5000  train 1.012  val 1.198
# 18.4 Practice: the terminal

| Keys | Does |
|---|---|
| **Super+Shift+R** | the mixer opens the folder in yazi, …
```

*(for example: the counts depend on your copy of the handbook, and the text it writes is new
every time — plausible-looking, often wrong, never copied. That is a language model)*

Read the loss as *surprise*: at step 0 it is about `ln(246) ≈ 5.5`, a blind guess among 246
characters; at 1.0 the model is nearly as sure of the next character as a reader who knows the
book's style.
