# src/kawa-lockmod/Makefile — builds kawa-lockmod, the lock screen's gtklock module (a shared
# library; theme.sh installs it as ~/.local/lib/fedokawaii/kawa-lockmod.so). theme.sh copies
# this folder to a temporary one and runs make there, as you, with O= that folder (by hand:
# mkdir /tmp/m && make O=/tmp/m). Needs gcc, make, pkgconf and gtk3-devel (GTK 3's headers:
# gtklock is a GTK 3 program, and the module runs inside it).
O        ?= .
CFLAGS   ?= -O2 -pipe
GFLAGS    = -std=c11 -Wall -Wextra -fPIC $(shell pkg-config --cflags gtk+-3.0)
GLIBS     = $(shell pkg-config --libs gtk+-3.0)

$(O)/kawa-lockmod: kawa-lockmod.c
	$(CC) $(CFLAGS) $(GFLAGS) -shared -o $@ kawa-lockmod.c $(LDFLAGS) $(GLIBS)

.PHONY: clean
clean:
	rm -f $(O)/kawa-lockmod
