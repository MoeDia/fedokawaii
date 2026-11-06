---
id: py-weather
title: the weather; the Game of Life
part: python
chapter: 42
minutes: 6
needs: [py-flashcards]
optional: no
---

## 42.3 the weather, from a web API

```python
"""sky — the next hours' temperature, from Open-Meteo (no key needed)"""
import json
import urllib.request

URL = ("https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
       "&hourly=temperature_2m&forecast_hours=12&timezone=auto")

def hours(data: dict) -> list[tuple[str, float]]:
    h = data["hourly"]
    return [(t[-5:], c) for t, c in zip(h["time"], h["temperature_2m"])]

def main() -> None:
    with urllib.request.urlopen(URL.format(lat=25.35, lon=55.39), timeout=10) as r:
        data = json.load(r)
    for time, celsius in hours(data):
        print(f"{time}  {celsius:5.1f}°  {'▮' * round(celsius / 2)}")

if __name__ == "__main__":
    main()
```

*(25.35, 55.39 is Sharjah: put your own place. The test feeds `hours` a small dictionary shaped
like the answer — no network in tests)*

## 42.4 the Game of Life

A grid of cells; each step, a live cell with two or three live neighbours lives on, a dead cell
with exactly three comes alive. Simple rules, endless patterns.

```python
"""life — Conway's Game of Life in the terminal"""
import time

def step(live: set[tuple[int, int]]) -> set[tuple[int, int]]:
    near: dict[tuple[int, int], int] = {}
    for x, y in live:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    near[(x + dx, y + dy)] = near.get((x + dx, y + dy), 0) + 1
    return {c for c, n in near.items() if n == 3 or (n == 2 and c in live)}

def show(live: set[tuple[int, int]], w: int = 40, h: int = 20) -> str:
    return "\n".join("".join("█" if (x, y) in live else "·" for x in range(w)) for y in range(h))

if __name__ == "__main__":
    cells = {(1, 0), (2, 1), (0, 2), (1, 2), (2, 2)}            # a glider
    for _ in range(60):
        print("\033[H\033[J" + show(cells))
        cells = step(cells)
        time.sleep(0.1)
```

**Test it:** a *blinker* — three cells in a row — turns into three in a column and back:
`assert step({(0, 1), (1, 1), (2, 1)}) == {(1, 0), (1, 1), (1, 2)}`.
