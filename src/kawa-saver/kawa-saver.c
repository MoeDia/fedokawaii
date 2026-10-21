/*
 * kawa-saver — the screensaver: sashiko, stitched across every screen.
 *
 *   kawa-saver         now (a look at it: any input ends it, nothing locks)
 *   kawa-saver --wash  the one transition (a theme switch, a new wallpaper): see wash()
 *   kawa-saver --idle  away 15 minutes (kawa-idle, from swayidle: never while something
 *                      plays): the screensaver, and the lock behind it — the first key or move
 *                      starts the lock (kawa-lock) at once and washes the cloth away while it
 *                      comes up; it goes only once the lock is there, so neither that key nor
 *                      any typed after it reaches a window. Switched off in quick
 *                      settings (~/.local/state/fedokawaii/saver: on, or off): the lock at once.
 *                      Should it not be able to show, it locks all the same.
 *
 * On the theme's ground (dark or light: current/saver.conf), needles run along the lines of a
 * hitomezashi grid — one stitch over, one under, each line starting on its own side — and the
 * thread they leave slowly makes the pattern — the bar's own cloth thread, each dot of it with
 * its shadow a dot down and to the right — a vermilion dot at each needle's tip.
 * Seals are stamped on the cloth now and then (a kanji of sewing, sleep or night — 縫 糸 針 夢
 * 眠 静 月 星 夜 …, accent_text in a 2-dot frame) and lifted again; a small patch, framed in
 * running stitch as the bar's clock is, tells the time (時 and "09:41 PM", the lock screen's
 * words) and moves every minute. When the cloth is
 * full it rests, then is washed (an ordered dither, block by block) and sewn anew. Everything
 * is drawn on a grid of dots as big as a pixel of the wallpapers' pixel art (3 px at 1080p,
 * 4 at 1440p, 6 at 4K), in the design system's own letters (Sumi UI at 16 px: glyphs.h).
 * Nothing on the screen stays put: no burn-in.
 *
 * Any key, click, scroll or move of the pointer ends it — and goes nowhere else: it holds the
 * keyboard while it shows (a layer on top of everything, the bar too), and it waits for the
 * key or button to be let go before it leaves, so neither press nor release reaches a window.
 * It answers at once: the cloth washes away into the ground (180 ms) as it leaves.
 * It ends too when the desktop locks otherwise (kawa-lock), and stays one at a time.
 *
 * 8 to 17 MB a 1080p screen (one or two pictures of it), almost no CPU (12 steps a second, only the
 * dots that changed are drawn). Built by theme.sh (src/kawa-saver/Makefile). Exit: 0 · 1 it
 * could not show (said on stderr) · 2 wrong use.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
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

#define CELL 8          /* the sashiko grid, in dots */
#define TILE 16         /* what is redrawn at once, in dots */
#define SEAL 26         /* a seal, as the panels draw it: the kanji (16) with 4 of paper and 1 of frame round it */
#define GAP GLYPH_COL   /* a gap, as the panels keep: a column of the letters */
#define MAXSEALS 6
#define NEEDLES 8
#define SPEED 2         /* dots a needle moves a step */

struct buffer {
	struct wl_buffer *wl;
	uint32_t *px;
	size_t size;
	bool busy;
	uint8_t *dirty;     /* the tiles this picture has not been given yet */
};

struct rect { int x, y, w, h; };
struct seal { bool live; struct rect r; long until; int glyph; };
struct needle { bool live; int line; int pos; int dir; };

