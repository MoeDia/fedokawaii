---
id: py-account
title: a useful class: a bank account
part: python
chapter: 34
minutes: 4
needs: [py-why-classes]
optional: no
---

## 34.3 a useful class: a bank account

Methods keep the rules in one place — here, *no withdrawing more than the balance*:

```python
class Account:
    def __init__(self, owner, balance=0):
        self.owner = owner
        self.balance = balance
        self.history = []

    def deposit(self, amount):
        if amount <= 0:
            raise ValueError("deposit must be positive")
        self.balance += amount
        self.history.append(("in", amount))

    def withdraw(self, amount):
        if amount > self.balance:
            raise ValueError(f"only {self.balance} available")
        self.balance -= amount
        self.history.append(("out", amount))

acc = Account("Sara", 100)
acc.deposit(50)
acc.withdraw(30)
print(acc.balance, acc.history)
try:
    acc.withdraw(500)
except ValueError as e:
    print("refused:", e)
```

*You should see:*

```text
120 [('in', 50), ('out', 30)]
refused: only 120 available
```
