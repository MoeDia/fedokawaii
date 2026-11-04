/*
 * kawa-saver — the screensaver: the lock's own painting, asleep (the owner, 4 Nov: "an upgrade to match the
 * new design"; one world with the lock; 19:11: a painting, never pixels).
 *
 *   kawa-saver         now (a look at it: any input ends it, nothing locks)
 *   kawa-saver --idle  away 15 minutes (kawa-idle, from swayidle: never while something
 *                      plays): the screensaver, with the lock under it — kawa-lock starts once
 *                      the painting covers the screen, and dwl keeps the saver over the lock
 *                      screen (its own layer, for this program alone). The first key or move only
 *                      wakes the world: the fires leap, the dark lifts, and the painting opens from
 *                      the figure's place outwards, soft-edged, onto the lock already there: the figure
 *                      is in it. A key pressed before the lock is up waits for it, so neither that key
 *                      nor any after it reaches a window. Already locked (a lock you asked
 *                      for, then away): the saver over it. Switched off in quick settings
 *                      (~/.local/state/fedokawaii/saver: on, or off): the lock at once.
 *                      Should it not be able to show, it locks all the same.
 *
 * What it shows is world.h's: the painting with no figure, the shade over it breathing with the fires, the lock's
 * own flames, smoke and embers on the dark, gold dust and petals on the light, the time a small seal stamped
 * somewhere else in the middle every minute. Twelve steps a second. Each is a layer of its own here (a subsurface,
 * scaled up smooth by the compositor where it is small), so a step recomputes almost nothing and sends almost nothing.
 *
 * Any key, click, scroll or move of the pointer ends it — and goes nowhere else: it holds the
 * keyboard while it shows (a layer on top of everything, the bar too), and without a lock it waits
 * for the key or button to be let go before it leaves, so neither press nor release reaches a window.
 * Without --idle it ends too when the desktop locks (kawa-lock); it stays one at a time. With the
 * screens dark (away 30 minutes) nothing is drawn or computed at all: no frames asked for, no steps.
 *
 * About 20 MB, near no CPU, a little of the GPU only where something moved. render.c draws the same world to files, for
 * the tests and the renders. Built by theme.sh (src/kawa-saver/Makefile).
 * Exit: 0 · 1 it could not show (said on stderr) · 2 wrong use.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "viewporter-client-protocol.h"
#include "world.h"

#define DARK_MS 1000     /* a frame asked for and not given for so long: the screens are dark */
#define WOKEN_MS 1000    /* screens lit by the key: the monitor finds its signal, then the world wakes (with WAKE_MS, inside dwl's SAVER_GUARD_MS, whatever lit them) */

struct shm_picture {
	struct wl_buffer *wl;
	void *map;
	size_t size;
	bool busy;
};

/* a layer on a screen: a subsurface, and how it is scaled */
struct sub {
	struct wl_surface *surface;
	struct wl_subsurface *subsurface;
	struct wp_viewport *viewport;
};

struct output {
	struct wl_list link;
	struct wl_output *wl;
	uint32_t global;
	int scale;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer;
	struct wp_viewport *viewport;
	int lw, lh;
	bool configured, closed, waiting_frame, ready;
	double asked_at;    /* when the frame waited for was asked for */
	struct sub shade, haze, air, seal, anims[MAXANIM];
};

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_subcompositor *subcompositor;
static struct wl_shm *shm;
static struct wp_viewporter *viewporter;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wl_seat *seat;
static struct wl_keyboard *keyboard;
static struct wl_pointer *pointer;
static struct wl_list outputs;
static bool leaving;                      /* input came: gone once every key and button is up (with --idle: once the world has woken) */
static bool idle_mode;                    /* --idle: the lock behind it */
static pid_t lock_pid;                    /* kawa-lock, started as it covers the screen (--idle) */
static bool lock_started;
static bool falling = true;               /* it comes over the screen */
static double fall_at, wake_at, wake_from;   /* when they began; the time no wake begins before */
static float front;                       /* how far from the figure's place it has opened, in pixels */
static int held;                          /* keys and buttons down */
static double leave_at;
static bool moved_base;
static double base_x, base_y;
static volatile sig_atomic_t stop;

static struct shm_picture pic_paint, pic_open, pic_shade, pic_haze, pic_air, pic_seal;
static struct shm_picture *pic_frames[MAXANIM];
static float front_was;
static uint8_t *open_tiles;
static bool seal_waits;

