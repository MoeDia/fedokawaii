---
id: py-lists-projects
title: projects
part: python
chapter: 29
minutes: 180
needs: [py-lists-practice]
optional: yes
---

**29.7 ★★★ Remove duplicates, keep order.** `unique([3, 1, 3, 2, 1])` returns `[3, 1, 2]`.

<!-- solution 29.7 -->
```python
def unique(items):
    seen = []
    for x in items:
        if x not in seen:
            seen.append(x)
    return seen

print(unique([3, 1, 3, 2, 1]))
```

*You should see:*

```text
[3, 1, 2]
```
<!-- /solution -->

**29.8 ★★★ Rotate.** `rotate(items, k)` moves the last `k` items to the front, with slices.
*Expected:* `rotate([1, 2, 3, 4, 5], 2)` → `[4, 5, 1, 2, 3]`.

<!-- solution 29.8 -->
```python
def rotate(items, k):
    k = k % len(items)
    return items[-k:] + items[:-k]

print(rotate([1, 2, 3, 4, 5], 2))
print(rotate([1, 2, 3, 4, 5], 7))
```

*You should see:*

```text
[4, 5, 1, 2, 3]
[4, 5, 1, 2, 3]
```
<!-- /solution -->

**29.9 ★★★★ Tic-tac-toe winner.** A board is a list of three lists of `"X"`, `"O"` or `" "`. Write `winner(board)` returning `"X"`,
`"O"` or `None`: check rows, columns and both diagonals.

<!-- solution 29.9 -->
```python
def winner(board):
    lines = [row for row in board]
    lines += [[board[r][c] for r in range(3)] for c in range(3)]
    lines.append([board[i][i] for i in range(3)])
    lines.append([board[i][2 - i] for i in range(3)])
    for line in lines:
        if line[0] != " " and line.count(line[0]) == 3:
            return line[0]
    return None

board = [["X", "O", " "],
         ["O", "X", " "],
         ["O", " ", "X"]]
print(winner(board))
print(winner([[" "] * 3 for _ in range(3)]))
```

*You should see:*

```text
X
None
```
<!-- /solution -->
