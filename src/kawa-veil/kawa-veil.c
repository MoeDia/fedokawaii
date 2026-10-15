/*
 * kawa-veil — smooth, pixel-drawn transitions for the desktop's theme and wallpaper.
 *
 *   kawa-veil [--rise | --fall | --dissolve] [--hold MS] [--time MS] [--] CMD [ARG…]
 *
 * It holds a still picture of every screen on top of everything (wlr-screencopy, shown on
 * the overlay layer, passing every click through), runs CMD underneath — the theme or the
 * wallpaper changes there — waits HOLD ms for the apps to redraw, then lets the still go,
 * block by block, over TIME ms:
 *
 *   --dissolve  an ordered-dither crossfade (8×8 Bayer), drifting slightly downwards —
 *               the wallpaper changes like this
 *   --rise      the new picture rises from the bottom edge as a row of seigaiha wave
 *               crests with a dithered fringe: dawn, for the light theme
 *   --fall      the same from the top edge, crests pointing down: nightfall, for the dark
 *
 * The blocks are as big as one pixel of the wallpaper pack's pixel art on that screen
 * (3 px on 1080p, 4 on 1440p, 6 on 4K), so the grain matches what is behind it. Every
 * frame only clears blocks — nothing is blended — so each one stays a crisp square.
 *
 * Whatever goes wrong, CMD still runs exactly once: no Wayland, no screencopy, a pixel
 * format it does not know or a screen that does not answer each just mean no veil there.
 * A watchdog removes the veil after 20 s whatever happens — and, should the compositor
 * have stalled before CMD started, starts CMD then. Exit status: CMD's.
 *
 * Built by theme.sh (src/kawa-veil/Makefile) with the tools that build dwl.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "viewporter-client-protocol.h"
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "wlr-screencopy-unstable-v1-client-protocol.h"

enum style { DISSOLVE, RISE, FALL };
enum { WAITING, READY, FAILED };
#define LEVELS 4096                       /* reveal values are quantised to this many steps */

static const uint8_t bayer[8][8] = {
	{  0, 32,  8, 40,  2, 34, 10, 42 }, { 48, 16, 56, 24, 50, 18, 58, 26 },
	{ 12, 44,  4, 36, 14, 46,  6, 38 }, { 60, 28, 52, 20, 62, 30, 54, 22 },
	{  3, 35, 11, 43,  1, 33,  9, 41 }, { 51, 19, 59, 27, 49, 17, 57, 25 },
	{ 15, 47,  7, 39, 13, 45,  5, 37 }, { 63, 31, 55, 23, 61, 29, 53, 21 },
};

struct buffer {
	struct wl_buffer *wl;
	uint8_t *data;
	bool busy;                            /* attached, not yet released by the compositor */
	int done;                             /* blocks of the reveal order cleared so far */
};

struct output {
	struct wl_list link;
	struct wl_output *wl;
	uint32_t global;
	int32_t transform;
	/* the still */
	struct zwlr_screencopy_frame_v1 *frame;
	int state;
	uint32_t format;
	int w, h, stride;
	bool y_invert, have_shm;
	struct buffer buf[2];
	size_t size;
	/* the veil */
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer;
	struct wp_viewport *viewport;
	int lw, lh;                           /* logical size, from the layer configure */
	bool configured, closed, waiting_frame;
	/* the reveal: blocks in the order they go, and how many go by each level */
	int bs, bw, bh;
	uint32_t *order;
	uint32_t *upto;                       /* upto[k] = number of blocks with value < k */
};

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct zwlr_screencopy_manager_v1 *screencopy;
static struct wp_viewporter *viewporter;
static uint32_t screencopy_version;
static struct wl_list outputs;

static double now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

/* one round of the Wayland event loop, waiting at most ms; false when the
 * connection is gone */
static bool pump(int ms)
{
	struct pollfd p = { .fd = wl_display_get_fd(display), .events = POLLIN };
	while (wl_display_prepare_read(display) != 0)
		if (wl_display_dispatch_pending(display) < 0)
			return false;
	if (wl_display_flush(display) < 0 && errno != EAGAIN) {
		wl_display_cancel_read(display);
		return false;
	}
	if (poll(&p, 1, ms) > 0) {
		if (wl_display_read_events(display) < 0)
			return false;
	} else {
		wl_display_cancel_read(display);
	}
	return wl_display_dispatch_pending(display) >= 0;
}