static double now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static time_t real_time(void)
{
	return time(NULL);
}

/* ── the pictures, shared with the compositor ───────────────────────────────────────── */
static void buffer_release(void *data, struct wl_buffer *b)
{
	(void)b;
	((struct shm_picture *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };

static bool shm_make(struct shm_picture *s, int w, int h)
{
	int stride = w * 4;
	s->size = (size_t)stride * (size_t)h;
	int fd = memfd_create("kawa-saver", MFD_CLOEXEC);
	if (fd < 0 || ftruncate(fd, (off_t)s->size) < 0) {
		if (fd >= 0) close(fd);
		return false;
	}
	s->map = mmap(NULL, s->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (s->map == MAP_FAILED) {
		close(fd);
		s->map = NULL;
		return false;
	}
	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)s->size);
	s->wl = wl_shm_pool_create_buffer(pool, 0, w, h, stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(pool);
	close(fd);
	wl_buffer_add_listener(s->wl, &buffer_listener, s);
	return true;
}

/* a strip's frames: one buffer each, in one pool, read-only once written: only attached */
static bool frames_make(struct anim *a, struct shm_picture **out)
{
	size_t one = (size_t)a->w * (size_t)a->h * 4, all = one * (size_t)a->n;
	int fd = memfd_create("kawa-saver", MFD_CLOEXEC);
	if (fd < 0 || ftruncate(fd, (off_t)all) < 0) {
		if (fd >= 0) close(fd);
		return false;
	}
	uint32_t *map = mmap(NULL, all, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (map == MAP_FAILED) {
		close(fd);
		return false;
	}
	/* (each frame a run of its own: the strip's rows are side by side) */
	for (int f = 0; f < a->n; f++)
		for (int y = 0; y < a->h; y++)
			memcpy(map + (size_t)f * (size_t)a->w * (size_t)a->h + (size_t)y * (size_t)a->w,
					a->frames + (size_t)y * (size_t)a->w * (size_t)a->n + (size_t)f * (size_t)a->w, (size_t)a->w * 4);
	free(a->frames);
	a->frames = NULL;
	struct shm_picture *p = calloc((size_t)a->n, sizeof *p);
	if (!p)
		return false;
	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)all);
	for (int f = 0; f < a->n; f++) {
		p[f].size = one;
		p[f].wl = wl_shm_pool_create_buffer(pool, (int32_t)(one * (size_t)f), a->w, a->h, a->w * 4, WL_SHM_FORMAT_ARGB8888);
	}
	wl_shm_pool_destroy(pool);
	close(fd);
	*out = p;
	return true;
}

static void frame_done(void *data, struct wl_callback *cb, uint32_t t)
{
	(void)t;
	wl_callback_destroy(cb);
	((struct output *)data)->waiting_frame = false;
}
static const struct wl_callback_listener frame_listener = { .done = frame_done };

/* a subsurface over the painting: sized to the screen (a small picture scaled up smooth), input passing through it */
static void sub_make(struct output *o, struct sub *s, int x, int y, int w, int h)
{
	s->surface = wl_compositor_create_surface(compositor);
	s->subsurface = wl_subcompositor_get_subsurface(subcompositor, s->surface, o->surface);
	s->viewport = wp_viewporter_get_viewport(viewporter, s->surface);
	wl_subsurface_set_desync(s->subsurface);
	wl_subsurface_set_position(s->subsurface, x * o->lw / art.w, y * o->lh / art.h);
	wp_viewport_set_destination(s->viewport, w * o->lw / art.w, h * o->lh / art.h);
	struct wl_region *none = wl_compositor_create_region(compositor);
	wl_surface_set_input_region(s->surface, none);
	wl_region_destroy(none);
}

static void sub_show(struct sub *s, struct wl_buffer *b, int x, int y, int w, int h)
{
	wl_surface_attach(s->surface, b, 0, 0);
	wl_surface_damage_buffer(s->surface, x, y, w, h);
	wl_surface_commit(s->surface);
}

/* the layers on this screen, from the bottom up */
static void output_setup(struct output *o)
{
	sub_make(o, &o->shade, 0, 0, art.w, art.h);
	for (int i = 0; i < art.na; i++)
		sub_make(o, &o->anims[i], art.anims[i].x, art.anims[i].y, art.anims[i].w, art.anims[i].h);
	if (!art.light)
		sub_make(o, &o->haze, 0, 0, art.w, art.h);
	sub_make(o, &o->air, 0, 0, art.w, art.h);
	sub_make(o, &o->seal, 0, 0, sealp.w, sealp.h);
	o->viewport = wp_viewporter_get_viewport(viewporter, o->surface);
	wp_viewport_set_destination(o->viewport, o->lw, o->lh);
	o->ready = true;
}

/* over a lock it hides all of it (nothing under it is drawn, the lock asked for no frames); while
 * it opens the lock shows through */
static void opaque(bool on)
{
	struct output *o;
	wl_list_for_each(o, &outputs, link) {
		if (!o->ready || o->closed)
			continue;
		if (on) {
			struct wl_region *r = wl_compositor_create_region(compositor);
			wl_region_add(r, 0, 0, o->lw, o->lh);
			wl_surface_set_opaque_region(o->surface, r);
			wl_region_destroy(r);
		} else {
			wl_surface_set_opaque_region(o->surface, NULL);
		}
	}
}

/* every screen asked for a frame long ago and got none: dark (the screens off), nothing to draw for */
static bool screens_dark(double t)
{
	struct output *o;
	bool any = false;
	wl_list_for_each(o, &outputs, link) {
		if (!o->ready || o->closed)
			continue;
		if (!o->waiting_frame || t - o->asked_at < DARK_MS)
			return false;
		any = true;
	}
	return any;
}

/* the world's pictures of a step, to the screens */
static void show_step(double t)
{
	struct output *o;
	wl_list_for_each(o, &outputs, link) {
		if (!o->ready || o->closed)
			continue;
		sub_show(&o->shade, pic_shade.wl, 0, 0, shade.w, shade.h);
		if (falling)                          /* (the rest once the painting covers the screen) */
			goto clock;
		for (int i = 0; i < art.na; i++)
			sub_show(&o->anims[i], pic_frames[i][art.anims[i].frame].wl, 0, 0, art.anims[i].w, art.anims[i].h);
		if (!art.light) {
			wl_surface_attach(o->haze.surface, pic_haze.wl, 0, 0);
			for (int k = 0; k < art.nt; k++)
				wl_surface_damage_buffer(o->haze.surface, haze_rect[k][0], haze_rect[k][1], haze_rect[k][2], haze_rect[k][3]);
			wl_surface_commit(o->haze.surface);
		}
		wl_surface_attach(o->air.surface, pic_air.wl, 0, 0);
		for (int k = 0; k < nair_was; k++)
			wl_surface_damage_buffer(o->air.surface, air_was[k].x, air_was[k].y, air_was[k].w, air_was[k].h);
		for (int k = 0; k < nair_now; k++)
			wl_surface_damage_buffer(o->air.surface, air_now[k].x, air_now[k].y, air_now[k].w, air_now[k].h);
		wl_surface_commit(o->air.surface);
		if (seal_changed || seal_waits) {
			wl_subsurface_set_position(o->seal.subsurface, seal_x * o->lw / art.w, seal_y * o->lh / art.h);
			sub_show(&o->seal, pic_seal.wl, 0, 0, sealp.w, sealp.h);
			wl_surface_commit(o->surface);    /* (the seal's new place is its parent's to take) */
		}
clock:
		if (!o->waiting_frame) {              /* (the clock of it all: no frames given, no steps taken) */
			struct wl_callback *cb = wl_surface_frame(o->shade.surface);
			wl_callback_add_listener(cb, &frame_listener, o);
			o->waiting_frame = true;
			o->asked_at = t;
			wl_surface_commit(o->shade.surface);
		}
	}
}

static void take_a_step(double t)
{
	tick++;
	world_step(t, waking || falling ? front : 0);
	pic_shade.busy = pic_haze.busy = pic_air.busy = false;
	if (seal_changed && falling)
		seal_waits = true;                /* (stamped as the painting comes: shown once it has) */
	show_step(t);
	if (!falling)
		seal_waits = false;
}

/* the painting at the front's place: the changed tiles only, the buffer the other one (the painting itself stays whole) */
static void show_open(void)
{
	if (pic_open.busy)
		return;
	int tw = (art.w + TILE - 1) / TILE, th = (art.h + TILE - 1) / TILE;
	memset(open_tiles, 0, (size_t)tw * (size_t)th);
	paint_open(pic_paint.map, pic_open.map, open_tiles, front, front_was);
	front_was = front;
	struct output *o;
	wl_list_for_each(o, &outputs, link) {
		if (!o->ready || o->closed)
			continue;
		wl_surface_attach(o->surface, pic_open.wl, 0, 0);
		for (int y = 0; y < th; y++)
			for (int x = 0; x < tw; x++) {
				if (!open_tiles[y * tw + x])
					continue;
				int e = x;
				while (e < tw && open_tiles[y * tw + e])
					e++;
				wl_surface_damage_buffer(o->surface, x * TILE, y * TILE, (e - x) * TILE, TILE);
				x = e;
			}
		wl_surface_commit(o->surface);
	}
	pic_open.busy = true;
}

static float front_max(void)
{
	float w = fmaxf((float)art.cx, (float)(art.w - art.cx)), h = fmaxf((float)art.cy, (float)(art.h - art.cy));
	return hypotf(w, h) + RAMP_PX + 2;   /* (wholly open at the far corner) */
}

static void wake_begin(double t)
{
	waking = true;
	wake_at = t;
	front = front_was = 0;
	if (!pic_open.map) {                      /* (all of the painting, once: from here it opens) */
		shm_make(&pic_open, art.w, art.h);
		memcpy(pic_open.map, pic_paint.map, pic_open.size);
	}
	struct output *o;
	wl_list_for_each(o, &outputs, link)       /* (the seal lifts at once) */
		if (o->ready && !o->closed) {
			wl_surface_attach(o->seal.surface, NULL, 0, 0);
			wl_surface_commit(o->seal.surface);
		}
	opaque(false);
}

static void layer_configure(void *data, struct zwlr_layer_surface_v1 *l, uint32_t serial,
		uint32_t w, uint32_t h)
{
	struct output *o = data;
	zwlr_layer_surface_v1_ack_configure(l, serial);
	if (o->configured && ((int)w != o->lw || (int)h != o->lh))
		o->closed = true;                 /* (a screen that changed size: left as it is) */
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

/* ── input: any of it ends the screensaver, and none of it goes further ─────────────── */
static void lock_start(void);
static void leave_now(void)
{
	if (leaving)
		return;
	leaving = true;
	leave_at = now_ms();
	/* (screens dark, lit by this very input: the monitor shows nothing for a moment yet) */
	wake_from = leave_at + (screens_dark(leave_at) ? WOKEN_MS : 0);
	if (idle_mode && !lock_started)
		lock_start();                     /* (not up yet: the painting stays until it is) */
}
static void kb_keymap(void *d, struct wl_keyboard *k, uint32_t f, int32_t fd, uint32_t s)
{
	(void)d, (void)k, (void)f, (void)s;
	close(fd);
}
static void kb_enter(void *d, struct wl_keyboard *k, uint32_t s, struct wl_surface *sf, struct wl_array *keys)
{
	(void)d, (void)k, (void)s, (void)sf, (void)keys;
}
static void kb_leave(void *d, struct wl_keyboard *k, uint32_t s, struct wl_surface *sf)
{
	(void)d, (void)k, (void)s, (void)sf;
}
static void kb_key(void *d, struct wl_keyboard *k, uint32_t s, uint32_t t, uint32_t key, uint32_t state)
{
	(void)d, (void)k, (void)s, (void)t, (void)key;
	if (state == WL_KEYBOARD_KEY_STATE_PRESSED) {
		held++;
		if (leaving)
			wake_from = 0;                /* (a second key: no more waiting) */
		leave_now();
	} else if (held > 0) {
		held--;
	}
}
static void kb_mods(void *d, struct wl_keyboard *k, uint32_t s, uint32_t a, uint32_t b, uint32_t c, uint32_t g)
{
	(void)d, (void)k, (void)s, (void)a, (void)b, (void)c, (void)g;
}
static void kb_repeat(void *d, struct wl_keyboard *k, int32_t r, int32_t dl)
{
	(void)d, (void)k, (void)r, (void)dl;
}
static const struct wl_keyboard_listener keyboard_listener = {
	.keymap = kb_keymap, .enter = kb_enter, .leave = kb_leave, .key = kb_key,
	.modifiers = kb_mods, .repeat_info = kb_repeat,
};

static void pt_enter(void *d, struct wl_pointer *p, uint32_t serial, struct wl_surface *s, wl_fixed_t x, wl_fixed_t y)
{
	(void)d, (void)s;
	wl_pointer_set_cursor(p, serial, NULL, 0, 0);   /* no pointer over the painting */
	if (!moved_base) {
		moved_base = true;
		base_x = wl_fixed_to_double(x), base_y = wl_fixed_to_double(y);
	}
}
static void pt_leave(void *d, struct wl_pointer *p, uint32_t s, struct wl_surface *sf)
{
	(void)d, (void)p, (void)s, (void)sf;
	moved_base = false;
}
static void pt_motion(void *d, struct wl_pointer *p, uint32_t t, wl_fixed_t x, wl_fixed_t y)
{
	(void)d, (void)p, (void)t;
	double dx = wl_fixed_to_double(x) - base_x, dy = wl_fixed_to_double(y) - base_y;
	if (!moved_base) {
		moved_base = true;
		base_x += dx, base_y += dy;
	} else if (dx * dx + dy * dy > 36) {   /* (a nudge of the desk is not a move) */
		leave_now();
	}
}
static void pt_button(void *d, struct wl_pointer *p, uint32_t s, uint32_t t, uint32_t b, uint32_t state)
{
	(void)d, (void)p, (void)s, (void)t, (void)b;
	if (state == WL_POINTER_BUTTON_STATE_PRESSED) {
		held++;
		leave_now();
	} else if (held > 0) {
		held--;
	}
}
static void pt_axis(void *d, struct wl_pointer *p, uint32_t t, uint32_t a, wl_fixed_t v)
{
	(void)d, (void)p, (void)t, (void)a, (void)v;
	leave_now();
}
static void pt_frame(void *d, struct wl_pointer *p) { (void)d, (void)p; }
static void pt_axis_source(void *d, struct wl_pointer *p, uint32_t s) { (void)d, (void)p, (void)s; }
static void pt_axis_stop(void *d, struct wl_pointer *p, uint32_t t, uint32_t a) { (void)d, (void)p, (void)t, (void)a; }
static void pt_axis_discrete(void *d, struct wl_pointer *p, uint32_t a, int32_t v) { (void)d, (void)p, (void)a, (void)v; }
static const struct wl_pointer_listener pointer_listener = {
	.enter = pt_enter, .leave = pt_leave, .motion = pt_motion, .button = pt_button,
	.axis = pt_axis, .frame = pt_frame, .axis_source = pt_axis_source,
	.axis_stop = pt_axis_stop, .axis_discrete = pt_axis_discrete,
};

static void seat_caps(void *d, struct wl_seat *s, uint32_t caps)
{
	(void)d;
	if ((caps & WL_SEAT_CAPABILITY_KEYBOARD) && !keyboard) {
		keyboard = wl_seat_get_keyboard(s);
		wl_keyboard_add_listener(keyboard, &keyboard_listener, NULL);
	}
	if ((caps & WL_SEAT_CAPABILITY_POINTER) && !pointer) {
		pointer = wl_seat_get_pointer(s);
		wl_pointer_add_listener(pointer, &pointer_listener, NULL);
	}
}
static void seat_name(void *d, struct wl_seat *s, const char *n) { (void)d, (void)s, (void)n; }
static const struct wl_seat_listener seat_listener = { .capabilities = seat_caps, .name = seat_name };

/* ── globals ────────────────────────────────────────────────────────────────────────── */
static void out_geometry(void *d, struct wl_output *w, int32_t x, int32_t y, int32_t pw,
		int32_t ph, int32_t sub, const char *make, const char *model, int32_t t)
{
	(void)d, (void)w, (void)x, (void)y, (void)pw, (void)ph, (void)sub, (void)make, (void)model, (void)t;
}
static void out_mode(void *d, struct wl_output *w, uint32_t f, int32_t x, int32_t y, int32_t r)
{
	(void)d, (void)w, (void)f, (void)x, (void)y, (void)r;
}
static void out_done(void *d, struct wl_output *w) { (void)d, (void)w; }
static void out_scale(void *d, struct wl_output *w, int32_t s)
{
	(void)w;
	((struct output *)d)->scale = s > 0 ? s : 1;
}
static void out_name(void *d, struct wl_output *w, const char *n) { (void)d, (void)w, (void)n; }
static void out_desc(void *d, struct wl_output *w, const char *n) { (void)d, (void)w, (void)n; }
static const struct wl_output_listener output_listener = {
	.geometry = out_geometry, .mode = out_mode, .done = out_done, .scale = out_scale,
	.name = out_name, .description = out_desc,
};

static void global_add(void *data, struct wl_registry *r, uint32_t name, const char *iface, uint32_t version)
{
	(void)data;
	if (!strcmp(iface, wl_compositor_interface.name) && version >= 4) {
		compositor = wl_registry_bind(r, name, &wl_compositor_interface, 4);
	} else if (!strcmp(iface, wl_subcompositor_interface.name)) {
		subcompositor = wl_registry_bind(r, name, &wl_subcompositor_interface, 1);
	} else if (!strcmp(iface, wp_viewporter_interface.name)) {
		viewporter = wl_registry_bind(r, name, &wp_viewporter_interface, 1);
	} else if (!strcmp(iface, wl_shm_interface.name)) {
		shm = wl_registry_bind(r, name, &wl_shm_interface, 1);
	} else if (!strcmp(iface, zwlr_layer_shell_v1_interface.name)) {
		layer_shell = wl_registry_bind(r, name, &zwlr_layer_shell_v1_interface, 1);
	} else if (!strcmp(iface, wl_seat_interface.name) && !seat) {
		seat = wl_registry_bind(r, name, &wl_seat_interface, version < 5 ? version : 5);
		wl_seat_add_listener(seat, &seat_listener, NULL);
	} else if (!strcmp(iface, wl_output_interface.name)) {
		struct output *o = calloc(1, sizeof *o);
		if (!o)
			return;
		o->global = name;
		o->scale = 1;
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

/* ── the program ────────────────────────────────────────────────────────────────────── */
static void on_signal(int s) { (void)s; stop = 1; }

static const char *runtime(void)
{
	const char *r = getenv("XDG_RUNTIME_DIR");
	return r && *r ? r : "/nonexistent";
}
static bool locked(void)
{
	char p[PATH_MAX];
	snprintf(p, sizeof p, "%s/kawa-lock.locked", runtime());
	return access(p, F_OK) == 0;
}

/* on, unless quick settings switched it off */
static bool wanted(void)
{
	char p[PATH_MAX], v[16] = { 0 };
	const char *st = getenv("XDG_STATE_HOME"), *home = getenv("HOME");
	if (st && *st) snprintf(p, sizeof p, "%s/fedokawaii/saver", st);
	else snprintf(p, sizeof p, "%s/.local/state/fedokawaii/saver", home ? home : "");
	FILE *f = fopen(p, "r");
	if (!f)
		return true;
	if (!fgets(v, sizeof v, f))
		v[0] = 0;
	fclose(f);
	return strncmp(v, "off", 3) != 0;
}

/* --idle: the lock, started as the painting covers the screen — under it, so the first input only
 * opens the painting onto a lock already up (dwl keeps the saver over the lock: its own scene
 * layer, LyrSaver). kawa-lock returns once every screen is locked (lock_up: it has) */
static void lock_start(void)
{
	if (lock_started)
		return;
	lock_started = true;
	pid_t pid = fork();
	if (pid == 0) {
		execlp("kawa-lock", "kawa-lock", (char *)NULL);
		_exit(127);
	}
	lock_pid = pid > 0 ? pid : -1;
}
static bool lock_up(void)
{
	if (lock_pid <= 0)
		return true;
	if (waitpid(lock_pid, NULL, WNOHANG) == 0)
		return false;
	lock_pid = -1;
	return true;
}
/* it cannot show: said; with --idle the lock comes all the same */
static int fail(const char *what)
{
	fprintf(stderr, "kawa-saver: %s\n", what);
	if (idle_mode) {
		execlp("kawa-lock", "kawa-lock", (char *)NULL);
		fprintf(stderr, "kawa-saver: kawa-lock: %s\n", strerror(errno));
	}
	return 1;
}

static void usage(void)
{
	fputs("usage: kawa-saver [--idle] [--seed N] [--pace MS]\n", stderr);
	exit(2);
}

int main(int argc, char **argv)
{
	unsigned seed = (unsigned)time(NULL) ^ (unsigned)getpid();
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--idle")) idle_mode = true;
		else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = (unsigned)strtoul(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--pace") && i + 1 < argc) pace = atoi(argv[++i]);   /* (renders: a faster clock) */
		else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
			puts("kawa-saver — the screensaver: the lock's painting asleep; any input ends it.\n"
			     "  kawa-saver         now (nothing locks)\n"
			     "  kawa-saver --idle  away 15 minutes (kawa-idle): the screensaver, the lock under it: the first\n"
			     "                     input wakes the world onto it (switched off in quick settings: the lock at once)");
			return 0;
		} else usage();
	}
	if (pace < 1 || pace > 1000)
		usage();
	rng = seed ? seed : 1;
	world_time = real_time;
	if (locked() && !idle_mode)
		return 0;                         /* a look while locked: the lock is over everything */
	/* (--idle while locked already — a lock you asked for, then away: the saver over it) */
	char lp[PATH_MAX];
	snprintf(lp, sizeof lp, "%s/kawa-saver.lock", runtime());
	int lk = open(lp, O_RDWR | O_CREAT | O_CLOEXEC, 0600);
	if (lk < 0 || flock(lk, LOCK_EX | LOCK_NB) < 0)
		return 0;                         /* one at a time */
	if (idle_mode && !wanted()) {
		execlp("kawa-lock", "kawa-lock", (char *)NULL);   /* switched off: the lock alone */
		return fail("kawa-lock could not start");
	}
	const char *home = getenv("HOME");
	if (!read_palette(home))
		return fail("no colours (fedokawaii repair puts saver.conf back)");
	if (!read_art(home))
		return fail("no scene (fedokawaii repair puts saver-scene.txt back)");
	display = wl_display_connect(NULL);
	if (!display)
		return fail("no Wayland session to show it on");
	signal(SIGTERM, on_signal);
	signal(SIGINT, on_signal);
	wl_list_init(&outputs);
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);
	if (!compositor || !subcompositor || !shm || !layer_shell || !viewporter)
		return fail("the compositor lacks layer-shell, subsurfaces, viewports or shared memory");
	if (!world_setup())
		return fail("out of memory");
	/* the pictures: the painting whole, what opens (the painting not yet there: all clear), the layers */
	char p[PATH_MAX + 64];
	snprintf(p, sizeof p, "%s/%s", art.dir, art.wall);
	if (!shm_make(&pic_paint, art.w, art.h) || !shm_make(&pic_open, art.w, art.h) || !shm_make(&pic_shade, shade.w, shade.h)
			|| !shm_make(&pic_haze, haze.w, haze.h) || !shm_make(&pic_air, air.w, air.h) || !shm_make(&pic_seal, sealp.w, sealp.h))
		return fail("out of memory");
	int pw = art.w, ph = art.h;
	if (!read_png(p, &pw, &ph, pic_paint.map))
		return fail("no painting (fedokawaii repair puts it back)");
	shade.px = pic_shade.map, haze.px = pic_haze.map, air.px = pic_air.map, sealp.px = pic_seal.map;
	open_tiles = calloc((size_t)((art.w + TILE - 1) / TILE) * (size_t)((art.h + TILE - 1) / TILE), 1);
	if (!open_tiles)
		return fail("out of memory");
	air_setup();
	for (int i = 0; i < art.na; i++)
		if (!frames_make(&art.anims[i], &pic_frames[i]))
			return fail("out of memory");
	struct output *o;
	wl_list_for_each(o, &outputs, link) {
		o->surface = wl_compositor_create_surface(compositor);
		o->layer = zwlr_layer_shell_v1_get_layer_surface(layer_shell, o->surface, o->wl,
				ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kawa-saver");
		zwlr_layer_surface_v1_add_listener(o->layer, &layer_listener, o);
		zwlr_layer_surface_v1_set_anchor(o->layer, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
				ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
				ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
		zwlr_layer_surface_v1_set_exclusive_zone(o->layer, -1);
		zwlr_layer_surface_v1_set_keyboard_interactivity(o->layer, 1);   /* every key ours */
		wl_surface_commit(o->surface);
	}
	wl_display_roundtrip(display);
	int shown = 0;
	wl_list_for_each(o, &outputs, link)
		if (o->configured && !o->closed && o->lw > 0 && o->lh > 0) {
			output_setup(o);
			shown++;
		}
	if (!shown)
		return fail("no screen took it");
	struct pollfd pfd = { .fd = wl_display_get_fd(display), .events = POLLIN };
	double next = now_ms(), next_look = next + 1000, lock_due = 0;
	fall_at = next;
	front = front_was = front_max();
	/* (nothing of it there yet: the first picture is clear, the desktop still showing) */
	wl_list_for_each(o, &outputs, link)
		if (o->ready) {
			wl_surface_attach(o->surface, pic_open.wl, 0, 0);
			wl_surface_damage_buffer(o->surface, 0, 0, art.w, art.h);
			wl_surface_commit(o->surface);
		}
	while (!stop) {
		double t = now_ms();
		bool dark = screens_dark(t);
		if (falling) {                    /* (the painting closes over the screen, the middle last) */
			double f = (t - fall_at) / FALL_MS;
			if (f >= 1 || leaving) {
				falling = false;
				front = 0;
				/* (the painting itself under it all now, the same pixels: nothing to send; the other's memory back) */
				wl_list_for_each(o, &outputs, link)
					if (o->ready && !o->closed) {
						wl_surface_attach(o->surface, pic_paint.wl, 0, 0);
						wl_surface_damage_buffer(o->surface, 0, 0, art.w, art.h);
						wl_surface_commit(o->surface);
					}
				wl_buffer_destroy(pic_open.wl);
				munmap(pic_open.map, pic_open.size);
				pic_open = (struct shm_picture){ 0 };
				opaque(true);
				lock_due = t + 40;        /* (a frame or two shown first) */
			} else {
				front = (float)((1 - spring(f)) * front_max());
				show_open();
			}
		}
		if (lock_due && t >= lock_due) {
			lock_due = 0;
			if (idle_mode)
				lock_start();
		}
		if (leaving) {
			/* gone once the world has woken (the lock is up, it has the keyboard from then: with
			 * it no key or button is waited for) or, without a lock, every key and button is up again
			 * (none reaches a window) — then dwl dissolves what is left of it away */
			if (!idle_mode) {
				if (held == 0)
					break;
			} else if (!waking) {
				if (lock_up() && !falling && t >= wake_from) {
					wake_begin(t);
					next = t;             /* (a step at once: the fires leap) */
				}
			} else {
				double f = (t - wake_at) / WAKE_MS;
				wake_p = f >= 1 ? 1.0f : (float)spring(f);
				front = wake_p * front_max();
				show_open();
				/* (the shade opens with it, every frame) */
				shade_step(front);
				wl_list_for_each(o, &outputs, link)
					if (o->ready && !o->closed)
						sub_show(&o->shade, pic_shade.wl, 0, 0, shade.w, shade.h);
				if (f >= 1)
					break;
			}
			if (t - leave_at > (idle_mode ? 15000 : 3000))
				break;                    /* (a key that never comes up, a lock that hangs) */
		}
		if (!idle_mode && t >= next_look) {
			next_look = t + 1000;
			if (locked())
				break;                    /* locked meanwhile: the lock is over it all */
		}
		if (!dark && t >= next) {
			next += pace;
			if (next < t) next = t + pace;
			take_a_step(t);
		}
		while (wl_display_prepare_read(display) != 0)
			if (wl_display_dispatch_pending(display) < 0)
				goto out;
		if (wl_display_flush(display) < 0 && errno != EAGAIN) {
			wl_display_cancel_read(display);
			break;
		}
		int wait = falling || waking ? 4 : leaving ? 8 : dark ? 1000 : (int)(next - now_ms());
		if (lock_due && wait > 8)
			wait = 8;
		if (poll(&pfd, 1, wait < 0 ? 0 : wait) > 0) {
			if (wl_display_read_events(display) < 0)
				break;
		} else {
			wl_display_cancel_read(display);
		}
		if (wl_display_dispatch_pending(display) < 0)
			break;
	}
out:
	if (lock_pid > 0)                     /* (stopped while the lock came up: it is waited for) */
		while (waitpid(lock_pid, NULL, 0) < 0 && errno == EINTR)
			;
	wl_list_for_each(o, &outputs, link) {
		if (o->layer)
			zwlr_layer_surface_v1_destroy(o->layer);
		if (o->surface)
			wl_surface_destroy(o->surface);
	}
	wl_display_roundtrip(display);
	wl_display_disconnect(display);
	return 0;
}
