/*
 * kawa-clipkeep — what you copy stays on the clipboard after the window you copied it
 * from is closed.
 *
 * On Wayland a copy is a promise: the app that copied hands the data over only when
 * something pastes, so closing that app empties the clipboard. kawa-clipkeep watches the
 * clipboard (wlr-data-control), reads every format of each new copy into memory as soon
 * as it is made, and — only when the clipboard is then emptied because its owner went
 * away — offers that copy again itself, in all its formats. While the app that copied is
 * open nothing changes: it keeps serving its own copy, and nothing is ever taken from it.
 *
 * Not kept: a copy a password manager marks as secret (x-kde-passwordManagerHint), one
 * bigger than 64 MiB in all, and the primary selection (select + middle-click). A format
 * that is not delivered within 3 s is left out; a pasting app that stops reading for 5 s
 * is let go. Started (and kept running) by ~/.config/dwl/autostart.sh; exits when the
 * compositor goes away. Built by theme.sh (src/kawa-clipkeep/Makefile) with the tools
 * that build dwl.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-data-control-unstable-v1-client-protocol.h"

#define MARK "application/x-kawa-clipkeep"   /* on our own copy, so we know it again */
#define SECRET "x-kde-passwordManagerHint"
#define MAX_TYPES 64
#define MAX_TOTAL ((size_t)64 << 20)
#define READ_MS 3000
#define WRITE_MS 5000
#define MAX_WRITERS 32

struct blob { char *mime; char *data; size_t len; };
struct copy { int refs; size_t n; struct blob b[MAX_TYPES]; };     /* a finished copy */
struct offer { struct zwlr_data_control_offer_v1 *o; size_t n; char *mime[MAX_TYPES]; bool mark, secret; };
struct reader { int fd; size_t cap; bool done; };
struct capture {                         /* a copy being read: one pipe per format */
	struct offer *of;
	struct copy *c;
	struct reader r[MAX_TYPES];
	size_t open, total;
	long long deadline;
};
struct writer { int fd; struct copy *c; size_t i, off; long long deadline; };

static struct wl_display *dpy;
static struct wl_seat *seat;
static struct zwlr_data_control_manager_v1 *mgr;
static struct zwlr_data_control_device_v1 *dev;
static struct offer *pending;            /* announced, not yet the selection */
static struct capture *cap;
static struct copy *kept;                /* the last copy read in full */
static bool kept_current;                /* …and it is the one on the clipboard now */
static bool vanished;                    /* the clipboard was emptied while reading */
static bool ours_shown;                  /* our own copy is the one on the clipboard */
static struct zwlr_data_control_source_v1 *own;
static struct writer writers[MAX_WRITERS];
static size_t nwriters;

static long long
now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (long long)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static void
copy_unref(struct copy *c)
{
	if (!c || --c->refs > 0)
		return;
	for (size_t i = 0; i < c->n; i++) {
		free(c->b[i].mime);
		free(c->b[i].data);
	}
	free(c);
}

static void
offer_free(struct offer *of)
{
	if (!of)
		return;
	if (of->o)
		zwlr_data_control_offer_v1_destroy(of->o);
	for (size_t i = 0; i < of->n; i++)
		free(of->mime[i]);
	free(of);
}

/* ── our own copy, offered again once the clipboard was emptied ─────────────── */

static void
writer_close(size_t k)
{
	close(writers[k].fd);
	copy_unref(writers[k].c);
	writers[k] = writers[--nwriters];
}

static void
source_send(void *data, struct zwlr_data_control_source_v1 *src, const char *mime, int32_t fd)
{
	struct copy *c = data;
	(void)src;
	for (size_t i = 0; i < c->n; i++) {
		if (strcmp(c->b[i].mime, mime) != 0)
			continue;
		if (nwriters == MAX_WRITERS) {   /* all taken by pastes that stopped reading: */
			size_t old = 0;              /* the one stalled longest gives way */
			for (size_t k = 1; k < nwriters; k++)
				if (writers[k].deadline < writers[old].deadline)
					old = k;
			writer_close(old);
		}
		fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
		c->refs++;
		writers[nwriters++] = (struct writer){ fd, c, i, 0, now_ms() + WRITE_MS };
		return;
	}
	close(fd);                       /* our mark, or a format we do not have */
}