struct output {
	struct wl_list link;
	struct wl_output *wl;
	uint32_t global;
	char name[64];      /* (--wash: grim's -o) */
	uint32_t *old;      /* (--wash: the screen as it was, W × H) */
	int scale;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer;
	int lw, lh;
	bool configured, closed, waiting_frame, ready;
	/* the picture, and the grid of dots it shows */
	int W, H, bs, cw, ch, tw, th;
	struct buffer buf[2];
	uint8_t *thread;    /* the cloth: what is sewn (a colour a dot) */
	uint8_t *dots;      /* what shows: the cloth, the seals and the clock over it */
	/* the sashiko */
	int nh, nv;         /* horizontal lines (rows of the grid), vertical ones */
	uint8_t *parity;    /* per line: which stitches are over */
	int *order, next;   /* the lines in the order they are sewn, and the next to take */
	struct needle needle[NEEDLES];
	int phase;          /* SEW, REST, WASH */
	long phase_at;
	struct seal seals[MAXSEALS];
	long next_seal;
	struct rect clock;
	int clock_min;
	unsigned rng;
};
enum { SEW, REST, WASH };

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
static bool leaving;                      /* input came: washed away, gone once every key and button is up */
static bool idle_mode;                    /* --idle: the lock behind it */
static pid_t lock_pid;                    /* kawa-lock, started at the first input (--idle) */
#define PART_MS 180                       /* the wash as it leaves */
static int held;                          /* keys and buttons down */
static double leave_at;
static bool moved_base;
static double base_x, base_y;
static volatile sig_atomic_t stop;

static const uint8_t bayer[8][8] = {
	{  0, 32,  8, 40,  2, 34, 10, 42 }, { 48, 16, 56, 24, 50, 18, 58, 26 },
	{ 12, 44,  4, 36, 14, 46,  6, 38 }, { 60, 28, 52, 20, 62, 30, 54, 22 },
	{  3, 35, 11, 43,  1, 33,  9, 41 }, { 51, 19, 59, 27, 49, 17, 57, 25 },
	{ 15, 47,  7, 39, 13, 45,  5, 37 }, { 63, 31, 55, 23, 61, 29, 53, 21 },
};

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

static bool in_rect(const struct rect *r, int x, int y)
{
	return x >= r->x && x < r->x + r->w && y >= r->y && y < r->y + r->h;
}

static bool covered(struct output *o, int x, int y)
{
	if (o->clock.w && in_rect(&o->clock, x, y))
		return true;
	for (int i = 0; i < MAXSEALS; i++)
		if (o->seals[i].live && in_rect(&o->seals[i].r, x, y))
			return true;
	return false;
}

static void put(struct output *o, int x, int y, uint8_t c)
{
	if (x < 0 || y < 0 || x >= o->cw || y >= o->ch)
		return;
	size_t i = (size_t)y * (size_t)o->cw + (size_t)x;
	if (o->dots[i] != c) {
		o->dots[i] = c;
		dirty(o, x, y, 1, 1);
	}
}

/* a dot of the cloth: kept, and shown unless a seal or the clock lies over it */
static void sew(struct output *o, int x, int y, uint8_t c)
{
	if (x < 0 || y < 0 || x >= o->cw || y >= o->ch)
		return;
	o->thread[(size_t)y * (size_t)o->cw + (size_t)x] = c;
	if (!covered(o, x, y))
		put(o, x, y, c);
}

/* the cloth shown again where r was (a seal lifted, the clock moved) */
static void uncover(struct output *o, struct rect r)
{
	for (int y = r.y; y < r.y + r.h; y++)
		for (int x = r.x; x < r.x + r.w; x++)
			if (x >= 0 && y >= 0 && x < o->cw && y < o->ch && !covered(o, x, y))
				put(o, x, y, o->thread[(size_t)y * (size_t)o->cw + (size_t)x]);
}

static void fill(struct output *o, int x, int y, int w, int h, uint8_t c)
{
	for (int j = y; j < y + h; j++)
		for (int i = x; i < x + w; i++)
			put(o, i, j, c);
}

static void frame(struct output *o, int x, int y, int w, int h, int t, uint8_t c)
{
	fill(o, x, y, w, t, c);
	fill(o, x, y + h - t, w, t, c);
	fill(o, x, y, t, h, c);
	fill(o, x + w - t, y, t, h, c);
}

static const struct glyph *glyph_of(const char *ch, size_t n)
{
	for (size_t i = 0; i < sizeof glyphs / sizeof *glyphs; i++)
		if (strlen(glyphs[i].ch) == n && !memcmp(glyphs[i].ch, ch, n))
			return &glyphs[i];
	return NULL;
}

