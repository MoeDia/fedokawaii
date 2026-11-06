---
id: asobi-moves
title: games
part: programs
chapter: 18
minutes: 14
needs: [desks-session]
optional: no
---

**Best at:** playing, with nothing of yours in reach. ASOBI (遊び, *play*) is a second user on this
machine, `asobi`, on a screen of its own. Every game lives there: Steam, Proton, your saves, and
Bottles for other Windows programs, each in its Flatpak sandbox on top. It cannot read your home, it
cannot use `sudo`, it reaches the Internet and nothing of this house.

**Super+G** goes in. The world starts on demand: gamescope takes the card, at your monitor's 1080p and
144 Hz with FreeSync, and shows Steam's gamepad UI; your controller and your sound follow you there.
**Super+G** in there comes back, and your desktop never stopped. Behind the desktop a game is frozen
exactly where it was and costs nothing but its memory; Steam alone goes on working, so a download
finishes. Closing Steam from its own menu ends the world, and the *close* row below does the same. The
first time, Steam asks you to sign in: yours to do, nothing here stores it. The crossed-out signal at the
top of Steam's screen only says its sandbox cannot see this machine's network settings: it is online.

Everything else is one small window: Super+U → system → **asobi**.

| Row | Does |
|---|---|
| enter | the same as Super+G |
| bottles | the world with Bottles in front instead of Steam (one at a time: Steam closes first) |
| close | the world ended: Steam closes properly, its saves go to its cloud |
| snapshot now | the world as it is, kept: it costs no room until the world changes |
| reset to a snapshot | the world exactly as it was then; what it replaced stays as `before-reset` |
| disk use | what the world holds, and what is free |
| drop folder | `~/Drop`: the one folder you share. Put a file there, the world finds it there |

The snapshot called **clean** is the world as it was installed, and it never goes: whatever a Windows
program did in there, a reset ends it. These are not your system's snapshots (Super+U → snapshots) and
not your backups: the world's home is left out of both, games come again from Steam.

If a game will not start: in Steam's game page, the gear → Properties → Compatibility → force a Proton
version. ProtonDB (`protondb.com`) lists what others did for each game.

### exercises

**18.1 ★ In and out.** Press Super+G, wait for Steam, press it again. Run `kawa-asobi state` on the
desktop: what does it say, and what does it say with a game running?

**18.2 ★★ The one door.** Put a text file in `~/Drop`. In Bottles, open it with Notepad. Now try
to find your home from there.

**18.3 ★★ Undo a world.** Take a snapshot, install something small in Bottles, then reset. Is it gone?
