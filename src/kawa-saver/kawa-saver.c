/*
 * kawa-saver — the screensaver: the lock's own scene, asleep (the owner, 4 Nov: "an upgrade to match the
 * new design").
 *
 *   kawa-saver         now (a look at it: any input ends it, nothing locks)
 *   kawa-saver --idle  away 15 minutes (kawa-idle, from swayidle: never while something
 *                      plays): the screensaver, with the lock under it — kawa-lock starts as
 *                      the saver shows, and dwl keeps the saver over the lock screen (its own
 *                      layer, for this program alone), so the first key or move only lifts
 *                      the sleep off a lock already there: no wait, no frame held.
 *                      A key pressed before the lock is up waits for it, so neither that key
 *                      nor any after it reaches a window. Already locked (a lock you asked
 *                      for, then away): the saver over it. Switched off in quick settings
 *                      (~/.local/state/fedokawaii/saver: on, or off): the lock at once.
 *                      Should it not be able to show, it locks all the same.
 *
 * The mood's scene, dimmed, gate shut (saver-scene.ppm: tools/build-saver.py, from the lock's own
 * pictures), drawn on a grid of dots as big as a pixel of the wallpapers' pixel art (3 px at
 * 1080p, 4 at 1440p, 6 at 4K). Alive, quietly: the torches' flames (the lock's own frames, 8 a
 * second, the two out of step), embers rising from them on the dark, gold dust falling on the light;
 * the time on a small patch (the day's seal, as the bar's clock, and "09:41 PM", in the design
 * system's own letters: glyphs.h) in another corner every minute.
 *
 * Any key, click, scroll or move of the pointer ends it — and goes nowhere else: it holds the
 * keyboard while it shows (a layer on top of everything, the bar too), and it waits for the
 * key or button to be let go before it leaves, so neither press nor release reaches a window.
 * It answers at once: dwl fades it away (180 ms) as it leaves.
 * Without --idle it ends too when the desktop locks (kawa-lock); it stays one at a time.
 *
 * 8 MB a 1080p screen or so, almost no CPU (12 steps a second, only the dots that changed are drawn).
 * Built by theme.sh (src/kawa-saver/Makefile). Exit: 0 · 1 it could not show (said on stderr) · 2 wrong use.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "glyphs.h"

/* ── the palette (current/saver.conf) ───────────────────────────────────────────────── */
enum { GROUND, SURFACE, EDGE2, THREAD, SHADE, TEXT, ACCENT, ACCENT_TEXT, NCOL };
static const char *colour_names[NCOL] = {
	"ground", "surface", "edge2", "thread", "shade", "text", "accent", "accent_text",
};
static uint32_t pal[NCOL];

#define TILE 16         /* what is redrawn at once, in dots */
#define SEAL 24         /* a seal, as the panels draw it: the kanji (14) with 4 of paper and 1 of frame round it */
#define GAP GLYPH_COL   /* a gap, as the panels keep: a column of the letters */
#define NSPARK 28       /* the embers, the gold dust */
#define FLAME_MS 125    /* a flame's frame */

struct buffer {
	struct wl_buffer *wl;
	uint32_t *px;
	size_t size;
	bool busy;
	uint8_t *dirty;     /* the tiles this picture has not been given yet */
};

struct rect { int x, y, w, h; };
struct spark { bool live; float x, y, vx, vy; int age, life, px, py; };

struct output {
	struct wl_list link;
	struct wl_output *wl;
	uint32_t global;
	int scale;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer;
	int lw, lh;
	bool configured, closed, waiting_frame, ready;
	/* the picture, and the grid of dots it shows */
	int W, H, bs, cw, ch, tw, th;
	struct buffer buf[2];
	uint32_t *under;    /* the scene on this screen's grid (a colour a dot) */
	uint32_t *dots;     /* what shows: the scene, the flames, the sparks and the clock over it */
	int ox, oy;         /* the scene's corner on the grid */
	struct spark sparks[NSPARK];
	struct rect clock;
	int clock_min, corner;
	unsigned rng;
};