static void draw_glyph(struct output *o, const struct glyph *g, int x, int y, uint8_t c)
{
	for (int r = 0; r < GLYPH_H; r++)
		for (int b = 0; b < g->w; b++)
			if (g->rows[r] >> (g->w - 1 - b) & 1)
				put(o, x + b, y + r, c);
}

/* the ink's box inside the glyph's cell (a seal centres its ink, as build-art.py does) */
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

/* a seal at x, y: SEAL × SEAL, the kanji's ink centred; stamped (a 2-dot accent_text frame)
 * or a heading's (1 dot of edge2) */
static void draw_seal(struct output *o, int x, int y, const struct glyph *g, bool stamped, uint8_t ground)
{
	int x0, y0, x1, y1;
	fill(o, x, y, SEAL, SEAL, ground);
	frame(o, x, y, SEAL, SEAL, stamped ? 2 : 1, stamped ? ACCENT_TEXT : EDGE2);
	ink(g, &x0, &y0, &x1, &y1);
	draw_glyph(o, g, x + (SEAL - (x1 - x0 + 1)) / 2 - x0, y + (SEAL - (y1 - y0 + 1)) / 2 - y0, ACCENT_TEXT);
}

/* ── the sashiko ────────────────────────────────────────────────────────────────────── */
/* line l: the first nh are horizontal (y = l·CELL), the rest vertical (x = (l-nh)·CELL);
 * its length in dots, and whether the dot at pos along it is a stitch over the cloth */
static int line_len(struct output *o, int l) { return l < o->nh ? o->cw : o->ch; }
static bool stitch(struct output *o, int l, int pos)
{
	int seg = pos / CELL, off = pos % CELL;
	return off != 0 && (seg + o->parity[l]) % 2 == 0;
}
static void line_dot(struct output *o, int l, int pos, int *x, int *y)
{
	if (l < o->nh) *x = pos, *y = l * CELL;
	else *x = (l - o->nh) * CELL, *y = pos;
}

static void new_cloth(struct output *o)
{
	int n = o->nh + o->nv;
	for (int l = 0; l < n; l++) {
		o->parity[l] = (uint8_t)rnd(o, 2);
		o->order[l] = l;
	}
	for (int i = n - 1; i > 0; i--) {    /* the lines in a random order */
		int j = (int)rnd(o, (unsigned)i + 1), t = o->order[i];
		o->order[i] = o->order[j], o->order[j] = t;
	}
	o->next = 0;
	for (int k = 0; k < NEEDLES; k++)
		o->needle[k].live = false;
	o->phase = SEW;
	o->phase_at = tick;
}

static void sew_step(struct output *o)
{
	bool any = false;
	for (int k = 0; k < NEEDLES; k++) {
		struct needle *nd = &o->needle[k];
		if (!nd->live && o->next < o->nh + o->nv) {
			nd->live = true;
			nd->line = o->order[o->next++];
			nd->dir = rnd(o, 2) ? 1 : -1;
			nd->pos = nd->dir > 0 ? 0 : line_len(o, nd->line) - 1;
		}
		if (!nd->live)
			continue;
		any = true;
		int x, y, len = line_len(o, nd->line);
		for (int s = 0; s < SPEED && nd->live; s++) {
			line_dot(o, nd->line, nd->pos, &x, &y);
			if (stitch(o, nd->line, nd->pos)) {
				sew(o, x, y, THREAD);         /* the stitch, its shadow a dot down and right */
				if (x + 1 < o->cw && y + 1 < o->ch &&
				    o->thread[(size_t)(y + 1) * (size_t)o->cw + (size_t)(x + 1)] == GROUND)
					sew(o, x + 1, y + 1, SHADE);
			} else {
				sew(o, x, y, o->thread[(size_t)y * (size_t)o->cw + (size_t)x]);
			}
			nd->pos += nd->dir;
			if (nd->pos < 0 || nd->pos >= len)
				nd->live = false;
		}
		for (int b = 0; nd->live && b < 3; b++) {   /* the needle: 3 dots of vermilion */
			int p = nd->pos + b * nd->dir;          /* ahead, sewn over as it moves on */
			if (p < 0 || p >= len)
				break;
			line_dot(o, nd->line, p, &x, &y);
			if (!covered(o, x, y))
				put(o, x, y, ACCENT);
		}
	}
	if (!any) {
		o->phase = REST;
		o->phase_at = tick;
	}
}

