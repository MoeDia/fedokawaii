/*
 * kawa-lockmod — the lock screen's own part of gtklock (a gtklock 4 module; kawa-lock loads it
 * with -m ~/.local/lib/fedokawaii/kawa-lockmod.so). On every screen:
 *
 *  The scene (the owner, 4 Nov 19:11: a painting, 1920 × 1080). The mood's picture (KAWA_LOCK_ART/
 *  lock-scene.png) drawn under gtklock's layout at the most the screen holds whole — pixel for pixel
 *  at its own size or a whole number of times it, smooth otherwise —, centred, the ground of
 *  lock-scene.txt round it — and on it, from lock-scene.txt: the password as marks in the mood's
 *  row — `marks W H N`, a strip lock-marks.png of N drawn marks with alpha, mark i the strip's i % N,
 *  its middle on the row (or, with no such line, `mark`'s three inks: a cross) —, the newest ones
 *  while more are typed than the row holds, in the Caps Lock ink while it is on, and the caret: a
 *  bar as tall as a mark at the next place, once a second, there while the line has the keyboard;
 *  every key flares the newest mark for a moment (an answer too past the row's end).
 *
 *  The gate (the owner, 4 Nov: "he faces me; a secret key opens his mouth; I type; he closes his mouth
 *  like he ate it; then he logs me in"; the same for the angel). lock-gate.png's frames, shut first,
 *  drawn over the scene at lock-scene.txt's gate: shut at rest and every key does nothing but the
 *  secret one (Tab), which opens it; open, keys type; Enter shuts it on
 *  the marks and only then tries the password; Esc shuts it, the line cleared; the screens going
 *  dark too. The secret key lights dark screens onto an opening gate. On Enter the marks stay in
 *  the mouth until the jaws meet. A wrong password (gtklock's error line, never shown): it opens
 *  again, the marks scattering and fading, the gate shaking a pixel of the scene twice — five steps
 *  of 48 ms. The right one: gtklock ends, dwl dissolves the lock off the desktop.
 *
 *  Its life (the owner, 4 Nov: "the torches really flickering, moving light on stone, smoke, the demon's
 *  eyes, the halo turning, embers, petals", cheap): what lock-scene.txt lists, only what changed drawn —
 *  `anim NAME X Y W H N MS`, a strip lock-NAME.png of N frames W × H with alpha, looped, a frame every
 *  MS, read once the first picture is up (a lock that shows at once); `sparks embers|petals N INK INK`,
 *  N of them, young and old, born in the `spawn X Y W H` boxes (up to four; none: flames, or the
 *  foot / the upper half). All of it asleep while the screens are dark or the saver lies over it.
 *  `markscale M` (default 1), for a scene drawn pixel for pixel: the caret, the sparks, a cross, the
 *  scatter's steps and the shake drawn M times the size round their points, the sparks M times as fast.
 *
 *  The samurai (the owner, 6 Nov: "reacts, super active, while he types"), only with `samurai X Y` in
 *  lock-scene.txt: the cell's top-left in the scene. lock-samurai.png's frames, lock-samurai.txt's
 *  states and times: idle, start for the first key, one of three cuts in turn for each next one (the
 *  order of the keys, never which), delete, wrong; the right one plays before gtklock unlocks (a hook on
 *  the application's shutdown, ahead of gtklock's handler, for as long as its frames and no longer).
 *  One timer, a frame's own time: nothing wakes between frames, nothing at all with the screens dark.
 *
 *  gtklock's own line stays for the keys, unseen from its
 *  first frame (its box at opacity 0; current/gtklock.css: window.kawa, no transitions), its
 *  words never shown. No date, no time, no keys: the scene is the lock. Anything the system
 *  says on the way (PAM: an expiring password, a locked account, a finger to place) is the one
 *  line of words low on the screen, as on the login screen (kawa-greet): the newest try's, each
 *  once.
 *
 *  The screens. Nothing touched for 5 s while the lock shows — the screensaver not over it —,
 *  the screens go dark (kawa-lock --screens off); any key, click, scroll or move lights them
 *  again straight onto the lock (--screens on). kawa-lock notes them in
 *  $XDG_RUNTIME_DIR/kawa-screens — "off" before they go dark, "on" once lit, "resumed" once lit
 *  as the computer wakes, the file's time the moment. The key that lights screens dark for
 *  longer than 2 s only wakes (it was pressed to wake: never a character, never a try); one
 *  within 2 s of their going dark counts as typed. After a sleep, every key and click in the
 *  first 2 s only wakes: an Enter that woke the machine is never a wrong password. And an
 *  Enter in an empty box is never a try.
 *
 * Without its art (no KAWA_LOCK_ART, a file missing) only the guard runs: gtklock's plain line.
 * Built by theme.sh (src/kawa-lockmod/Makefile) against GTK 3's headers.
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <gtk/gtk.h>

/* gtklock 4's window, as its modules see it (gtklock-module.h, MIT, Jovan Lanik) — the
 * fields must stay in this order: gtklock hands us its own */
struct Window {
	GdkMonitor *monitor;
	GtkWidget *window;
	GtkWidget *overlay;
	GtkWidget *window_box;
	GtkWidget *body_revealer;
	GtkWidget *body_grid;
	GtkWidget *input_label;
	GtkWidget *input_field;
	GtkWidget *message_revealer;
	GtkWidget *message_scrolled_window;
	GtkWidget *message_box;
	GtkWidget *unlock_button;
	GtkWidget *error_label;
	GtkWidget *warning_label;
	GtkWidget *info_box;
	GtkWidget *time_box;
	GtkWidget *clock_label;
	GtkWidget *date_label;
	void *module_data[];
};
struct GtkLock;

const gchar module_name[] = "kawa";
const guint module_major_version = 4;
const guint module_minor_version = 0;

#define GUARD_US (2 * G_USEC_PER_SEC)
#define DARK_AFTER_US (5 * G_USEC_PER_SEC)

static int self_id;
static char screens[PATH_MAX], saver[PATH_MAX];   /* kawa-lock's note; the screensaver's lock */
static gint64 touched_at;                 /* the last input (µs, real time), the lock's start first */
static gint64 woken;                      /* the "off" note already answered (its time) */
static guint waking_key;                  /* the key that woke them, swallowed until it is let go */
static gboolean saver_was_up;
enum { NONE, OFF, ON, RESUMED };

