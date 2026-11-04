/*
 * kawa-saver — the screensaver: the lock's own painting, asleep (the owner, 4 Nov: "an upgrade to match the
 * new design"; one world with the lock).
 *
 *   kawa-saver         now (a look at it: any input ends it, nothing locks)
 *   kawa-saver --idle  away 15 minutes (kawa-idle, from swayidle: never while something
 *                      plays): the screensaver, with the lock under it — kawa-lock starts once
 *                      the painting covers the screen, and dwl keeps the saver over the lock
 *                      screen (its own layer, for this program alone). The first key or move only
 *                      wakes the world: the painting opens, dot by dot, from the figure's place
 *                      and from the torches, onto the lock already there, and the figure is in it.
 *                      A key pressed before the lock is up waits for it, so neither that key
 *                      nor any after it reaches a window. Already locked (a lock you asked
 *                      for, then away): the saver over it. Switched off in quick settings
 *                      (~/.local/state/fedokawaii/saver: on, or off): the lock at once.
 *                      Should it not be able to show, it locks all the same.
 *
 * The painting (saver-scene.ppm: tools/build-saver.py, the lock's own pixels without the figure) at the
 * lock's own whole scale and place. What moves in it, 12 steps a second, no dot off the painting's grid:
 *   the light   the torches' (lanterns') pools, stepped bands dithered at their rim, breathing with
 *               the flame (each dot knows how near it lies, its relief towards the fire counted in:
 *               the carvings catch the light before the stone behind them);
 *   the flames  the lock's own frames, wandering among them, never a loop;
 *   the halo    a slow glow going round the ring of flames where the figure stands in the lock;
 *   the air     dark: embers rising and smoke along the beam; light: gold dust and falling petals;
 *   the time    a small seal (hakubun, the digits cut out of the red) stamped somewhere else inside
 *               the ring every minute: the world's own clock, never burnt in.
 *
 * Any key, click, scroll or move of the pointer ends it — and goes nowhere else: it holds the
 * keyboard while it shows (a layer on top of everything, the bar too), and without a lock it waits
 * for the key or button to be let go before it leaves, so neither press nor release reaches a window.
 * Without --idle it ends too when the desktop locks (kawa-lock); it stays one at a time. With the
 * screens dark (away 30 minutes) nothing is drawn or computed at all: no frames asked for, no steps.
 *
 * About 15 MB on a 1080p screen, near no CPU: a light step moves only the dots a band just passed
 * (each torch's dots are kept sorted by distance), and only the tiles that changed are drawn and damaged.
 * --render DIR draws its frames to files instead, with no screen (tests/look/test_saver.sh, the renders).
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

/* ── the inks (current/saver.conf) ──────────────────────────────────────────────────── */
enum { SPARK_HOT, SPARK, SPARK_COOL, SPARK_DIM, DRIFT, DRIFT_LO, SEAL_INK, SEAL_HOT, SEAL_CUT, NCOL };
static const char *colour_names[NCOL] = {
	"spark_hot", "spark", "spark_cool", "spark_dim", "drift", "drift_lo", "seal", "seal_hot", "seal_cut",
};
static uint32_t pal[NCOL];

#define TILE 16          /* what is redrawn at once, in dots */
#define BANDS 5          /* a torch's pool: so many steps of light round it */
#define LEVELS (BANDS + 2)   /* no band · each band (the last: the painting as the lock shows it) · the halo's crest */
#define HOT (BANDS + 1)
#define MAXTORCH 4
#define NSPARK 56        /* embers, gold dust */
#define SMOKE_ABOVE 24   /* the beam: so far above a flame's frame */
#define SMOKE_ALONG 66   /* how far the smoke creeps along under it */
#define NPETAL 22        /* the petals: the near ones and the far ones */
#define OVCAP (1 << 15)  /* the most dots drawn over the painting in a step */
#define STEP_MS 83       /* 12 steps a second */
#define WAKE_MS 430      /* the world wakes (§11: 400–450) */
#define FALL_MS 1200     /* it falls asleep (the wash's own time) */
#define DARK_MS 1000     /* a frame asked for and not given for so long: the screens are dark */
#define WOKEN_MS 1200    /* screens lit by the key: the monitor finds its signal, then the world wakes */
#define SEAL_W 17
#define SEAL_H 22

struct buffer {
	struct wl_buffer *wl;
	uint32_t *px;
	size_t size;
	bool busy;
	uint8_t *dirty;     /* the tiles this picture has not been given yet */
};

struct output {
	struct wl_list link;
	struct wl_output *wl;
	uint32_t global;
	int scale;
	struct wl_surface *surface;
	struct zwlr_layer_surface_v1 *layer;
	int lw, lh;
	bool configured, closed, waiting_frame, ready;
	double asked_at;    /* when the frame waited for was asked for */
	/* the picture: the painting n × n, its corner, the lock's own place on this screen */
	int pw, ph, n, ox, oy;
	struct buffer buf[2];
};

/* the mood: how its light falls */
static const struct mood {
	float band[BANDS];            /* the pool's steps, how far each reaches at rest, in dots */
	uint16_t shade[LEVELS][3];    /* a level's light on the paint, red, green, blue, 256 = as painted */
	float relief;                 /* how far the carvings' slopes towards the fire reach beyond the rest, in dots */
	float rim;                    /* the band's dithered rim, in dots */
	int halo_floor;               /* the halo's light where the glow is not */
	float halo_speed;             /* its turn, in 1/256 of a circle a step */
} moods[2] = {
	{	/* the dark: hard, a dungeon carved out of black by its fire */
		{ 214, 158, 112, 74, 42 },
		{ { 62, 60, 70 }, { 84, 80, 88 }, { 118, 112, 112 }, { 164, 154, 146 }, { 212, 202, 188 }, { 256, 256, 256 }, { 330, 300, 250 } },
		15.0f, 7.0f, 1, 0.42f,
	},
	{	/* the light: gold hour in the sky, the lanterns warm against it */
		{ 212, 164, 122, 84, 50 },
		{ { 224, 216, 198 }, { 230, 224, 208 }, { 236, 230, 216 }, { 243, 239, 226 }, { 250, 247, 238 }, { 256, 256, 256 }, { 276, 272, 252 } },
		5.0f, 9.0f, 3, 0.30f,
	},
};
static const struct mood *M;