static void wash_step(struct output *o, int level)   /* level 0…64: dots at or under it go */
{
	for (int y = 0; y < o->ch; y++)
		for (int x = 0; x < o->cw; x++) {
			size_t i = (size_t)y * (size_t)o->cw + (size_t)x;
			if (o->thread[i] != GROUND && bayer[(y / 2) & 7][(x / 2) & 7] < level)
				sew(o, x, y, GROUND);
		}
}

/* leaving: everything shown — the cloth, the seals, the clock — washed into the ground, in the
 * same ordered dither (level 0…65) */
static void part_step(struct output *o, int level)
{
	for (int y = 0; y < o->ch; y++)
		for (int x = 0; x < o->cw; x++)
			if (bayer[(y / 2) & 7][(x / 2) & 7] < level)
				put(o, x, y, GROUND);
}

/* ── the seals and the clock ────────────────────────────────────────────────────────── */
/* a free place on the grid for a w × h thing: inside the cells, a dot from the lines (a seal,
 * framed by the stitches round it), or over the lines, its edges on them (lines: the clock) */
static bool place(struct output *o, int w, int h, bool lines, struct rect *r, const struct rect *skip)
{
	int cx = (w + 1 + CELL - 1) / CELL, cy = (h + 1 + CELL - 1) / CELL;
	int gw = o->cw / CELL - cx, gh = o->ch / CELL - cy;
	if (gw < 1 || gh < 1)
		return false;
	for (int tries = 0; tries < 40; tries++) {
		int d = lines ? 0 : 1;
		struct rect c = { (int)(rnd(o, (unsigned)gw) + 1) * CELL + d, (int)(rnd(o, (unsigned)gh) + 1) * CELL + d, w, h };
		if (c.x + w >= o->cw - CELL || c.y + h >= o->ch - CELL)
			continue;
		bool clash = false;
		struct rect pad = { c.x - CELL, c.y - CELL, w + 2 * CELL, h + 2 * CELL };
		for (int i = 0; i < MAXSEALS && !clash; i++) {
			const struct rect *s = &o->seals[i].r;
			clash = o->seals[i].live && s != skip && s->x < pad.x + pad.w && pad.x < s->x + s->w &&
				s->y < pad.y + pad.h && pad.y < s->y + s->h;
		}
		if (!clash && o->clock.w && &o->clock != skip)
			clash = o->clock.x < pad.x + pad.w && pad.x < o->clock.x + o->clock.w &&
				o->clock.y < pad.y + pad.h && pad.y < o->clock.y + o->clock.h;
		if (!clash) {
			*r = c;
			return true;
		}
	}
	return false;
}

static void seals_step(struct output *o)
{
	long per_s = 1000 / pace;
	for (int i = 0; i < MAXSEALS; i++)
		if (o->seals[i].live && tick >= o->seals[i].until) {
			o->seals[i].live = false;
			uncover(o, o->seals[i].r);
		}
	if (tick < o->next_seal)
		return;
	o->next_seal = tick + per_s * (5 + (long)rnd(o, 5));
	for (int i = 0; i < MAXSEALS; i++) {
		if (o->seals[i].live)
			continue;
		struct rect r;
		if (!place(o, SEAL, SEAL, false, &r, NULL))
			return;
		size_t nk = 0;                    /* the kanji: one of saver_kanji's (3 bytes each) */
		for (const char *p = saver_kanji; *p; p += 3) nk++;
		const char *k = saver_kanji + 3 * rnd(o, (unsigned)nk);
		const struct glyph *g = glyph_of(k, 3);
		if (!g)
			return;
		o->seals[i] = (struct seal){ true, r, tick + per_s * (30 + (long)rnd(o, 30)), (int)(g - glyphs) };
		draw_seal(o, r.x, r.y, g, true, GROUND);
		return;
	}
}

