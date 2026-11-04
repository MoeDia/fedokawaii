---
id: rs-bank
title: checkpoint: a bank with commands
part: rust
chapter: 54
minutes: 40
needs: [rs-option-work]
optional: no
---

## 54.9 checkpoint project — a bank with commands

Level 2 in one program: a struct (the account), an enum (the commands), `match`, `Option`, and
borrowing (`&mut self`). The commands come from a list here so the program runs by itself;
chapter 50's checkpoint showed how to read them from the keyboard instead.

```rust
#[derive(Debug)]
enum Command {
    Deposit(u64),
    Withdraw(u64),
    Balance,
    History,
}

fn parse(line: &str) -> Option<Command> {
    let mut words = line.split_whitespace();
    let cmd = words.next()?;
    let amount = words.next().and_then(|w| w.parse::<u64>().ok());
    match (cmd, amount) {
        ("deposit", Some(n)) => Some(Command::Deposit(n)),
        ("withdraw", Some(n)) => Some(Command::Withdraw(n)),
        ("balance", None) => Some(Command::Balance),
        ("history", None) => Some(Command::History),
        _ => None,
    }
}

struct Account {
    balance: u64,
    history: Vec<String>,
}

impl Account {
    fn run(&mut self, c: Command) -> String {
        match c {
            Command::Deposit(n) => {
                self.balance += n;
                self.history.push(format!("+{n}"));
                format!("deposited {n}")
            }
            Command::Withdraw(n) if n > self.balance => format!("refused: only {} left", self.balance),
            Command::Withdraw(n) => {
                self.balance -= n;
                self.history.push(format!("-{n}"));
                format!("withdrew {n}")
            }
            Command::Balance => format!("balance {}", self.balance),
            Command::History => self.history.join(" "),
        }
    }
}

fn main() {
    let mut acc = Account { balance: 0, history: Vec::new() };
    for line in ["deposit 100", "withdraw 30", "withdraw 500", "lend 5", "balance", "history"] {
        let reply = match parse(line) {
            Some(cmd) => acc.run(cmd),
            None => String::from("unknown command"),
        };
        println!("> {line:<14} {reply}");
    }
}
```

*You should see:*

```text
> deposit 100    deposited 100
> withdraw 30    withdrew 30
> withdraw 500   refused: only 70 left
> lend 5         unknown command
> balance        balance 70
> history        +100 -30
```

> **Checkpoint.** Add (1) a `Transfer(u64, String)` command between named accounts — keep them
> in a `Vec<(String, Account)>` for now; (2) an `Undo` that reverses the last deposit or
> withdrawal; (3) reading commands from the keyboard until `quit`. Level 2 done: you understand
> ownership, the part of Rust that is truly new.
