---
id: py-timeouts
title: timeouts, limiting
part: python
chapter: 38
minutes: 4
needs: [py-switching]
optional: no
---

## 38.5 timeouts

A network call can hang. `asyncio.timeout` gives up after a time you choose:

```python
import asyncio

async def slow_answer():
    await asyncio.sleep(5)
    return 42

async def main():
    try:
        async with asyncio.timeout(0.5):
            print(await slow_answer())
    except TimeoutError:
        print("gave up after 0.5 s")

asyncio.run(main())
```

*You should see:*

```text
gave up after 0.5 s
```

## 38.6 limiting: a semaphore

Starting a thousand requests at once can overload a server (or get you blocked). A
**semaphore** lets only N run at a time:

```python
import asyncio, time

async def job(i, limit):
    async with limit:
        await asyncio.sleep(0.2)
        return i

async def main():
    limit = asyncio.Semaphore(3)
    start = time.perf_counter()
    results = await asyncio.gather(*(job(i, limit) for i in range(9)))
    print(results, f"{time.perf_counter() - start:.1f} s")

asyncio.run(main())
```

*You should see:*

```text
[0, 1, 2, 3, 4, 5, 6, 7, 8] 0.6 s
```

*(9 jobs of 0.2 s, 3 at a time: three rounds, about 0.6 s)*