/* kawa-lock's note: what it says, and *when (µs, real time) it was written */
static int note(gint64 *when)
{
	char buf[16] = { 0 };
	struct stat st;
	int fd = open(screens, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return NONE;
	ssize_t n = read(fd, buf, sizeof buf - 1);
	int r = fstat(fd, &st);
	close(fd);
	if (n <= 0 || r < 0)
		return NONE;
	*when = (gint64)st.st_mtim.tv_sec * G_USEC_PER_SEC + st.st_mtim.tv_nsec / 1000;
	return !strncmp(buf, "off", 3) ? OFF : !strncmp(buf, "on", 2) ? ON : !strncmp(buf, "resumed", 7) ? RESUMED : NONE;
}
static void screens_set(const char *how)
{
	gchar *argv[] = { "kawa-lock", "--screens", (gchar *)how, NULL };
	g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL |
			G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, NULL, NULL);
}
/* the screensaver shows (it holds its lock file while it runs): the lock under it is not idle */
static gboolean saver_up(void)
{
	int fd = open(saver, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return FALSE;
	gboolean up = flock(fd, LOCK_SH | LOCK_NB) < 0;
	close(fd);
	return up;
}

static void gate_rest(void);
static gboolean gate_keys(struct Window *win, GdkEventKey *ev);
static void gate_wake_key(struct Window *win, GdkEventKey *ev);
static void scene_sleep(gboolean sleep);

/* every input on the lock, before the lock sees it: the 5 s clock set again; dark screens lit.
 * True when the input only wakes (above) — then it goes no further */
static gboolean waking(void)
{
	gint64 mt = 0, now = g_get_real_time();
	int n = note(&mt);
	touched_at = now;
	if (n == OFF && mt != woken) {
		woken = mt;
		screens_set("on");
		scene_sleep(FALSE);
		return now - mt > GUARD_US;
	}
	return n == RESUMED && now >= mt && now - mt < GUARD_US;
}
/* four times a second: nothing touched for 5 s on lit screens, the screensaver not over the lock — dark */
static gboolean idle_tick(gpointer data)
{
	gint64 mt = 0, now = g_get_real_time();
	int n = note(&mt);
	gboolean up = saver_up();
	(void)data;
	if (saver_was_up && !up)
		touched_at = now;                 /* (the saver washed off: the lock seen from now) */
	saver_was_up = up;
	scene_sleep((n == OFF && mt != woken) || up);   /* (asked to light: alive as the picture comes) */
	if (n == OFF || up)
		return G_SOURCE_CONTINUE;
	if (now - MAX(touched_at, mt) >= DARK_AFTER_US) {
		touched_at = now;
		screens_set("off");
		gate_rest();
	}
	return G_SOURCE_CONTINUE;
}

static gboolean on_key(GtkWidget *w, GdkEventKey *ev, gpointer data)
{
	struct Window *win = data;
	(void)w;
	if (waking_key && ev->hardware_keycode == waking_key) {   /* (its repeats, then its release) */
		if (ev->type == GDK_KEY_RELEASE)
			waking_key = 0;
		return TRUE;
	}
	if (waking()) {
		if (ev->type == GDK_KEY_PRESS) {
			waking_key = ev->hardware_keycode;
			gate_wake_key(win, ev);
		}
		return TRUE;
	}
	if (gate_keys(win, ev))
		return TRUE;
	if (ev->type == GDK_KEY_PRESS && win->input_field && gtk_widget_has_focus(win->input_field) &&
			(ev->keyval == GDK_KEY_Return || ev->keyval == GDK_KEY_KP_Enter ||
			 ev->keyval == GDK_KEY_ISO_Enter) &&
			gtk_entry_get_text_length(GTK_ENTRY(win->input_field)) == 0)
		return TRUE;                      /* an empty box: nothing to try */
	return FALSE;
}

static gboolean on_button(GtkWidget *w, GdkEventButton *ev, gpointer data)
{
	(void)w, (void)ev, (void)data;
	return waking();
}
static gboolean on_move(GtkWidget *w, GdkEvent *ev, gpointer data)   /* a move or a scroll */
{
	(void)w, (void)ev, (void)data;
	waking();
	return FALSE;
}

/* gtklock puts an eye on the line's end each time the keyboard moves to another screen's lock (a
 * monitor off and on): never drawn here — taken off as it is set, before any picture of it loads
 * (an icon that fails to load aborts GTK 3: a lock screen gone) */
static void no_icon(GObject *o, GParamSpec *p, gpointer data)
{
	(void)p, (void)data;
	if (gtk_entry_get_icon_name(GTK_ENTRY(o), GTK_ENTRY_ICON_SECONDARY))
		gtk_entry_set_icon_from_icon_name(GTK_ENTRY(o), GTK_ENTRY_ICON_SECONDARY, NULL);
}

/* ── the scene (lock-scene.txt: build-lock.py's words) ────────────────────────────────── */
typedef struct { double r, g, b; } ink;
#define MAX_ANIMS 12
#define MAX_SPARKS 64
static struct {
	cairo_surface_t *img, *flame, *gate, *marks;
	int w, h, fw, fh, frames, nflames, fx[4], fy[4];
	int gx, gy, gw, gh, gn;               /* the gate: where its frames lie, each's size, how many */
	int mw, mh, mn;                       /* the drawn marks: each's size, how many */
	struct anim { cairo_surface_t *img; char name[32]; int x, y, w, h, n, ms, frame; } anim[MAX_ANIMS];
	int nanims;
	struct spark { gboolean live; float x, y, vx, vy; int age, life, px, py; } spark[MAX_SPARKS];
	int nsparks;
	struct { int x, y, w, h; } spawn[4];  /* where sparks are born */
	int nspawn;
	int ms;                               /* markscale: the marks' pixel, in the scene's */
	gboolean petals;
	ink young, old;
	int rx, ry, pitch, rn;                /* the password's row: the first mark, the pitch, how many */
	int cx, cy, cr;                       /* the plate */
	int wy0, wy1;                         /* the rows the line of words is centred in */
	ink ground, arms, core, corner, caps, caret;
	cairo_surface_t *sam;                 /* the samurai's frames, row by row */
	int sx, sy, scw, sch, scols;          /* his cell's top-left, its size, the frames in a row */
} S;

#define STEP_US (48 * 1000)               /* a step of the wrong password's 240 ms */
#define STEPS 5

struct look {                             /* one window's */
	struct Window *win;
	GtkWidget *area;
	int tried;                            /* marks when the last try began */
	int typed;                            /* the line's length at its last change */
	gint64 wrong;                         /* its failure's moment (µs, monotonic), 0 none */
	gint64 flare;                         /* the newest mark flares until then (µs, monotonic) */
	guint tick, flare_src;
	GtkWidget *words;                     /* the line of words */
	int seen[2];                          /* gtklock's bars (errors, the rest) before the last try */
	guint words_src;
};
#define FLARE_US (90 * 1000)
static GList *looks;
static int frame;                         /* the flames' (8 a second) */
static gboolean caret_on = TRUE;
static guint flame_timer, life_timer, caret_timer;
static gboolean asleep, life_loaded;      /* no frames wanted; the strips read */
static char scene_dir[PATH_MAX];
static cairo_filter_t filter = CAIRO_FILTER_NEAREST;   /* whole times the scene's pixels; smooth otherwise */

static gboolean hexink(const char *s, ink *c)
{
	unsigned v;
	if (!s || sscanf(s, "%6x", &v) != 1)
		return FALSE;
	c->r = ((v >> 16) & 255) / 255.0, c->g = ((v >> 8) & 255) / 255.0, c->b = (v & 255) / 255.0;
	return TRUE;
}

/* ── the samurai's states (lock-samurai.txt: build-samurai.py's words) ─────────────────── */
enum { SAM_IDLE, SAM_START, SAM_READY, SAM_KEY0, SAM_KEY1, SAM_KEY2, SAM_DELETE, SAM_RIGHT, SAM_WRONG, SAM_STATES };
#define SAM_FRAMES 8
static const char *const sam_names[SAM_STATES] = { "idle", "start", "ready", "key0", "key1", "key2", "delete", "right", "wrong" };
static struct { gboolean loop; int n, frame[SAM_FRAMES], ms[SAM_FRAMES]; } sam_st[SAM_STATES];

static gboolean sam_load(const char *dir)
{
	char path[PATH_MAX], line[256];
	g_snprintf(path, sizeof path, "%s/lock-samurai.txt", dir);
	FILE *f = fopen(path, "re");
	if (!f)
		return FALSE;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "cell %d %d %d", &S.scw, &S.sch, &S.scols) == 3)
			continue;
		char *save = NULL, *name = strtok_r(line, " \n", &save), *kind = strtok_r(NULL, " \n", &save), *t;
		for (int i = 0; name && kind && i < SAM_STATES; i++) {
			if (strcmp(name, sam_names[i]))
				continue;
			sam_st[i].loop = !strcmp(kind, "loop");
			while (sam_st[i].n < SAM_FRAMES && (t = strtok_r(NULL, " \n", &save)) &&
					sscanf(t, "%d:%d", &sam_st[i].frame[sam_st[i].n], &sam_st[i].ms[sam_st[i].n]) == 2)
				sam_st[i].n++;
		}
	}
	fclose(f);
	for (int i = 0; i < SAM_STATES; i++)
		if (!sam_st[i].n)
			return FALSE;
	if (S.scw <= 0 || S.sch <= 0 || S.scols <= 0)
		return FALSE;
	g_snprintf(path, sizeof path, "%s/lock-samurai.png", dir);
	S.sam = cairo_image_surface_create_from_png(path);
	if (cairo_surface_status(S.sam) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(S.sam);
		S.sam = NULL;
		return FALSE;
	}
	return TRUE;
}