/* the mood's pictures (tools/build-saver.py) and lock-scene.txt's words */
static struct {
	int w, h;
	unsigned char *rgb;
	int fw, fh, frames, nflames, fx[4], fy[4];
	unsigned char *flame;   /* its frames side by side, the key colour where nothing is */
	bool dust;              /* the light mood: dust falling, not embers rising */
	uint32_t spark[3];      /* a spark's ink as it lives: young, grown, old */
} art;

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wl_seat *seat;
static struct wl_keyboard *keyboard;
static struct wl_pointer *pointer;
static struct wl_list outputs;
static long tick;                         /* steps since the start */
static int pace = 80;                     /* ms a step */
static unsigned seed;
static bool leaving;                      /* input came: gone once every key and button is up (with --idle: once the lock is) */
static bool idle_mode;                    /* --idle: the lock behind it */
static pid_t lock_pid;                    /* kawa-lock, started as it shows (--idle) */
static bool lock_started;
static int held;                          /* keys and buttons down */
static double leave_at;
static bool moved_base;
static double base_x, base_y;
static volatile sig_atomic_t stop;

static double now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static unsigned rnd(struct output *o, unsigned n)
{
	o->rng = o->rng * 1103515245u + 12345u;
	return n ? (o->rng >> 8) % n : 0;
}

/* ── the dots ───────────────────────────────────────────────────────────────────────── */
static void dirty(struct output *o, int x, int y, int w, int h)
{
	if (x < 0) w += x, x = 0;
	if (y < 0) h += y, y = 0;
	if (x + w > o->cw) w = o->cw - x;
	if (y + h > o->ch) h = o->ch - y;
	if (w <= 0 || h <= 0)
		return;
	for (int ty = y / TILE; ty <= (y + h - 1) / TILE; ty++)
		for (int tx = x / TILE; tx <= (x + w - 1) / TILE; tx++)
			for (int b = 0; b < 2; b++)
				if (o->buf[b].dirty)
					o->buf[b].dirty[ty * o->tw + tx] = 1;
}

static void put(struct output *o, int x, int y, uint32_t c)
{
	if (x < 0 || y < 0 || x >= o->cw || y >= o->ch)
		return;
	size_t i = (size_t)y * (size_t)o->cw + (size_t)x;
	if (o->dots[i] != c) {
		o->dots[i] = c;
		dirty(o, x, y, 1, 1);
	}
}

static uint32_t under(struct output *o, int x, int y)
{
	return o->under[(size_t)y * (size_t)o->cw + (size_t)x];
}

static bool on_clock(struct output *o, int x, int y)
{
	struct rect *r = &o->clock;
	return r->w && x >= r->x && x < r->x + r->w && y >= r->y && y < r->y + r->h;
}

static void fill(struct output *o, int x, int y, int w, int h, uint32_t c)
{
	for (int j = y; j < y + h; j++)
		for (int i = x; i < x + w; i++)
			put(o, i, j, c);
}

static const struct glyph *glyph_of(const char *ch, size_t n)
{
	for (size_t i = 0; i < sizeof glyphs / sizeof *glyphs; i++)
		if (strlen(glyphs[i].ch) == n && !memcmp(glyphs[i].ch, ch, n))
			return &glyphs[i];
	return NULL;
}

static void draw_glyph(struct output *o, const struct glyph *g, int x, int y, uint32_t c)
{
	for (int r = 0; r < GLYPH_H; r++)
		for (int b = 0; b < g->w; b++)
			if (g->rows[r] >> (g->w - 1 - b) & 1)
				put(o, x + b, y + r, c);
}

/* the ink's box inside the glyph's cell (a seal centres its ink) */
static void ink(const struct glyph *g, int *x0, int *y0, int *x1, int *y1)
{
	*x0 = g->w, *y0 = GLYPH_H, *x1 = -1, *y1 = -1;
	for (int r = 0; r < GLYPH_H; r++)
		for (int b = 0; b < g->w; b++)
			if (g->rows[r] >> (g->w - 1 - b) & 1) {
				if (b < *x0) *x0 = b;
				if (b > *x1) *x1 = b;
				if (r < *y0) *y0 = r;
				if (r > *y1) *y1 = r;
			}
}

/* ── the flames ─────────────────────────────────────────────────────────────────────── */
static void flames_step(struct output *o)
{
	int frame = (int)(tick * pace / FLAME_MS);
	for (int i = 0; i < art.nflames; i++) {
		int f = (frame + 3 * i) % art.frames;
		for (int y = 0; y < art.fh; y++)
			for (int x = 0; x < art.fw; x++) {
				int dx = o->ox + art.fx[i] + x, dy = o->oy + art.fy[i] + y;
				if (dx < 0 || dy < 0 || dx >= o->cw || dy >= o->ch || on_clock(o, dx, dy))
					continue;
				const unsigned char *p = art.flame + 3 * ((size_t)y * (size_t)art.fw * (size_t)art.frames
						+ (size_t)f * (size_t)art.fw + (size_t)x);
				bool none = p[0] == 255 && p[1] == 0 && p[2] == 255;
				put(o, dx, dy, none ? under(o, dx, dy) : 0xff000000u | (uint32_t)p[0] << 16 | (uint32_t)p[1] << 8 | p[2]);
			}
	}
}

