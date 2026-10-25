# Goal
fedokawaii (github.com/MoeDia/fedokawaii, PUBLIC): scripts that turn Fedora 44 (Btrfs, "Custom OS") into a
retro-Japanese pixel dwl desktop for the owner (Mohamed Eldoush, PC user dia). He installs once, then never
changes code again: it must be rock solid, self-updating (3-month cycle), zero issues. This is the LAST round:
every issue he ever raised must be gone (0%).

Hardware: RX 9060 XT + Ryzen 5 9600X iGPU (610M), LG 1080p 144 Hz (HDMI-A-1, card1), BT dongle (controller),
Logitech G305, 61-key keyboard (no Print key).

# Standing rules (never violate)
- zero fallbacks; one tool per job; no redundancy; TUI over GUI; no Flatpak; Neovim only editor; Brave Origin only browser
- follow docs/design-system.md; every element deliberate; no redundant info in UI; menus spaced, sectioned (kanji+name heading)
- no "…" truncation; official icons or our own pixel seals
- performance and RAM paramount
- never ask the owner, decide myself; but keep him informed
- token-efficient, sequential, careful, deterministic work; perfection; treat every warning seriously
- visuals matter a lot: pixel-perfect alignment, coherence, consistency; both dark and light themes
- commit attribution: Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com> +
  Claude-Session: https://claude.ai/code/session_012aAfXDs8UWSfDAyN8E5kjg
- security: never use/store/repeat his password; keys only in ~/.config/fedokawaii/secrets.sh (600); never redraw Steam's logo
- (owner 22:08) Where a request or a better idea is blocked by a limitation of the software itself (mostly
  open source), patch/extend/write it ourselves — also for any problem tried before and not solved
  (e.g. boot flicker: plymouth/amdgpu/greetd hand-off; animations: dwl/wlroots; waybar limits; cursor states)
