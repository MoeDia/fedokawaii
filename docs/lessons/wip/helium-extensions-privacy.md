---
id: helium-extensions-privacy
title: Few extensions, few leaks
part: 1
minutes: 12
---
## idea
Helium comes with the browser's own extras removed: no wallet, no VPN, no news, no usage or crash reports. uBlock, which blocks ads and trackers, stays. Every extension you add can read the pages you visit, so the rule here is few: add one only when it does a job nothing else does. If a site misbehaves, the lion icon in the address bar changes the blocking for that one site, which is the first thing to try before blaming the browser. The settings under Privacy and security hold the data-collection switches; look at them once rather than assume.

## exercise
In Helium open a page with ads. Click the lion icon in the address bar and read what it says is blocked. Then open chrome://settings, search privacy and read the switches under Privacy and security. Change nothing unless you know why; Esc and Ctrl+W when done.

## check
```check
ask: What icon in the address bar changes the blocking for one site?
answer: lion
proof: grep -q 'The lion icon in the address bar' docs/fedokawaii-guide.md
```
