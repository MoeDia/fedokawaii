---
id: py-tune-projects
title: projects
part: python
chapter: 46
minutes: 30
needs: [py-tune-practice]
optional: yes
---

**46.3 ★★★ Load it later.** Write `chat.py` that loads the base model, adds the adapter with
`PeftModel.from_pretrained(model, "keys-lora")`, and answers questions in a loop.