/* ── shared memory ─────────────────────────────────────────────────────────── */
static uint8_t *shm_alloc(size_t size, int *fd)
{
	uint8_t *p;
	*fd = memfd_create("kawa-veil", MFD_CLOEXEC);
	if (*fd < 0)
		return NULL;
	if (ftruncate(*fd, (off_t)size) < 0) {
		close(*fd);
		return NULL;
	}
	p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, *fd, 0);
	if (p == MAP_FAILED) {
		close(*fd);
		return NULL;
	}
	return p;
}

static struct wl_buffer *shm_buffer(struct output *o, int fd, uint32_t format)
{
	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)o->size);
	struct wl_buffer *b = wl_shm_pool_create_buffer(pool, 0, o->w, o->h, o->stride, format);
	wl_shm_pool_destroy(pool);
	return b;
}

static void buffer_release(void *data, struct wl_buffer *wl_buffer)
{
	(void)wl_buffer;
	((struct buffer *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };

/* ── the still: screencopy ─────────────────────────────────────────────────── */
static bool known_format(uint32_t f)
{
	return f == WL_SHM_FORMAT_XRGB8888 || f == WL_SHM_FORMAT_ARGB8888 ||
	       f == WL_SHM_FORMAT_XBGR8888 || f == WL_SHM_FORMAT_ABGR8888;
}

static void start_copy(struct output *o)
{
	int fd;
	o->size = (size_t)o->stride * (size_t)o->h;
	o->buf[0].data = shm_alloc(o->size, &fd);
	if (!o->buf[0].data) {
		o->state = FAILED;
		return;
	}
	/* screencopy writes in its own format; the same memory is shown later as ARGB */
	struct wl_buffer *target = shm_buffer(o, fd, o->format);
	o->buf[0].wl = shm_buffer(o, fd, WL_SHM_FORMAT_ARGB8888);
	close(fd);
	zwlr_screencopy_frame_v1_copy(o->frame, target);
	/* the request holds what it needs: the target object can go once the frame does */
	wl_buffer_destroy(target);
}

static void frame_buffer(void *data, struct zwlr_screencopy_frame_v1 *f, uint32_t format,
		uint32_t width, uint32_t height, uint32_t stride)
{
	struct output *o = data;
	(void)f;
	if (o->have_shm || !known_format(format) || width == 0 || height == 0 ||
			width > 16384 || height > 16384 || stride < width * 4)
		return;
	o->have_shm = true;
	o->format = format;
	o->w = (int)width, o->h = (int)height, o->stride = (int)stride;
	if (screencopy_version < 3)            /* no buffer_done before version 3 */
		start_copy(o);
}

static void frame_buffer_done(void *data, struct zwlr_screencopy_frame_v1 *f)
{
	struct output *o = data;
	(void)f;
	if (o->have_shm)
		start_copy(o);
	else
		o->state = FAILED;
}

static void frame_flags(void *data, struct zwlr_screencopy_frame_v1 *f, uint32_t flags)
{
	(void)f;
	((struct output *)data)->y_invert = flags & ZWLR_SCREENCOPY_FRAME_V1_FLAGS_Y_INVERT;
}

static void frame_ready(void *data, struct zwlr_screencopy_frame_v1 *f,
		uint32_t sec_hi, uint32_t sec_lo, uint32_t nsec)
{
	(void)f, (void)sec_hi, (void)sec_lo, (void)nsec;
	((struct output *)data)->state = READY;
}

static void frame_failed(void *data, struct zwlr_screencopy_frame_v1 *f)
{
	(void)f;
	((struct output *)data)->state = FAILED;
}

static void frame_damage(void *data, struct zwlr_screencopy_frame_v1 *f,
		uint32_t x, uint32_t y, uint32_t w, uint32_t h)
{
	(void)data, (void)f, (void)x, (void)y, (void)w, (void)h;
}

static void frame_dmabuf(void *data, struct zwlr_screencopy_frame_v1 *f,
		uint32_t format, uint32_t w, uint32_t h)
{
	(void)data, (void)f, (void)format, (void)w, (void)h;
}

static const struct zwlr_screencopy_frame_v1_listener frame_listener = {
	.buffer = frame_buffer, .flags = frame_flags, .ready = frame_ready,
	.failed = frame_failed, .damage = frame_damage, .linux_dmabuf = frame_dmabuf,
	.buffer_done = frame_buffer_done,
};

/* the copied pixels → opaque ARGB8888, rows the right way up */
static void normalise(struct output *o)
{
	uint8_t *d = o->buf[0].data;
	bool swap = o->format == WL_SHM_FORMAT_XBGR8888 || o->format == WL_SHM_FORMAT_ABGR8888;
	if (o->y_invert) {
		uint8_t *row = malloc((size_t)o->stride);
		if (row) {
			for (int y = 0; y < o->h / 2; y++) {
				uint8_t *a = d + (size_t)y * (size_t)o->stride, *b = d + (size_t)(o->h - 1 - y) * (size_t)o->stride;
				memcpy(row, a, (size_t)o->stride);
				memcpy(a, b, (size_t)o->stride);
				memcpy(b, row, (size_t)o->stride);
			}
			free(row);
		}
	}
	for (int y = 0; y < o->h; y++) {
		uint32_t *p = (uint32_t *)(d + (size_t)y * (size_t)o->stride);
		for (int x = 0; x < o->w; x++) {
			uint32_t v = p[x];
			if (swap)
				v = (v & 0x0000ff00u) | ((v & 0xffu) << 16) | ((v >> 16) & 0xffu);
			p[x] = v | 0xff000000u;
		}
	}
}

/* ── the reveal order ──────────────────────────────────────────────────────── */
/* a block as the screen is seen (lx, ly in a lw × lh grid) → the same block in the
 * still, which screencopy hands over in the screen's scan-out orientation */
static void to_buffer(int32_t transform, int lw, int lh, int lx, int ly, int *bx, int *by)
{
	switch (transform) {
	case WL_OUTPUT_TRANSFORM_90:          *bx = ly;          *by = lw - 1 - lx; break;
	case WL_OUTPUT_TRANSFORM_180:         *bx = lw - 1 - lx; *by = lh - 1 - ly; break;
	case WL_OUTPUT_TRANSFORM_270:         *bx = lh - 1 - ly; *by = lx;          break;
	case WL_OUTPUT_TRANSFORM_FLIPPED:     *bx = lw - 1 - lx; *by = ly;          break;
	case WL_OUTPUT_TRANSFORM_FLIPPED_90:  *bx = ly;          *by = lx;          break;
	case WL_OUTPUT_TRANSFORM_FLIPPED_180: *bx = lx;          *by = lh - 1 - ly; break;
	case WL_OUTPUT_TRANSFORM_FLIPPED_270: *bx = lh - 1 - ly; *by = lw - 1 - lx; break;
	default:                              *bx = lx;          *by = ly;          break;
	}
}

static bool plan(struct output *o, enum style style)
{
	/* portrait screens: the long side counts as the width */
	int W = o->w > o->h ? o->w : o->h, H = o->w > o->h ? o->h : o->w;
	int bs = (W + 639) / 640, t = (H + 359) / 360;
	o->bs = bs > t ? bs : t;
	if (o->bs < 2)
		o->bs = 2;
	o->bw = (o->w + o->bs - 1) / o->bs;
	o->bh = (o->h + o->bs - 1) / o->bs;
	size_t n = (size_t)o->bw * (size_t)o->bh;
	uint16_t *val = malloc(n * sizeof *val);
	o->order = malloc(n * sizeof *o->order);
	o->upto = calloc(LEVELS + 1, sizeof *o->upto);
	if (!val || !o->order || !o->upto) {
		free(val);
		return false;
	}
	/* the wave crests: arcs of two seigaiha tiles — 96 px at 1080p, scaled with the
	 * screen's height (128 at 1440p, 192 at 4K) */
	double chord = 96.0 * (H / 1080.0 > 1 ? H / 1080.0 : 1) / o->bs, r = chord / 2;
	double band = r * 1.2;                /* the dithered fringe behind each crest */
	/* planned as the screen is seen (up is up on a turned screen too), then each block
	 * is put where it lies in the still, which is in the screen's scan-out orientation */
	int lw = o->transform & 1 ? o->bh : o->bw, lh = o->transform & 1 ? o->bw : o->bh;
	for (int ly = 0; ly < lh; ly++)
		for (int lx = 0; lx < lw; lx++) {
			double b = (bayer[ly & 7][lx & 7] + 0.5) / 64.0, v;
			if (style == DISSOLVE) {
				v = 0.85 * b + 0.15 * (lh > 1 ? (double)ly / (lh - 1) : 0);
			} else {
				double f = fmod(lx + 0.5, chord) - r;
				double depth = r - sqrt(fmax(r * r - f * f, 0));  /* 0 on a crest */
				double d = style == RISE ? lh - 1 - ly : ly;
				v = (d + depth + band * b) / (lh + r + band);
			}
			int bx, by;
			to_buffer(o->transform, lw, lh, lx, ly, &bx, &by);
			int k = (int)(v * LEVELS);
			val[(size_t)by * (size_t)o->bw + (size_t)bx] = (uint16_t)(k < 0 ? 0 : k >= LEVELS ? LEVELS - 1 : k);
		}
	/* counting sort: upto[k] = blocks with value < k, order = blocks by value */
	for (size_t i = 0; i < n; i++)
		o->upto[val[i] + 1]++;
	for (int k = 1; k <= LEVELS; k++)
		o->upto[k] += o->upto[k - 1];
	uint32_t *next = malloc(LEVELS * sizeof *next);
	if (!next) {
		free(val);
		return false;
	}
	memcpy(next, o->upto, LEVELS * sizeof *next);
	for (size_t i = 0; i < n; i++)
		o->order[next[val[i]]++] = (uint32_t)i;
	free(next);
	free(val);
	return true;
}

/* clear blocks [b->done, upto) of the order in this buffer; returns the damaged box */
static void clear_blocks(struct output *o, struct buffer *b, uint32_t upto,
		int *x0, int *y0, int *x1, int *y1)
{
	for (; b->done < (int)upto; b->done++) {
		uint32_t i = o->order[b->done];
		int bx = (int)(i % (uint32_t)o->bw), by = (int)(i / (uint32_t)o->bw);
		int px = bx * o->bs, py = by * o->bs;
		int pw = px + o->bs > o->w ? o->w - px : o->bs;
		int ph = py + o->bs > o->h ? o->h - py : o->bs;
		for (int y = py; y < py + ph; y++)
			memset(b->data + (size_t)y * (size_t)o->stride + (size_t)px * 4, 0, (size_t)pw * 4);
		if (px < *x0) *x0 = px;
		if (py < *y0) *y0 = py;
		if (px + pw > *x1) *x1 = px + pw;
		if (py + ph > *y1) *y1 = py + ph;
	}
}

/* ── the veil surface ──────────────────────────────────────────────────────── */
static void layer_configure(void *data, struct zwlr_layer_surface_v1 *l, uint32_t serial,
		uint32_t w, uint32_t h)
{
	struct output *o = data;
	zwlr_layer_surface_v1_ack_configure(l, serial);
	o->lw = (int)w, o->lh = (int)h;
	o->configured = true;
}

static void layer_closed(void *data, struct zwlr_layer_surface_v1 *l)
{
	(void)l;
	((struct output *)data)->closed = true;
}

static const struct zwlr_layer_surface_v1_listener layer_listener = {
	.configure = layer_configure, .closed = layer_closed,
};

static void frame_done(void *data, struct wl_callback *cb, uint32_t t)
{
	(void)t;
	wl_callback_destroy(cb);
	((struct output *)data)->waiting_frame = false;
}
static const struct wl_callback_listener frame_cb_listener = { .done = frame_done };

static void commit_frame(struct output *o)
{
	struct wl_callback *cb = wl_surface_frame(o->surface);
	wl_callback_add_listener(cb, &frame_cb_listener, o);
	o->waiting_frame = true;
	wl_surface_commit(o->surface);
}

static bool open_veil(struct output *o)
{
	int fd;
	/* without a viewport the still must be a whole multiple of the logical size */
	bool turned = o->transform & 1;
	int sw = turned ? o->h : o->w, sh = turned ? o->w : o->h;
	int scale = 1;
	if (!viewporter) {
		if (o->lw <= 0 || sw % o->lw || sh % o->lh || sw / o->lw != sh / o->lh)
			return false;
		scale = sw / o->lw;
	}
	o->buf[1].data = shm_alloc(o->size, &fd);
	if (!o->buf[1].data)
		return false;
	memcpy(o->buf[1].data, o->buf[0].data, o->size);
	o->buf[1].wl = shm_buffer(o, fd, WL_SHM_FORMAT_ARGB8888);
	close(fd);
	for (int i = 0; i < 2; i++)
		wl_buffer_add_listener(o->buf[i].wl, &buffer_listener, &o->buf[i]);
	/* the still is in the screen's own scan-out orientation: undo the output transform
	 * (90° and 270° swap; 180° and the flipped ones are their own inverse) */
	int32_t t = o->transform;
	if ((t & 1) && !(t & 4))
		t ^= 2;
	wl_surface_set_buffer_transform(o->surface, t);
	if (viewporter) {
		o->viewport = wp_viewporter_get_viewport(viewporter, o->surface);
		wp_viewport_set_destination(o->viewport, o->lw, o->lh);
	} else {
		wl_surface_set_buffer_scale(o->surface, scale);
	}
	wl_surface_attach(o->surface, o->buf[0].wl, 0, 0);
	o->buf[0].busy = true;
	wl_surface_damage_buffer(o->surface, 0, 0, o->w, o->h);
	commit_frame(o);
	return true;
}

static void close_veil(struct output *o)
{
	if (o->layer)
		zwlr_layer_surface_v1_destroy(o->layer), o->layer = NULL;
	if (o->viewport)
		wp_viewport_destroy(o->viewport), o->viewport = NULL;
	if (o->surface)
		wl_surface_destroy(o->surface), o->surface = NULL;
}

/* ── globals ───────────────────────────────────────────────────────────────── */
static void out_geometry(void *data, struct wl_output *w, int32_t x, int32_t y, int32_t pw,
		int32_t ph, int32_t sub, const char *make, const char *model, int32_t transform)
{
	(void)w, (void)x, (void)y, (void)pw, (void)ph, (void)sub, (void)make, (void)model;
	((struct output *)data)->transform = transform;
}
static void out_mode(void *d, struct wl_output *w, uint32_t f, int32_t x, int32_t y, int32_t r)
{
	(void)d, (void)w, (void)f, (void)x, (void)y, (void)r;
}
static void out_done(void *d, struct wl_output *w) { (void)d, (void)w; }
static void out_scale(void *d, struct wl_output *w, int32_t s) { (void)d, (void)w, (void)s; }
static void out_name(void *d, struct wl_output *w, const char *n) { (void)d, (void)w, (void)n; }
static void out_desc(void *d, struct wl_output *w, const char *n) { (void)d, (void)w, (void)n; }
static const struct wl_output_listener output_listener = {
	.geometry = out_geometry, .mode = out_mode, .done = out_done, .scale = out_scale,
	.name = out_name, .description = out_desc,
};

static void global_add(void *data, struct wl_registry *r, uint32_t name, const char *iface,
		uint32_t version)
{
	(void)data;
	if (!strcmp(iface, wl_compositor_interface.name) && version >= 4) {
		compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
	} else if (!strcmp(iface, wl_shm_interface.name)) {
		shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
	} else if (!strcmp(iface, zwlr_layer_shell_v1_interface.name)) {
		layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
	} else if (!strcmp(iface, zwlr_screencopy_manager_v1_interface.name)) {
		screencopy_version = version < 3 ? version : 3;
		screencopy = wl_registry_bind(r, name, &zwlr_screencopy_manager_v1_interface,
				screencopy_version);
	} else if (!strcmp(iface, wp_viewporter_interface.name)) {
		viewporter = wl_registry_bind(r, name, &wp_viewporter_interface, 1);
	} else if (!strcmp(iface, wl_output_interface.name)) {
		struct output *o = calloc(1, sizeof *o);
		if (!o)
			return;
		o->global = name;
		o->wl = wl_registry_bind(r, name, &wl_output_interface, version < 4 ? version : 4);
		wl_output_add_listener(o->wl, &output_listener, o);
		wl_list_insert(&outputs, &o->link);
	}
}

static void global_remove(void *data, struct wl_registry *r, uint32_t name)
{
	struct output *o;
	(void)data, (void)r;
	wl_list_for_each(o, &outputs, link)
		if (o->global == name)
			o->closed = true;
}

static const struct wl_registry_listener registry_listener = {
	.global = global_add, .global_remove = global_remove,
};

/* ── the program ───────────────────────────────────────────────────────────── */
/* the watchdog: SIGALRM after 20 s. Ending the process takes the veil away (the compositor
 * drops a client's surfaces with it); if CMD has not been started yet, it is started in our
 * place instead (execve, async-signal-safe, with the path looked up beforehand), so a
 * stalled compositor never swallows the change. */
static char **wd_cmd;
static char wd_path[PATH_MAX];
static volatile sig_atomic_t wd_child;   /* 0 = CMD not started yet */
extern char **environ;

static void watchdog(int sig)
{
	(void)sig;
	if (!wd_child) {
		if (wd_path[0])
			execve(wd_path, wd_cmd, environ);
		_exit(127);
	}
	int st;
	_exit(waitpid((pid_t)wd_child, &st, WNOHANG) == (pid_t)wd_child && WIFEXITED(st) ?
			WEXITSTATUS(st) : 0);
}

/* CMD's executable, as execvp would find it (empty if there is none) */
static void look_up(const char *name)
{
	if (strchr(name, '/')) {
		snprintf(wd_path, sizeof wd_path, "%s", name);
		return;
	}
	const char *path = getenv("PATH");
	for (const char *p = path ? path : "/usr/local/bin:/usr/bin:/bin"; ; p++) {
		const char *end = strchrnul(p, ':');
		int n = snprintf(wd_path, sizeof wd_path, "%.*s%s%s", (int)(end - p), p,
				end > p ? "/" : "", name);
		if (n > 0 && (size_t)n < sizeof wd_path && access(wd_path, X_OK) == 0)
			return;
		if (!*end)
			break;
		p = end;
	}
	wd_path[0] = '\0';
}

static int run(char **cmd, pid_t *child)
{
	sigset_t alrm, old;                   /* no watchdog between fork and wd_child */
	sigemptyset(&alrm);
	sigaddset(&alrm, SIGALRM);
	sigprocmask(SIG_BLOCK, &alrm, &old);
	*child = fork();
	if (*child == 0) {
		sigprocmask(SIG_SETMASK, &old, NULL);
		execvp(cmd[0], cmd);
		fprintf(stderr, "kawa-veil: %s: %s\n", cmd[0], strerror(errno));
		_exit(127);
	}
	if (*child > 0)
		wd_child = *child;
	sigprocmask(SIG_SETMASK, &old, NULL);
	return *child > 0 ? 0 : -1;
}

static int status_of(int st)
{
	return WIFEXITED(st) ? WEXITSTATUS(st) : WIFSIGNALED(st) ? 128 + WTERMSIG(st) : 1;
}

static void usage(void)
{
	fputs("usage: kawa-veil [--rise|--fall|--dissolve] [--hold MS] [--time MS] [--] CMD [ARG...]\n",
			stderr);
	exit(2);
}

int main(int argc, char **argv)
{
	enum style style = DISSOLVE;
	int hold = 180, length = 650, i = 1;
	for (; i < argc && argv[i][0] == '-'; i++) {
		if (!strcmp(argv[i], "--")) { i++; break; }
		else if (!strcmp(argv[i], "--rise")) style = RISE;
		else if (!strcmp(argv[i], "--fall")) style = FALL;
		else if (!strcmp(argv[i], "--dissolve")) style = DISSOLVE;
		else if (!strcmp(argv[i], "--hold") && i + 1 < argc) hold = atoi(argv[++i]);
		else if (!strcmp(argv[i], "--time") && i + 1 < argc) length = atoi(argv[++i]);
		else usage();
	}
	if (i >= argc)
		usage();
	char **cmd = argv + i;
	if (hold < 0 || hold > 5000) hold = 180;
	if (length < 50 || length > 5000) length = 650;

	/* nothing to veil (no session named, or none answering): just the command */
	const char *wd = getenv("WAYLAND_DISPLAY");
	if ((wd && *wd) || getenv("WAYLAND_SOCKET"))
		display = wl_display_connect(NULL);
	if (!display) {
		execvp(cmd[0], cmd);
		fprintf(stderr, "kawa-veil: %s: %s\n", cmd[0], strerror(errno));
		return 127;
	}
	wd_cmd = cmd;                         /* whatever happens, the screens come back */
	look_up(cmd[0]);
	signal(SIGALRM, watchdog);
	alarm(20);
	wl_list_init(&outputs);
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);

	struct output *o;
	int veiled = 0;
	if (compositor && shm && layer_shell && screencopy) {
		/* 1. a still of every screen */
		wl_list_for_each(o, &outputs, link) {
			o->frame = zwlr_screencopy_manager_v1_capture_output(screencopy, 0, o->wl);
			zwlr_screencopy_frame_v1_add_listener(o->frame, &frame_listener, o);
		}
		for (double end = now_ms() + 1000; now_ms() < end;) {
			bool waiting = false;
			wl_list_for_each(o, &outputs, link)
				waiting |= o->state == WAITING;
			if (!waiting || !pump(20))
				break;
		}
		/* 2. shown on top of everything, clicks passing through */
		wl_list_for_each(o, &outputs, link) {
			if (o->frame)
				zwlr_screencopy_frame_v1_destroy(o->frame), o->frame = NULL;
			if (o->state != READY || !o->buf[0].data || o->closed)
				continue;
			normalise(o);
			o->surface = wl_compositor_create_surface(compositor);
			struct wl_region *none = wl_compositor_create_region(compositor);
			wl_surface_set_input_region(o->surface, none);
			wl_region_destroy(none);
			o->layer = zwlr_layer_shell_v1_get_layer_surface(layer_shell, o->surface, o->wl,
					ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kawa-veil");
			zwlr_layer_surface_v1_add_listener(o->layer, &layer_listener, o);
			zwlr_layer_surface_v1_set_anchor(o->layer, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
					ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
					ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
			zwlr_layer_surface_v1_set_exclusive_zone(o->layer, -1);
			wl_surface_commit(o->surface);
		}
		wl_display_roundtrip(display);
		wl_list_for_each(o, &outputs, link) {
			if (!o->surface)
				continue;
			if (o->configured && !o->closed && o->lw > 0 && o->lh > 0 &&
					plan(o, style) && open_veil(o))
				veiled++;
			else
				close_veil(o);
		}
		/* 3. wait until the stills are on screen (one frame each, at most 200 ms) */
		for (double end = now_ms() + 200; veiled && now_ms() < end;) {
			bool waiting = false;
			wl_list_for_each(o, &outputs, link)
				waiting |= o->surface && o->waiting_frame;
			if (!waiting || !pump(10))
				break;
		}
	}

	/* 4. the change itself, underneath */
	pid_t child;
	int st = 0;
	if (!veiled) {
		wl_display_disconnect(display);
		alarm(0);
		execvp(cmd[0], cmd);
		fprintf(stderr, "kawa-veil: %s: %s\n", cmd[0], strerror(errno));
		return 127;
	}
	if (run(cmd, &child) < 0) {           /* no process to spare: the change, unveiled */
		fprintf(stderr, "kawa-veil: fork: %s\n", strerror(errno));
		wl_display_disconnect(display);
		alarm(0);
		execvp(cmd[0], cmd);
		return 127;
	}
	bool exited = false;
	for (double end = now_ms() + 12000; !exited && now_ms() < end;) {
		pid_t r = waitpid(child, &st, WNOHANG);
		if (r == child || (r < 0 && errno == ECHILD))
			exited = true;
		else if (!pump(15))
			break;
	}
	/* 5. a moment for the apps to redraw, then the reveal */
	for (double end = now_ms() + hold; now_ms() < end;)
		if (!pump((int)(end - now_ms()) + 1))
			break;
	double t0 = now_ms();
	for (;;) {
		double t = (now_ms() - t0) / length;
		if (t >= 1)
			break;
		double p = t * t * (3 - 2 * t);   /* ease in and out */
		int level = (int)(p * LEVELS);
		wl_list_for_each(o, &outputs, link) {
			if (!o->surface || o->closed || o->waiting_frame)
				continue;
			struct buffer *b = !o->buf[0].busy ? &o->buf[0] : !o->buf[1].busy ? &o->buf[1] : NULL;
			if (!b)
				continue;
			int x0 = o->w, y0 = o->h, x1 = 0, y1 = 0;
			clear_blocks(o, b, o->upto[level], &x0, &y0, &x1, &y1);
			wl_surface_attach(o->surface, b->wl, 0, 0);
			b->busy = true;
			if (x1 > x0 && (o->transform & 1))  /* a turned screen: the whole still, as some */
				wl_surface_damage_buffer(o->surface, 0, 0, o->w, o->h);  /* compositors misplace part damage */
			else if (x1 > x0)
				wl_surface_damage_buffer(o->surface, x0, y0, x1 - x0, y1 - y0);
			commit_frame(o);
		}
		if (!pump(4))
			break;
	}
	wl_list_for_each(o, &outputs, link)
		close_veil(o);
	wl_display_flush(display);
	wl_display_roundtrip(display);
	if (!exited && waitpid(child, &st, WNOHANG) != child)
		return 0;                         /* still running: it carries on without us */
	return status_of(st);
}