/* the mood's pictures (tools/build-saver.py) and the lock's words (lock-scene.txt) */
static struct {
	int w, h;
	unsigned char *rgb;           /* the painting */
	uint32_t ground;              /* round it, on a screen of another shape: as the lock */
	int fw, fh, frames, nflames, fx[MAXTORCH], fy[MAXTORCH];
	unsigned char *flame;         /* its frames side by side, the key colour where nothing is */
	float *flame_size;            /* how much fire each frame holds, -1 … 1 */
	bool light;                   /* the light mood: dust and petals, not embers and smoke */
	int cx, cy, r0, r1;           /* the halo: its middle, its radii */
	uint32_t inks[4];
	int ninks;
} art;

/* the world: one painting, every screen shows it */
static uint32_t *dots;            /* what shows, a colour a dot (0: the lock shows through) */
static uint8_t *lights;           /* a dot's light: the torch's in the low four bits, the halo's in the high */
static uint8_t *marks;            /* the step that last drew over this dot, 0: nothing lies on it */
static uint16_t *ranks;           /* when the dot opens as the world wakes (and last shuts as it falls asleep) */
static int open_to, rank_end;     /* every dot ranked under open_to shows what lies under the saver */
static uint32_t *over, *over_was; /* the dots drawn over the painting in this step, in the last */
static int nover, nover_was;
static uint8_t stamp = 1;

struct torch {
	int x, y;                     /* the fire's middle */
	uint32_t *order;              /* its dots, nearest first */
	uint16_t *key;                /* how near, in 1/8 dots */
	int n, at[BANDS];             /* how many; how far down the list each band reaches */
	float slow, quick, flick;     /* the breath's phases, the flame's flicker */
	int frame, gust;              /* the flame's frame; steps to its next gust (under 0: in it) */
};
static struct torch torches[MAXTORCH];

struct spark { bool live; float x, y, vx, vy, ph; int age, life; bool big; };
struct petal { bool live; float x, y, x0, vy, amp, w, ph; int frame, turn, rest; bool far; };
static struct spark sparks[NSPARK];
static struct petal petals[NPETAL];
static uint32_t *ring;            /* the halo's dots */
static uint8_t *ring_ang;         /* … where on the circle */
static int nring;
static uint8_t lobe[256];         /* the glow round the circle */
static float halo_at;
static long seal_minute = -1;
static int seal_x, seal_y, seal_struck;
static char seal_digits[5];

static struct wl_display *display;
static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct zwlr_layer_shell_v1 *layer_shell;
static struct wl_seat *seat;
static struct wl_keyboard *keyboard;
static struct wl_pointer *pointer;
static struct wl_list outputs;
static long tick;                         /* steps since the start */
static int pace = STEP_MS;                /* ms a step */
static unsigned rng;
static bool leaving;                      /* input came: gone once every key and button is up (with --idle: once the world has woken) */
static bool idle_mode;                    /* --idle: the lock behind it */
static pid_t lock_pid;                    /* kawa-lock, started as it covers the screen (--idle) */
static bool lock_started;
static bool falling = true, waking;       /* it comes over the screen; it opens onto the lock */
static double fall_at, wake_at, wake_from;   /* when they began; the time (ms, the clock's) no wake begins before */
static int held;                          /* keys and buttons down */
static double leave_at;
static bool moved_base;
static double base_x, base_y;
static volatile sig_atomic_t stop;
static const char *render_dir;            /* --render: frames to files, no screen */
static time_t render_clock;               /* (and its clock: from here, a step at a time) */
static long changed;                      /* dots changed since it was last counted */

static double now_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

static unsigned rnd(unsigned n)
{
	rng ^= rng << 13, rng ^= rng >> 17, rng ^= rng << 5;
	return n ? rng % n : 0;
}

static float frnd(float a, float b)
{
	return a + (b - a) * (float)rnd(10000) / 10000.0f;
}

static const uint8_t BAYER[8][8] = {
	{ 0, 32, 8, 40, 2, 34, 10, 42 }, { 48, 16, 56, 24, 50, 18, 58, 26 },
	{ 12, 44, 4, 36, 14, 46, 6, 38 }, { 60, 28, 52, 20, 62, 30, 54, 22 },
	{ 3, 35, 11, 43, 1, 33, 9, 41 }, { 51, 19, 59, 27, 49, 17, 57, 25 },
	{ 15, 47, 7, 39, 13, 45, 5, 37 }, { 63, 31, 55, 23, 61, 29, 53, 21 },
};

/* ── the dots ───────────────────────────────────────────────────────────────────────── */
static void put(size_t i, uint32_t c)
{
	if (dots[i] == c)
		return;
	dots[i] = c;
	changed++;
	if (render_dir)
		return;
	size_t y = i / (size_t)art.w, x = i - y * (size_t)art.w;
	size_t t = y / TILE * (size_t)((art.w + TILE - 1) / TILE) + x / TILE;
	struct output *o;
	wl_list_for_each(o, &outputs, link)
		for (int b = 0; b < 2; b++)
			if (o->buf[b].dirty)
				o->buf[b].dirty[t] = 1;
}

/* a dot as the light has it now */
static uint32_t colour_of(size_t i)
{
	if (ranks[i] < open_to)
		return 0;
	int lo = lights[i] & 15, hi = lights[i] >> 4;
	const uint16_t *m = M->shade[lo > hi ? lo : hi];
	const unsigned char *p = art.rgb + 3 * i;
	uint32_t r = p[0] * (uint32_t)m[0] >> 8, g = p[1] * (uint32_t)m[1] >> 8, b = p[2] * (uint32_t)m[2] >> 8;
	return 0xff000000u | (r > 255 ? 255 : r) << 16 | (g > 255 ? 255 : g) << 8 | (b > 255 ? 255 : b);
}

/* drawn over the painting for this step (gone at the next unless drawn again) */
static void draw(int x, int y, uint32_t c)
{
	if (x < 0 || y < 0 || x >= art.w || y >= art.h)
		return;
	size_t i = (size_t)y * (size_t)art.w + (size_t)x;
	if (ranks[i] < open_to)
		return;                           /* (the lock's own world there already) */
	if (marks[i] != stamp) {
		if (nover == OVCAP)
			return;
		marks[i] = stamp;
		over[nover++] = (uint32_t)i;
	}
	put(i, c);
}

static uint32_t mix(uint32_t a, uint32_t b, unsigned k)   /* k/256 of b over a */
{
	uint32_t r = ((a >> 16 & 255) * (256 - k) + (b >> 16 & 255) * k) >> 8;
	uint32_t g = ((a >> 8 & 255) * (256 - k) + (b >> 8 & 255) * k) >> 8;
	uint32_t l = ((a & 255) * (256 - k) + (b & 255) * k) >> 8;
	return 0xff000000u | r << 16 | g << 8 | l;
}

