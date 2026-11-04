---
id: rs-own-error
title: your own error type
part: rust
chapter: 56
minutes: 6
needs: [rs-box-dyn]
optional: no
---

## 56.6 your own error type

For a library, callers want to know *which* error happened, to handle each differently. An enum
says it exactly:

```rust
use std::fmt;

#[derive(Debug, PartialEq)]
enum BankError {
    Insufficient { needed: u64, available: u64 },
    AccountFrozen,
}

impl fmt::Display for BankError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self {
            BankError::Insufficient { needed, available } => {
                write!(f, "needed {needed}, only {available} available")
            }
            BankError::AccountFrozen => write!(f, "the account is frozen"),
        }
    }
}

impl std::error::Error for BankError {}

fn withdraw(balance: u64, amount: u64, frozen: bool) -> Result<u64, BankError> {
    if frozen {
        return Err(BankError::AccountFrozen);
    }
    if amount > balance {
        return Err(BankError::Insufficient { needed: amount, available: balance });
    }
    Ok(balance - amount)
}

fn main() {
    println!("{:?}", withdraw(100, 30, false));
    for (amount, frozen) in [(500, false), (10, true)] {
        if let Err(e) = withdraw(100, amount, frozen) {
            println!("refused: {e}");
        }
    }
}
```

*You should see:*

```text
Ok(70)
refused: needed 500, only 100 available
refused: the account is frozen
```

*(`Display` says how the error reads to a person; `impl Error` lets it go into `Box<dyn Error>`.
The `thiserror` crate writes this code for you; `anyhow` is the crate for quick programs —
chapter 62 uses it)*