static gboolean scene_load(const char *dir)
{
	char path[PATH_MAX], line[256], a[16], b[16], c[16], name[32];
	int ok = 0;
	gboolean samurai = FALSE;
	g_strlcpy(scene_dir, dir, sizeof scene_dir);
	g_snprintf(path, sizeof path, "%s/lock-scene.txt", dir);
	FILE *f = fopen(path, "re");
	if (!f)
		return FALSE;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "size %d %d", &S.w, &S.h) == 2) ok |= 1;
		else if (sscanf(line, "ground %15s", a) == 1) ok |= hexink(a, &S.ground) << 1;
		else if (sscanf(line, "frames %d %d %d", &S.fw, &S.fh, &S.frames) == 3) ;
		else if (S.nflames < 4 && sscanf(line, "flame %d %d", &S.fx[S.nflames], &S.fy[S.nflames]) == 2) S.nflames++;
		else if (sscanf(line, "gate %d %d %d %d %d", &S.gx, &S.gy, &S.gw, &S.gh, &S.gn) == 5) ;
		else if (S.nanims < MAX_ANIMS && sscanf(line, "anim %31s %d %d %d %d %d %d", name, &S.anim[S.nanims].x,
				&S.anim[S.nanims].y, &S.anim[S.nanims].w, &S.anim[S.nanims].h, &S.anim[S.nanims].n, &S.anim[S.nanims].ms) == 7) {
			struct anim *an = &S.anim[S.nanims];
			g_strlcpy(an->name, name, sizeof an->name);
			if (an->n > 0 && an->ms > 0)
				S.nanims++;
		}
		else if (sscanf(line, "markscale %d", &S.ms) == 1) ;
		else if (sscanf(line, "marks %d %d %d", &S.mw, &S.mh, &S.mn) == 3) ;
		else if (S.nspawn < 4 && sscanf(line, "spawn %d %d %d %d", &S.spawn[S.nspawn].x, &S.spawn[S.nspawn].y,
				&S.spawn[S.nspawn].w, &S.spawn[S.nspawn].h) == 4) S.nspawn++;
		else if (sscanf(line, "sparks %15s %d %15s %15s", a, &S.nsparks, b, c) == 4) {
			S.petals = !strcmp(a, "petals");
			S.nsparks = MIN(S.nsparks, MAX_SPARKS);
			hexink(b, &S.young), hexink(c, &S.old);
		}
		else if (sscanf(line, "row %d %d %d %d", &S.rx, &S.ry, &S.pitch, &S.rn) == 4) ok |= 4;
		else if (sscanf(line, "mark %15s %15s %15s", a, b, c) == 3)
			ok |= (hexink(a, &S.arms) && hexink(b, &S.core) && hexink(c, &S.corner)) << 3;
		else if (sscanf(line, "caps %15s", a) == 1) hexink(a, &S.caps);
		else if (sscanf(line, "caret %15s", a) == 1) hexink(a, &S.caret);
		else if (sscanf(line, "plate %d %d %d", &S.cx, &S.cy, &S.cr) == 3) ok |= 16;
		else if (sscanf(line, "words %d %d", &S.wy0, &S.wy1) == 2) ok |= 32;
		else if (sscanf(line, "samurai %d %d", &S.sx, &S.sy) == 2) samurai = TRUE;
	}
	fclose(f);
	S.ms = MAX(S.ms, 1);
	/* (the cross's inks only without drawn marks, the plate only without a gate) */
	if ((ok & 39) != 39 || (!S.mn && !(ok & 8)) || (!S.gn && !(ok & 16)) || S.w <= 0 || S.h <= 0 || S.rn <= 0 || S.wy1 < S.wy0)
		return FALSE;
	g_snprintf(path, sizeof path, "%s/lock-scene.png", dir);
	S.img = cairo_image_surface_create_from_png(path);
	if (cairo_surface_status(S.img) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(S.img);
		S.img = NULL;
		return FALSE;
	}
	if (S.nflames && S.frames > 0 && S.fw > 0 && S.fh > 0) {
		g_snprintf(path, sizeof path, "%s/lock-flame.png", dir);
		S.flame = cairo_image_surface_create_from_png(path);
		if (cairo_surface_status(S.flame) != CAIRO_STATUS_SUCCESS) {
			cairo_surface_destroy(S.flame);
			S.flame = NULL;
		}
	}
	if (!S.flame)
		S.nflames = 0;                    /* (no frames to draw: no flames, no timer for them) */
	if (S.gn > 1 && S.gw > 0 && S.gh > 0) {
		g_snprintf(path, sizeof path, "%s/lock-gate.png", dir);
		S.gate = cairo_image_surface_create_from_png(path);
		if (cairo_surface_status(S.gate) != CAIRO_STATUS_SUCCESS) {
			cairo_surface_destroy(S.gate);
			S.gate = NULL;
		}
	}
	if (!S.gate)
		S.gn = 0;                         /* (no frames: the scene's own open gate, as it is drawn) */
	if (S.mn > 0 && S.mw > 0 && S.mh > 0) {
		g_snprintf(path, sizeof path, "%s/lock-marks.png", dir);
		S.marks = cairo_image_surface_create_from_png(path);
		if (cairo_surface_status(S.marks) != CAIRO_STATUS_SUCCESS) {
			cairo_surface_destroy(S.marks);
			S.marks = NULL;
			return FALSE;
		}
	}
	return !samurai || sam_load(dir);
}