static int luma(uint32_t c)
{
	return (int)((c >> 16 & 255) * 3 + (c >> 8 & 255) * 6 + (c & 255)) / 10;
}

/* ── the light ──────────────────────────────────────────────────────────────────────── */
/* each dot belongs to its nearest fire, and is kept in that fire's list by how near it lies —
 * its slope towards the fire and its place in the dither counted in — so a band's breath only
 * touches the dots between where it reached and where it reaches now */
static float paint_luma(int x, int y)
{
	if (x < 0) x = 0;
	if (y < 0) y = 0;
	if (x >= art.w) x = art.w - 1;
	if (y >= art.h) y = art.h - 1;
	const unsigned char *p = art.rgb + 3 * ((size_t)y * (size_t)art.w + (size_t)x);
	return (float)(p[0] * 3 + p[1] * 6 + p[2]) / 2550.0f;
}

static bool world_setup(void)
{
	size_t n = (size_t)art.w * (size_t)art.h;
	dots = calloc(n, sizeof *dots);
	lights = calloc(n, 1);
	marks = calloc(n, 1);
	ranks = malloc(n * sizeof *ranks);
	over = malloc(OVCAP * sizeof *over);
	over_was = malloc(OVCAP * sizeof *over_was);
	uint16_t *key = malloc(n * sizeof *key);
	uint8_t *own = malloc(n);
	if (!dots || !lights || !marks || !ranks || !over || !over_was || !key || !own)
		return false;
	int nt = art.nflames;
	for (int t = 0; t < nt; t++) {
		torches[t].x = art.fx[t] + art.fw / 2;
		torches[t].y = art.fy[t] + art.fh * 3 / 5;
		torches[t].slow = (float)t * 2.1f, torches[t].quick = (float)t * 0.9f;
		torches[t].frame = (t * 3) % art.frames;
		torches[t].gust = 140 + (int)rnd(240);
	}
	int top = 0;
	for (int y = 0; y < art.h; y++)
		for (int x = 0; x < art.w; x++) {
			size_t i = (size_t)y * (size_t)art.w + (size_t)x;
			float best = 1e9f, bdx = 0, bdy = 0;
			int bt = 0;
			for (int t = 0; t < nt; t++) {
				float dx = (float)x + 0.5f - (float)torches[t].x, dy = (float)y + 0.5f - (float)torches[t].y;
				float d = dx * dx + dy * dy;
				if (d < best)
					best = d, bt = t, bdx = dx, bdy = dy;
			}
			float d = sqrtf(best), k = d;
			if (d > 0.5f) {                   /* (lighter away from the fire: a slope that faces it) */
				int ux = (int)lroundf(2 * bdx / d), uy = (int)lroundf(2 * bdy / d);
				k -= M->relief * (paint_luma(x + ux, y + uy) - paint_luma(x - ux, y - uy));
			}
			k += M->rim * (float)BAYER[y & 7][x & 7] / 64.0f;
			key[i] = (uint16_t)(k < 0 ? 0 : k * 8);
			own[i] = (uint8_t)bt;
			if (key[i] > top)
				top = key[i];
			/* the opening: from the figure's place, and out of each fire's pool */
			float c = hypotf((float)x + 0.5f - (float)art.cx, (float)y + 0.5f - (float)art.cy);
			float r = d * 1.25f + 40 < c ? d * 1.25f + 40 : c;
			int rank = (int)((r + 40.0f * (float)BAYER[y & 7][x & 7] / 64.0f) * 4);
			ranks[i] = (uint16_t)rank;
			if (rank + 1 > rank_end)
				rank_end = rank + 1;
		}
	/* (sorted by counting: a few milliseconds, once) */
	int *count = malloc(((size_t)top + 2) * sizeof *count);
	if (!count)
		return false;
	for (int t = 0; t < nt; t++) {
		memset(count, 0, ((size_t)top + 2) * sizeof *count);
		int m = 0;
		for (size_t i = 0; i < n; i++)
			if (own[i] == t) {
				count[key[i] + 1]++;
				m++;
			}
		for (int k = 0; k <= top; k++)
			count[k + 1] += count[k];
		torches[t].n = m;
		torches[t].order = malloc((size_t)m * sizeof *torches[t].order);
		torches[t].key = malloc((size_t)m * sizeof *torches[t].key);
		if (!torches[t].order || !torches[t].key)
			return false;
		for (size_t i = 0; i < n; i++)
			if (own[i] == t) {
				int at = count[key[i]]++;
				torches[t].order[at] = (uint32_t)i;
				torches[t].key[at] = key[i];
			}
	}
	free(count);
	free(key);
	free(own);
	/* the halo: its inks, at their place on the circle */
	ring = malloc(n * sizeof *ring);
	ring_ang = malloc(n);
	if (!ring || !ring_ang)
		return false;
	for (int y = 0; y < art.h; y++)
		for (int x = 0; x < art.w; x++) {
			float dx = (float)x + 0.5f - (float)art.cx, dy = (float)y + 0.5f - (float)art.cy, r = hypotf(dx, dy);
			if (r < (float)art.r0 || r > (float)art.r1)
				continue;
			const unsigned char *p = art.rgb + 3 * ((size_t)y * (size_t)art.w + (size_t)x);
			uint32_t c = (uint32_t)p[0] << 16 | (uint32_t)p[1] << 8 | p[2];
			for (int k = 0; k < art.ninks; k++)
				if (c == art.inks[k]) {
					ring[nring] = (uint32_t)y * (uint32_t)art.w + (uint32_t)x;
					ring_ang[nring++] = (uint8_t)((atan2f(dy, dx) / (2 * (float)M_PI) + 1.0f) * 256.0f);
					break;
				}
		}
	ring = realloc(ring, ((size_t)nring + 1) * sizeof *ring);
	ring_ang = realloc(ring_ang, (size_t)nring + 1);
	for (int a = 0; a < 256; a++) {           /* (crests of three sizes, unevenly round the circle) */
		float t = (float)a / 256.0f * 2 * (float)M_PI;
		float v = 0.5f + 0.5f * sinf(t + 0.3f), w = 0.5f + 0.5f * sinf(2 * t + 2.0f), u = 0.5f + 0.5f * sinf(3 * t + 4.1f);
		float g = 0.55f * v * v * v + 0.30f * w * w * w * w + 0.25f * u * u * u * u * u;
		lobe[a] = (uint8_t)(g > 1 ? 255 : g * 255);
	}
	open_to = rank_end;                       /* (it comes over the screen from nothing) */
	for (size_t i = 0; i < n; i++)
		dots[i] = 0;
	return true;
}

