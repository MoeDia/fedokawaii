# src/kawa-saver/Makefile — builds kawa-saver, the screensaver. theme.sh copies this folder to
# a temporary one and runs make there, as you, with O= that folder (by hand: mkdir /tmp/s &&
# make O=/tmp/s). Needs gcc, make, pkgconf, wayland-devel (libwayland-client,
# wayland-scanner) and wayland-protocols-devel — the packages that build dwl, kept installed
# for exactly this.
O        ?= .
PROTOCOLS = $(shell pkg-config --variable=pkgdatadir wayland-protocols)
SCANNER   = $(shell pkg-config --variable=wayland_scanner wayland-scanner)
CFLAGS   ?= -O2 -pipe
WFLAGS    = -std=c11 -Wall -Wextra $(shell pkg-config --cflags wayland-client)
WLIBS     = $(shell pkg-config --libs wayland-client)
XML       = wlr-layer-shell-unstable-v1=wlr-layer-shell-unstable-v1.xml \
            xdg-shell=$(PROTOCOLS)/stable/xdg-shell/xdg-shell.xml \
            alpha-modifier-v1=$(PROTOCOLS)/staging/alpha-modifier/alpha-modifier-v1.xml
NAMES     = $(foreach x,$(XML),$(firstword $(subst =, ,$(x))))
GEN_H     = $(NAMES:%=$(O)/%-client-protocol.h)
GEN_C     = $(NAMES:%=$(O)/%-protocol.c)
xml_of    = $(lastword $(subst =, ,$(filter $(1)=%,$(XML))))

$(O)/kawa-saver: kawa-saver.c glyphs.h $(GEN_H) $(GEN_C)
	$(CC) $(CFLAGS) $(WFLAGS) -I$(O) -o $@ kawa-saver.c $(GEN_C) $(LDFLAGS) $(WLIBS)

$(O)/%-client-protocol.h:
	$(SCANNER) client-header $(call xml_of,$*) $@

$(O)/%-protocol.c:
	$(SCANNER) private-code $(call xml_of,$*) $@

.PHONY: clean
clean:
	rm -f $(O)/kawa-saver $(GEN_H) $(GEN_C)