/* a running stitch round w × h at x, y as the bar's patches have it: 3 dots on, 2 off, laid
 * from both corners so it is symmetric and every corner is sewn; each dot's shadow a dot down
 * and right (inside the box: the frame takes w-1 × h-1, the shadow the last column and row) */
static bool run_on(int i, int n) { int d = i < n - 1 - i ? i : n - 1 - i; return d % 5 < 3; }
static void stitch_frame(struct output *o, int x, int y, int w, int h)
{
	int fw = w - 1, fh = h - 1;
	for (int pass = 0; pass < 2; pass++)  /* the shadows, then the thread over them */
		for (int i = 0; i < fw; i++)
			for (int j = 0; j < fh; j++) {
				bool edge = i == 0 || j == 0 || i == fw - 1 || j == fh - 1;
				if (!edge || !((j == 0 || j == fh - 1) ? run_on(i, fw) : run_on(j, fh)))
					continue;
				if (pass == 0)
					put(o, x + i + 1, y + j + 1, SHADE);
				else
					put(o, x + i, y + j, THREAD);
			}
}

/* the clock: a patch over the grid's lines, its edges on them (the surface, framed in running
 * stitch as the bar's clock is) — its heading seal 時 and the time in text, centred in it */
static void draw_clock(struct output *o, const char *t)
{
	struct rect r = o->clock;
	fill(o, r.x, r.y, r.w, r.h, SURFACE);
	stitch_frame(o, r.x, r.y, r.w, r.h);
	const struct glyph *g = glyph_of("時", strlen("時"));
	int cw = SEAL + GAP + GLYPH_COL * (int)strlen(t), x = r.x + (r.w - cw) / 2, y = r.y + (r.h - SEAL) / 2;
	if (g)
		draw_seal(o, x, y, g, false, SURFACE);
	x += SEAL + GAP, y += (SEAL - GLYPH_H) / 2 + 1;
	for (const char *p = t; *p; p++) {
		const struct glyph *c = glyph_of(p, 1);
		if (c)
			draw_glyph(o, c, x, y, TEXT);
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
	struct rect old = o->clock, r;
	int w = 8 + SEAL + GAP + GLYPH_COL * (int)strlen(t) + 8, h = 8 + SEAL + 8;
	w = (w + CELL - 2) / CELL * CELL + 1, h = (h + CELL - 2) / CELL * CELL + 1;   /* line to line */
	if (!place(o, w, h, true, &r, &o->clock))
		return;
	o->clock_min = tm.tm_min;
	o->clock = r;                         /* (moved every minute: nothing stays put) */
	if (old.w)
		uncover(o, old);
	draw_clock(o, t);
}

static void step(struct output *o)
{
	long per_s = 1000 / pace;
	switch (o->phase) {
	case SEW:
		sew_step(o);
		break;
	case REST:                            /* the cloth full: a minute to look at it */
		if (tick - o->phase_at > 60 * per_s) {
			o->phase = WASH;
			o->phase_at = tick;
		}
		break;
	case WASH: {                          /* washed in 4 s, then sewn anew */
		long t = tick - o->phase_at, len = 4 * per_s;
		wash_step(o, (int)(65 * t / (len ? len : 1)));
		if (t >= len)
			new_cloth(o);
		break;
	}
	}
	seals_step(o);
	clock_step(o);
}

/* ── the screens ────────────────────────────────────────────────────────────────────── */
static void buffer_release(void *data, struct wl_buffer *b)
{
	(void)b;
	((struct buffer *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };
static uint32_t buffer_format = WL_SHM_FORMAT_XRGB8888;   /* (--wash: ARGB, its washed dots clear) */

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
					uint32_t c = pal[o->dots[(size_t)y * (size_t)o->cw + (size_t)x]];
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
	o->nh = (o->ch - 1) / CELL + 1, o->nv = (o->cw - 1) / CELL + 1;
	size_t n = (size_t)o->cw * (size_t)o->ch;
	o->thread = calloc(n, 1);
	o->dots = calloc(n, 1);
	o->parity = calloc((size_t)(o->nh + o->nv), 1);
	o->order = calloc((size_t)(o->nh + o->nv), sizeof *o->order);
	if (!o->thread || !o->dots || !o->parity || !o->order)
		return false;
	o->rng = seed ^ (o->global * 2654435761u);
	o->clock_min = -1;
	new_cloth(o);
	o->next_seal = tick + 2 * (1000 / pace);
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
		if (idle_mode)
			lock_start();             /* the lock coming up while the cloth washes away */
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
static void out_name(void *d, struct wl_output *w, const char *n)
{
	(void)w;
	snprintf(((struct output *)d)->name, sizeof ((struct output *)d)->name, "%s", n);
}
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

/* --idle: the lock, started at the first input — kawa-lock returns once every screen is
 * locked (lock_up: it has) */
static void lock_start(void)
{
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

static void usage(void)
{
	fputs("usage: kawa-saver [--idle] [--seed N] [--pace MS]\n", stderr);
	exit(2);
}

/* ── --wash: the one transition (a theme switch, a new wallpaper) ────────────────────────
 * The screen as it was (grim, each monitor) laid over everything, then washed away as the
 * screensaver washes its cloth: an ordered dither on the same grid of dots, 8 steps of 32 ms
 * (~1/4 s), the new look showing through more of the dots at each step — stepped, never eased
 * (design-system §5). It never takes input (no keyboard, an empty input region: every click
 * goes through to what is under it). The caller reads "covered" on our stdout once the old
 * picture is up, makes its change underneath, then closes our stdin: the wash starts. SIGTERM
 * (another switch while this one washes: kawa-theme) takes it away at once — the final state.
 * Anything that fails (no grim, no screen) prints "covered" all the same and leaves: the change
 * is never held up. Our pid in $XDG_RUNTIME_DIR/kawa-wash.pid while it shows. */
#define WASH_STEPS 8
#define WASH_MS 32
static bool load_ppm(struct output *o, const char *path)
{
	FILE *f = fopen(path, "rb");
	int w, h, mx;
	if (!f)
		return false;
	if (fscanf(f, "P6 %d %d %d", &w, &h, &mx) != 3 || mx != 255 || fgetc(f) == EOF || w != o->W || h != o->H) {
		fclose(f);
		return false;
	}
	o->old = malloc((size_t)w * (size_t)h * 4);
	uint8_t *row = malloc((size_t)w * 3);
	bool ok = o->old && row;
	for (int y = 0; ok && y < h; y++) {
		ok = fread(row, 3, (size_t)w, f) == (size_t)w;
		for (int x = 0; ok && x < w; x++)
			o->old[(size_t)y * (size_t)w + (size_t)x] = 0xff000000u | (uint32_t)row[3 * x] << 16
				| (uint32_t)row[3 * x + 1] << 8 | row[3 * x + 2];
	}
	free(row);
	fclose(f);
	return ok;
}

/* step k (0: whole, WASH_STEPS: gone) of the wash into b, and shown */
static void wash_draw(struct output *o, struct buffer *b, int k)
{
	int level = 64 * k / WASH_STEPS;
	for (int y = 0; y < o->H; y++) {
		uint32_t *dst = b->px + (size_t)y * (size_t)o->W, *src = o->old + (size_t)y * (size_t)o->W;
		const uint8_t *br = bayer[(y / o->bs) & 7];
		for (int x = 0; x < o->W; x++)
			dst[x] = br[(x / o->bs) & 7] < level ? 0 : src[x];
	}
	wl_surface_attach(o->surface, b->wl, 0, 0);
	wl_surface_damage_buffer(o->surface, 0, 0, o->W, o->H);
	b->busy = true;
	struct wl_callback *cb = wl_surface_frame(o->surface);
	wl_callback_add_listener(cb, &frame_listener, o);
	o->waiting_frame = true;
	wl_surface_commit(o->surface);
}

static int wash(void)
{
	char pidp[PATH_MAX], tmp[PATH_MAX];
	struct output *o;
	bool covered = false;
	signal(SIGTERM, on_signal);
	signal(SIGINT, on_signal);
	signal(SIGPIPE, SIG_IGN);
	buffer_format = WL_SHM_FORMAT_ARGB8888;
	snprintf(pidp, sizeof pidp, "%s/kawa-wash.pid", runtime());
	display = wl_display_connect(NULL);
	if (!display)
		goto done;
	wl_list_init(&outputs);
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	wl_display_roundtrip(display);
	if (!compositor || !shm || !layer_shell)
		goto done;
	wl_list_for_each(o, &outputs, link) {
		o->surface = wl_compositor_create_surface(compositor);
		struct wl_region *none = wl_compositor_create_region(compositor);
		wl_surface_set_input_region(o->surface, none);   /* every click goes through */
		wl_region_destroy(none);
		o->layer = zwlr_layer_shell_v1_get_layer_surface(layer_shell, o->surface, o->wl,
				ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kawa-wash");
		zwlr_layer_surface_v1_add_listener(o->layer, &layer_listener, o);
		zwlr_layer_surface_v1_set_anchor(o->layer, ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP |
				ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
				ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
		zwlr_layer_surface_v1_set_exclusive_zone(o->layer, -1);
		zwlr_layer_surface_v1_set_keyboard_interactivity(o->layer, 0);
		wl_surface_commit(o->surface);
	}
	wl_display_roundtrip(display);
	/* the screens as they are, before anything of ours is on them */
	int shown = 0;
	wl_list_for_each(o, &outputs, link) {
		if (!o->configured || o->closed || o->lw <= 0 || !o->name[0])
			continue;
		o->W = o->lw * o->scale, o->H = o->lh * o->scale;
		int L = o->W > o->H ? o->W : o->H, S = o->W > o->H ? o->H : o->W;
		int a = (L + 639) / 640, c = (S + 359) / 360;
		o->bs = a > c ? a : c;
		o->tw = o->th = 1;
		snprintf(tmp, sizeof tmp, "%s/kawa-wash-%d.ppm", runtime(), (int)o->global);
		pid_t g = fork();
		if (g == 0) {
			int nul = open("/dev/null", O_WRONLY);
			if (nul >= 0) { dup2(nul, 1); dup2(nul, 2); }
			execlp("grim", "grim", "-t", "ppm", "-o", o->name, tmp, (char *)NULL);
			_exit(127);
		}
		int st = 1;
		if (g > 0)
			while (waitpid(g, &st, 0) < 0 && errno == EINTR)
				;
		bool got = g > 0 && WIFEXITED(st) && WEXITSTATUS(st) == 0 && load_ppm(o, tmp);
		unlink(tmp);
		if (!got || !make_buffer(o, &o->buf[0]) || !make_buffer(o, &o->buf[1]))
			continue;
		wl_surface_set_buffer_scale(o->surface, o->scale);
		o->ready = true;
		wash_draw(o, &o->buf[0], 0);
		shown++;
	}
	if (!shown || stop)
		goto done;
	FILE *pf = fopen(pidp, "w");
	if (pf) { fprintf(pf, "%d\n", (int)getpid()); fclose(pf); }
	/* covered once every screen has shown the old picture (its frame done), 300 ms at most */
	double t0 = now_ms();
	for (;;) {
		bool all = true;
		wl_list_for_each(o, &outputs, link)
			if (o->ready && o->waiting_frame && !o->closed) all = false;
		if (all || stop || now_ms() - t0 > 300)
			break;
		struct pollfd p = { .fd = wl_display_get_fd(display), .events = POLLIN };
		wl_display_flush(display);
		if (poll(&p, 1, 20) > 0 && wl_display_dispatch(display) < 0)
			goto done;
	}
	puts("covered");
	fflush(stdout);
	covered = true;
	/* the change underneath: until our stdin closes (3 s at most), the screens kept */
	struct pollfd pp[2] = { { .fd = 0, .events = POLLIN }, { .fd = wl_display_get_fd(display), .events = POLLIN } };
	t0 = now_ms();
	while (!stop && now_ms() - t0 < 3000) {
		wl_display_flush(display);
		if (poll(pp, 2, 50) <= 0)
			continue;
		if (pp[1].revents & POLLIN && wl_display_dispatch(display) < 0)
			goto done;
		if (pp[0].revents & (POLLIN | POLLHUP)) {
			char c[64];
			if (read(0, c, sizeof c) <= 0)
				break;
		}
	}
	/* washed away: one step every 32 ms (the first one a step on, as the new look draws) */
	for (int k = 1; k <= WASH_STEPS && !stop; k++) {
		double next = now_ms() + WASH_MS;
		while (!stop && now_ms() < next) {
			struct pollfd p = { .fd = wl_display_get_fd(display), .events = POLLIN };
			wl_display_flush(display);
			int w = (int)(next - now_ms());
			if (poll(&p, 1, w < 0 ? 0 : w) > 0 && wl_display_dispatch(display) < 0)
				goto done;
		}
		wl_list_for_each(o, &outputs, link) {
			if (!o->ready || o->closed)
				continue;
			struct buffer *b = !o->buf[0].busy ? &o->buf[0] : !o->buf[1].busy ? &o->buf[1] : NULL;
			if (b)
				wash_draw(o, b, k);   /* (both still on screen: this step skipped there) */
		}
	}
done:
	if (!covered) {
		puts("covered");
		fflush(stdout);
	}
	unlink(pidp);
	if (display) {
		wl_list_for_each(o, &outputs, link) {
			if (o->layer)
				zwlr_layer_surface_v1_destroy(o->layer);
			if (o->surface)
				wl_surface_destroy(o->surface);
		}
		wl_display_roundtrip(display);
		wl_display_disconnect(display);
	}
	return 0;
}

int main(int argc, char **argv)
{
	seed = (unsigned)time(NULL) ^ (unsigned)getpid();
	if (argc == 2 && !strcmp(argv[1], "--wash"))
		return wash();
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--idle")) idle_mode = true;
		else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = (unsigned)strtoul(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--pace") && i + 1 < argc) pace = atoi(argv[++i]);   /* (renders: a faster clock) */
		else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
			puts("kawa-saver — the screensaver (sashiko stitched across every screen); any input ends it.\n"
			     "  kawa-saver         now (nothing locks)\n"
			     "  kawa-saver --idle  away 15 minutes (kawa-idle): the screensaver, the lock behind it as it\n"
			     "                     ends (switched off in quick settings: the lock at once)\n"
			     "  kawa-saver --wash  the transition of a theme switch or a new wallpaper: the screen as it\n"
			     "                     was, washed away in 8 dithered steps once stdin closes (kawa-theme)");
			return 0;
		} else usage();
	}
	if (pace < 1 || pace > 1000)
		usage();
	if (locked())
		return 0;                         /* the lock is over everything: nothing to show */
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
	struct pollfd pfd = { .fd = wl_display_get_fd(display), .events = POLLIN };
	double next = now_ms();
	while (!stop) {
		double t = now_ms();
		if (leaving) {
			/* at once: the cloth washes away into the ground (PART_MS) — and with --idle the
			 * lock comes up behind it meanwhile. Gone once it is washed, the lock is up (it has
			 * the keyboard from then: with it no key or button is waited for), and, without
			 * a lock, every key and button is up again (none reaches a window) */
			int level = (int)(65 * (t - leave_at) / PART_MS);
			wl_list_for_each(o, &outputs, link)
				if (o->ready && !o->closed)
					part_step(o, level > 65 ? 65 : level);
			bool washed = t - leave_at >= PART_MS;
			if (washed && (idle_mode ? lock_up() : held == 0))
				break;
			if (t - leave_at > (idle_mode ? 15000 : 3000))
				break;                    /* (a key that never comes up, a lock that hangs) */
		}
		if (!leaving && t >= next) {
			next += pace;
			if (next < t) next = t + pace;
			tick++;
			if (tick % (1000 / pace + 1) == 0 && locked())
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