static void relight(size_t i)
{
	if (!marks[i])
		put(i, colour_of(i));
}

static void torch_step(struct torch *t)
{
	t->slow += 0.034f, t->quick += 0.097f;
	t->flick += (frnd(-1, 1) - t->flick) * 0.32f;
	/* the flame wanders among its frames, and the light goes with what it holds */
	unsigned r = rnd(10);
	t->frame = (t->frame + (r < 7 ? 1 : r < 9 ? 0 : art.frames - 1)) % art.frames;
	float k = 0.05f * sinf(t->slow) + 0.03f * sinf(t->quick) + 0.03f * t->flick;
	if (art.frames > 0)
		k += 0.022f * art.flame_size[t->frame];
	/* now and then a draught: the fire ducks, then flares and throws sparks */
	if (--t->gust < 0) {
		float g = (float)-t->gust / 16.0f;
		k += g < 0.3f ? -0.10f * g / 0.3f : 0.17f * sinf((g - 0.3f) / 0.7f * (float)M_PI) - 0.10f * (1 - (g - 0.3f) / 0.7f);
		if (t->gust == -5)
			for (int s = 0, thrown = 0; s < NSPARK && thrown < 5; s++)
				if (!sparks[s].live) {
					sparks[s] = (struct spark){ .live = true, .x = (float)t->x + frnd(-4, 4), .y = (float)t->y - 8, .vx = frnd(-0.7f, 0.7f),
						.vy = frnd(-1.5f, -0.8f), .ph = frnd(0, 6), .life = 28 + (int)rnd(40), .big = thrown == 0 };
					thrown++;
				}
		if (t->gust <= -16)
			t->gust = 160 + (int)rnd(380);
	}
	if (waking)
		k += 0.3f;                            /* (the world wakes: the fires leap) */
	/* (the outer steps breathe less: far from the fire the light is calm) */
	static const float reach[BANDS] = { 0.5f, 0.62f, 0.8f, 1.0f, 1.25f };
	for (int b = 0; b < BANDS; b++) {
		int want = (int)(M->band[b] * (1 + k * reach[b]) * 8);
		int at = t->at[b];
		while (at < t->n && t->key[at] < want) {
			uint32_t i = t->order[at++];
			lights[i]++;
			relight(i);
		}
		while (at > 0 && t->key[at - 1] >= want) {
			uint32_t i = t->order[--at];
			lights[i]--;
			relight(i);
		}
		t->at[b] = at;
	}
}

/* the halo: a glow goes round the ring, unhurried */
static void halo_step(void)
{
	halo_at += M->halo_speed;
	int phase = (int)halo_at & 255;
	for (int k = 0; k < nring; k++) {
		uint32_t i = ring[k];
		int v = lobe[(ring_ang[k] + phase) & 255];
		int y = (int)(i / (uint32_t)art.w), x = (int)(i - (uint32_t)y * (uint32_t)art.w);
		int l = M->halo_floor + ((v + BAYER[y & 7][x & 7]) * (HOT - M->halo_floor + 1) >> 8);
		if (l > HOT)
			l = HOT;
		if (lights[i] >> 4 != l) {
			lights[i] = (uint8_t)((lights[i] & 15) | l << 4);
			relight(i);
		}
	}
}

/* ── the flames ─────────────────────────────────────────────────────────────────────── */
static void flames_step(void)
{
	for (int t = 0; t < art.nflames; t++)
		for (int y = 0; y < art.fh; y++)
			for (int x = 0; x < art.fw; x++) {
				const unsigned char *p = art.flame + 3 * ((size_t)y * (size_t)art.fw * (size_t)art.frames
						+ (size_t)torches[t].frame * (size_t)art.fw + (size_t)x);
				if (p[0] == 255 && p[1] == 0 && p[2] == 255)
					continue;
				draw(art.fx[t] + x, art.fy[t] + y, 0xff000000u | (uint32_t)p[0] << 16 | (uint32_t)p[1] << 8 | p[2]);
			}
}

/* ── the air, dark: embers rise from the fires, smoke climbs to the beam and creeps along it ── */
static void embers_step(void)
{
	for (int t = 0; t < art.nflames; t++) {
		if (rnd(6))
			continue;
		for (int s = 0; s < NSPARK; s++)
			if (!sparks[s].live) {
				sparks[s] = (struct spark){ .live = true, .x = (float)torches[t].x + frnd(-5, 5), .y = (float)art.fy[t] + frnd(4, 16),
					.vx = frnd(-0.2f, 0.2f), .vy = frnd(-1.05f, -0.45f), .ph = frnd(0, 6.28f), .life = 42 + (int)rnd(78), .big = rnd(9) == 0 };
				break;
			}
	}
	for (int s = 0; s < NSPARK; s++) {
		struct spark *e = &sparks[s];
		if (!e->live)
			continue;
		if (++e->age > e->life) {
			e->live = false;
			continue;
		}
		float was_x = e->x, was_y = e->y;
		e->ph += 0.21f;
		e->vx += frnd(-0.03f, 0.03f);
		e->x += e->vx + 0.28f * sinf(e->ph);
		e->y += e->vy;
		e->vy *= 0.995f;
		int a = 4 * e->age / (e->life + 1);
		uint32_t c = pal[a == 0 ? SPARK_HOT : a == 1 ? SPARK : a == 2 ? SPARK_COOL : SPARK_DIM];
		int x = (int)e->x, y = (int)e->y;
		if (fabsf(e->vy) > 0.7f && a < 3)     /* (fast, and bright: a dot of tail) */
			draw((int)was_x, (int)was_y, pal[a < 2 ? SPARK_COOL : SPARK_DIM]);
		if (e->big && a < 2) {                /* (the rare big one: the lock's password ember) */
			draw(x - 1, y, pal[SPARK]), draw(x + 1, y, pal[SPARK]);
			draw(x, y - 1, pal[SPARK]), draw(x, y + 1, pal[SPARK]);
		}
		draw(x, y, c);
	}
}

/* a thread of smoke off each flame's tip, in two strands: it curls up to the beam, spreads and creeps along
 * under it, thinning to nothing, whole dots in the dither — no state but the flame's time, so it never repeats by much */
