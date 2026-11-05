---
id: py-async-practice
title: practice
part: python
chapter: 38
minutes: 12
needs: [py-real-async]
optional: no
---

**38.1 ★ Hello, later.** An async `greet(name, delay)` that waits then prints; run three with `gather`, delays 0.3, 0.1, 0.2.
In which order do they print?

<!-- solution 38.1 -->
```python
import asyncio

async def greet(name, delay):
    await asyncio.sleep(delay)
    print("hello", name)

async def main():
    await asyncio.gather(greet("a", 0.3), greet("b", 0.1), greet("c", 0.2))

asyncio.run(main())
```

*You should see:*

```text
hello b
hello c
hello a
```
<!-- /solution -->

**38.2 ★ Results in order.** Show that `gather` returns results in the order you passed them, not the order they finish.

<!-- solution 38.2 -->
```python
import asyncio

async def value(v, delay):
    await asyncio.sleep(delay)
    return v

async def main():
    print(await asyncio.gather(value("first", 0.2), value("second", 0.1)))

asyncio.run(main())
```

*You should see:*

```text
['first', 'second']
```
<!-- /solution -->

**38.3 ★★ Time it.** Ten coroutines that each sleep 0.5 s: time them one after another (`await` in a loop), then
with `gather`.

<!-- solution 38.3 -->
```python
import asyncio, time

async def nap():
    await asyncio.sleep(0.5)

async def main():
    t = time.perf_counter()
    for _ in range(10):
        await nap()
    print(f"one by one: {time.perf_counter() - t:.1f} s")
    t = time.perf_counter()
    await asyncio.gather(*(nap() for _ in range(10)))
    print(f"together:   {time.perf_counter() - t:.1f} s")

asyncio.run(main())
```

*You should see:*

```text
one by one: 5.0 s
together:   0.5 s
```
<!-- /solution -->

**38.4 ★★ Timeout per job.** Five jobs with delays 0.1 to 0.5 s; give each a 0.35 s timeout and print which finished.

<!-- solution 38.4 -->
```python
import asyncio

async def job(d):
    await asyncio.sleep(d)
    return d

async def with_timeout(d):
    try:
        async with asyncio.timeout(0.35):
            return f"{await job(d)} ok"
    except TimeoutError:
        return f"{d} timed out"

async def main():
    print(await asyncio.gather(*(with_timeout(d / 10) for d in range(1, 6))))

asyncio.run(main())
```

*You should see:*

```text
['0.1 ok', '0.2 ok', '0.3 ok', '0.4 timed out', '0.5 timed out']
```
<!-- /solution -->
