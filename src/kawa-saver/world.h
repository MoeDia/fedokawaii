/*
 * src/kawa-saver/world.h — what kawa-saver shows, with no screen in it: the painting's light and air, computed into plain
 * pictures (premultiplied ARGB) that kawa-saver hands to the compositor as layers and render.c lays over each other in
 * software for the tests and the renders. Every picture but the painting is small or mostly empty, and the compositor
 * scales and blends them on the GPU: a step costs next to nothing.
 *
 *   the painting   static, full size, the lock's own without the figure (saver-scene.txt: wall)
 *   the shade      1/8 size, scaled up smooth: the darkness over the painting, open round the fires, breathing with them
 *   the anims      the lock's own strips (flames, light on the stones), the same frames in the same places
 *   the haze       1/4 size: smoke off each flame, curling up to the beam and creeping along it (the dark mood)
 *   the air        1/2 size: embers rising (dark), gold dust and petals falling (light)
 *   the seal       the time, stamped somewhere else in the middle every minute, its digits cut out of the red
 */
#include <math.h>
#include <png.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define SHADE_DIV 8
#define HAZE_DIV 4
#define AIR_DIV 2
#define MAXTORCH 4
#define MAXANIM 8
#define MAXRECT 256      /* what the air redraws in a step */
#define NSPARK 64        /* embers, gold dust */
#define NPETAL 24        /* petals, near and far */
#define STEP_MS 83       /* 12 steps a second */
#define WAKE_MS 440      /* the world wakes (§11: 400–450) */
#define FALL_MS 1200     /* it falls asleep (the wash's own time) */
#define RAMP_PX 150      /* the soft edge of the opening, in pixels */

/* ── the inks (current/saver.conf) ──────────────────────────────────────────────────── */
enum { SPARK_HOT, SPARK, SPARK_COOL, SPARK_DIM, DRIFT, DRIFT_LO, SEAL_INK, SEAL_HOT, SEAL_CUT, SHADE_INK, NCOL };
static const char *colour_names[NCOL] = {
	"spark_hot", "spark", "spark_cool", "spark_dim", "drift", "drift_lo", "seal", "seal_hot", "seal_cut", "shade",
};
static uint32_t pal[NCOL];

/* the mood: how its dark falls */
static const struct mood {
	float floor;      /* the shade where no fire reaches */
	float edge;       /* how much of a pool's reach is already wholly lit */
	float gamma;      /* the shade's fall towards the fire: above 1, harder */
} moods[2] = {
	{ 0.86f, 0.62f, 1.25f },     /* the dark: hard, a dungeon carved out of black by its fire */
	{ 0.24f, 0.70f, 1.0f },      /* the light: the gold hour in the sky, the lanterns warm against it */
};
static const struct mood *M;

struct picture { uint32_t *px; int w, h; };
struct rect { int x, y, w, h; };

struct anim {
	char file[64];
	int x, y, w, h, n, ms;
	uint32_t *frames;     /* side by side, premultiplied */
	int frame;
	double next;
};

struct torch {
	int x, y, reach;              /* the fire's middle, how far its pool reaches, in pixels */
	uint8_t *fall;                /* its pool on the shade's grid, a texel round it spare */
	float slow, quick, flick;     /* the breath's phases, the flame's flicker */
	float k;                      /* the light it gives now */
	int gust;                     /* steps to its next gust (under 0: in it) */
	int sway, sway_y;             /* where the pool leans, in the shade's texels */
};

static struct {
	int w, h;                     /* the painting's size */
	bool light;                   /* the light mood: dust and petals, not embers and smoke */
	char wall[64];                /* its file */
	int cx, cy, cr;               /* the figure's place: where the world opens, the seal's ground */
	int ceiling;                  /* the beam the smoke stops at */
	int nt, na;
	int seal_w, seal_h, digit_w, digit_h;   /* saver-seal.png: the seal, a digit's cell */
	uint8_t *seal;                /* … its alpha: the seal, then the ten digits */
	struct torch torches[MAXTORCH];
	struct anim anims[MAXANIM];
	char dir[4096];
} art;

struct spark { bool live; float x, y, vx, vy, ph; int age, life; bool big; };
struct petal { bool live; float x, y, x0, vy, amp, w, ph; int frame, turn, rest; bool far; };
static struct spark sparks[NSPARK];
static struct petal petals[NPETAL];

