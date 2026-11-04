/*
 * src/kawa-saver/render.c — kawa-saver's world with no screen: its layers laid over each other as the compositor lays
 * them (premultiplied, the small ones scaled up smooth), written as P6 files; what a step costs on stdout. The tests
 * and the renders use it; it is not installed.
 *   kawa-saver-render DIR [--steps N] [--every K] [--fall] [--wake] [--frames K] [--clock HH:MM] [--seed N] [--under FILE.png]
 *     --every   each K-th step written (0: none), named step-N.ppm
 *     --frames  of the fall and the wake (144 frames a second), each K-th written (and the last), named fall-MS, wake-MS
 *     --under   the lock's picture, what shows where the world has opened (default: magenta, to be measured)
 *   HOME's ~/.config/fedokawaii/current says the mood; it reads what kawa-saver reads.
 * Exit 0 · 1 it could not · 2 wrong use.
 */
#define _GNU_SOURCE
#include <unistd.h>
#include "world.h"

static const char *dir;
static time_t clock_at;
static double clock_ms;
static uint32_t *paint, *under, *opened, *out;
static uint8_t *tiles;

static time_t render_time(void)
{
	return clock_at + (time_t)(clock_ms / 1000);
}

static double wall_ms(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e3 + (double)ts.tv_nsec / 1e6;
}

/* a small picture over OUT, scaled up by DIV, smooth (bilinear, as the compositor) */
static void lay(const struct picture *p, int div)
{
	for (int y = 0; y < art.h; y++) {
		float fy = ((float)y + 0.5f) / (float)div - 0.5f;
		int y0 = (int)floorf(fy), wy = (int)((fy - (float)y0) * 256);
		int ya = y0 < 0 ? 0 : y0 >= p->h ? p->h - 1 : y0, yb = y0 + 1 < 0 ? 0 : y0 + 1 >= p->h ? p->h - 1 : y0 + 1;
		for (int x = 0; x < art.w; x++) {
			float fx = ((float)x + 0.5f) / (float)div - 0.5f;
			int x0 = (int)floorf(fx), wx = (int)((fx - (float)x0) * 256);
			int xa = x0 < 0 ? 0 : x0 >= p->w ? p->w - 1 : x0, xb = x0 + 1 < 0 ? 0 : x0 + 1 >= p->w ? p->w - 1 : x0 + 1;
			uint32_t a = p->px[ya * p->w + xa], b = p->px[ya * p->w + xb], c = p->px[yb * p->w + xa], d = p->px[yb * p->w + xb];
			if (!(a | b | c | d))
				continue;
			uint32_t top = scale_px(a, (uint32_t)(256 - wx)) + scale_px(b, (uint32_t)wx);
			uint32_t bot = scale_px(c, (uint32_t)(256 - wx)) + scale_px(d, (uint32_t)wx);
			uint32_t s = scale_px(top, (uint32_t)(256 - wy)) + scale_px(bot, (uint32_t)wy);
			uint32_t *q = out + (size_t)y * (size_t)art.w + (size_t)x;
			*q = over_px(s, *q);
		}
	}
}

static bool write_frame(const char *name, long at, const uint32_t *base, bool seal, bool all)
{
	size_t n = (size_t)art.w * (size_t)art.h;
	for (size_t i = 0; i < n; i++)
		out[i] = over_px(base[i], under ? under[i] : 0xffff00ffu);
	lay(&shade, SHADE_DIV);
	for (int i = 0; all && i < art.na; i++) {
		const struct anim *a = &art.anims[i];
		for (int y = 0; y < a->h; y++)
			for (int x = 0; x < a->w; x++) {
				size_t k = (size_t)(a->y + y) * (size_t)art.w + (size_t)(a->x + x);
				if (a->x + x < art.w && a->y + y < art.h)
					out[k] = over_px(a->frames[(size_t)y * (size_t)a->w * (size_t)a->n + (size_t)a->frame * (size_t)a->w + (size_t)x], out[k]);
			}
	}
	if (all && !art.light)
		lay(&haze, HAZE_DIV);
	if (all)
		lay(&air, AIR_DIV);
	if (seal)
		for (int y = 0; y < sealp.h; y++)
			for (int x = 0; x < sealp.w; x++)
				if (seal_x + x >= 0 && seal_y + y >= 0 && seal_x + x < art.w && seal_y + y < art.h) {
					size_t k = (size_t)(seal_y + y) * (size_t)art.w + (size_t)(seal_x + x);
					out[k] = over_px(sealp.px[y * sealp.w + x], out[k]);
				}
	char p[4200];
	snprintf(p, sizeof p, "%s/%s-%06ld.ppm", dir, name, at);
	FILE *f = fopen(p, "w");
	if (!f)
		return false;
	fprintf(f, "P6 %d %d 255\n", art.w, art.h);
	unsigned char *row = malloc(n * 3);
	if (!row) {
		fclose(f);
		return false;
	}
	for (size_t i = 0; i < n; i++)
		row[3 * i] = out[i] >> 16 & 255, row[3 * i + 1] = out[i] >> 8 & 255, row[3 * i + 2] = out[i] & 255;
	bool ok = fwrite(row, 1, n * 3, f) == n * 3;
	free(row);
	return !fclose(f) && ok;
}

/* (a stamp, for the tests) */
static void note_seal(void)
{
	if (seal_changed && seal_struck == 1)
		printf("seal %s %d %d\n", seal_digits, seal_x, seal_y);
}

static float front_max(void)
{
	float w = fmaxf((float)art.cx, (float)(art.w - art.cx)), h = fmaxf((float)art.cy, (float)(art.h - art.cy));
	return hypotf(w, h) + RAMP_PX + 2;
}