static void
source_cancelled(void *data, struct zwlr_data_control_source_v1 *src)
{
	zwlr_data_control_source_v1_destroy(src);
	copy_unref(data);
	if (src == own)
		own = NULL;
}

static const struct zwlr_data_control_source_v1_listener source_listener = {
	.send = source_send,
	.cancelled = source_cancelled,
};

static void
offer_again(void)
{
	if (!kept || !kept_current || own)
		return;
	own = zwlr_data_control_manager_v1_create_data_source(mgr);
	kept->refs++;
	zwlr_data_control_source_v1_add_listener(own, &source_listener, kept);
	for (size_t i = 0; i < kept->n; i++)
		zwlr_data_control_source_v1_offer(own, kept->b[i].mime);
	zwlr_data_control_source_v1_offer(own, MARK);
	zwlr_data_control_device_v1_set_selection(dev, own);
}

/* ── reading a new copy ──────────────────────────────────────────────────────── */

static void
capture_end(bool keep)
{
	if (!cap)
		return;
	for (size_t i = 0; i < cap->of->n; i++)
		if (!cap->r[i].done && cap->r[i].fd >= 0)
			close(cap->r[i].fd);
	if (keep) {                      /* only the formats that arrived whole, and not empty */
		size_t n = 0;
		for (size_t i = 0; i < cap->c->n; i++) {
			if (cap->r[i].done && cap->c->b[i].len > 0)
				cap->c->b[n++] = cap->c->b[i];
			else {
				free(cap->c->b[i].mime);
				free(cap->c->b[i].data);
			}
		}
		cap->c->n = n;
		keep = n > 0;
	}
	if (keep) {
		copy_unref(kept);
		kept = cap->c;
		kept_current = true;
	} else {
		copy_unref(cap->c);
	}
	offer_free(cap->of);
	free(cap);
	cap = NULL;
	if (keep && vanished)            /* emptied while it was being read */
		offer_again();
	vanished = false;
}

static bool
ignored_type(const char *m)
{
	/* X11 bookkeeping targets, not data */
	static const char *const skip[] = { "TARGETS", "MULTIPLE", "TIMESTAMP", "SAVE_TARGETS", "DELETE", NULL };
	for (size_t i = 0; skip[i]; i++)
		if (strcmp(m, skip[i]) == 0)
			return true;
	return false;
}

static void
capture_start(struct offer *of)
{
	cap = calloc(1, sizeof *cap);
	struct copy *c = calloc(1, sizeof *c);
	if (!cap || !c) {
		free(cap);
		free(c);
		cap = NULL;
		offer_free(of);
		return;
	}
	c->refs = 1;
	cap->of = of;
	cap->c = c;
	cap->deadline = now_ms() + READ_MS;
	for (size_t i = 0; i < of->n; i++) {
		int p[2];
		c->b[i].mime = strdup(of->mime[i]);
		c->n = i + 1;
		cap->r[i] = (struct reader){ -1, 0, true };
		if (!c->b[i].mime || ignored_type(of->mime[i]) || pipe2(p, O_CLOEXEC) < 0) {
			cap->r[i].done = false;          /* left out */
			continue;
		}
		/* only our end is non-blocking: the app writes into the other end as it would
		 * into any paste, and a plain write loop meeting EAGAIN would stop early */
		if (fcntl(p[0], F_SETFL, O_NONBLOCK) < 0) {
			close(p[0]);
			close(p[1]);
			cap->r[i].done = false;
			continue;
		}
		zwlr_data_control_offer_v1_receive(of->o, of->mime[i], p[1]);
		close(p[1]);
		cap->r[i] = (struct reader){ p[0], 0, false };
		cap->open++;
	}
	wl_display_flush(dpy);
	if (cap->open == 0)
		capture_end(false);
}

