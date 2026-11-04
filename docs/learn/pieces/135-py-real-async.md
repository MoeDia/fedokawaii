---
id: py-real-async
title: real use, when it helps, mistakes
part: python
chapter: 38
minutes: 5
needs: [py-timeouts]
optional: no
---

## 38.7 real use: many web requests

The real network needs an async library; the standard one is `httpx` (`uv add httpx`). The shape
is always the same — one client, many `await`ed requests gathered together:

```python
import asyncio
import httpx

async def main():
    urls = [f"https://httpbin.org/delay/1?n={i}" for i in range(5)]
    async with httpx.AsyncClient(timeout=10) as client:
        replies = await asyncio.gather(*(client.get(u) for u in urls))
    print([r.status_code for r in replies])

asyncio.run(main())
```

*(not run here: it needs the network. Five one-second requests finish in about one second.
The Claude SDK has the same: `anthropic.AsyncAnthropic`, chapter 47)*

## 38.8 when async helps

| Your program is slow because it | Use |
|---|---|
| waits for the network, disk, a database, an API | **async** (or threads) |
| computes: maths, images, training | not async: NumPy, multiprocessing, or Rust (Part V) |

async does not make computing faster: there is still only one thing running at a time. It
makes *waiting* overlap.

## 38.9 common mistakes

**1. Forgetting `await`.** You get a coroutine object, not its result, and a warning:

```python
import asyncio

async def answer():
    return 42

async def main():
    x = answer()
    print(x)
    print(await answer())

asyncio.run(main())
```

*You should see:*

```text
<coroutine object answer at 0x7f4288b99d80>
42
/root/.local/share/uv/python/cpython-3.14.6-linux-x86_64-gnu/lib/python3.14/asyncio/events.py:94: RuntimeWarning: coroutine 'answer' was never awaited
  self._context.run(self._callback, *self._args)
RuntimeWarning: Enable tracemalloc to get the object allocation traceback
```

*(Python also warns, on the error stream, that the first coroutine "was never awaited")*

**2. `time.sleep` (or any slow normal call) inside async code.** It stops the whole event loop:
nothing else runs. Use `await asyncio.sleep`, and async libraries for I/O.

**3. Calling `asyncio.run` inside async code.** There is one `asyncio.run`, at the top; inside,
always `await`.
