---
id: py-tests-projects
title: projects
part: python
chapter: 35
minutes: 180
needs: [py-tests-practice]
optional: yes
---

**35.7 ★★★ Test first: Roman numerals.** Write tests first for `roman(n)`: 1 → I, 4 → IV, 9 → IX, 14 → XIV, 40 → XL, 1994 → MCMXCIV,
2026 → MMXXVI. Then make them pass.

<!-- solution 35.7 -->
```python
def roman(n):
    table = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
             (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    out = ""
    for value, sym in table:
        while n >= value:
            out += sym
            n -= value
    return out

for n, r in [(1, "I"), (4, "IV"), (9, "IX"), (14, "XIV"), (40, "XL"), (1994, "MCMXCIV"), (2026, "MMXXVI")]:
    assert roman(n) == r, (n, roman(n))
print("all 7 pass")
```

*You should see:*

```text
all 7 pass
```
<!-- /solution -->

**35.8 ★★★ A fixture of your own.** Write a pytest fixture `basket` (with `@pytest.fixture`) that returns a `Basket` holding two
items, and two tests that use it.

<!-- solution 35.8 -->
```python
import pytest
from shop import Basket, Item

@pytest.fixture
def basket():
    b = Basket()
    b.items += [Item("rice", 7.25, 3), Item("tea", 12.5)]
    return b

def test_total(basket):
    assert basket.total() == pytest.approx(34.25)

def test_two_items(basket):
    assert len(basket.items) == 2
```
*(each test receives a new basket: changing it in one test cannot affect another)*
<!-- /solution -->

**35.9 ★★★★ Tests for the expense tracker.** Write a `test_ledger.py` for level 3's checkpoint: `parse` (good line, three bad shapes,
parametrized), `totals`, and a `save`-then-`load` round trip through `tmp_path`. Aim for
every function covered; run `uv add --dev pytest-cov` and `uv run pytest --cov` to see how much
of `ledger.py` the tests run.

<!-- solution 35.9 -->
```python
import pytest
from ledger import load, parse, save, totals

def test_parse_good():
    assert parse("2026-10-21 food 32.5") == {"date": "2026-10-21", "category": "food", "amount": 32.5}

@pytest.mark.parametrize("line", ["", "lunch", "2026-10-21 food", "2026-10-21 food x"])
def test_parse_bad(line):
    with pytest.raises(ValueError):
        parse(line)

def test_totals():
    rows = [parse("d food 1"), parse("d food 2"), parse("d taxi 5")]
    assert totals(rows) == {"food": 3, "taxi": 5}

def test_round_trip(tmp_path):
    rows = [parse("2026-10-21 food 32.5")]
    save(tmp_path / "e.csv", rows)
    assert load(tmp_path / "e.csv") == rows

def test_missing_file(tmp_path):
    assert load(tmp_path / "none.csv") == []
```
*(8 tests; `--cov` should report 100 % of `ledger.py`)*
<!-- /solution -->
