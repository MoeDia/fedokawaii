# src/kawa-saver/Makefile — builds kawa-saver, the screensaver. theme.sh copies this folder to
# a temporary one and runs make there, as you, with O= that folder (by hand: mkdir /tmp/s &&
# make O=/tmp/s). Needs gcc, make, pkgconf, wayland-devel (libwayland-client,
# wayland-scanner), wayland-protocols-devel and libpng-devel (cairo-devel's, for mako) — the packages
# that build dwl and mako, kept installed for exactly this. `make O=… render` also builds the
# world without a screen, for the tests and the renders (render.c): never installed.
O        ?= .
PROTOCOLS = $(shell pkg-config --variable=pkgdatadir wayland-protocols)
SCANNER   = $(shell pkg-config --variable=wayland_scanner wayland-scanner)
CFLAGS   ?= -O2 -pipe
WFLAGS    = -std=c11 -Wall -Wextra $(shell pkg-config --cflags wayland-client libpng)
WLIBS     = $(shell pkg-config --libs wayland-client libpng) -lm
XML       = wlr-layer-shell-unstable-v1=wlr-layer-shell-unstable-v1.xml \
            xdg-shell=$(PROTOCOLS)/stable/xdg-shell/xdg-shell.xml \
            viewporter=$(PROTOCOLS)/stable/viewporter/viewporter.xml
NAMES     = $(foreach x,$(XML),$(firstword $(subst =, ,$(x))))
GEN_H     = $(NAMES:%=$(O)/%-client-protocol.h)
GEN_C     = $(NAMES:%=$(O)/%-protocol.c)
xml_of    = $(lastword $(subst =, ,$(filter $(1)=%,$(XML))))

$(O)/kawa-saver: kawa-saver.c world.h $(GEN_H) $(GEN_C)
	$(CC) $(CFLAGS) $(WFLAGS) -I$(O) -o $@ kawa-saver.c $(GEN_C) $(LDFLAGS) $(WLIBS)

render: $(O)/kawa-saver-render
$(O)/kawa-saver-render: render.c world.h
	$(CC) $(CFLAGS) $(WFLAGS) -o $@ render.c $(LDFLAGS) $(WLIBS)

$(O)/%-client-protocol.h:
	$(SCANNER) client-header $(call xml_of,$*) $@

$(O)/%-protocol.c:
	$(SCANNER) private-code $(call xml_of,$*) $@

.PHONY: clean render
clean:
	rm -f $(O)/kawa-saver $(O)/kawa-saver-render $(GEN_H) $(GEN_C)
