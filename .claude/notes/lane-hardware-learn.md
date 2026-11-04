# Learn pieces from lane-hardware (for docs/fedokawaii-learn.md, the book update on the owner's word)

Written to the book's voice; each is one lesson. Numbers are measured on this PC, 4 Nov 2026. T36's plan asks
for a piece "lights", T38's for a piece "monitor". Not added to the book by this lane: lane-learning owns the
cut (`docs/learn/syllabus.txt`, `tools/learn-pieces.py`), and the book's update waits for the owner's word.

## The lights

Every light in your PC is one steady red: the Gigabyte logo, the fans and the hub, the cooler, the keyboard.
They do not move, and while nothing changes they cost no CPU and no bus traffic. They change on four events:

| When | They |
|---|---|
| the lock screen comes up | fade to about 30 % |
| the screens go off (also the monitor's own button), or the PC sleeps | go out, the cooler's display too |
| you unlock, or the PC wakes | come back to full |
| you press the lights' row in quick settings (Super+X) | go off or on, and stay that way across reboots |

One program does it all, `kawa-rgb`, running as a system service (`systemctl status kawa-rgb`). It speaks to each
device in that device's own small protocol: the motherboard's Mystic Light and the keyboard over USB, the card's
logo over its I2C bus. The fans, the hub and the cooler's fan take their colour from the motherboard's header.

**Why a service of the system's, and not yours.** The keyboard's USB node also carries your keystrokes. Giving your
session access to it would let any program of yours read every key you type. The service runs alone with that
access, it has no capabilities and no network, and it never reads from that node.

**Each device has its own red.** Brands render the same numbers differently, so `/etc/fedokawaii/rgb.conf` holds a
value per device (`NAME R G B`) and they look alike. The file comes from the repository.

**Off is off.** Each device also keeps a colour in its own memory, which it shows from power-on until the service
starts. The switch writes that memory too, so a PC with its lights off stays dark from the first second. Flash wears
out, so the service reads first and writes only when something differs.

**The cooler's little display** shows the CPU's temperature, averaged over a few seconds. It is a USB device that
calls itself a keyboard and has no keys; the service sends it the number, in the report the maker's own software
uses, once a second. It goes out with the lights: sent digits it does not know, it shows none.

To see what the service found: `kawa-rgb status`.

## The monitor

Your monitor is an LG 24G411A-B. Its own menu can be set from the PC, over a channel in the HDMI cable (DDC/CI);
that is how brightness already works. `~/.config/fedokawaii/monitor.conf` lists what the desktop wants, and at
every login and every wake `kawa-display --monitor` reads each value and writes it only if it differs. So a factory
reset of the monitor comes back to this by itself.

| Setting | Value | Why |
|---|---|---|
| colour preset | sRGB | the desktop's palette is drawn in sRGB; the panel's own colours run about 20 % wider, so reds run hot in its other presets |
| contrast | 70 | the maker's default |
| red, green, blue gain and black level | 50 each | the maker's defaults |

No colorimeter has measured this panel, and a screenshot cannot see what the panel does: it happens after the picture
leaves the card. So these are the maker's and the standard's values, not a calibration. No colour profile is
applied, because there is no measurement to build one from.

**What is not set from here.** Response time, Black Stabilizer and FreeSync's own switch are not offered over this
channel; they stay in the monitor's menu, at its joystick. LG's private codes are left alone: nothing on the PC could
tell what writing them did, and other people's LG monitors have needed a factory reset after such experiments.

**FreeSync.** It works, and it was measured on this PC: with a window full screen, 100 fps gave 10.0 ms between
frames, 60 fps gave 16.67 ms, and 40 fps gave 25.0 ms, each following the picture. With FreeSync off, the same 100 fps
landed on whole refreshes, 6.94 or 13.89 ms apart. The monitor's own report of its refresh stays at 143.90 Hz either
way, so it is no witness; the times come from dwl. Its range is 48 to 144 Hz.

The desktop keeps FreeSync on while a window is full screen, and off otherwise. A full-screen video benefits: 60 fps
on a fixed 144 Hz screen cannot be even (144 / 60 = 2.4), so its frames are held unevenly. Quick settings (Super+X)
cycles it: full screen, always, off. `fedokawaii freesync` shows what the card is doing this moment.

**Switched off at its own button**, or dropped off the cable while asleep, the monitor comes back to the same
workspace, layout, focused window and refresh rate.