static struct picture shade, haze, air, sealp;
static uint32_t shade_table[256];     /* a pool's light → the shade's pixel */
static uint16_t *shade_dist;          /* each shade texel's distance from the figure's place, in pixels */
static struct rect air_was[MAXRECT], air_now[MAXRECT];
static int nair_was, nair_now;
static int haze_rect[MAXTORCH][4];
static uint32_t smoke_table[256];
static long tick;                     /* steps since the start */
static int pace = STEP_MS;            /* ms a step */
static unsigned rng;
static bool waking;                   /* the world opens onto the lock */
static float wake_p;                  /* how far */
static long seal_minute = -1;
static int seal_x, seal_y, seal_struck;
static bool seal_changed;
static char seal_digits[5];
static time_t (*world_time)(void);

static unsigned rnd(unsigned n)
{
	rng ^= rng << 13, rng ^= rng >> 17, rng ^= rng << 5;
	return n ? rng % n : 0;
}

static float frnd(float a, float b)
{
	return a + (b - a) * (float)rnd(10000) / 10000.0f;
}

/* premultiplied: k/255 of ink c */
static uint32_t ink_at(uint32_t c, int a)
{
	uint32_t r = (c >> 16 & 255) * (uint32_t)a / 255, g = (c >> 8 & 255) * (uint32_t)a / 255, b = (c & 255) * (uint32_t)a / 255;
	return (uint32_t)a << 24 | r << 16 | g << 8 | b;
}

/* a premultiplied pixel times m/256 */
static inline uint32_t scale_px(uint32_t p, uint32_t m)
{
	uint32_t rb = ((p & 0x00ff00ffu) * m >> 8) & 0x00ff00ffu;
	uint32_t ag = ((p >> 8 & 0x00ff00ffu) * m) & 0xff00ff00u;
	return ag | rb;
}

/* src over dst, both premultiplied */
static inline uint32_t over_px(uint32_t s, uint32_t d)
{
	uint32_t a = 256 - (s >> 24);
	uint32_t rb = ((d & 0x00ff00ffu) * a >> 8) & 0x00ff00ffu;
	uint32_t ag = ((d >> 8 & 0x00ff00ffu) * a) & 0xff00ff00u;
	return s + (ag | rb);
}

/* a spring, no bounce: starts at no speed, flows, settles — the whole way in t = 1 */
static double spring(double t)
{
	if (t >= 1)
		return 1;
	double a = 5.2 * t;
	return (1 - exp(-a) * (1 + a)) / (1 - exp(-5.2) * (1 + 5.2));
}

/* ── its files ──────────────────────────────────────────────────────────────────────── */
/* a PNG into w × h premultiplied ARGB words (NULL if it cannot be read) */
static uint32_t *read_png(const char *path, int *w, int *h, uint32_t *into)
{
	png_image im;
	memset(&im, 0, sizeof im);
	im.version = PNG_IMAGE_VERSION;
	if (!png_image_begin_read_from_file(&im, path))
		return NULL;
	im.format = PNG_FORMAT_BGRA;
	if (*w && (*w != (int)im.width || *h != (int)im.height)) {
		png_image_free(&im);
		return NULL;
	}
	*w = (int)im.width, *h = (int)im.height;
	uint32_t *px = into ? into : malloc((size_t)im.width * im.height * 4);
	if (!px || !png_image_finish_read(&im, NULL, px, 0, NULL)) {
		png_image_free(&im);
		if (!into)
			free(px);
		return NULL;
	}
	size_t n = (size_t)im.width * im.height;
	for (size_t i = 0; i < n; i++) {
		uint32_t c = px[i], a = c >> 24;
		if (a != 255)
			px[i] = a << 24 | ((c >> 16 & 255) * a / 255) << 16 | ((c >> 8 & 255) * a / 255) << 8 | ((c & 255) * a / 255);
	}
	return px;
}

