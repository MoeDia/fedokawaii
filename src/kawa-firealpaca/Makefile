# src/kawa-firealpaca/Makefile — builds kawa-firealpaca, what dresses FireAlpaca as the desktop (a
# shared library kawa-sketch loads into it; theme.sh installs it as
# ~/.local/lib/fedokawaii/kawa-firealpaca.so). theme.sh copies this folder to a temporary one and
# runs make there, as you, with O= that folder (by hand: mkdir /tmp/m && make O=/tmp/m). Needs gcc
# and make; no Qt headers: it reaches Qt through its exported functions.
O        ?= .
CFLAGS   ?= -O2 -pipe
FAFLAGS   = -std=gnu11 -Wall -Wextra -fPIC

$(O)/kawa-firealpaca: kawa-firealpaca.c
	$(CC) $(CFLAGS) $(FAFLAGS) -shared -o $@ kawa-firealpaca.c $(LDFLAGS) -ldl -lpthread

.PHONY: clean
clean:
	rm -f $(O)/kawa-firealpaca