static void smoke_step(void)
{
	float tf = (float)tick;
	int ceiling = art.fy[0] - SMOKE_ABOVE;
	for (int t = 0; t < art.nflames; t++)
		for (int w = 0; w < 2; w++) {
			float x0 = (float)torches[t].x + (w ? 1.5f : -1.5f), y0 = (float)art.fy[t] + 2, rise = y0 - (float)ceiling;
			float side = w ? 1.0f : -1.0f, ph = tf * 0.17f + (float)t * 1.7f + (float)w * 2.4f;
			float len = rise + SMOKE_ALONG + 22 * sinf(tf * 0.011f + (float)t + (float)w);
			for (float d = 0; d < len; d += 1.0f) {
				float u = d / len;
				float amp = 0.8f + 7.5f * u;
				float wig = amp * sinf(0.21f * d - ph) + 0.45f * amp * sinf(0.083f * d - ph * 0.57f + (float)w);
				float past = d > rise ? d - rise : 0;
				float x = x0 + wig + side * past, y = y0 - (d < rise ? d : rise) + (past > 0 ? 0.22f * wig * (past > 24 ? 1 : past / 24) : 0);
				float width = 0.9f + 3.2f * u;
				/* (it rises in breaths: thicker and thinner along the thread) */
				float dens = (1 - u) * (1 - u * 0.4f) * (0.5f + 0.42f * sinf(0.11f * d - ph * 1.3f));
				if (dens <= 0)
					continue;
				int n = (int)ceilf(width);
				for (int k = -n; k <= n; k++) {
					float e = (float)k / width;
					if (e * e >= 1)
						continue;
					int px = past > 0 ? (int)x : (int)x + k, py = past > 0 ? (int)y + k : (int)y;
					if (px < 0 || py < 0 || px >= art.w || py >= art.h)
						continue;
					if ((float)BAYER[py & 7][px & 7] / 64.0f >= dens * (1 - e * e))
						continue;
					size_t i = (size_t)py * (size_t)art.w + (size_t)px;
					int lit = lights[i] & 15;
					draw(px, py, mix(colour_of(i), pal[DRIFT], (unsigned)(70 + lit * 22 - (int)(u * 40))));
				}
			}
		}
}

/* ── the air, light: gold dust hanging in it, catching the light; petals falling ──────── */
static void dust_step(void)
{
	for (int k = 0; k < 2; k++) {
		if (rnd(6))
			continue;
		for (int s = 0; s < NSPARK; s++)
			if (!sparks[s].live) {
				int t = art.nflames ? (int)rnd((unsigned)art.nflames) : 0;
				bool near = art.nflames && rnd(2);
				sparks[s] = (struct spark){ .live = true,
					.x = near ? (float)torches[t].x + frnd(-70, 70) : frnd(0, (float)art.w),
					.y = near ? (float)torches[t].y + frnd(-50, 60) : frnd(46, (float)art.h),
					.vx = frnd(-0.09f, 0.09f), .vy = frnd(-0.1f, 0.03f), .ph = frnd(0, 6.28f), .life = 90 + (int)rnd(170) };
				break;
			}
	}
	for (int s = 0; s < NSPARK; s++) {
		struct spark *e = &sparks[s];
		if (!e->live)
			continue;
		if (++e->age > e->life) {
			e->live = false;
			continue;
		}
		e->ph += 0.17f;
		e->x += e->vx + 0.05f * sinf(e->ph * 0.4f), e->y += e->vy;
		float tw = sinf(e->ph);
		if (tw < 0.05f)
			continue;                         /* (it turns away: not seen) */
		int x = (int)e->x, y = (int)e->y;
		if (x < 0 || y < 0 || x >= art.w || y >= art.h)
			continue;
		bool pale_under = luma(colour_of((size_t)y * (size_t)art.w + (size_t)x)) > 196;
		draw(x, y, pal[pale_under ? (tw > 0.7f ? SPARK_COOL : SPARK) : (tw > 0.7f ? SPARK_HOT : SPARK)]);
		if (tw > 0.93f && !pale_under)        /* (the moment it flashes) */
			draw(x + 1, y, pal[SPARK]), draw(x - 1, y, pal[SPARK]), draw(x, y + 1, pal[SPARK]), draw(x, y - 1, pal[SPARK]);
	}
}

static const char *const PETAL[6][5] = {
	{ ".PP..", "PPPP.", "PPPPP", ".PPPp", "..pp." },
	{ "...PP", "..PPP", ".PPPp", "PPpp.", ".p..." },
	{ "....P", "...PP", "..PPp", ".PPp.", ".p..." },
	{ ".....", "...pp", ".pPPp", "pp...", "....." },
	{ "...pp", "..ppp", ".pppP", "ppPP.", ".P..." },
	{ ".pp..", "pppp.", "ppppP", ".pPPP", "..PP." },
};
static const char *const PETAL_FAR[4][3] = {
	{ ".P.", "PPP", ".p." },
	{ "..P", ".Pp", "p.." },
	{ "...", "PPp", "..." },
	{ "p..", ".pP", "..P" },
};

static void petals_step(void)
{
	for (int s = 0; s < NPETAL; s++) {
		struct petal *p = &petals[s];
		if (!p->live) {
			if (rnd(36))
				continue;
			bool far = s % 5 >= 3;
			*p = (struct petal){ .live = true, .far = far, .x0 = frnd(-20, (float)art.w + 20), .y = far ? 46 : frnd(36, 48),
				.vy = far ? frnd(0.26f, 0.4f) : frnd(0.5f, 0.8f), .amp = far ? frnd(3, 7) : frnd(6, 15), .w = frnd(0.05f, 0.11f),
				.ph = frnd(0, 6.28f), .frame = (int)rnd(6), .turn = 1 + (int)rnd(3) };
			p->x = p->x0;
		}
		if (p->rest > 0) {                    /* (landed: a moment on the ground, then gone) */
			if (--p->rest == 0) {
				p->live = false;
				continue;
			}
		} else {
			p->ph += p->w;
			p->x = p->x0 + p->amp * sinf(p->ph);
			p->y += p->vy * (0.8f + 0.2f * cosf(p->ph * 2));
			if (tick % (p->far ? 4 : 3) == 0)
				p->frame += p->turn;
			if (p->y >= (float)art.h - (p->far ? 30 : 16) - (float)(s * 7 % 9)) {
				p->rest = 40 + (int)rnd(60);
				if (p->far)
					p->live = false;
			}
		}
		int x = (int)p->x, y = (int)p->y;
		if (p->far) {
			const char *const *f = PETAL_FAR[p->frame % 4];
			for (int j = 0; j < 3; j++)
				for (int i = 0; i < 3; i++)
					if (f[j][i] != '.')
						draw(x + i, y + j, pal[DRIFT_LO]);
		} else {
			const char *const *f = PETAL[p->frame % 6];
			for (int j = 0; j < 5; j++)
				for (int i = 0; i < 5; i++)
					if (f[j][i] != '.')
						draw(x + i, y + j, pal[f[j][i] == 'P' ? DRIFT : DRIFT_LO]);
		}
	}
}

