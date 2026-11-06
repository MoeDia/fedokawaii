---
id: py-async-projects
title: projects
part: python
chapter: 38
minutes: 180
needs: [py-async-practice]
optional: yes
---

**38.5 ★★★ A producer and a consumer.** With `asyncio.Queue`: a producer puts 5 numbers (one every 0.1 s), a consumer takes and prints
their squares; stop with a `None` sentinel.

<!-- solution 38.5 -->
```python
import asyncio

async def producer(q):
    for i in range(5):
        await asyncio.sleep(0.1)
        await q.put(i)
    await q.put(None)

async def consumer(q):
    while (item := await q.get()) is not None:
        print("square", item * item)

async def main():
    q = asyncio.Queue()
    await asyncio.gather(producer(q), consumer(q))

asyncio.run(main())
```

*You should see:*

```text
square 0
square 1
square 4
square 9
square 16
```
<!-- /solution -->

**38.6 ★★★ A failure in a group.** In a `TaskGroup`, one task raises `ValueError`. Catch it with `except* ValueError` and show the
other tasks were cancelled.

<!-- solution 38.6 -->
```python
import asyncio

async def ok(i):
    try:
        await asyncio.sleep(1)
        print("finished", i)
    except asyncio.CancelledError:
        print("cancelled", i)
        raise

async def bad():
    await asyncio.sleep(0.1)
    raise ValueError("boom")

async def main():
    try:
        async with asyncio.TaskGroup() as tg:
            tg.create_task(ok(1)); tg.create_task(ok(2)); tg.create_task(bad())
    except* ValueError as eg:
        print("caught:", eg.exceptions)

asyncio.run(main())
```

*You should see:*

```text
cancelled 2
cancelled 1
caught: (ValueError('boom'),)
```
<!-- /solution -->

**38.7 ★★★★ A polite crawler, simulated.** Simulate fetching 20 pages (`await asyncio.sleep(random.uniform(0.05, 0.2))`), at most 4 at a
time (a semaphore), each with a 0.15 s timeout, and report how many succeeded, how many timed
out, and the total time.

<!-- solution 38.7 -->
```python
import asyncio, random, time

random.seed(4)

async def fetch(i, limit):
    async with limit:
        try:
            async with asyncio.timeout(0.15):
                await asyncio.sleep(random.uniform(0.05, 0.2))
                return True
        except TimeoutError:
            return False

async def main():
    limit = asyncio.Semaphore(4)
    t = time.perf_counter()
    results = await asyncio.gather(*(fetch(i, limit) for i in range(20)))
    print(f"{sum(results)} ok, {results.count(False)} timed out, under 2 s: {time.perf_counter() - t < 2}")

asyncio.run(main())
```

*You should see:*

```text
13 ok, 7 timed out, under 2 s: True
```
<!-- /solution -->
