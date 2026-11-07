---
id: debugging-bisect
title: Cut the problem in halves
part: 2
minutes: 15
needs: [debugging-prints]
---
## idea
When the bug could be anywhere in a long program, check the middle. If the value is already wrong there, the bug lies in the first half; if it is right, in the second. Cut again. Ten steps find one line among a thousand. The same idea works on a pipeline in the shell: run the first half of the commands and look at what comes out.

```python
data = "3 1 two 4"
nums = data.split()
nums = [int(x) for x in nums]
print(sum(nums))
```

This stops with a ValueError. Print nums after split: the list is fine. The cut is the int line, and the word "two" is what it cannot read.

## exercise
In ~/dojo/py write cut.py with the code above and run it to see the error. Fix the data, not the code: change "two" to 2.

## check
```check
run: python3 cut.py
in: py
expect: 10
```

## answer
The halves told you the split worked and the conversion failed, so the data was the problem.

```file cut.py
data = "3 1 2 4"
nums = data.split()
nums = [int(x) for x in nums]
print(sum(nums))
```