/* read what has arrived for format i; true once it is complete (or given up) */
static void
capture_read(size_t i)
{
	struct reader *r = &cap->r[i];
	struct blob *b = &cap->c->b[i];
	for (;;) {
		if (b->len == r->cap) {
			size_t cap2 = r->cap ? r->cap * 2 : 4096;
			char *d = realloc(b->data, cap2);
			if (!d)
				goto fail;
			b->data = d;
			r->cap = cap2;
		}
		ssize_t n = read(r->fd, b->data + b->len, r->cap - b->len);
		if (n > 0) {
			b->len += (size_t)n;
			cap->total += (size_t)n;
			if (cap->total > MAX_TOTAL) {   /* too big to keep: the whole copy */
				capture_end(false);
				return;
			}
			continue;
		}
		if (n == 0) {                   /* complete */
			close(r->fd);
			r->fd = -1;
			r->done = true;
			cap->open--;
			if (cap->open == 0)
				capture_end(true);
			return;
		}
		if (errno == EINTR)
			continue;
		if (errno == EAGAIN)
			return;
		goto fail;
	}
fail:
	close(r->fd);
	r->fd = -1;                             /* this format is left out */
	cap->open--;
	if (cap->open == 0)
		capture_end(true);
}

/* ── the clipboard's events ──────────────────────────────────────────────────── */

static void
offer_type(void *data, struct zwlr_data_control_offer_v1 *o, const char *mime)
{
	struct offer *of = data;
	(void)o;
	if (strcmp(mime, MARK) == 0)
		of->mark = true;
	else if (strcmp(mime, SECRET) == 0)
		of->secret = true;
	else if (of->n < MAX_TYPES && (of->mime[of->n] = strdup(mime)))
		of->n++;
}

static const struct zwlr_data_control_offer_v1_listener offer_listener = { .offer = offer_type };

static void
device_offer(void *data, struct zwlr_data_control_device_v1 *d, struct zwlr_data_control_offer_v1 *o)
{
	(void)data; (void)d;
	struct offer *of = calloc(1, sizeof *of);
	if (!of) {
		zwlr_data_control_offer_v1_destroy(o);
		return;
	}
	of->o = o;
	zwlr_data_control_offer_v1_add_listener(o, &offer_listener, of);
	offer_free(pending);
	pending = of;
}

static void
device_selection(void *data, struct zwlr_data_control_device_v1 *d, struct zwlr_data_control_offer_v1 *o)
{
	(void)data; (void)d;
	struct offer *of = pending && pending->o == o ? pending : NULL;
	if (of)
		pending = NULL;
	if (!o) {
		if (ours_shown) {               /* our own copy, cleared on purpose: let it be */
			ours_shown = false;
			kept_current = false;
		} else if (cap) {               /* emptied while being read: decided at its end */
			vanished = true;
		} else {                        /* emptied because its owner closed */
			offer_again();
		}
		return;
	}
	ours_shown = false;
	if (!of) {                              /* not one we were told about */
		zwlr_data_control_offer_v1_destroy(o);
		return;
	}
	if (of->mark) {                         /* our own copy, back on the clipboard */
		ours_shown = true;
		offer_free(of);
		return;
	}
	capture_end(false);                     /* a newer copy replaces one still being read */
	kept_current = false;
	if (own) {                              /* someone copied: ours is not needed now */
		copy_unref(zwlr_data_control_source_v1_get_user_data(own));
		zwlr_data_control_source_v1_destroy(own);
		own = NULL;
	}
	if (of->secret) {                       /* a password: never kept */
		copy_unref(kept);
		kept = NULL;
		offer_free(of);
		return;
	}
	capture_start(of);
}

static void
device_finished(void *data, struct zwlr_data_control_device_v1 *d)
{
	(void)data; (void)d;
	exit(1);                                /* the seat is gone */
}

static const struct zwlr_data_control_device_v1_listener device_listener = {
	.data_offer = device_offer,
	.selection = device_selection,
	.finished = device_finished,
};

static void
registry_global(void *data, struct wl_registry *reg, uint32_t name, const char *iface, uint32_t version)
{
	(void)data; (void)version;
	if (!seat && strcmp(iface, wl_seat_interface.name) == 0)
		seat = wl_registry_bind(reg, name, &wl_seat_interface, 1);
	else if (strcmp(iface, zwlr_data_control_manager_v1_interface.name) == 0)
		mgr = wl_registry_bind(reg, name, &zwlr_data_control_manager_v1_interface, 1);
}