/* the scene's scale and corner on a widget W × H: all of it, the most the screen holds */
static double fit(GtkWidget *a, int *ox, int *oy)
{
	int W = gtk_widget_get_allocated_width(a), H = gtk_widget_get_allocated_height(a);
	double n = MIN((double)W / S.w, (double)H / S.h);
	*ox = (int)((W - n * S.w) / 2), *oy = (int)((H - n * S.h) / 2);
	return n;
}
static void redraw(GtkWidget *a, int x, int y, int w, int h)   /* a part, in the scene's pixels */
{
	int ox, oy;
	double n = fit(a, &ox, &oy);
	if (n == (int)n)
		gtk_widget_queue_draw_area(a, ox + (int)n * x, oy + (int)n * y, (int)n * w, (int)n * h);
	else                                  /* (smooth: a pixel's edge reaches its neighbours) */
		gtk_widget_queue_draw_area(a, ox + (int)(n * x) - 1, oy + (int)(n * y) - 1, (int)(n * w) + 3, (int)(n * h) + 3);
}
/* a mark's size in the scene */
static int mark_w(void) { return S.marks ? S.mw : 3 * S.ms; }
static int mark_h(void) { return S.marks ? S.mh : 3 * S.ms; }
static void redraw_row(struct look *l)    /* (a mark's flare fits in the margin) */
{
	redraw(l->area, S.rx - mark_w(), S.ry - mark_h(), S.pitch * S.rn + 2 * mark_w(), 2 * mark_h());
}

static void dot(cairo_t *cr, int x, int y, const ink *c)
{
	cairo_set_source_rgb(cr, c->r, c->g, c->b);
	cairo_rectangle(cr, x - S.ms / 2, y - S.ms / 2, S.ms, S.ms);
	cairo_fill(cr);
}
static void mark(cairo_t *cr, int x, int y, const ink *arms, const ink *core, const ink *corner)
{
	if (corner)
		for (int i = 0; i < 4; i++)
			dot(cr, x + S.ms * (i & 1 ? 1 : -1), y + S.ms * (i & 2 ? 1 : -1), corner);
	for (int i = 0; i < 4; i++)
		dot(cr, x + S.ms * ((i == 0) - (i == 1)), y + S.ms * ((i == 2) - (i == 3)), arms);
	if (core)
		dot(cr, x, y, core);
}
/* a drawn mark: its strip's frame f, its middle on (x, y); Caps Lock: its shape in that ink */
static void drawn(cairo_t *cr, int f, int x, int y, double zoom, double alpha, const ink *flat)
{
	cairo_save(cr);
	cairo_translate(cr, x, y);
	cairo_scale(cr, zoom, zoom);
	cairo_rectangle(cr, -S.mw / 2, -S.mh / 2, S.mw, S.mh);
	cairo_clip(cr);
	if (flat) {
		cairo_set_source_rgba(cr, flat->r, flat->g, flat->b, alpha);
		cairo_mask_surface(cr, S.marks, -S.mw / 2 - f * S.mw, -S.mh / 2);
	} else {
		cairo_set_source_surface(cr, S.marks, -S.mw / 2 - f * S.mw, -S.mh / 2);
		cairo_paint_with_alpha(cr, alpha);
	}
	cairo_restore(cr);
}
static void paint_scene(cairo_t *cr, int dx)
{
	cairo_set_source_surface(cr, S.img, dx, 0);
	cairo_pattern_set_filter(cairo_get_source(cr), filter);
	cairo_rectangle(cr, dx, 0, S.w, S.h);
	cairo_fill(cr);
}

/* ── the gate ─────────────────────────────────────────────────────────────────────────── */
#define GATE_US (340 * 1000)              /* opening, shutting: all its frames */
enum { GATE_SHUT, GATE_OPENING, GATE_OPEN, GATE_SHUTTING };
static int gate = GATE_OPEN, gate_frame, gate_from;   /* (no frames: always open) */
static gint64 gate_t0;
static guint gate_src;
static struct Window *gate_try;           /* the window whose password goes in once it is shut */

static void gate_redraw(void)
{
	for (GList *g = looks; g; g = g->next) {
		redraw(((struct look *)g->data)->area, S.gx - 2 * S.ms, S.gy - 2 * S.ms, S.gw + 4 * S.ms, S.gh + 4 * S.ms);
		redraw_row(g->data);
	}
}
static gboolean gate_step(gpointer data)
{
	double q = (double)(g_get_monotonic_time() - gate_t0) / GATE_US;
	(void)data;
	q = q > 1 ? 1 : q;
	q = q * q * (3 - 2 * q);              /* (gentle at both ends) */
	int f = (int)(gate_from + ((gate == GATE_OPENING ? S.gn - 1 : 0) - gate_from) * q + .5);
	if (f != gate_frame) {
		gate_frame = f;
		gate_redraw();
	}
	if (q < 1)
		return G_SOURCE_CONTINUE;
	gate_src = 0;
	if (gate == GATE_OPENING) {
		gate = GATE_OPEN;
		gate_redraw();
	} else {
		gate = GATE_SHUT;
		if (gate_try) {                   /* (eaten: now the password is tried) */
			struct Window *w = gate_try;
			gate_try = NULL;
			gtk_widget_activate(w->input_field);
		}
	}
	return G_SOURCE_REMOVE;
}
static void gate_go(int to)
{
	gate = to;
	gate_from = gate_frame;               /* (from wherever it was: no jump) */
	gate_t0 = g_get_monotonic_time();
	if (!gate_src)
		gate_src = g_timeout_add(7, gate_step, NULL);   /* (a frame of the screen's, near enough) */
	gate_redraw();
}
/* the gate at rest, shut, nothing typed */
static void gate_rest(void)
{
	if (!S.gn)
		return;
	if (gate_src)
		g_source_remove(gate_src);
	gate_src = 0, gate_frame = 0, gate = GATE_SHUT, gate_try = NULL;
	for (GList *g = looks; g; g = g->next) {
		struct look *l = g->data;
		gtk_entry_set_text(GTK_ENTRY(l->win->input_field), "");
	}
	gate_redraw();
}
/* the secret key, shut and no try waiting for its word (gtklock's line is insensitive while PAM runs) */
static void gate_wake_key(struct Window *win, GdkEventKey *ev)
{
	if (S.gn && ev->keyval == GDK_KEY_Tab && gate == GATE_SHUT && gtk_widget_is_sensitive(win->input_field))
		gate_go(GATE_OPENING);
}
/* a key, once the screens are lit: what the gate makes of it; TRUE: it goes no further */
static gboolean gate_keys(struct Window *win, GdkEventKey *ev)
{
	gboolean enter = ev->keyval == GDK_KEY_Return || ev->keyval == GDK_KEY_KP_Enter || ev->keyval == GDK_KEY_ISO_Enter;
	if (!S.gn)
		return FALSE;
	if (ev->keyval == GDK_KEY_Tab || gate == GATE_SHUT || gate == GATE_SHUTTING) {
		/* (shut, every key is nothing but the secret one) */
		if (ev->type == GDK_KEY_PRESS)
			gate_wake_key(win, ev);
		return TRUE;
	}
	if (ev->type != GDK_KEY_PRESS)
		return FALSE;
	if (ev->keyval == GDK_KEY_Escape) {
		gtk_entry_set_text(GTK_ENTRY(win->input_field), "");
		gate_go(GATE_SHUTTING);
		return TRUE;
	}
	if (enter && gtk_entry_get_text_length(GTK_ENTRY(win->input_field)) > 0) {
		gate_try = win;
		gate_go(GATE_SHUTTING);
		return TRUE;
	}
	return FALSE;
}

