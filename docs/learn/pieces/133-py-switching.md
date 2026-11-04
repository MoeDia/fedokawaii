---
id: py-switching
title: seeing the switching; tasks
part: python
chapter: 38
minutes: 4
needs: [py-waiting]
optional: no
---

## 38.3 seeing the switching

Each coroutine runs until its `await`, then the loop runs another:

```python
import asyncio

async def worker(name, delay):
    for i in range(3):
        print(f"{name} step {i}")
        await asyncio.sleep(delay)

async def main():
    await asyncio.gather(worker("fast", 0.1), worker("slow", 0.25))

asyncio.run(main())
```

*You should see:*

```text
fast step 0
slow step 0
fast step 1
fast step 2
slow step 1
slow step 2
```

## 38.4 tasks and TaskGroup

`asyncio.TaskGroup` starts tasks that run in the background, and waits for them all when its
block ends. If one fails, the others are cancelled and the error comes out — no task is left
running unnoticed:

```python
import asyncio

async def fetch(n):
    await asyncio.sleep(0.1 * n)
    return n * n

async def main():
    async with asyncio.TaskGroup() as tg:
        tasks = [tg.create_task(fetch(n)) for n in range(1, 6)]
    print([t.result() for t in tasks])

asyncio.run(main())
```

*You should see:*

```text
[1, 4, 9, 16, 25]
```
