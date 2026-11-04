---
id: py-waiting
title: waiting, not working: async and await
part: python
chapter: 38
minutes: 6
needs: [py-generators-practice]
optional: no
---

> **In this chapter**
>
> - why waiting is the slow part of most programs
> - `async def`, `await`, and `asyncio.run`
> - many waits at once: `gather`, `TaskGroup`, timeouts
> - when async helps, and when it does not

## 38.1 waiting, not working

Most programs that feel slow are not computing: they are **waiting** — for a web page, a
database, a model's answer. While one request waits, the computer could send ten more.
**async** code lets one program have many waits going at once, and switch to whichever is
ready.

Here is the slow way: three downloads that each take one second, one after the other.
`time.sleep` stands in for the network:

```python
import time

def download(name):
    time.sleep(1)
    return f"{name} done"

start = time.perf_counter()
for name in ["a", "b", "c"]:
    print(download(name))
print(f"took {time.perf_counter() - start:.0f} s")
```

*You should see:*

```text
a done
b done
c done
took 3 s
```

## 38.2 async and await

The same with `asyncio`. `async def` makes a **coroutine** — a function that can pause.
`await` marks the place where it waits, and lets others run meanwhile. `asyncio.gather` starts
several at once and waits for all:

```python
import asyncio
import time

async def download(name):
    await asyncio.sleep(1)
    return f"{name} done"

async def main():
    results = await asyncio.gather(download("a"), download("b"), download("c"))
    print(results)

start = time.perf_counter()
asyncio.run(main())
print(f"took {time.perf_counter() - start:.0f} s")
```

*You should see:*

```text
['a done', 'b done', 'c done']
took 1 s
```

Three seconds became one: the three waits overlapped.

| Piece | Means |
|---|---|
| `async def f():` | `f()` makes a coroutine; nothing runs yet |
| `await x` | run `x`, and let other work go on while it waits |
| `asyncio.run(main())` | start the event loop and run `main` to its end — once, at the top |
| `asyncio.gather(a, b, c)` | run them together; their results, in order |
| `asyncio.sleep(s)` | wait without blocking the others (never `time.sleep` inside async code) |

> **Word — event loop.** The part of asyncio that keeps a list of waiting coroutines, and runs
> whichever is ready. `asyncio.run` makes one, runs your `main`, and closes it.