/* ── the sparks: embers rising from the torches, dust falling through the sky ─────────── */
static void spark_new(struct output *o, struct spark *s)
{
	s->live = true, s->age = 0, s->px = s->py = -1;
	if (art.dust) {
		s->x = (float)rnd(o, (unsigned)o->cw), s->y = (float)rnd(o, (unsigned)o->ch / 2);
		s->vx = ((float)rnd(o, 40) - 20) / 200.0f, s->vy = 0.12f + (float)rnd(o, 20) / 100.0f;
		s->life = 90 + (int)rnd(o, 120);
	} else {
		int i = art.nflames ? (int)rnd(o, (unsigned)art.nflames) : 0;
		s->x = (float)(o->ox + (art.nflames ? art.fx[i] + (int)rnd(o, (unsigned)art.fw) : (int)rnd(o, (unsigned)o->cw)));
		s->y = (float)(o->oy + (art.nflames ? art.fy[i] + art.fh / 3 : o->ch - 1));
		s->vx = ((float)rnd(o, 40) - 20) / 100.0f, s->vy = -0.35f - (float)rnd(o, 50) / 100.0f;
		s->life = 40 + (int)rnd(o, 70);
	}
}

static void sparks_step(struct output *o)
{
	for (int i = 0; i < NSPARK; i++) {
		struct spark *s = &o->sparks[i];
		if (!s->live) {
			if (rnd(o, 40) == 0)
				spark_new(o, s);
			continue;
		}
		if (s->px >= 0 && !on_clock(o, s->px, s->py))
			put(o, s->px, s->py, under(o, s->px, s->py));
		if (++s->age > s->life) {
			s->live = false;
			continue;
		}
		s->vx += ((float)rnd(o, 21) - 10) / 400.0f;   /* (the air moves it) */
		s->x += s->vx, s->y += s->vy;
		s->px = (int)s->x, s->py = (int)s->y;
		if (s->px < 0 || s->py < 0 || s->px >= o->cw || s->py >= o->ch) {
			s->live = false;
			continue;
		}
		if (!on_clock(o, s->px, s->py))
			put(o, s->px, s->py, art.spark[3 * s->age / (s->life + 1)]);
	}
}

/* the clock: a small patch — its seal the day's (月 … 日, as the bar's clock) and the time in text,
 * centred in it; wday as localtime counts it (Sunday 0) */
static void draw_clock(struct output *o, const char *t, int wday)
{
	struct rect r = o->clock;
	fill(o, r.x, r.y, r.w, r.h, pal[SURFACE]);
	fill(o, r.x, r.y, r.w, 1, pal[EDGE2]);
	fill(o, r.x, r.y + r.h - 1, r.w, 1, pal[EDGE2]);
	fill(o, r.x, r.y, 1, r.h, pal[EDGE2]);
	fill(o, r.x + r.w - 1, r.y, 1, r.h, pal[EDGE2]);
	const struct glyph *g = glyph_of(saver_days + 3 * (wday % 7), 3);
	int cw = SEAL + GAP + GLYPH_COL * (int)strlen(t), x = r.x + (r.w - cw) / 2, y = r.y + (r.h - SEAL) / 2;
	if (g) {
		int x0, y0, x1, y1;
		ink(g, &x0, &y0, &x1, &y1);
		draw_glyph(o, g, x + (SEAL - (x1 - x0 + 1)) / 2 - x0, y + (SEAL - (y1 - y0 + 1)) / 2 - y0, pal[ACCENT_TEXT]);
	}
	x += SEAL + GAP, y += (SEAL - GLYPH_H) / 2 + 1;
	for (const char *p = t; *p; p++) {
		const struct glyph *c = glyph_of(p, 1);
		if (c)
			draw_glyph(o, c, x, y, pal[TEXT]);
		x += GLYPH_COL;
	}
}