static gboolean life_load(gpointer data);
static int sam, sam_f;                    /* the samurai's state, its frame */

static gboolean draw(GtkWidget *a, cairo_t *cr, gpointer data)
{
	struct look *l = data;
	struct Window *win = l->win;
	int ox, oy;
	double n = fit(a, &ox, &oy);
	filter = n == (int)n ? CAIRO_FILTER_NEAREST : CAIRO_FILTER_GOOD;
	if (!life_loaded) {                   /* (the first picture is up: now the strips) */
		life_loaded = TRUE;
		g_timeout_add(30, life_load, NULL);
	}
	cairo_set_source_rgb(cr, S.ground.r, S.ground.g, S.ground.b);
	cairo_paint(cr);
	cairo_translate(cr, ox, oy);
	cairo_scale(cr, n, n);
	paint_scene(cr, 0);
	/* a wrong password: its step (0 … STEPS-1), the gate (or the plate) a pixel aside on the odd ones */
	int step = -1, dx = 0;
	if (l->wrong) {
		step = (int)((g_get_monotonic_time() - l->wrong) / STEP_US);
		if (step >= STEPS)
			step = -1;
		else
			dx = S.ms * (step == 0 || step == 2 ? 1 : step == 1 || step == 3 ? -1 : 0);
	}
	if (S.gate) {
		cairo_save(cr);
		cairo_rectangle(cr, S.gx + dx, S.gy, S.gw, S.gh);
		cairo_clip(cr);
		cairo_set_source_surface(cr, S.gate, S.gx + dx - gate_frame * S.gw, S.gy);
		cairo_pattern_set_filter(cairo_get_source(cr), filter);
		cairo_paint(cr);
		cairo_restore(cr);
	} else if (dx) {
		cairo_save(cr);
		cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE);   /* (the rim in whole pixels: no blended ink) */
		cairo_arc(cr, S.cx + dx, S.cy, S.cr, 0, 2 * G_PI);
		cairo_clip(cr);
		paint_scene(cr, dx);
		cairo_restore(cr);
	}
	for (int i = 0; S.flame && i < S.nflames; i++) {
		int f = (frame + 3 * i) % S.frames;   /* (the two out of step) */
		cairo_set_source_surface(cr, S.flame, S.fx[i] - f * S.fw, S.fy[i]);
		cairo_pattern_set_filter(cairo_get_source(cr), filter);
		cairo_rectangle(cr, S.fx[i], S.fy[i], S.fw, S.fh);
		cairo_fill(cr);
	}
	for (int i = 0; i < S.nanims; i++) {
		struct anim *an = &S.anim[i];
		if (!an->img)
			continue;
		cairo_save(cr);
		cairo_rectangle(cr, an->x, an->y, an->w, an->h);
		cairo_clip(cr);
		cairo_set_source_surface(cr, an->img, an->x - an->frame * an->w, an->y);
		cairo_pattern_set_filter(cairo_get_source(cr), filter);
		cairo_paint(cr);
		cairo_restore(cr);
	}
	for (int i = 0; i < S.nsparks; i++) {
		struct spark *sp = &S.spark[i];
		if (sp->live)
			dot(cr, sp->px, sp->py, sp->age * 2 < sp->life ? &S.young : &S.old);
	}
	if (S.sam) {
		int f = sam_st[sam].frame[sam_f];
		cairo_save(cr);
		cairo_rectangle(cr, S.sx, S.sy, S.scw, S.sch);
		cairo_clip(cr);
		cairo_set_source_surface(cr, S.sam, S.sx - f % S.scols * S.scw, S.sy - f / S.scols * S.sch);
		cairo_pattern_set_filter(cairo_get_source(cr), filter);
		cairo_paint(cr);
		cairo_restore(cr);
	}
	GtkWidget *e = win->input_field;
	gboolean open = gate == GATE_OPEN;    /* the marks in the mouth while it is open… */
	gboolean eating = gate == GATE_SHUTTING && gate_try && gate_frame >= S.gn / 2;   /* …until the jaws meet */
	int len = e ? (int)gtk_entry_get_text_length(GTK_ENTRY(e)) : 0, shown = open || eating ? MIN(len, S.rn) : 0;
	GdkKeymap *km = gdk_keymap_get_for_display(gtk_widget_get_display(a));
	gboolean caps = gdk_keymap_get_caps_lock_state(km);
	const ink *arms = caps ? &S.caps : &S.arms;
	if (eating) {
		cairo_save(cr);
		cairo_rectangle(cr, S.gx, S.gy, S.gw, S.gh);
		cairo_clip(cr);
	}
	if (step >= 0) {                      /* the tried ones scatter, dimming, then go */
		for (int i = 0; i < MIN(l->tried, S.rn); i++) {
			int vx = (int)((i * 7 + 3) % 5) - 2, vy = i % 2 ? -1 - (i % 3 > 0) : 1 + (i % 4 == 0);
			int x = S.rx + S.pitch * i + dx + S.ms * vx * step, y = S.ry + S.ms * vy * step;
			if (S.marks) {
				if (step < 4)
					drawn(cr, i % S.mn, x, y, 1, step < 2 ? 1 : .5, caps ? &S.caps : NULL);
			} else if (step < 2)
				mark(cr, x, y, arms, &S.core, &S.corner);
			else if (step < 4)
				mark(cr, x, y, &S.corner, arms, NULL);
		}
	} else {
		gboolean flaring = shown && g_get_monotonic_time() < l->flare;
		for (int i = 0; i < shown; i++) {     /* (the newest flaring: larger, or its corners in the arms' ink) */
			gboolean f = flaring && i == shown - 1;
			if (S.marks)
				drawn(cr, i % S.mn, S.rx + S.pitch * i, S.ry, f ? 1.25 : 1, 1, caps ? &S.caps : NULL);
			else
				mark(cr, S.rx + S.pitch * i, S.ry, arms, &S.core, f ? arms : &S.corner);
		}
	}
	if (eating)
		cairo_restore(cr);
	if (caret_on && open && step < 0 && e && gtk_widget_has_focus(e) && gtk_widget_is_sensitive(e)) {
		cairo_set_source_rgb(cr, S.caret.r, S.caret.g, S.caret.b);
		cairo_rectangle(cr, S.rx + S.pitch * shown - S.ms / 2, S.ry - mark_h() / 2, S.ms, mark_h());   /* (a mark's height) */
		cairo_fill(cr);
	}
	return FALSE;
}

