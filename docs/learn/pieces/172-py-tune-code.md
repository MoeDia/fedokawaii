---
id: py-tune-code
title: the data, and the code
part: python
chapter: 46
minutes: 11
needs: [py-transformer-practice]
optional: no
---

> **In this chapter**
>
> - take a real pretrained language model from Hugging Face
> - teach it facts of your own with LoRA, in minutes, on your card
> - compare its answers before and after

Training a useful language model from nothing takes months of computing. **Fine-tuning** takes
one that already knows language and teaches it a little more. **LoRA** (low-rank adaptation)
makes that cheap: the model's own weights stay frozen, and small extra matrices — under 1 % of
the size — learn the change.

## 46.1 the data: questions and answers about your desktop

Write `keys.jsonl`, one question and answer per line (forty or more is good; the tables of
this book are a ready source):

```text
{"q": "How do I open a terminal on Fedokawaii?", "a": "Super+Return opens foot, the terminal."}
{"q": "How do I take a screenshot of a region?", "a": "Press Print and drag a box; it is saved and copied."}
{"q": "Where do my notes live?", "a": "In ~/Notes/notes.md; Super+N opens them."}
```

## 46.2 the code

```text
$ uv add transformers peft
```

```python
# tune.py — LoRA fine-tuning of a small chat model on keys.jsonl
import json

import torch
from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM, AutoTokenizer

NAME = "HuggingFaceTB/SmolLM2-360M-Instruct"
DEVICE = "cuda"
torch.manual_seed(0)

tok = AutoTokenizer.from_pretrained(NAME)
model = AutoModelForCausalLM.from_pretrained(NAME, dtype=torch.bfloat16).to(DEVICE)

def prompt(q: str) -> str:
    return tok.apply_chat_template([{"role": "user", "content": q}],
                                   tokenize=False, add_generation_prompt=True)

def ask(q: str) -> str:
    enc = tok(prompt(q), return_tensors="pt", add_special_tokens=False).to(DEVICE)
    out = model.generate(**enc, max_new_tokens=60, do_sample=False)
    return tok.decode(out[0, enc.input_ids.shape[1]:], skip_special_tokens=True)

def example(q: str, a: str):
    """the whole exchange as tokens; the labels hide the question (-100): only the answer is learnt"""
    p = tok(prompt(q), add_special_tokens=False).input_ids
    full = tok(prompt(q) + a + tok.eos_token, add_special_tokens=False).input_ids
    ids = torch.tensor([full], device=DEVICE)
    labels = ids.clone()
    labels[0, :len(p)] = -100
    return ids, labels

```

Then the training itself, in the same file: ask once before, attach LoRA, four passes, ask again:

```python
pairs = [json.loads(line) for line in open("keys.jsonl", encoding="utf-8")]
test_q = "How do I open a terminal on Fedokawaii?"
print("before:", ask(test_q))

model = get_peft_model(model, LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"], task_type="CAUSAL_LM"))
model.print_trainable_parameters()
opt = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=2e-4)

model.train()
for epoch in range(4):
    total = 0.0
    for pair in pairs:
        ids, labels = example(pair["q"], pair["a"])
        loss = model(input_ids=ids, labels=labels).loss
        opt.zero_grad()
        loss.backward()
        opt.step()
        total += loss.item()
    print(f"epoch {epoch}  loss {total / len(pairs):.3f}")

model.eval()
print("after:", ask(test_q))
model.save_pretrained("keys-lora")
```

```text
$ uv run tune.py
before: To open a terminal, press Ctrl+Alt+T or search for "Terminal" in the applications menu.
trainable params: 3,276,800 || all params: 365,097,920 || trainable%: 0.8975
epoch 0  loss 2.104
epoch 1  loss 0.712
epoch 2  loss 0.253
epoch 3  loss 0.118
after: Super+Return opens foot, the terminal.
```

*(for example)* Before, it answered what most Linux desktops do; after, yours. The adapter in
`keys-lora/` is a few megabytes: the base model stays as it was downloaded.

> **Careful.** With forty examples, it memorises them; ask the same thing in other words and it
> may still answer the old way. More, more varied examples — each fact asked three ways — teach
> it rather than make it recite. And a small model invents with confidence: never trust its
> answer about something it was not taught.