static void clock_step(struct output *o)
{
	time_t now = time(NULL);
	struct tm tm;
	localtime_r(&now, &tm);
	if (tm.tm_min == o->clock_min && o->clock.w)
		return;
	char t[16];
	strftime(t, sizeof t, "%I:%M %p", &tm);
	struct rect old = o->clock;
	int w = 8 + SEAL + GAP + GLYPH_COL * (int)strlen(t) + 8, h = SEAL + 8, m = 16;
	o->corner = (o->corner + 1) % 4;      /* (another corner every minute) */
	o->clock = (struct rect){ o->corner & 1 ? o->cw - w - m : m, o->corner & 2 ? o->ch - h - m : m, w, h };
	o->clock_min = tm.tm_min;
	if (old.w)
		for (int y = old.y; y < old.y + old.h; y++)
			for (int x = old.x; x < old.x + old.w; x++)
				if (!on_clock(o, x, y))
					put(o, x, y, under(o, x, y));
	draw_clock(o, t, tm.tm_wday);
}

static void step(struct output *o)
{
	flames_step(o);
	sparks_step(o);
	clock_step(o);
}

/* ── the screens ────────────────────────────────────────────────────────────────────── */
static void buffer_release(void *data, struct wl_buffer *b)
{
	(void)b;
	((struct buffer *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };
static uint32_t buffer_format = WL_SHM_FORMAT_XRGB8888;

static bool make_buffer(struct output *o, struct buffer *b)
{
	int stride = o->W * 4;
	b->size = (size_t)stride * (size_t)o->H;
	int fd = memfd_create("kawa-saver", MFD_CLOEXEC);
	if (fd < 0 || ftruncate(fd, (off_t)b->size) < 0) {
		if (fd >= 0) close(fd);
		return false;
	}
	b->px = mmap(NULL, b->size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (b->px == MAP_FAILED) {
		close(fd);
		b->px = NULL;
		return false;
	}
	struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)b->size);
	b->wl = wl_shm_pool_create_buffer(pool, 0, o->W, o->H, stride, buffer_format);
	wl_shm_pool_destroy(pool);
	close(fd);
	wl_buffer_add_listener(b->wl, &buffer_listener, b);
	b->dirty = malloc((size_t)o->tw * (size_t)o->th);
	if (!b->dirty)
		return false;
	memset(b->dirty, 1, (size_t)o->tw * (size_t)o->th);   /* a new picture: all of it */
	return true;
}

static void frame_done(void *data, struct wl_callback *cb, uint32_t t)
{
	(void)t;
	wl_callback_destroy(cb);
	((struct output *)data)->waiting_frame = false;
}
static const struct wl_callback_listener frame_listener = { .done = frame_done };

/* what changed since this picture was last shown, into it, and shown */
static void flush(struct output *o)
{
	if (!o->ready || o->waiting_frame || o->closed)
		return;
	struct buffer *b = !o->buf[0].busy ? &o->buf[0] : &o->buf[1];
	if (b->busy)
		return;
	if (!b->wl && !make_buffer(o, b))
		return;
	bool any = false;
	for (int ty = 0; ty < o->th; ty++)
		for (int tx = 0; tx < o->tw; tx++) {
			if (!b->dirty[ty * o->tw + tx])
				continue;
			b->dirty[ty * o->tw + tx] = 0;
			any = true;
			int x0 = tx * TILE, y0 = ty * TILE;
			for (int y = y0; y < y0 + TILE && y < o->ch; y++)
				for (int x = x0; x < x0 + TILE && x < o->cw; x++) {
					uint32_t c = o->dots[(size_t)y * (size_t)o->cw + (size_t)x];
					int px = x * o->bs, py = y * o->bs;
					for (int j = py; j < py + o->bs && j < o->H; j++) {
						uint32_t *row = b->px + (size_t)j * (size_t)o->W;
						for (int i = px; i < px + o->bs && i < o->W; i++)
							row[i] = c;
					}
				}
			wl_surface_damage_buffer(o->surface, x0 * o->bs, y0 * o->bs, TILE * o->bs, TILE * o->bs);
		}
	if (!any)
		return;
	wl_surface_attach(o->surface, b->wl, 0, 0);
	b->busy = true;
	struct wl_callback *cb = wl_surface_frame(o->surface);
	wl_callback_add_listener(cb, &frame_listener, o);
	o->waiting_frame = true;
	wl_surface_commit(o->surface);
}

/* the grid for this screen, once its size is known */
static bool setup(struct output *o)
{
	o->W = o->lw * o->scale, o->H = o->lh * o->scale;
	int L = o->W > o->H ? o->W : o->H, S = o->W > o->H ? o->H : o->W;
	int a = (L + 639) / 640, b = (S + 359) / 360;
	o->bs = a > b ? a : b;
	if (o->bs < 2)
		o->bs = 2;
	o->cw = (o->W + o->bs - 1) / o->bs, o->ch = (o->H + o->bs - 1) / o->bs;
	o->tw = (o->cw + TILE - 1) / TILE, o->th = (o->ch + TILE - 1) / TILE;
	size_t n = (size_t)o->cw * (size_t)o->ch;
	o->under = calloc(n, sizeof *o->under);
	o->dots = calloc(n, sizeof *o->dots);
	if (!o->under || !o->dots)
		return false;
	o->rng = seed ^ (o->global * 2654435761u);
	o->clock_min = -1;
	/* the scene centred on the grid (a screen of another shape: cut, or the ground round it) */
	o->ox = (o->cw - art.w) / 2, o->oy = (o->ch - art.h) / 2;
	for (int y = 0; y < o->ch; y++)
		for (int x = 0; x < o->cw; x++) {
			int sx = x - o->ox, sy = y - o->oy;
			uint32_t c = pal[SHADE];
			if (sx >= 0 && sy >= 0 && sx < art.w && sy < art.h) {
				const unsigned char *p = art.rgb + 3 * ((size_t)sy * (size_t)art.w + (size_t)sx);
				c = 0xff000000u | (uint32_t)p[0] << 16 | (uint32_t)p[1] << 8 | p[2];
			}
			o->under[(size_t)y * (size_t)o->cw + (size_t)x] = o->dots[(size_t)y * (size_t)o->cw + (size_t)x] = c;
		}
	wl_surface_set_buffer_scale(o->surface, o->scale);
	o->ready = true;
	return true;
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
	if (!leaving) {
		leaving = true;
		leave_at = now_ms();
		if (idle_mode && !lock_started)
			lock_start();             /* (not up yet: the cloth stays until it is) */
	}
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
	wl_pointer_set_cursor(p, serial, NULL, 0, 0);   /* no pointer over the cloth */
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

/* --idle: the lock, started as the saver shows — under it, so the first input only washes
 * the cloth away from over a lock already up (dwl keeps the saver over the lock: its own
 * scene layer, LyrSaver). kawa-lock returns once every screen is locked (lock_up: it has) */
static void lock_start(void)
{
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

static bool read_palette(void)
{
	char p[PATH_MAX], line[256];
	const char *home = getenv("HOME");
	snprintf(p, sizeof p, "%s/.config/fedokawaii/current/saver.conf", home ? home : "");
	FILE *f = fopen(p, "r");
	if (!f) {
		fprintf(stderr, "kawa-saver: %s: %s (fedokawaii repair puts it back)\n", p, strerror(errno));
		return false;
	}
	unsigned have = 0;
	while (fgets(line, sizeof line, f)) {
		char *eq = strchr(line, '=');
		if (line[0] == '#' || !eq)
			continue;
		*eq = 0;
		for (int i = 0; i < NCOL; i++)
			if (!strcmp(line, colour_names[i])) {
				pal[i] = 0xff000000u | (uint32_t)strtoul(eq + 1, NULL, 16);
				have |= 1u << i;
			}
	}
	fclose(f);
	if (have != (1u << NCOL) - 1) {
		fprintf(stderr, "kawa-saver: %s lacks a colour (fedokawaii repair puts it back)\n", p);
		return false;
	}
	return true;
}

/* a P6 picture (tools/build-saver.py writes them): its bytes, its size */
static unsigned char *read_ppm(const char *path, int *w, int *h)
{
	FILE *f = fopen(path, "r");
	int max = 0;
	if (!f)
		return NULL;
	unsigned char *px = NULL;
	if (fscanf(f, "P6 %d %d %d", w, h, &max) == 3 && max == 255 && *w > 0 && *h > 0 && fgetc(f) != EOF) {
		size_t n = 3 * (size_t)*w * (size_t)*h;
		px = malloc(n);
		if (px && fread(px, 1, n, f) != n) {
			free(px);
			px = NULL;
		}
	}
	fclose(f);
	return px;
}

/* the mood's scene: its pictures, and lock-scene.txt's words for the flames */
static bool read_art(void)
{
	char dir[PATH_MAX], cur[PATH_MAX], link[64], p[PATH_MAX + 32], line[256];
	const char *home = getenv("HOME");
	snprintf(cur, sizeof cur, "%s/.config/fedokawaii/current", home ? home : "");
	ssize_t n = readlink(cur, link, sizeof link - 1);
	if (n <= 0)
		return false;
	link[n] = 0;
	const char *mood = strrchr(link, '/');
	mood = mood ? mood + 1 : link;
	art.dust = !strcmp(mood, "light");
	snprintf(dir, sizeof dir, "%s/.local/share/fedokawaii/%s", home ? home : "", mood);
	snprintf(p, sizeof p, "%s/saver-scene.ppm", dir);
	if (!(art.rgb = read_ppm(p, &art.w, &art.h)))
		return false;
	snprintf(p, sizeof p, "%s/lock-scene.txt", dir);
	FILE *f = fopen(p, "r");
	if (!f)
		return false;
	int fw = 0, fh = 0, frames = 0;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "frames %d %d %d", &fw, &fh, &frames) == 3) ;
		else if (art.nflames < 4 && sscanf(line, "flame %d %d", &art.fx[art.nflames], &art.fy[art.nflames]) == 2)
			art.nflames++;
	}
	fclose(f);
	int w = 0, h = 0;
	snprintf(p, sizeof p, "%s/saver-flame.ppm", dir);
	if (art.nflames && frames > 0 && (art.flame = read_ppm(p, &w, &h)) && w == fw * frames && h == fh)
		art.fw = fw, art.fh = fh, art.frames = frames;
	else
		art.nflames = 0;
	art.spark[0] = art.dust ? pal[ACCENT_TEXT] : pal[TEXT];
	art.spark[1] = art.dust ? pal[THREAD] : pal[ACCENT_TEXT];
	art.spark[2] = art.dust ? pal[EDGE2] : pal[ACCENT];
	return true;
}