int main(int argc, char **argv)
{
	long steps = 240, every = 1, frames_every = 1, frame_no = 0;
	bool fall = false, wake = false;
	const char *clock = NULL, *under_file = NULL;
	unsigned seed = 7;
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--steps") && i + 1 < argc) steps = atol(argv[++i]);
		else if (!strcmp(argv[i], "--every") && i + 1 < argc) every = atol(argv[++i]);
		else if (!strcmp(argv[i], "--frames") && i + 1 < argc) frames_every = atol(argv[++i]);
		else if (!strcmp(argv[i], "--clock") && i + 1 < argc) clock = argv[++i];
		else if (!strcmp(argv[i], "--seed") && i + 1 < argc) seed = (unsigned)strtoul(argv[++i], NULL, 10);
		else if (!strcmp(argv[i], "--under") && i + 1 < argc) under_file = argv[++i];
		else if (!strcmp(argv[i], "--fall")) fall = true;
		else if (!strcmp(argv[i], "--wake")) wake = true;
		else if (argv[i][0] != '-' && !dir) dir = argv[i];
		else {
			fputs("usage: kawa-saver-render DIR [--steps N] [--every K] [--fall] [--wake] [--frames K] [--clock HH:MM] [--seed N] [--under FILE.png]\n", stderr);
			return 2;
		}
	}
	if (!dir || frames_every < 1)
		return 2;
	rng = seed ? seed : 1;
	world_time = render_time;
	const char *home = getenv("HOME");
	if (!read_palette(home))
		return 1;
	if (!read_art(home)) {
		fputs("kawa-saver-render: no scene\n", stderr);
		return 1;
	}
	if (!world_setup())
		return 1;
	size_t n = (size_t)art.w * (size_t)art.h;
	char p[4200];
	snprintf(p, sizeof p, "%s/%s", art.dir, art.wall);
	int w = art.w, h = art.h;
	if (!(paint = read_png(p, &w, &h, NULL))) {
		fprintf(stderr, "kawa-saver-render: %s: no painting of %d × %d\n", p, art.w, art.h);
		return 1;
	}
	if (under_file && !(under = read_png(under_file, &w, &h, NULL))) {
		fprintf(stderr, "kawa-saver-render: %s: not a picture of %d × %d\n", under_file, art.w, art.h);
		return 1;
	}
	opened = calloc(n, 4), out = malloc(n * 4);
	shade.px = calloc((size_t)shade.w * (size_t)shade.h, 4);
	haze.px = calloc((size_t)haze.w * (size_t)haze.h, 4);
	air.px = calloc((size_t)air.w * (size_t)air.h, 4);
	sealp.px = calloc((size_t)sealp.w * (size_t)sealp.h, 4);
	tiles = calloc((size_t)(art.w / TILE + 2) * (size_t)(art.h / TILE + 2), 1);
	if (!opened || !out || !shade.px || !haze.px || !air.px || !sealp.px || !tiles)
		return 1;
	air_setup();
	clock_at = time(NULL);
	int hh, mm;
	if (clock && sscanf(clock, "%d:%d", &hh, &mm) == 2) {
		struct tm tm;
		localtime_r(&clock_at, &tm);
		tm.tm_hour = hh, tm.tm_min = mm, tm.tm_sec = 0;
		clock_at = mktime(&tm);
	}
	double frame = 1000.0 / 144, next = 0;
	float front = front_max(), was = front;
	if (fall) {
		for (double t = 0; t < FALL_MS; t += frame) {
			front = (float)((1 - spring(t / FALL_MS)) * front_max());
			paint_open(paint, opened, tiles, front, was);
			was = front;
			clock_ms = t;
			if (t >= next) {
				next += pace;
				tick++;
				world_step(t, front);
				note_seal();
			}
			if ((frame_no++ % frames_every == 0 || t + frame >= FALL_MS) && !write_frame("fall", (long)(t + 0.5), opened, false, false))
				return 1;
		}
	}
	long most = 0, total = 0;
	double slowest = 0, spent = 0;
	for (long s = 1; s <= steps; s++) {
		clock_ms += pace;
		tick++;
		double t0 = wall_ms();
		world_step(clock_ms, 0);
		double took = wall_ms() - t0;
		if (s > 12) {
			spent += took;
			if (took > slowest) slowest = took;
		}
		total += nair_now, most = nair_now > most ? nair_now : most;
		note_seal();
		if (every && s % every == 0 && !write_frame("step", s, paint, true, true))
			return 1;
	}
	if (steps > 12)
		printf("a step: %.0f µs on average, %.0f at most; the air: %ld rects on average, %ld at most\n",
				spent / (double)(steps - 12) * 1e3, slowest * 1e3, total / steps, most);
	if (wake) {
		memcpy(opened, paint, n * 4);
		waking = true;
		next = clock_ms;
		front = was = 0;
		double t0 = clock_ms;
		long steps_ms = 0;
		frame_no = 0;
		for (double t = 0; t <= WAKE_MS + frame; t += frame) {
			double f = t / WAKE_MS;
			wake_p = f >= 1 ? 1.0f : (float)spring(f);
			front = wake_p * front_max();
			double t1 = wall_ms();
			paint_open(paint, opened, tiles, front, was);
			was = front;
			clock_ms = t0 + t;
			if (clock_ms >= next) {
				next += pace;
				tick++;
				world_step(clock_ms, front);
			} else {
				shade_step(front);
			}
			double took = wall_ms() - t1;
			steps_ms = (long)took > steps_ms ? (long)took : steps_ms;
			if ((frame_no++ % frames_every == 0 || t + frame > WAKE_MS + frame) && !write_frame("wake", (long)(t + 0.5), opened, false, true))
				return 1;
		}
		printf("a frame of the wake: %ld ms at most\n", steps_ms);
	}
	return 0;
}
