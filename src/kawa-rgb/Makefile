# src/kawa-rgb/Makefile — builds kawa-rgb, the lights' one tool. theme.sh copies this folder to a
# temporary one and runs make there, as you, with O= that folder (by hand: mkdir /tmp/r && make
# O=/tmp/r), then root takes the one file in as /usr/local/bin/kawa-rgb. Needs gcc and make, the
# packages that build dwl, kept installed for exactly this; no libraries but the C library's.
O        ?= .
CFLAGS   ?= -O2 -pipe
WFLAGS    = -std=c11 -Wall -Wextra

$(O)/kawa-rgb: kawa-rgb.c
	$(CC) $(CFLAGS) $(WFLAGS) -o $@ kawa-rgb.c $(LDFLAGS) -lm

.PHONY: clean
clean:
	rm -f $(O)/kawa-rgb