/* ── the time: a small seal, stamped elsewhere in the ring every minute ─────────────── */
static const uint8_t DIGIT[10][7] = {
	{ 0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e }, { 0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e },
	{ 0x0e, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1f }, { 0x1f, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0e },
	{ 0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02 }, { 0x1f, 0x10, 0x1e, 0x01, 0x01, 0x11, 0x0e },
	{ 0x06, 0x08, 0x10, 0x1e, 0x11, 0x11, 0x0e }, { 0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 },
	{ 0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e }, { 0x0e, 0x11, 0x11, 0x0f, 0x01, 0x02, 0x0c },
};

static time_t time_now(void)
{
	return render_dir ? render_clock + tick * pace / 1000 : time(NULL);
}

static void seal_step(void)
{
	if (waking)
		return;                               /* (no time in the lock) */
	time_t now = time_now();
	long minute = (long)(now / 60);
	if (minute != seal_minute) {
		struct tm tm;
		localtime_r(&now, &tm);
		strftime(seal_digits, sizeof seal_digits, "%I%M", &tm);
		seal_minute = minute;
		/* a spiral through the ring's middle (Vogel's: the golden angle), each minute far from the last */
		int k = (int)(minute % 21);
		float R = (float)art.r0 - 16, r = R * sqrtf(((float)k + 0.5f) / 21.0f), a = (float)k * 2.39996f;
		seal_x = art.cx + (int)(r * cosf(a)) - SEAL_W / 2;
		seal_y = art.cy + (int)(r * sinf(a)) - SEAL_H / 2;
		seal_struck = 1;
	}
	if (seal_struck-- > 0) {                  /* (down: a dot larger all round, the hot ink, for one step) */
		for (int y = -1; y <= SEAL_H; y++)
			for (int x = -1; x <= SEAL_W; x++)
				draw(seal_x + x, seal_y + y, pal[SEAL_HOT]);
		return;
	}
	for (int y = 0; y < SEAL_H; y++)
		for (int x = 0; x < SEAL_W; x++) {
			bool edge = x == 0 || y == 0 || x == SEAL_W - 1 || y == SEAL_H - 1;
			bool corner = (x == 0 || x == SEAL_W - 1) && (y == 0 || y == SEAL_H - 1);
			/* (a seal is worn: a corner gone, a bite out of the edge here and there, its own each minute) */
			unsigned h = (unsigned)(x * 73 + y * 151) * 2654435761u + (unsigned)seal_minute * 40503u;
			if (corner || (edge && (h >> 24) < 24))
				continue;
			bool line = x == 1 || y == 1 || x == SEAL_W - 2 || y == SEAL_H - 2;
			draw(seal_x + x, seal_y + y, pal[line && !corner ? SEAL_CUT : SEAL_INK]);
		}
	for (int d = 0; d < 4; d++) {
		const uint8_t *g = DIGIT[seal_digits[d] & 15];
		int gx = seal_x + 3 + (d & 1) * 6, gy = seal_y + 3 + (d >> 1) * 9;
		for (int r = 0; r < 7; r++)
			for (int b = 0; b < 5; b++)
				if (g[r] >> (4 - b) & 1)
					draw(gx + b, gy + r, pal[SEAL_CUT]);
	}
}

/* one step of the world */
static void step(void)
{
	nover_was = nover, nover = 0;
	uint32_t *l = over_was;
	over_was = over, over = l;
	stamp = stamp == 255 ? 1 : (uint8_t)(stamp + 1);
	for (int t = 0; t < art.nflames; t++)
		torch_step(&torches[t]);
	halo_step();
	if (art.light) {
		dust_step();
		petals_step();
	} else {
		smoke_step();
		embers_step();
	}
	flames_step();
	seal_step();
	/* what lay on the painting and lies there no longer: the painting again */
	for (int k = 0; k < nover_was; k++) {
		uint32_t i = over_was[k];
		if (marks[i] != stamp) {
			marks[i] = 0;
			put(i, colour_of(i));
		}
	}
}

/* every dot between where the opening was and where it is now shows what it shows now */
static void open_move(int to)
{
	int a = to < open_to ? to : open_to, b = to < open_to ? open_to : to;
	if (a == b)
		return;
	open_to = to;
	size_t n = (size_t)art.w * (size_t)art.h;
	for (size_t i = 0; i < n; i++)
		if (ranks[i] >= a && ranks[i] < b && !marks[i])
			put(i, colour_of(i));
}

/* a spring, no bounce: starts at no speed, flows, settles — the whole way in t = 1 */
static double spring(double t)
{
	if (t >= 1)
		return 1;
	double a = 5.2 * t;
	return (1 - exp(-a) * (1 + a)) / (1 - exp(-5.2) * (1 + 5.2));
}

/* ── the screens ────────────────────────────────────────────────────────────────────── */
static void buffer_release(void *data, struct wl_buffer *b)
{
	(void)b;
	((struct buffer *)data)->busy = false;
}
static const struct wl_buffer_listener buffer_listener = { .release = buffer_release };

