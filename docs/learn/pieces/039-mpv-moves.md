---
id: mpv-moves
title: video and sound
part: programs
chapter: 16
minutes: 12
needs: [desks-session]
optional: no
---

**Best at:** playing anything — files, links, playlists — with the keyboard, and keeping your
place. `mpv URL` plays a YouTube link directly (yt-dlp fetches it).

<!-- fig:app-mpv | mpv, its controls shown on the picture. -->

| Keys | Does |
|---|---|
| **Space** | pause |
| **←** **→** · **↑** **↓** | 5 s · 1 min |
| **[** **]** · **Backspace** | slower · faster · normal speed |
| **v** · **j** · **#** | subtitles on/off · next subtitle track · next audio track |
| **z** · **Z** | subtitles earlier · later |
| **s** | a screenshot of the frame |
| **Ctrl+P** | a menu of everything |
| **q** | quit, keeping the position |

| Command | Does |
|---|---|
| `mpv "https://youtu.be/…"` | play a web video |
| `yt-dlp "URL"` | keep it, in the best quality |
| `yt-dlp -x --audio-format opus "URL"` | the sound only |
| `mpv --speed=1.5 lecture.mp4` | a lecture at 1.5× |

**Syncplay:** a film with a friend elsewhere, each from your own copy. In yazi, **W** on the
film; agree on a room name; one person's pause pauses both. **Enter** in mpv chats.

### exercises

**16.1 ★ A lecture faster.** Play a long talk at 1.5× and slow it back with **Backspace**.

**16.2 ★★ Keep the audio.** Download a talk's sound as Opus and play it in mpv.

**16.3 ★★ Together.** Watch a short film with a friend through Syncplay.