static gboolean flames_tick(gpointer data)
{
	(void)data;
	frame = (frame + 1) % MAX(S.frames, 1);
	for (GList *g = looks; g; g = g->next)
		for (int i = 0; i < S.nflames; i++)
			redraw(((struct look *)g->data)->area, S.fx[i], S.fy[i], S.fw, S.fh);
	return G_SOURCE_CONTINUE;
}
/* the scene's life, 25 times a second: an anim's new frame, the sparks' new places (only those drawn) */
static void redraw_all(int x, int y, int w, int h)
{
	for (GList *g = looks; g; g = g->next)
		redraw(((struct look *)g->data)->area, x, y, w, h);
}
static guint life_rng = 2463534242u;
static int life_rnd(int n)
{
	life_rng ^= life_rng << 13, life_rng ^= life_rng >> 17, life_rng ^= life_rng << 5;
	return n > 0 ? (int)(life_rng % (guint)n) : 0;
}
static gboolean life_tick(gpointer data)
{
	gint64 ms = g_get_monotonic_time() / 1000;
	(void)data;
	for (int i = 0; i < S.nanims; i++) {
		struct anim *an = &S.anim[i];
		int f = (int)(ms / an->ms % an->n);
		if (an->img && f != an->frame) {
			an->frame = f;
			redraw_all(an->x, an->y, an->w, an->h);
		}
	}
	for (int i = 0; i < S.nsparks; i++) {
		struct spark *sp = &S.spark[i];
		if (!sp->live) {
			if (life_rnd(40))
				continue;
			sp->live = TRUE, sp->age = 0, sp->px = sp->py = -1;
			if (S.petals) {
				sp->x = (float)life_rnd(S.w), sp->y = (float)life_rnd(S.h / 2);
				sp->vx = (float)(life_rnd(40) - 20) / 100.0f, sp->vy = 0.15f + (float)life_rnd(30) / 100.0f;
				sp->life = 120 + life_rnd(160);
			} else {
				int t = S.nflames ? life_rnd(S.nflames) : 0;
				sp->x = (float)(S.nflames ? S.fx[t] + life_rnd(MAX(S.fw, 1)) : life_rnd(S.w));
				sp->y = (float)(S.nflames ? S.fy[t] + S.fh / 3 : S.h - 1);
				sp->vx = (float)(life_rnd(40) - 20) / 120.0f, sp->vy = -0.3f - (float)life_rnd(50) / 100.0f;
				sp->life = 50 + life_rnd(90);
			}
			if (S.nspawn) {
				int t = life_rnd(S.nspawn);
				sp->x = (float)(S.spawn[t].x + life_rnd(MAX(S.spawn[t].w, 1)));
				sp->y = (float)(S.spawn[t].y + life_rnd(MAX(S.spawn[t].h, 1)));
			}
			continue;
		}
		if (sp->px >= 0)
			redraw_all(sp->px - S.ms / 2, sp->py - S.ms / 2, S.ms, S.ms);
		if (++sp->age > sp->life) {
			sp->live = FALSE;
			continue;
		}
		sp->vx += (float)(life_rnd(21) - 10) / 500.0f;   /* (the air moves it) */
		sp->x += S.ms * sp->vx, sp->y += S.ms * sp->vy;
		sp->px = (int)sp->x, sp->py = (int)sp->y;
		if (sp->px < 0 || sp->py < 0 || sp->px >= S.w || sp->py >= S.h)
			sp->live = FALSE;
		else
			redraw_all(sp->px - S.ms / 2, sp->py - S.ms / 2, S.ms, S.ms);
	}
	return G_SOURCE_CONTINUE;
}

/* the samurai: a frame, then a timer for exactly its time; a state played once goes on to the next */
static guint sam_src;
static int sam_len, sam_cut;              /* the line's length; the cut the next key takes */
static gboolean sam_trying;               /* a password with PAM: the line's clearing is no delete */
static gboolean sam_step(gpointer data);
static void sam_show(void)
{
	redraw_all(S.sx, S.sy, S.scw, S.sch);
	sam_src = asleep ? 0 : g_timeout_add(sam_st[sam].ms[sam_f], sam_step, NULL);
}
static void sam_go(int state)
{
	if (!S.sam)
		return;
	if (sam_src)
		g_source_remove(sam_src);
	sam = state, sam_f = 0;
	sam_show();
}
static gboolean sam_step(gpointer data)
{
	(void)data;
	sam_src = 0;
	if (++sam_f < sam_st[sam].n) {
		sam_show();
	} else if (sam_st[sam].loop) {
		sam_f = 0;
		sam_show();
	} else if (sam == SAM_RIGHT) {
		sam_f--;                          /* (the last pose, until gtklock is gone) */
	} else {
		sam_go(sam_len ? SAM_READY : SAM_IDLE);
	}
	return G_SOURCE_REMOVE;
}
static gboolean sam_wake(gpointer data)
{
	(void)data;
	return G_SOURCE_REMOVE;
}
/* the application's shutdown, before gtklock's handler unlocks: a password was with PAM and no failure
 * came, so it was right. Its frames, on this thread's own loop, for their time and not a moment more */
static gboolean sam_right(GSignalInvocationHint *hint, guint n, const GValue *params, gpointer data)
{
	(void)hint, (void)n, (void)params, (void)data;
	if (S.sam && sam_trying && !asleep) {
		int ms = 0;
		for (int i = 0; i < sam_st[SAM_RIGHT].n; i++)
			ms += sam_st[SAM_RIGHT].ms[i];
		gint64 end = g_get_monotonic_time() + ms * 1000;
		sam_go(SAM_RIGHT);
		g_timeout_add(ms + 1, sam_wake, NULL);
		while (g_get_monotonic_time() < end)
			g_main_context_iteration(NULL, TRUE);
	}
	return FALSE;
}

