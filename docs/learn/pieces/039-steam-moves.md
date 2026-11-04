---
id: steam-moves
title: games
part: programs
chapter: 18
minutes: 7
needs: [desks-session]
optional: no
---

**Best at:** Windows games on Linux through Proton. The gamepad in the bar shows Steam is on;
right-click it for its menu.

| Launch option (right-click a game → Properties) | Does |
|---|---|
| `gamemoderun %command%` | the processor tuned for the game |
| `mangohud %command%` | the overlay: frames per second, temperatures (**Right Shift+F12**) |
| `gamescope -W 2560 -H 1440 -r 144 -f -- %command%` | the game in its own compositor, fixed size and rate |

If a game will not start: Properties → Compatibility → force a Proton version (GE-Proton is
installed). ProtonDB (`protondb.com`) lists what others did for each game.

### exercises

**18.1 ★ The overlay.** Add `mangohud %command%` to a game and find its frame rate.

**18.2 ★★ Compare.** Play a minute with and without `gamemoderun` and compare the frame rate.
