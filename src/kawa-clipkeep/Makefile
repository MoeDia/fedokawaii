# src/kawa-clipkeep/Makefile — builds kawa-clipkeep. theme.sh copies this folder to a
# temporary one and runs make there, as you, with O= that folder (by hand: mkdir /tmp/k &&
# make O=/tmp/k). Needs gcc, make, pkgconf, wayland-devel (libwayland-client,
# wayland-scanner) — the packages that build dwl, kept installed for exactly this.
O        ?= .
SCANNER   = $(shell pkg-config --variable=wayland_scanner wayland-scanner)
CFLAGS   ?= -O2 -pipe
WFLAGS    = -std=c11 -Wall -Wextra $(shell pkg-config --cflags wayland-client)
WLIBS     = $(shell pkg-config --libs wayland-client)
P         = wlr-data-control-unstable-v1

$(O)/kawa-clipkeep: kawa-clipkeep.c $(O)/$(P)-client-protocol.h $(O)/$(P)-protocol.c
	$(CC) $(CFLAGS) $(WFLAGS) -I$(O) -o $@ kawa-clipkeep.c $(O)/$(P)-protocol.c $(LDFLAGS) $(WLIBS)

$(O)/$(P)-client-protocol.h: $(P).xml
	$(SCANNER) client-header $(P).xml $@

$(O)/$(P)-protocol.c: $(P).xml
	$(SCANNER) private-code $(P).xml $@

.PHONY: clean
clean:
	rm -f $(O)/kawa-clipkeep $(O)/$(P)-client-protocol.h $(O)/$(P)-protocol.c
