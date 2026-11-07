---
id: calculator-downloads
title: Small tools of the desk
part: 1
minutes: 13
---
## idea
The calculator is qalc, and it understands units and money. Type calc in the launcher and the answer shows as you type: 5 ft to cm, 120 usd to aed. Enter copies the answer. Downloads arrive in ~/downloads, a folder for arrivals only: it is outside every snapshot, so move what you keep into ~/notes or ~/books and delete the rest. The folder is one path you will type often, and a terminal knows it as ~/downloads.

## exercise
Open the calculator by typing calc in the launcher. Ask 3.5 h to min and read the answer, then press Esc. In a terminal, run ls ~/downloads and look at what has arrived.

## check
```check
ask: Which folder holds what you download, outside every snapshot?
answer: ~/downloads
proof: grep -q '| `~/downloads/` | arrivals only | not in snapshots' docs/fedokawaii-guide.md
```
