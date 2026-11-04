# iso/inputs.sh — what tools/build-iso.sh builds from, every input pinned: the same inputs and the
# same commit give the same bytes. The release is the newest stable Fedora fedokawaii has proven
# (.claude/notes/iso-design.md §1); a new one is a new pin here, after its VM pre-flight.
# Sources, 4 Nov 2026: https://fedoraproject.org/releases.json (netinst link and checksum),
# dl.fedoraproject.org's releases/45 tree (the RPMs: the same compose as the netinst's kernel and
# Plymouth, sha256sum of each file).
# shellcheck shell=bash disable=SC2034
ISO_RELEASE=45
ISO_NETINST=Fedora-Server-netinst-x86_64-45-1.4.iso
ISO_NETINST_URL=https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Server/x86_64/iso/$ISO_NETINST
ISO_NETINST_SHA256=a1e916f139a05955b943cf183b020780cca9c399b02b8f5ec4354c9e5c1dff1a
ISO_VOLID=Fedora-S-dvd-x86_64-45     # (Fedora's own: inst.stage2 and GRUB's search depend on it)
ISO_RPM_URL=https://dl.fedoraproject.org/pub/fedora/linux/releases/45/Everything/x86_64/os/Packages
# NAME SHA256: the boot splash's graphics in the installer's first stage (its initrd has none: Plymouth
# 26's script plugin dies on a NULL console viewer, its "text rendering isn't working", without a label
# plugin and a font: the plugin, freetype, its own libraries) and implantisomd5, run from the unpacked
# package: nothing is installed on the builder
ISO_RPMS=(
  "plymouth-graphics-libs-26.134.222-6.fc45.x86_64.rpm 8ef0adb7c8f59d61b04d1ac13e27edabdec3154f3be4a9ddcd807900a3430eab"
  "plymouth-plugin-script-26.134.222-6.fc45.x86_64.rpm 9316587eead077cf5f37b983cf193b7094c860aeeb5a89e196d61426ef570077"
  "libpng-1.6.58-2.fc45.x86_64.rpm 50d53362cea5de0a13caaa1bbcb8f835b6b894e49a7844c6571eeb5c0d64fb34"
  "libdrm-2.4.134-2.fc45.x86_64.rpm b6b6575c734d899dd25c2c6af93ce14195f2143467973f4544865371b6fc74f9"
  "isomd5sum-1.2.5-9.fc45.x86_64.rpm 91e157072788f1e4b3f2757536cb42aaf1447cb04e689381d7eae40e09c53380"
  "plymouth-plugin-label-26.134.222-6.fc45.x86_64.rpm 34af9fdcca7c080537f4025ae8b1cbffc264a400c01bd8bd5b0dadcad4855c3d"
  "freetype-2.14.3-2.fc45.x86_64.rpm f78539a886319f7d6c01c353fa517f84a77c75e75fe74c90fc4981071680cd04"
  "harfbuzz-14.5.0-1.fc45.x86_64.rpm 9ee65bffa2bda682f7565463ba24c4f40d92faa9f0b3d52549c9c75fadda9cc1"
  "graphite2-1.3.14-22.fc45.x86_64.rpm 08cd675bdea4dab2021ee29f8d5a25407b5a94cec78cfa98d889c1b43a32ae6f"
)