static gboolean caret_tick(gpointer data)
{
	(void)data;
	caret_on = !caret_on;
	for (GList *g = looks; g; g = g->next)
		redraw_row(g->data);
	return G_SOURCE_CONTINUE;
}
static void caret_restart(void)           /* (solid while typing: the blink starts over) */
{
	caret_on = TRUE;
	if (caret_timer)
		g_source_remove(caret_timer);
	caret_timer = asleep ? 0 : g_timeout_add(500, caret_tick, NULL);
}
/* the strips, read once the first picture is up; then the scene's life starts */
static gboolean life_load(gpointer data)
{
	char path[PATH_MAX];
	(void)data;
	for (int i = 0; i < S.nanims; i++) {
		struct anim *an = &S.anim[i];
		g_snprintf(path, sizeof path, "%s/lock-%s.png", scene_dir, an->name);
		an->img = cairo_image_surface_create_from_png(path);
		if (cairo_surface_status(an->img) != CAIRO_STATUS_SUCCESS)
			cairo_surface_destroy(an->img), an->img = NULL;
	}
	if ((S.nanims || S.nsparks) && !asleep)
		life_timer = g_timeout_add(40, life_tick, NULL);
	return G_SOURCE_REMOVE;
}
/* no frames wanted (the screens dark, the saver over it): no timer wakes this process; back, a whole new picture */
static void scene_sleep(gboolean sleep)
{
	if (sleep == asleep || !S.img)
		return;
	asleep = sleep;
	if (sleep) {
		if (flame_timer)
			g_source_remove(flame_timer);
		if (life_timer)
			g_source_remove(life_timer);
		if (caret_timer)
			g_source_remove(caret_timer);
		if (sam_src)
			g_source_remove(sam_src);
		flame_timer = life_timer = caret_timer = sam_src = 0;
		return;
	}
	if (S.nflames)
		flame_timer = g_timeout_add(1000 / 8, flames_tick, NULL);
	if (life_loaded && (S.nanims || S.nsparks))
		life_timer = g_timeout_add(40, life_tick, NULL);
	caret_timer = g_timeout_add(500, caret_tick, NULL);
	if (S.sam)
		sam_show();
	redraw_all(0, 0, S.w, S.h);
}

static gboolean wrong_tick(GtkWidget *a, GdkFrameClock *clock, gpointer data)
{
	struct look *l = data;
	(void)clock;
	if (S.gn)
		redraw(a, S.gx - 2 * S.ms, S.gy - 2 * S.ms, S.gw + 4 * S.ms, S.gh + 4 * S.ms);
	else
		redraw(a, S.cx - S.cr - 4 * S.ms, S.cy - S.cr - 4 * S.ms, 2 * S.cr + 8 * S.ms, 2 * S.cr + 8 * S.ms);
	if (g_get_monotonic_time() - l->wrong < STEPS * STEP_US)
		return G_SOURCE_CONTINUE;
	l->wrong = 0, l->tick = 0;
	return G_SOURCE_REMOVE;
}
static gboolean flare_end(gpointer data)
{
	struct look *l = data;
	l->flare_src = 0;
	redraw_row(l);
	return G_SOURCE_REMOVE;
}
static void on_changed(GtkEditable *e, gpointer data)
{
	struct look *l = data;
	int len = (int)gtk_entry_get_text_length(GTK_ENTRY(e));
	if (len > l->typed) {                 /* (a key typed: its answer, also past the seventh) */
		l->flare = g_get_monotonic_time() + FLARE_US;
		if (l->flare_src)                 /* (a key within the last one's flare: it ends later) */
			g_source_remove(l->flare_src);
		l->flare_src = g_timeout_add(FLARE_US / 1000 + 1, flare_end, l);
	}
	if (!sam_trying && gtk_widget_has_focus(GTK_WIDGET(e))) {   /* (only that a key came: never which) */
		if (len > sam_len)
			sam_go(sam_len ? SAM_KEY0 + sam_cut++ % 3 : SAM_START);
		else if (len < sam_len)
			sam_go(SAM_DELETE);
	}
	sam_len = len;
	l->typed = len;
	caret_restart();
	redraw_row(l);
}
static void on_state(GObject *o, GParamSpec *p, gpointer data)   /* focus or busy changed */
{
	(void)o, (void)p;
	redraw_row(data);
}
/* what PAM said: gtklock's info bars in its unseen box — every try's so far, errors first, each
 * try's after the ones before it — counted into n; with s, the words of those past l->seen,
 * each once */
static void bars_read(struct look *l, int n[2], GString *s)
{
	GList *bars = gtk_container_get_children(GTK_CONTAINER(l->win->message_box));
	n[0] = n[1] = 0;
	for (GList *b = bars; b; b = b->next) {
		if (!GTK_IS_INFO_BAR(b->data))
			continue;
		int k = gtk_info_bar_get_message_type(b->data) == GTK_MESSAGE_INFO;
		if (n[k]++ < l->seen[k] || !s)
			continue;
		GList *ws = gtk_container_get_children(GTK_CONTAINER(gtk_info_bar_get_content_area(b->data)));
		for (GList *w = ws; w; w = w->next) {
			const char *t = GTK_IS_LABEL(w->data) ? gtk_label_get_text(w->data) : NULL;
			if (t && *t && !strstr(s->str, t))
				g_string_append_printf(s, "%s%s", s->len ? "\n" : "", t);   /* (each its own line) */
		}
		g_list_free(ws);
	}
	g_list_free(bars);
}
static gboolean words_show(gpointer data)
{
	struct look *l = data;
	int n[2];
	GString *s = g_string_new(NULL);
	l->words_src = 0;
	bars_read(l, n, s);
	gtk_label_set_text(GTK_LABEL(l->words), s->str);
	g_string_free(s, TRUE);
	return G_SOURCE_REMOVE;
}
/* the line's place: across the screen's middle, in the middle of the scene's rows for it (a stone
 * course of the wall, the gold under the last cloud) — clear of every edge of the picture */
static gboolean place_words(GtkOverlay *o, GtkWidget *w, GdkRectangle *r, gpointer data)
{
	struct look *l = data;
	int ox, oy, W, h;
	double n;
	if (w != l->words)
		return FALSE;
	n = fit(l->area, &ox, &oy);
	W = gtk_widget_get_allocated_width(GTK_WIDGET(o));
	gtk_widget_get_preferred_width(w, NULL, &r->width);
	r->width = MIN(r->width, W);
	gtk_widget_get_preferred_height_for_width(w, r->width, NULL, &h);
	r->height = h;
	r->x = (W - r->width) / 2;
	r->y = oy + (int)(n * S.wy0) + ((int)(n * (S.wy1 - S.wy0 + 1)) - h) / 2;
	return TRUE;
}
/* gtklock makes its bars again for each new word (each bar first, its words then): read once it is done */
static void on_bars(GtkContainer *box, GtkWidget *bar, gpointer data)
{
	struct look *l = data;
	(void)box, (void)bar;
	if (!l->words_src)
		l->words_src = g_idle_add(words_show, l);
}
static void on_try(GtkEntry *e, gpointer data)   /* Enter: after gtklock's own handler */
{
	struct look *l = data;
	l->tried = (int)gtk_entry_get_text_length(e);
	sam_trying = TRUE;
	if (l->words) {                       /* (its words come after this: the thread just began) */
		int n[2];
		bars_read(l, n, NULL);
		l->seen[0] = n[0], l->seen[1] = n[1];
		gtk_label_set_text(GTK_LABEL(l->words), "");
	}
}
static void on_error(GObject *o, GParamSpec *p, gpointer data)   /* gtklock's error line */
{
	struct look *l = data;
	const char *t = gtk_label_get_text(GTK_LABEL(o));
	(void)p;
	if (!t || !*t)
		return;
	l->wrong = g_get_monotonic_time();
	sam_trying = FALSE;
	sam_go(SAM_WRONG);
	if (!l->tick)
		l->tick = gtk_widget_add_tick_callback(l->area, wrong_tick, l, NULL);
	if (S.gn)                             /* (spat out: open again, the line empty) */
		gate_go(GATE_OPENING);
}
static void on_caps(GdkKeymap *k, gpointer data)
{
	(void)k, (void)data;
	for (GList *g = looks; g; g = g->next)
		redraw_row(g->data);
}