static bool make_buffer(struct output *o, struct buffer *b)
{
	int stride = o->pw * 4;
	b->size = (size_t)stride * (size_t)o->ph;
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
	b->wl = wl_shm_pool_create_buffer(pool, 0, o->pw, o->ph, stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(pool);
	close(fd);
	wl_buffer_add_listener(b->wl, &buffer_listener, b);
	size_t tiles = (size_t)((art.w + TILE - 1) / TILE) * (size_t)((art.h + TILE - 1) / TILE);
	b->dirty = malloc(tiles);
	if (!b->dirty)
		return false;
	memset(b->dirty, 1, tiles);               /* a new picture: all of it */
	/* round the painting (a screen of another shape): the lock's own ground, it never changes */
	if (o->ox || o->oy)
		for (int y = 0; y < o->ph; y++)
			for (int x = 0; x < o->pw; x++)
				if (x < o->ox || y < o->oy || x >= o->ox + o->n * art.w || y >= o->oy + o->n * art.h)
					b->px[(size_t)y * (size_t)o->pw + (size_t)x] = art.ground;
	return true;
}

static void frame_done(void *data, struct wl_callback *cb, uint32_t t)
{
	(void)t;
	wl_callback_destroy(cb);
	((struct output *)data)->waiting_frame = false;
}
static const struct wl_callback_listener frame_listener = { .done = frame_done };

/* what changed since this picture was last shown, into it, and shown: each run of tiles a piece of damage */
static void flush(struct output *o)
{
	if (!o->ready || o->waiting_frame || o->closed)
		return;
	struct buffer *b = !o->buf[0].busy ? &o->buf[0] : &o->buf[1];
	if (b->busy)
		return;
	if (!b->wl && !make_buffer(o, b))
		return;
	int tw = (art.w + TILE - 1) / TILE, th = (art.h + TILE - 1) / TILE, n = o->n;
	bool any = false;
	for (int ty = 0; ty < th; ty++) {
		int y0 = ty * TILE, y1 = y0 + TILE < art.h ? y0 + TILE : art.h;
		for (int tx = 0; tx < tw; tx++) {
			if (!b->dirty[ty * tw + tx])
				continue;
			int end = tx;
			while (end < tw && b->dirty[ty * tw + end])
				b->dirty[ty * tw + end++] = 0;
			int x0 = tx * TILE, x1 = end * TILE < art.w ? end * TILE : art.w;
			for (int y = y0; y < y1; y++) {
				uint32_t *row = b->px + (size_t)(o->oy + y * n) * (size_t)o->pw + (size_t)(o->ox + x0 * n), *q = row;
				const uint32_t *d = dots + (size_t)y * (size_t)art.w + (size_t)x0;
				for (int x = x0; x < x1; x++, d++)
					for (int j = 0; j < n; j++)
						*q++ = *d;
				for (int j = 1; j < n; j++)
					memcpy(row + (size_t)j * (size_t)o->pw, row, (size_t)(x1 - x0) * (size_t)n * 4);
			}
			wl_surface_damage_buffer(o->surface, o->ox + x0 * n, o->oy + y0 * n, (x1 - x0) * n, (y1 - y0) * n);
			any = true;
			tx = end;
		}
	}
	if (!any)
		return;
	wl_surface_attach(o->surface, b->wl, 0, 0);
	b->busy = true;
	struct wl_callback *cb = wl_surface_frame(o->surface);
	wl_callback_add_listener(cb, &frame_listener, o);
	o->waiting_frame = true;
	o->asked_at = now_ms();
	wl_surface_commit(o->surface);
}

/* the lock's own scale and place on this screen (kawa-lockmod: the most whole pixels it holds, centred) */
static void setup(struct output *o)
{
	o->pw = o->lw * o->scale, o->ph = o->lh * o->scale;
	o->n = o->pw / art.w < o->ph / art.h ? o->pw / art.w : o->ph / art.h;
	if (o->n < 1)
		o->n = 1;
	o->ox = (o->pw - o->n * art.w) / 2, o->oy = (o->ph - o->n * art.h) / 2;
	wl_surface_set_buffer_scale(o->surface, o->scale);
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

/* the mood: its painting and flames, lock-scene.txt's words (the lock's own places), saver-scene.txt's (the halo) */
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
	art.light = !strcmp(mood, "light");
	M = &moods[art.light];
	snprintf(dir, sizeof dir, "%s/.local/share/fedokawaii/%s", home ? home : "", mood);
	snprintf(p, sizeof p, "%s/saver-scene.ppm", dir);
	if (!(art.rgb = read_ppm(p, &art.w, &art.h)))
		return false;
	snprintf(p, sizeof p, "%s/lock-scene.txt", dir);
	FILE *f = fopen(p, "r");
	if (!f)
		return false;
	int fw = 0, fh = 0, frames = 0;
	unsigned g;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "frames %d %d %d", &fw, &fh, &frames) == 3) ;
		else if (sscanf(line, "ground %x", &g) == 1)
			art.ground = 0xff000000u | g;
		else if (art.nflames < MAXTORCH && sscanf(line, "flame %d %d", &art.fx[art.nflames], &art.fy[art.nflames]) == 2)
			art.nflames++;
	}
	fclose(f);
	int w = 0, h = 0;
	snprintf(p, sizeof p, "%s/saver-flame.ppm", dir);
	if (!art.nflames || frames <= 0 || !(art.flame = read_ppm(p, &w, &h)) || w != fw * frames || h != fh)
		return false;
	art.fw = fw, art.fh = fh, art.frames = frames;
	art.flame_size = calloc((size_t)frames, sizeof *art.flame_size);
	if (!art.flame_size)
		return false;
	float low = 1e9f, high = 0;
	for (int k = 0; k < frames; k++) {
		for (int y = 0; y < fh; y++)
			for (int x = 0; x < fw; x++) {
				const unsigned char *q = art.flame + 3 * ((size_t)y * (size_t)w + (size_t)k * (size_t)fw + (size_t)x);
				art.flame_size[k] += !(q[0] == 255 && q[1] == 0 && q[2] == 255);
			}
		if (art.flame_size[k] < low) low = art.flame_size[k];
		if (art.flame_size[k] > high) high = art.flame_size[k];
	}
	for (int k = 0; k < frames; k++)
		art.flame_size[k] = high > low ? 2 * (art.flame_size[k] - low) / (high - low) - 1 : 0;
	snprintf(p, sizeof p, "%s/saver-scene.txt", dir);
	if (!(f = fopen(p, "r")))
		return false;
	bool halo = false;
	while (fgets(line, sizeof line, f)) {
		unsigned c[4];
		int got = sscanf(line, "halo %d %d %d %d %x %x %x %x", &art.cx, &art.cy, &art.r0, &art.r1, &c[0], &c[1], &c[2], &c[3]);
		if (got > 4) {
			art.ninks = got - 4;
			for (int k = 0; k < art.ninks; k++)
				art.inks[k] = c[k];
			halo = true;
		}
	}
	fclose(f);
	return halo;
}

/* ── no screen: the frames as files (P6; where the lock would show through, the key colour) ── */
static bool render_write(const char *name, long at)
{
	char p[PATH_MAX];
	snprintf(p, sizeof p, "%s/%s-%06ld.ppm", render_dir, name, at);
	FILE *f = fopen(p, "w");
	if (!f)
		return false;
	fprintf(f, "P6 %d %d 255\n", art.w, art.h);
	size_t n = (size_t)art.w * (size_t)art.h;
	unsigned char *row = malloc(n * 3);
	if (!row) {
		fclose(f);
		return false;
	}
	for (size_t i = 0; i < n; i++) {
		uint32_t c = dots[i];
		row[3 * i] = c ? c >> 16 & 255 : 255, row[3 * i + 1] = c ? c >> 8 & 255 : 0, row[3 * i + 2] = c ? c & 255 : 254;
	}
	bool ok = fwrite(row, 1, n * 3, f) == n * 3;
	free(row);
	return !fclose(f) && ok;
}