static bool read_palette(const char *home)
{
	char p[4096], line[256];
	snprintf(p, sizeof p, "%s/.config/fedokawaii/current/saver.conf", home ? home : "");
	FILE *f = fopen(p, "r");
	if (!f) {
		fprintf(stderr, "kawa-saver: %s: %m (fedokawaii repair puts it back)\n", p);
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

/* the mood (current's link), its words (saver-scene.txt: tools/build-saver.py) and its strips */
static bool read_art(const char *home)
{
	char cur[4096], link[64], p[4200], line[256];
	snprintf(cur, sizeof cur, "%s/.config/fedokawaii/current", home ? home : "");
	ssize_t n = readlink(cur, link, sizeof link - 1);
	if (n <= 0)
		return false;
	link[n] = 0;
	const char *mood = strrchr(link, '/');
	mood = mood ? mood + 1 : link;
	art.light = !strcmp(mood, "light");
	M = &moods[art.light];
	snprintf(art.dir, sizeof art.dir, "%s/.local/share/fedokawaii/%s", home ? home : "", mood);
	snprintf(p, sizeof p, "%s/saver-scene.txt", art.dir);
	FILE *f = fopen(p, "r");
	if (!f)
		return false;
	while (fgets(line, sizeof line, f)) {
		struct torch *t = &art.torches[art.nt];
		struct anim *a = &art.anims[art.na];
		if (sscanf(line, "size %d %d", &art.w, &art.h) == 2) ;
		else if (sscanf(line, "wall %63s", art.wall) == 1) ;
		else if (sscanf(line, "centre %d %d %d", &art.cx, &art.cy, &art.cr) == 3) ;
		else if (sscanf(line, "ceiling %d", &art.ceiling) == 1) ;
		else if (sscanf(line, "seal %d %d %d %d", &art.seal_w, &art.seal_h, &art.digit_w, &art.digit_h) == 4) ;
		else if (art.nt < MAXTORCH && sscanf(line, "torch %d %d %d", &t->x, &t->y, &t->reach) == 3)
			art.nt++;
		else if (art.na < MAXANIM && sscanf(line, "anim %63s %d %d %d %d %d %d", a->file, &a->x, &a->y, &a->w, &a->h, &a->n, &a->ms) == 7)
			art.na++;
	}
	fclose(f);
	if (art.w <= 0 || art.h <= 0 || !art.wall[0] || art.cr <= 0 || art.seal_w <= 0)
		return false;
	int sw = art.seal_w + 10 * art.digit_w, sh = art.seal_h;
	snprintf(p, sizeof p, "%s/saver-seal.png", art.dir);
	uint32_t *atlas = read_png(p, &sw, &sh, NULL);
	art.seal = malloc((size_t)sw * (size_t)sh);
	if (!atlas || !art.seal)
		return false;
	for (size_t i = 0; i < (size_t)sw * (size_t)sh; i++)
		art.seal[i] = (uint8_t)(atlas[i] >> 24);
	free(atlas);
	for (int i = 0; i < art.na; i++) {
		struct anim *a = &art.anims[i];
		int w = a->w * a->n, h = a->h;
		snprintf(p, sizeof p, "%s/%s", art.dir, a->file);
		if (a->n < 1 || a->ms < 1 || !(a->frames = read_png(p, &w, &h, NULL))) {
			fprintf(stderr, "kawa-saver: %s: not the strip saver-scene.txt says\n", p);
			return false;
		}
	}
	return true;
}

/* ── the light ──────────────────────────────────────────────────────────────────────── */
static bool world_setup(void)
{
	shade.w = art.w / SHADE_DIV, shade.h = art.h / SHADE_DIV;
	haze.w = art.w / HAZE_DIV, haze.h = art.h / HAZE_DIV;
	air.w = art.w / AIR_DIV, air.h = art.h / AIR_DIV;
	sealp.w = art.seal_w, sealp.h = art.seal_h;
	size_t n = (size_t)shade.w * (size_t)shade.h, fall = (size_t)(shade.w + 2) * (size_t)(shade.h + 2);
	shade_dist = malloc(n * sizeof *shade_dist);
	if (!shade_dist)
		return false;
	for (int t = 0; t < art.nt; t++) {
		struct torch *c = &art.torches[t];
		c->fall = malloc(fall);
		if (!c->fall)
			return false;
		for (int y = -1; y <= shade.h; y++)
			for (int x = -1; x <= shade.w; x++) {
				float d = hypotf((float)(x * SHADE_DIV + SHADE_DIV / 2 - c->x), (float)(y * SHADE_DIV + SHADE_DIV / 2 - c->y));
				float v = 1 - d / (float)c->reach;
				c->fall[(size_t)(y + 1) * (size_t)(shade.w + 2) + (size_t)(x + 1)] = (uint8_t)(v <= 0 ? 0 : v * 255);
			}
		c->slow = (float)t * 2.1f, c->quick = (float)t * 0.9f;
		c->k = 1;
		c->gust = 140 + (int)rnd(240);
	}
	for (int y = 0; y < shade.h; y++)
		for (int x = 0; x < shade.w; x++)
			shade_dist[(size_t)y * (size_t)shade.w + (size_t)x] =
				(uint16_t)hypotf((float)(x * SHADE_DIV + SHADE_DIV / 2 - art.cx), (float)(y * SHADE_DIV + SHADE_DIV / 2 - art.cy));
	for (int l = 0; l < 256; l++) {           /* (a pool's value → the shade) */
		float v = (float)l / 255 / M->edge;
		v = v > 1 ? 1 : v;
		float a = M->floor * powf(1 - v * v * (3 - 2 * v), M->gamma);
		shade_table[l] = ink_at(pal[SHADE_INK], (int)(a * 255));
	}
	for (int a = 0; a < 256; a++)
		smoke_table[a] = ink_at(pal[DRIFT], a * 110 / 255);
	return true;
}

static void torch_step(struct torch *t)
{
	t->slow += 0.034f, t->quick += 0.097f;
	t->flick += (frnd(-1, 1) - t->flick) * 0.32f;
	float k = 1 + 0.05f * sinf(t->slow) + 0.03f * sinf(t->quick) + 0.04f * t->flick;
	/* now and then a draught: the fire ducks, then flares and throws sparks */
	if (--t->gust < 0) {
		float g = (float)-t->gust / 16.0f;
		k += g < 0.3f ? -0.14f * g / 0.3f : 0.24f * sinf((g - 0.3f) / 0.7f * (float)M_PI) - 0.14f * (1 - (g - 0.3f) / 0.7f);
		if (t->gust == -5 && !art.light)
			for (int s = 0, thrown = 0; s < NSPARK && thrown < 6; s++)
				if (!sparks[s].live) {
					sparks[s] = (struct spark){ .live = true, .x = (float)t->x + frnd(-14, 14), .y = (float)t->y - 40, .vx = frnd(-2.2f, 2.2f),
						.vy = frnd(-4.6f, -2.4f), .ph = frnd(0, 6), .life = 28 + (int)rnd(40), .big = thrown == 0 };
					thrown++;
				}
		if (t->gust <= -16)
			t->gust = 160 + (int)rnd(380);
	}
	t->k = k;
	/* (the pool leans with the flame, a texel of the shade at most) */
	if (rnd(5) == 0)
		t->sway = (int)rnd(3) - 1;
	if (rnd(9) == 0)
		t->sway_y = (int)rnd(3) - 1;
}

/* the shade: each texel the fires' light, through the table; while the world opens, less and less of it from the middle out */
static void shade_step(float open_r)
{
	int sw = shade.w, sh = shade.h, nt = art.nt;
	const uint8_t *fall[MAXTORCH];
	int k[MAXTORCH];
	float boost = waking ? 1 + 3 * wake_p : 1;
	for (int t = 0; t < nt; t++) {
		const struct torch *c = &art.torches[t];
		fall[t] = c->fall + (size_t)(1 + c->sway_y) * (size_t)(sw + 2) + (size_t)(1 + c->sway);
		k[t] = (int)(c->k * boost * 256);
	}
	uint32_t *px = shade.px;
	for (int y = 0; y < sh; y++) {
		for (int x = 0; x < sw; x++, px++) {
			int l = 0;
			for (int t = 0; t < nt; t++)
				l += *fall[t]++ * k[t];
			l >>= 8;
			*px = shade_table[l > 255 ? 255 : l];
		}
		for (int t = 0; t < nt; t++)
			fall[t] += 2;
	}
	if (open_r > -RAMP_PX) {
		size_t n = (size_t)sw * (size_t)sh;
		for (size_t i = 0; i < n; i++) {
			float m = ((float)shade_dist[i] - open_r) / RAMP_PX;
			if (m >= 1)
				continue;
			shade.px[i] = m <= 0 ? 0 : scale_px(shade.px[i], (uint32_t)(m * 256));
		}
	}
}

/* ── the air: a sheet of plain pixels, what a step drew noted so the next can take it off ─ */
static void air_note(int x, int y, int w, int h)
{
	if (x < 0) w += x, x = 0;
	if (y < 0) h += y, y = 0;
	if (x + w > air.w) w = air.w - x;
	if (y + h > air.h) h = air.h - y;
	if (w <= 0 || h <= 0 || nair_now == MAXRECT)
		return;
	air_now[nair_now++] = (struct rect){ x, y, w, h };
}

static inline void plot(int x, int y, uint32_t c)
{
	if (x >= 0 && y >= 0 && x < air.w && y < air.h) {
		uint32_t *p = air.px + (size_t)y * (size_t)air.w + (size_t)x;
		*p = over_px(c, *p);
	}
}

/* a soft dot, R texels, ink c at its middle with alpha a (0–255) */
static void glow(float fx, float fy, float r, uint32_t c, int a)
{
	int x0 = (int)fx, y0 = (int)fy, n = (int)ceilf(r);
	air_note(x0 - n, y0 - n, 2 * n + 1, 2 * n + 1);
	for (int y = -n; y <= n; y++)
		for (int x = -n; x <= n; x++) {
			float d = hypotf((float)x, (float)y) / r;
			if (d < 1)
				plot(x0 + x, y0 + y, ink_at(c, (int)((float)a * (1 - d) * (1 - d))));
		}
}

/* dark: embers rise from the fires, cooling, swaying in the draught */
static void embers_step(void)
{
	for (int t = 0; t < art.nt; t++) {
		if (rnd(3))
			continue;
		for (int s = 0; s < NSPARK; s++)
			if (!sparks[s].live) {
				sparks[s] = (struct spark){ .live = true, .x = (float)art.torches[t].x + frnd(-22, 22), .y = (float)art.torches[t].y - frnd(10, 70),
					.vx = frnd(-0.8f, 0.8f), .vy = frnd(-3.8f, -1.5f), .ph = frnd(0, 6.28f), .life = 50 + (int)rnd(90), .big = rnd(6) == 0 };
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
		e->ph += 0.21f;
		e->vx += frnd(-0.1f, 0.1f);
		e->x += e->vx + 0.9f * sinf(e->ph);
		e->y += e->vy;
		e->vy *= 0.995f;
		int a = 4 * e->age / (e->life + 1);
		float x = e->x / AIR_DIV, y = e->y / AIR_DIV;
		uint32_t c = pal[a == 0 ? SPARK_HOT : a == 1 ? SPARK : a == 2 ? SPARK_COOL : SPARK_DIM];
		glow(x, y, e->big ? 5.0f : 3.4f, pal[a < 2 ? SPARK : SPARK_COOL], a == 3 ? 120 : 230);
		plot((int)x, (int)y, c);
		if (a < 3)
			plot((int)x + 1, (int)y, c), plot((int)x, (int)y + 1, c), plot((int)x + 1, (int)y + 1, c);
	}
}

/* light: gold dust hanging in the air, catching the light now and then */
static void dust_step(void)
{
	for (int k = 0; k < 3; k++) {
		if (rnd(5))
			continue;
		for (int s = 0; s < NSPARK; s++)
			if (!sparks[s].live) {
				int t = art.nt ? (int)rnd((unsigned)art.nt) : 0;
				bool near = art.nt && rnd(2);
				sparks[s] = (struct spark){ .live = true,
					.x = near ? (float)art.torches[t].x + frnd(-260, 260) : frnd(0, (float)art.w),
					.y = near ? (float)art.torches[t].y + frnd(-180, 220) : frnd(0, (float)art.h),
					.vx = frnd(-0.3f, 0.3f), .vy = frnd(-0.34f, 0.1f), .ph = frnd(0, 6.28f), .life = 90 + (int)rnd(170) };
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
		e->x += e->vx + 0.16f * sinf(e->ph * 0.4f), e->y += e->vy;
		float tw = sinf(e->ph);
		if (tw < 0.05f)
			continue;                         /* (it turns away: not seen) */
		float x = e->x / AIR_DIV, y = e->y / AIR_DIV;
		glow(x, y, tw > 0.8f ? 3.2f : 2.0f, pal[SPARK], (int)(tw * 230));
		if (tw > 0.75f)
			plot((int)x, (int)y, pal[SPARK_HOT]);
	}
}

/* a petal, turned and seen at an angle: PETAL_S texels, drawn soft once for all at the start */
#define PETAL_S 15
#define PETAL_FRAMES 24
static uint32_t petal_near[PETAL_FRAMES][PETAL_S * PETAL_S], petal_far[PETAL_FRAMES][PETAL_S * PETAL_S];

static void petal_draw(uint32_t *out, int frame, float size, uint32_t body, uint32_t edge)
{
	float th = (float)frame / PETAL_FRAMES * 2 * (float)M_PI;
	float tumble = fabsf(cosf(th * 2 + 0.7f)) * 0.82f + 0.18f;
	float cs = cosf(th), sn = sinf(th);
	for (int y = 0; y < PETAL_S; y++)
		for (int x = 0; x < PETAL_S; x++) {
			int inside = 0, rim = 0;
			for (int j = 0; j < 4; j++)
				for (int i = 0; i < 4; i++) {
					float px = (float)x + (float)i / 4 + 0.125f - PETAL_S / 2.0f, py = (float)y + (float)j / 4 + 0.125f - PETAL_S / 2.0f;
					float u = (cs * px + sn * py) / size, v = (-sn * px + cs * py) / (size * tumble);
					/* (long, narrow at the root, a notch in its tip) */
					float w = 0.64f * sqrtf(fmaxf(0, 1 - u * u)) * (1 + 0.28f * u);
					bool in = fabsf(v) < w && !(u > 0.72f && fabsf(v) < 0.16f);
					inside += in;
					rim += in && (fabsf(v) > w - 0.17f || u < -0.8f || u > 0.82f);
				}
			float a = (float)inside / 16;
			uint32_t c = rim * 2 > inside ? edge : body;
			out[y * PETAL_S + x] = inside ? ink_at(c, (int)(a * (rim * 2 > inside ? 215 : 240))) : 0;
		}
}

static void petals_step(void)
{
	for (int s = 0; s < NPETAL; s++) {
		struct petal *p = &petals[s];
		if (!p->live) {
			if (rnd(30))
				continue;
			bool far = s % 5 >= 3;
			*p = (struct petal){ .live = true, .far = far, .x0 = frnd(-60, (float)art.w + 60), .y = -16,
				.vy = far ? frnd(0.8f, 1.2f) : frnd(1.5f, 2.4f), .amp = far ? frnd(9, 22) : frnd(18, 46), .w = frnd(0.05f, 0.11f),
				.ph = frnd(0, 6.28f), .frame = (int)rnd(PETAL_FRAMES), .turn = 1 + (int)rnd(2) };
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
			p->frame += p->turn;
			if (p->y >= (float)art.h - 12 - (float)(s * 19 % 34)) {
				p->rest = 40 + (int)rnd(60);
				if (p->far)
					p->live = false;
			}
		}
		const uint32_t *f = (p->far ? petal_far : petal_near)[p->frame % PETAL_FRAMES];
		int x0 = (int)(p->x / AIR_DIV) - PETAL_S / 2, y0 = (int)(p->y / AIR_DIV) - PETAL_S / 2;
		air_note(x0, y0, PETAL_S, PETAL_S);
		for (int y = 0; y < PETAL_S; y++)
			for (int x = 0; x < PETAL_S; x++)
				if (f[y * PETAL_S + x])
					plot(x0 + x, y0 + y, f[y * PETAL_S + x]);
	}
}

static void air_step(void);

/* the sprites; and the air already moving at the first picture, as if it had always been */
static void air_setup(void)
{
	if (art.light)
		for (int f = 0; f < PETAL_FRAMES; f++) {
			petal_draw(petal_near[f], f, 6.4f, pal[DRIFT], pal[DRIFT_LO]);
			petal_draw(petal_far[f], f, 3.8f, pal[DRIFT], pal[DRIFT_LO]);
		}
	for (int s = 0; s < 340; s++) {
		tick++;
		air_step();
	}
}

/* what the last step drew off the sheet, this step's on it; the damage: both */
static void air_step(void)
{
	for (int k = 0; k < nair_now; k++)
		air_was[k] = air_now[k];
	nair_was = nair_now, nair_now = 0;
	for (int k = 0; k < nair_was; k++) {
		const struct rect *r = &air_was[k];
		for (int y = r->y; y < r->y + r->h; y++)
			memset(air.px + (size_t)y * (size_t)air.w + (size_t)r->x, 0, (size_t)r->w * 4);
	}
	if (art.light) {
		dust_step();
		petals_step();
	} else {
		embers_step();
	}
}

/* ── the smoke: a thread off each flame's tip, in two strands: it curls up to the beam, spreads and creeps along under it,
 * thinning to nothing. A soft brush along each strand, on the haze (scaled up smooth): no state but the flame's time ── */
static void haze_step(void)
{
	float tf = (float)tick;
	for (int t = 0; t < art.nt; t++) {
		const struct torch *c = &art.torches[t];
		int top = c->y - art.anims[0].h / 2;   /* (a flame's tip: the fire's middle, half a strip up) */
		int rw = 480 / HAZE_DIV * 2, rh = (top - art.ceiling + 80) / HAZE_DIV;
		int ox = c->x / HAZE_DIV - rw / 2, oy = (art.ceiling - 60) / HAZE_DIV;
		if (ox < 0) ox = 0;
		if (oy < 0) oy = 0;
		if (ox + rw > haze.w) rw = haze.w - ox;
		if (oy + rh > haze.h) rh = haze.h - oy;
		if (rw <= 0 || rh <= 0)
			continue;
		haze_rect[t][0] = ox, haze_rect[t][1] = oy, haze_rect[t][2] = rw, haze_rect[t][3] = rh;
		for (int y = 0; y < rh; y++)
			memset(haze.px + (size_t)(oy + y) * (size_t)haze.w + (size_t)ox, 0, (size_t)rw * 4);
		for (int w = 0; w < 2; w++) {
			float x0 = (float)c->x / HAZE_DIV + (w ? 1.0f : -1.0f), y0 = (float)top / HAZE_DIV;
			float rise = y0 - (float)art.ceiling / HAZE_DIV;
			float side = w ? 1.0f : -1.0f, ph = tf * 0.15f + (float)t * 1.7f + (float)w * 2.4f;
			float len = rise + 50 + 16 * sinf(tf * 0.011f + (float)t + (float)w);
			for (float d = 0; d < len; d += 1.0f) {
				float u = d / len;
				float amp = 0.6f + 4.2f * u;
				float wig = amp * sinf(0.2f * d - ph) + 0.45f * amp * sinf(0.083f * d - ph * 0.57f + (float)w);
				float past = d > rise ? d - rise : 0;
				float x = x0 + wig + side * past, y = y0 - (d < rise ? d : rise) + (past > 0 ? 0.25f * wig * (past > 20 ? 1 : past / 20) : 0);
				float r = 1.2f + 4.2f * u;
				float dens = (1 - u * u) * (0.66f + 0.34f * sinf(0.1f * d - ph * 1.3f));
				int n = (int)ceilf(r);
				for (int j = -n; j <= n; j++)
					for (int i = -n; i <= n; i++) {
						int sx = (int)x + i, sy = (int)y + j;
						if (sx < ox || sy < oy || sx >= ox + rw || sy >= oy + rh)
							continue;
						float e = ((float)i * (float)i + (float)j * (float)j) / (r * r);
						if (e >= 1)
							continue;
						uint32_t v = smoke_table[(int)(dens * (1 - e) * 255)];
						uint32_t *q = haze.px + (size_t)sy * (size_t)haze.w + (size_t)sx;
						if ((v >> 24) > (*q >> 24))
							*q = v;
					}
			}
		}
	}
}

/* ── the time: a small seal, hakubun, the digits cut out of the red; another place in the middle every minute ── */
/* changes the picture only at the minute, and the step after it (it is struck, in the hot ink); says so in seal_changed */
static void seal_step(void)
{
	seal_changed = false;
	if (waking)
		return;
	time_t now = world_time();
	long minute = (long)(now / 60);
	if (minute != seal_minute) {
		struct tm tm;
		localtime_r(&now, &tm);
		strftime(seal_digits, sizeof seal_digits, "%I%M", &tm);
		seal_minute = minute;
		/* a spiral through the middle (Vogel's: the golden angle), each minute far from the last */
		int k = (int)(minute % 21);
		float r = (float)art.cr * sqrtf(((float)k + 0.5f) / 21.0f), a = (float)k * 2.39996f;
		seal_x = art.cx + (int)(r * cosf(a)) - sealp.w / 2;
		seal_y = art.cy + (int)(r * sinf(a)) - sealp.h / 2;
		seal_struck = 2;
	}
	if (!seal_struck)
		return;
	seal_changed = true;
	uint32_t ink = pal[--seal_struck ? SEAL_HOT : SEAL_INK];
	int atlas = art.seal_w + 10 * art.digit_w;
	for (int y = 0; y < sealp.h; y++)
		for (int x = 0; x < sealp.w; x++)
			sealp.px[y * sealp.w + x] = ink_at(ink, art.seal[y * atlas + x]);
	/* the digits cut out: two rows of two, centred */
	int gap = 1, x0 = (sealp.w - 2 * art.digit_w - gap) / 2, y0 = (sealp.h - 2 * art.digit_h) / 2;
	for (int d = 0; d < 4; d++) {
		int gx = x0 + (d & 1) * (art.digit_w + gap), gy = y0 + (d >> 1) * art.digit_h;
		const uint8_t *g = art.seal + art.seal_w + (seal_digits[d] & 15) * art.digit_w;
		for (int y = 0; y < art.digit_h; y++)
			for (int x = 0; x < art.digit_w; x++) {
				int m = g[y * atlas + x];
				if (m) {
					uint32_t *q = &sealp.px[(gy + y) * sealp.w + gx + x];
					*q = over_px(ink_at(pal[SEAL_CUT], m), *q);
				}
			}
	}
}

/* the strips: a frame each its own time */
static void anims_step(double now)
{
	for (int i = 0; i < art.na; i++) {
		struct anim *a = &art.anims[i];
		if (now >= a->next) {
			a->next = now + a->ms;
			a->frame = (a->frame + 1) % a->n;
		}
	}
}

/* one step of the world; open_r: the opening's front, pixels from the figure's place (below -RAMP_PX: shut) */
static void world_step(double now, float open_r)
{
	for (int t = 0; t < art.nt; t++)
		torch_step(&art.torches[t]);
	shade_step(open_r);
	if (!art.light)
		haze_step();
	air_step();
	anims_step(now);
	seal_step();
}

/* the painting, opening: dst = paint times the shade of the opening's edge, on the rows and spans between where its soft
 * edge was and where it is (a ring: all that changed). r: the front now, was: the front at the last call; TILES marks what
 * changed, TILE × TILE pixels */
#define TILE 64
static long open_changed;
static void paint_open(const uint32_t *paint, uint32_t *dst, uint8_t *tiles, float r, float was)
{
	int W = art.w, H = art.h, cx = art.cx, cy = art.cy, tw = (W + TILE - 1) / TILE;
	float lo = fminf(r, was) - RAMP_PX, hi = fmaxf(r, was);
	if (lo < 0) lo = 0;
	for (int y = 0; y < H; y++) {
		float dy = (float)y + 0.5f - (float)cy, ady = fabsf(dy);
		if (ady >= hi)
			continue;
		float xo = sqrtf(hi * hi - dy * dy), xi = lo > ady ? sqrtf(lo * lo - dy * dy) : 0;
		for (int side = 0; side < 2; side++) {
			int a = side ? (int)((float)cx + xi) : (int)((float)cx - xo), b = side ? (int)((float)cx + xo) + 1 : (int)((float)cx - xi) + 1;
			if (a < 0) a = 0;
			if (b > W) b = W;
			if (a >= b)
				continue;
			const uint32_t *s = paint + (size_t)y * (size_t)W;
			uint32_t *d = dst + (size_t)y * (size_t)W;
			for (int x = a; x < b; x++) {
				float dx = (float)x + 0.5f - (float)cx;
				float m = (sqrtf(dx * dx + dy * dy) - (r - RAMP_PX)) / RAMP_PX;
				d[x] = m >= 1 ? s[x] : m <= 0 ? 0 : scale_px(s[x], (uint32_t)(m * 256));
			}
			open_changed += b - a;
			for (int t = a / TILE; t <= (b - 1) / TILE; t++)
				tiles[(size_t)(y / TILE) * (size_t)tw + (size_t)t] = 1;
		}
	}
}