void on_activation(struct GtkLock *gtklock, int id)
{
	(void)gtklock;
	self_id = id;
	const char *run = g_getenv("XDG_RUNTIME_DIR"), *art = g_getenv("KAWA_LOCK_ART");
	g_snprintf(screens, sizeof screens, "%s/kawa-screens", run && *run ? run : "/nonexistent");
	g_snprintf(saver, sizeof saver, "%s/kawa-saver.lock", run && *run ? run : "/nonexistent");
	touched_at = g_get_real_time();
	saver_was_up = saver_up();
	g_timeout_add(250, idle_tick, NULL);   /* (dark 5.0–5.25 s after the last input) */
	if (!art || !*art || !scene_load(art))
		return;
	if (S.gn)
		gate = GATE_SHUT;
	if (S.nflames)
		flame_timer = g_timeout_add(1000 / 8, flames_tick, NULL);
	caret_timer = g_timeout_add(500, caret_tick, NULL);
	if (S.sam) {
		sam_go(SAM_IDLE);
		g_signal_add_emission_hook(g_signal_lookup("shutdown", G_TYPE_APPLICATION), 0, sam_right, NULL, NULL);
	}
}

void on_window_create(struct GtkLock *gtklock, struct Window *win)
{
	(void)gtklock;
	/* every key and click passes here first (a window's handlers run before its own) */
	g_signal_connect(win->window, "key-press-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "key-release-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "button-press-event", G_CALLBACK(on_button), win);
	g_signal_connect(win->window, "button-release-event", G_CALLBACK(on_button), win);
	gtk_widget_add_events(win->window, GDK_POINTER_MOTION_MASK | GDK_SCROLL_MASK | GDK_SMOOTH_SCROLL_MASK);
	g_signal_connect(win->window, "motion-notify-event", G_CALLBACK(on_move), win);
	g_signal_connect(win->window, "scroll-event", G_CALLBACK(on_move), win);
	if (win->input_field)
		g_signal_connect(win->input_field, "notify::secondary-icon-name", G_CALLBACK(no_icon), NULL);
	if (!S.img || !win->overlay || !GTK_IS_OVERLAY(win->overlay) || !win->window_box || !win->input_field)
		return;
	/* the scene under the layout: the overlay's main child, gtklock's box over it */
	struct look *l = g_new0(struct look, 1);
	l->win = win;
	l->area = gtk_drawing_area_new();
	gtk_widget_set_can_focus(l->area, FALSE);
	g_signal_connect(l->area, "draw", G_CALLBACK(draw), l);
	g_object_ref(win->window_box);
	gtk_container_remove(GTK_CONTAINER(win->overlay), win->window_box);
	gtk_container_add(GTK_CONTAINER(win->overlay), l->area);
	gtk_overlay_add_overlay(GTK_OVERLAY(win->overlay), win->window_box);
	g_object_unref(win->window_box);
	if (win->message_box && GTK_IS_CONTAINER(win->message_box)) {
		/* the line of words: kawa-greet's twin (its place: lock-scene.txt's words; its CSS name:
		 * window.kawa #error-label) */
		l->words = gtk_label_new(NULL);
		gtk_widget_set_name(l->words, "error-label");
		gtk_label_set_line_wrap(GTK_LABEL(l->words), TRUE);   /* (a long one from PAM: whole) */
		gtk_label_set_max_width_chars(GTK_LABEL(l->words), 60);
		gtk_label_set_justify(GTK_LABEL(l->words), GTK_JUSTIFY_CENTER);
		gtk_overlay_add_overlay(GTK_OVERLAY(win->overlay), l->words);
		gtk_overlay_set_overlay_pass_through(GTK_OVERLAY(win->overlay), l->words, TRUE);
		g_signal_connect(win->overlay, "get-child-position", G_CALLBACK(place_words), l);
		g_signal_connect(win->message_box, "add", G_CALLBACK(on_bars), l);
		g_signal_connect(win->message_box, "remove", G_CALLBACK(on_bars), l);
	}
	gtk_style_context_add_class(gtk_widget_get_style_context(win->window), "kawa");
	gtk_widget_set_opacity(win->window_box, 0);   /* (its line unseen from the first frame, whatever the CSS does) */
	g_signal_connect(win->input_field, "changed", G_CALLBACK(on_changed), l);
	g_signal_connect(win->input_field, "notify::has-focus", G_CALLBACK(on_state), l);
	g_signal_connect(win->input_field, "notify::sensitive", G_CALLBACK(on_state), l);
	g_signal_connect_after(win->input_field, "activate", G_CALLBACK(on_try), l);
	if (win->error_label)
		g_signal_connect(win->error_label, "notify::label", G_CALLBACK(on_error), l);
	static gboolean caps_heard;
	if (!caps_heard) {
		caps_heard = TRUE;
		g_signal_connect(gdk_keymap_get_for_display(gtk_widget_get_display(win->window)),
				"state-changed", G_CALLBACK(on_caps), NULL);
	}
	win->module_data[self_id] = l;
	looks = g_list_prepend(looks, l);
}

void on_window_destroy(struct GtkLock *gtklock, struct Window *win)
{
	(void)gtklock;
	struct look *l = win->module_data[self_id];
	if (!l)
		return;
	looks = g_list_remove(looks, l);
	if (l->flare_src)
		g_source_remove(l->flare_src);
	if (l->words_src)
		g_source_remove(l->words_src);
	if (gate_try == win)
		gate_try = NULL;
	/* (gtklock destroys the window's insides after this: no signal of theirs may still reach l) */
	g_signal_handlers_disconnect_by_data(win->input_field, l);
	if (win->error_label)
		g_signal_handlers_disconnect_by_data(win->error_label, l);
	if (l->words) {
		g_signal_handlers_disconnect_by_data(win->message_box, l);
		g_signal_handlers_disconnect_by_data(win->overlay, l);
	}
	g_free(l);
	win->module_data[self_id] = NULL;
}