/* the fall (--fall), STEPS steps asleep (each EVERY-th written), the wake (--wake): at 144 frames a second where
 * the opening moves, as on the screen; what a step costs on stdout */
static int render(long steps, long every, bool fall, bool wake)
{
	double frame = 1000.0 / 144, next = 0;
	if (fall) {
		for (double t = 0; t < FALL_MS; t += frame) {
			open_move((int)(rank_end * (1 - spring(t / FALL_MS))));
			if (t >= next) {
				next += pace;
				tick++;
				step();
			}
			if (!render_write("fall", (long)(t + 0.5)))
				return 1;
		}
		falling = false;
	}
	falling = false;
	open_move(0);
	long most = 0, total = 0;
	double slowest = 0, spent = 0;
	for (long s = 1; s <= steps; s++) {
		tick++;
		changed = 0;
		double t0 = now_ms();
		step();
		double took = now_ms() - t0;
		if (s > 24) {                         /* (the first steps bring the whole light up) */
			total += changed, spent += took;
			if (changed > most) most = changed;
			if (took > slowest) slowest = took;
		}
		if (every && s % every == 0 && !render_write("step", s))
			return 1;
	}
	if (steps > 24)
		printf("a step: %ld dots changed on average, %ld at most; %.0f µs on average, %.0f at most\n",
				total / (steps - 24), most, spent / (double)(steps - 24) * 1e3, slowest * 1e3);
	if (wake) {
		next = 0;
		waking = true;
		for (double t = 0; t < WAKE_MS; t += frame) {
			open_move((int)(rank_end * spring(t / WAKE_MS)));
			if (t >= next) {
				next += pace;
				tick++;
				step();
			}
			if (!render_write("wake", (long)(t + 0.5)))
				return 1;
		}
		open_move(rank_end);
		tick++;
		step();
		if (!render_write("wake", WAKE_MS))
			return 1;
	}
	return 0;
}

static void usage(void)
{
	fputs("usage: kawa-saver [--idle] [--seed N] [--pace MS]\n"
	      "       kawa-saver --render DIR [--steps N] [--every K] [--fall] [--wake] [--clock HH:MM]\n", stderr);
	exit(2);
}

int main(int argc, char **argv)
{
	unsigned seed = (unsigned)time(NULL) ^ (unsigned)getpid();
	long steps = 240, every = 1;
	bool fall = false, wake = false;
	const char *clock = NULL;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--idle")) idle_mode = true;
		else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = (unsigned)strtoul(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--pace") && i + 1 < argc) pace = atoi(argv[++i]);   /* (renders: a faster clock) */
		else if (!strcmp(argv[i], "--render") && i + 1 < argc) render_dir = argv[++i];
		else if (!strcmp(argv[i], "--steps") && i + 1 < argc) steps = atol(argv[++i]);
		else if (!strcmp(argv[i], "--every") && i + 1 < argc) every = atol(argv[++i]);
		else if (!strcmp(argv[i], "--clock") && i + 1 < argc) clock = argv[++i];
		else if (!strcmp(argv[i], "--fall")) fall = true;
		else if (!strcmp(argv[i], "--wake")) wake = true;
		else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
			puts("kawa-saver — the screensaver: the lock's painting asleep; any input ends it.\n"
			     "  kawa-saver         now (nothing locks)\n"
			     "  kawa-saver --idle  away 15 minutes (kawa-idle): the screensaver, the lock under it: the first\n"
			     "                     input wakes the world onto it (switched off in quick settings: the lock at once)\n"
			     "  kawa-saver --render DIR [--steps N] [--every K] [--fall] [--wake] [--clock HH:MM]\n"
			     "                     its frames as files, no screen, what a step costs on stdout");
			return 0;
		} else usage();
	}
	if (pace < 1 || pace > 1000 || steps < 0 || every < 0)
		usage();
	rng = seed ? seed : 1;
	if (render_dir) {
		if (!read_palette())
			return 1;
		if (!read_art())
			return fail("no scene (fedokawaii repair puts saver-scene.ppm back)");
		if (!world_setup())
			return fail("out of memory");
		render_clock = time(NULL);
		int hh, mm;
		if (clock && sscanf(clock, "%d:%d", &hh, &mm) == 2) {
			struct tm tm;
			localtime_r(&render_clock, &tm);
			tm.tm_hour = hh, tm.tm_min = mm, tm.tm_sec = 0;
			render_clock = mktime(&tm);
		}
		wl_list_init(&outputs);
		return render(steps, every, fall, wake);
	}
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
	if (!world_setup())
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
			setup(o);
			shown++;
		}
	if (!shown)
		return fail("no screen took it");
	struct pollfd pfd = { .fd = wl_display_get_fd(display), .events = POLLIN };
	double next = now_ms(), next_look = next + 1000, lock_due = 0;
	fall_at = next;
	while (!stop) {
		double t = now_ms();
		bool dark = screens_dark(t);
		if (falling) {                    /* (the painting comes over the screen; once it covers it, the lock under it) */
			double f = (t - fall_at) / FALL_MS;
			if (f >= 1 || leaving) {
				falling = false;
				open_move(0);
				opaque(true);
				lock_due = t + 40;        /* (a frame or two shown first) */
			} else {
				open_move((int)(rank_end * (1 - spring(f))));
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
			 * (none reaches a window) — then dwl dissolves what is left of its picture away */
			if (!idle_mode) {
				if (held == 0)
					break;
			} else if (!waking) {
				if (lock_up() && !falling && t >= wake_from) {
					waking = true;
					wake_at = t;
					next = t;             /* (a step at once: the seal lifts, the fires leap) */
					opaque(false);
				}
			} else {
				double f = (t - wake_at) / WAKE_MS;
				open_move(f >= 1 ? rank_end : (int)(rank_end * spring(f)));
				if (f >= 1) {
					wl_list_for_each(o, &outputs, link)
						flush(o);
					break;
				}
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
			tick++;
			step();
		}
		wl_list_for_each(o, &outputs, link)
			flush(o);                     /* (a frame done since: what waited goes out) */
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