static void usage(void)
{
	fputs("usage: kawa-saver [--idle] [--seed N] [--pace MS]\n", stderr);
	exit(2);
}

int main(int argc, char **argv)
{
	seed = (unsigned)time(NULL) ^ (unsigned)getpid();
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--idle")) idle_mode = true;
		else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = (unsigned)strtoul(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--pace") && i + 1 < argc) pace = atoi(argv[++i]);   /* (renders: a faster clock) */
		else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
			puts("kawa-saver — the screensaver (sashiko stitched across every screen); any input ends it.\n"
			     "  kawa-saver         now (nothing locks)\n"
			     "  kawa-saver --idle  away 15 minutes (kawa-idle): the screensaver, the lock behind it as it\n"
			     "                     ends (switched off in quick settings: the lock at once)");
			return 0;
		} else usage();
	}
	if (pace < 1 || pace > 1000)
		usage();
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
	if (!read_palette())
		return fail("no colours (fedokawaii repair puts saver.conf back)");
	if (!read_art())
		return fail("no scene (fedokawaii repair puts saver-scene.ppm back)");
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
	if (!compositor || !shm || !layer_shell)
		return fail("the compositor lacks layer-shell or shared memory");
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
		if (o->configured && !o->closed && o->lw > 0 && o->lh > 0 && setup(o))
			shown++;
	if (!shown)
		return fail("no screen took it");
	if (idle_mode) {
		wl_display_roundtrip(display);    /* (its first frame shown before the lock comes) */
		lock_start();
	}
	struct pollfd pfd = { .fd = wl_display_get_fd(display), .events = POLLIN };
	double next = now_ms();
	while (!stop) {
		double t = now_ms();
		if (leaving) {
			/* gone once the lock is up (it has the keyboard from then: with it no key or
			 * button is waited for) or, without a lock, every key and button is up again
			 * (none reaches a window) — whole until then; dwl dissolves its last picture
			 * away over what it covered, cell by cell (dwl.patch: layeranims) */
			if (idle_mode ? lock_up() : held == 0)
				break;
			if (t - leave_at > (idle_mode ? 15000 : 3000))
				break;                    /* (a key that never comes up, a lock that hangs) */
		}
		if (!leaving && t >= next) {
			next += pace;
			if (next < t) next = t + pace;
			tick++;
			if (!idle_mode && tick % (1000 / pace + 1) == 0 && locked())
				break;                    /* locked meanwhile: the lock is over it all */
			wl_list_for_each(o, &outputs, link)
				if (o->ready && !o->closed) {
					step(o);
					flush(o);
				}
		}
		wl_list_for_each(o, &outputs, link)
			if (o->ready && !o->closed)
				flush(o);                 /* (a frame done since: what waited goes out) */
		while (wl_display_prepare_read(display) != 0)
			if (wl_display_dispatch_pending(display) < 0)
				goto out;
		if (wl_display_flush(display) < 0 && errno != EAGAIN) {
			wl_display_cancel_read(display);
			break;
		}
		int wait = leaving ? 8 : (int)(next - now_ms());
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