static void
registry_remove(void *data, struct wl_registry *reg, uint32_t name)
{
	(void)data; (void)reg; (void)name;
}

static const struct wl_registry_listener registry_listener = {
	.global = registry_global,
	.global_remove = registry_remove,
};

/* ── the loop ────────────────────────────────────────────────────────────────── */

int
main(void)
{
	signal(SIGPIPE, SIG_IGN);                /* a pasting app that closed its end */
	if (!(dpy = wl_display_connect(NULL))) {
		fputs("kawa-clipkeep: no Wayland display\n", stderr);
		return 1;
	}
	struct wl_registry *reg = wl_display_get_registry(dpy);
	wl_registry_add_listener(reg, &registry_listener, NULL);
	wl_display_roundtrip(dpy);
	if (!seat || !mgr) {
		fputs("kawa-clipkeep: the compositor offers no clipboard control (wlr-data-control)\n", stderr);
		return 1;
	}
	dev = zwlr_data_control_manager_v1_get_data_device(mgr, seat);
	zwlr_data_control_device_v1_add_listener(dev, &device_listener, NULL);

	struct pollfd p[1 + MAX_TYPES + MAX_WRITERS];
	int who[1 + MAX_TYPES + MAX_WRITERS];   /* reader index, or -1 - writer index */
	for (;;) {
		while (wl_display_prepare_read(dpy) != 0)
			if (wl_display_dispatch_pending(dpy) < 0)
				return 1;
		if (wl_display_flush(dpy) < 0 && errno != EAGAIN) {
			wl_display_cancel_read(dpy);
			return 1;
		}
		nfds_t n = 0;
		p[n++] = (struct pollfd){ wl_display_get_fd(dpy), POLLIN, 0 };
		long long t = now_ms(), wake = -1;
		if (cap) {
			for (size_t i = 0; i < cap->of->n; i++)
				if (!cap->r[i].done && cap->r[i].fd >= 0) {
					who[n] = (int)i;
					p[n++] = (struct pollfd){ cap->r[i].fd, POLLIN, 0 };
				}
			wake = cap->deadline;
		}
		for (size_t k = 0; k < nwriters; k++) {
			who[n] = -1 - (int)k;
			p[n++] = (struct pollfd){ writers[k].fd, POLLOUT, 0 };
			if (wake < 0 || writers[k].deadline < wake)
				wake = writers[k].deadline;
		}
		int timeout = wake < 0 ? -1 : wake <= t ? 0 : (int)(wake - t);
		if (poll(p, n, timeout) < 0 && errno != EINTR) {
			wl_display_cancel_read(dpy);
			return 1;
		}
		if (p[0].revents & (POLLERR | POLLHUP)) {
			wl_display_cancel_read(dpy);
			return 0;                        /* the compositor is gone */
		}
		if (p[0].revents & POLLIN) {
			if (wl_display_read_events(dpy) < 0)
				return 1;
		} else {
			wl_display_cancel_read(dpy);
		}
		/* the fds polled above may have changed while events ran: match them again */
		struct capture *seen = cap;
		for (nfds_t k = 1; k < n && cap == seen && cap; k++) {
			if (who[k] < 0 || !(p[k].revents & (POLLIN | POLLHUP | POLLERR)))
				continue;
			size_t i = (size_t)who[k];
			if (!cap->r[i].done && cap->r[i].fd == p[k].fd)
				capture_read(i);
		}
		for (size_t k = nwriters; k-- > 0;) {
			struct writer *w = &writers[k];
			struct blob *b = &w->c->b[w->i];
			ssize_t m = 0;
			if (w->off < b->len)
				m = write(w->fd, b->data + w->off, b->len - w->off);
			if (m > 0) {
				w->off += (size_t)m;
				w->deadline = now_ms() + WRITE_MS;
			}
			if (w->off >= b->len || (m < 0 && errno != EAGAIN && errno != EINTR)
			    || now_ms() > w->deadline)
				writer_close(k);
		}
		if (cap && now_ms() >= cap->deadline)
			capture_end(true);              /* keep the formats that did arrive */
		wl_display_dispatch_pending(dpy);
	}
}
