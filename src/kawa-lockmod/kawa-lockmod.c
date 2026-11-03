/*
 * kawa-lockmod — the lock screen's own part of gtklock (a gtklock 4 module; kawa-lock loads it
 * with -m ~/.local/lib/fedokawaii/kawa-lockmod.so). On every screen:
 *
 *  The scene. The mood's picture (KAWA_LOCK_ART/lock-scene.png, tools/build-lock.py: 640 × 360)
 *  drawn under gtklock's layout at whole pixels — N × N each, N the most the screen holds (3 on
 *  1080p), centred, the ground of lock-scene.txt round it — and on it, from lock-scene.txt: the
 *  torches' flames (lock-flame.png's frames, 8 a second, the two out of step), the password as
 *  marks in the mood's row (the demon's mouth: an ember for each character; the sky by Seiōbo's
 *  peach: a mote) — the newest ones while more are typed than the row holds —, the arms in the
 *  Caps Lock ink while it is on, and the caret: a bar at the next place, once a second, there
 *  while the line has the keyboard. A wrong password (gtklock's error line, never shown): the
 *  marks scatter and fade, the face (the plate) shakes a pixel of the scene twice — 240 ms, five
 *  steps of 48. gtklock's own line stays for the keys: invisible (current/gtklock.css,
 *  window.kawa), its words never shown. No date, no time, no keys: the scene is the lock.
 *
 *  The wake guard. The key that wakes the computer, or lights the dark screens, only wakes:
 *  kawa-lock notes the screens in $XDG_RUNTIME_DIR/kawa-screens — "off" before they go dark,
 *  "on" once they are lit (its time: the moment) — and while they are dark, and for 2 s after
 *  they come back, every key and click here is swallowed: an Enter that woke the machine is
 *  never a wrong password. A stale "off" (a session that ended in the dark) holds only the
 *  first 2 s of keys after it was written. And an Enter in an empty box is never a try.
 *
 * Without its art (no KAWA_LOCK_ART, a file missing) only the guard runs: gtklock's plain line.
 * Built by theme.sh (src/kawa-lockmod/Makefile) against GTK 3's headers.
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <string.h>
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

static int self_id;
static char screens[PATH_MAX];            /* $XDG_RUNTIME_DIR/kawa-screens */
static gint64 off_mtime = -1, off_first;  /* the "off" last seen, and its first swallowed event */

/* true while what reaches the lock screen only wakes it (above) */
static gboolean guarded(void)
{
	char buf[8] = { 0 };
	struct stat st;
	int fd = open(screens, O_RDONLY | O_CLOEXEC);
	if (fd < 0)
		return FALSE;
	ssize_t n = read(fd, buf, sizeof buf - 1);
	int r = fstat(fd, &st);
	close(fd);
	if (n <= 0 || r < 0)
		return FALSE;
	gint64 now = g_get_real_time();
	gint64 mt = (gint64)st.st_mtim.tv_sec * G_USEC_PER_SEC + st.st_mtim.tv_nsec / 1000;
	if (!strncmp(buf, "on", 2))
		return now >= mt && now - mt < GUARD_US;
	if (strncmp(buf, "off", 3))
		return FALSE;
	if (mt != off_mtime) {
		off_mtime = mt;
		off_first = now;
	}
	return now - off_first < GUARD_US;
}

static gboolean on_key(GtkWidget *w, GdkEventKey *ev, gpointer data)
{
	struct Window *win = data;
	(void)w;
	if (guarded())
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
	return guarded();
}

/* ── the scene (lock-scene.txt: build-lock.py's words) ────────────────────────────────── */
typedef struct { double r, g, b; } ink;
static struct {
	cairo_surface_t *img, *flame;
	int w, h, fw, fh, frames, nflames, fx[4], fy[4];
	int rx, ry, pitch, rn;                /* the password's row: the first mark, the pitch, how many */
	int cx, cy, cr;                       /* the plate */
	ink ground, arms, core, corner, caps, caret;
} S;

#define STEP_US (48 * 1000)               /* a step of the wrong password's 240 ms */
#define STEPS 5

struct look {                             /* one window's */
	struct Window *win;
	GtkWidget *area;
	int tried;                            /* marks when the last try began */
	gint64 wrong;                         /* its failure's moment (µs, monotonic), 0 none */
	guint tick;
};
static GList *looks;
static int frame;                         /* the flames' (8 a second) */
static gboolean caret_on = TRUE;
static guint flame_timer, caret_timer;

static gboolean hexink(const char *s, ink *c)
{
	unsigned v;
	if (!s || sscanf(s, "%6x", &v) != 1)
		return FALSE;
	c->r = ((v >> 16) & 255) / 255.0, c->g = ((v >> 8) & 255) / 255.0, c->b = (v & 255) / 255.0;
	return TRUE;
}

static gboolean scene_load(const char *dir)
{
	char path[PATH_MAX], line[256], a[16], b[16], c[16];
	int ok = 0;
	g_snprintf(path, sizeof path, "%s/lock-scene.txt", dir);
	FILE *f = fopen(path, "re");
	if (!f)
		return FALSE;
	while (fgets(line, sizeof line, f)) {
		if (sscanf(line, "size %d %d", &S.w, &S.h) == 2) ok |= 1;
		else if (sscanf(line, "ground %15s", a) == 1) ok |= hexink(a, &S.ground) << 1;
		else if (sscanf(line, "frames %d %d %d", &S.fw, &S.fh, &S.frames) == 3) ;
		else if (S.nflames < 4 && sscanf(line, "flame %d %d", &S.fx[S.nflames], &S.fy[S.nflames]) == 2) S.nflames++;
		else if (sscanf(line, "row %d %d %d %d", &S.rx, &S.ry, &S.pitch, &S.rn) == 4) ok |= 4;
		else if (sscanf(line, "mark %15s %15s %15s", a, b, c) == 3)
			ok |= (hexink(a, &S.arms) && hexink(b, &S.core) && hexink(c, &S.corner)) << 3;
		else if (sscanf(line, "caps %15s", a) == 1) hexink(a, &S.caps);
		else if (sscanf(line, "caret %15s", a) == 1) hexink(a, &S.caret);
		else if (sscanf(line, "plate %d %d %d", &S.cx, &S.cy, &S.cr) == 3) ok |= 16;
	}
	fclose(f);
	if (ok != 31 || S.w <= 0 || S.h <= 0 || S.rn <= 0)
		return FALSE;
	g_snprintf(path, sizeof path, "%s/lock-scene.png", dir);
	S.img = cairo_image_surface_create_from_png(path);
	if (cairo_surface_status(S.img) != CAIRO_STATUS_SUCCESS) {
		cairo_surface_destroy(S.img);
		S.img = NULL;
		return FALSE;
	}
	if (S.nflames && S.frames > 0) {
		g_snprintf(path, sizeof path, "%s/lock-flame.png", dir);
		S.flame = cairo_image_surface_create_from_png(path);
		if (cairo_surface_status(S.flame) != CAIRO_STATUS_SUCCESS) {
			cairo_surface_destroy(S.flame);
			S.flame = NULL;
			S.nflames = 0;
		}
	}
	return TRUE;
}

/* the scene's scale and corner on a widget W × H */
static int fit(GtkWidget *a, int *ox, int *oy)
{
	int W = gtk_widget_get_allocated_width(a), H = gtk_widget_get_allocated_height(a);
	int n = MAX(1, MIN(W / S.w, H / S.h));
	*ox = (W - n * S.w) / 2, *oy = (H - n * S.h) / 2;
	return n;
}
static void redraw(GtkWidget *a, int x, int y, int w, int h)   /* a part, in the scene's pixels */
{
	int ox, oy, n = fit(a, &ox, &oy);
	gtk_widget_queue_draw_area(a, ox + n * x, oy + n * y, n * w, n * h);
}
static void redraw_row(struct look *l)
{
	redraw(l->area, S.rx - 2, S.ry - 3, S.pitch * S.rn + 4, 7);
}

static void dot(cairo_t *cr, int x, int y, const ink *c)
{
	cairo_set_source_rgb(cr, c->r, c->g, c->b);
	cairo_rectangle(cr, x, y, 1, 1);
	cairo_fill(cr);
}
static void mark(cairo_t *cr, int x, int y, const ink *arms, const ink *core, const ink *corner)
{
	if (corner)
		for (int i = 0; i < 4; i++)
			dot(cr, x + (i & 1 ? 1 : -1), y + (i & 2 ? 1 : -1), corner);
	for (int i = 0; i < 4; i++)
		dot(cr, x + (i == 0) - (i == 1), y + (i == 2) - (i == 3), arms);
	if (core)
		dot(cr, x, y, core);
}
static void paint_scene(cairo_t *cr, int dx)
{
	cairo_set_source_surface(cr, S.img, dx, 0);
	cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_NEAREST);
	cairo_rectangle(cr, dx, 0, S.w, S.h);
	cairo_fill(cr);
}

static gboolean draw(GtkWidget *a, cairo_t *cr, gpointer data)
{
	struct look *l = data;
	struct Window *win = l->win;
	int ox, oy, n = fit(a, &ox, &oy);
	cairo_set_source_rgb(cr, S.ground.r, S.ground.g, S.ground.b);
	cairo_paint(cr);
	cairo_translate(cr, ox, oy);
	cairo_scale(cr, n, n);
	paint_scene(cr, 0);
	/* a wrong password: its step (0 … STEPS-1), the plate a pixel aside on the odd ones */
	int step = -1, dx = 0;
	if (l->wrong) {
		step = (int)((g_get_monotonic_time() - l->wrong) / STEP_US);
		if (step >= STEPS)
			step = -1;
		else
			dx = step == 0 || step == 2 ? 1 : step == 1 || step == 3 ? -1 : 0;
	}
	if (dx) {
		cairo_save(cr);
		cairo_arc(cr, S.cx + dx, S.cy, S.cr, 0, 2 * G_PI);
		cairo_clip(cr);
		paint_scene(cr, dx);
		cairo_restore(cr);
	}
	for (int i = 0; S.flame && i < S.nflames; i++) {
		int f = (frame + 3 * i) % S.frames;   /* (the two out of step) */
		cairo_set_source_surface(cr, S.flame, S.fx[i] - f * S.fw, S.fy[i]);
		cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_NEAREST);
		cairo_rectangle(cr, S.fx[i], S.fy[i], S.fw, S.fh);
		cairo_fill(cr);
	}
	GtkWidget *e = win->input_field;
	int len = e ? (int)gtk_entry_get_text_length(GTK_ENTRY(e)) : 0, shown = MIN(len, S.rn);
	GdkKeymap *km = gdk_keymap_get_for_display(gtk_widget_get_display(a));
	const ink *arms = gdk_keymap_get_caps_lock_state(km) ? &S.caps : &S.arms;
	if (step >= 0) {                      /* the tried ones scatter, dimming, then go */
		for (int i = 0; i < MIN(l->tried, S.rn); i++) {
			int vx = (int)((i * 7 + 3) % 5) - 2, vy = i % 2 ? -1 - (i % 3 > 0) : 1 + (i % 4 == 0);
			int x = S.rx + S.pitch * i + dx + vx * step, y = S.ry + vy * step;
			if (step < 2)
				mark(cr, x, y, arms, &S.core, &S.corner);
			else if (step < 4)
				mark(cr, x, y, &S.corner, arms, NULL);
		}
	} else {
		for (int i = 0; i < shown; i++)
			mark(cr, S.rx + S.pitch * i, S.ry, arms, &S.core, &S.corner);
	}
	if (caret_on && step < 0 && e && gtk_widget_has_focus(e) && gtk_widget_is_sensitive(e)) {
		cairo_set_source_rgb(cr, S.caret.r, S.caret.g, S.caret.b);
		cairo_rectangle(cr, S.rx + S.pitch * shown, S.ry - 2, 1, 5);
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
	caret_timer = g_timeout_add(500, caret_tick, NULL);
}

static gboolean wrong_tick(GtkWidget *a, GdkFrameClock *clock, gpointer data)
{
	struct look *l = data;
	(void)clock;
	redraw(a, S.cx - S.cr - 4, S.cy - S.cr - 4, 2 * S.cr + 8, 2 * S.cr + 8);
	if (g_get_monotonic_time() - l->wrong < STEPS * STEP_US)
		return G_SOURCE_CONTINUE;
	l->wrong = 0, l->tick = 0;
	return G_SOURCE_REMOVE;
}
static void on_changed(GtkEditable *e, gpointer data)
{
	(void)e;
	caret_restart();
	redraw_row(data);
}
static void on_state(GObject *o, GParamSpec *p, gpointer data)   /* focus or busy changed */
{
	(void)o, (void)p;
	redraw_row(data);
}
static void on_try(GtkEntry *e, gpointer data)   /* Enter: after gtklock's own handler */
{
	((struct look *)data)->tried = (int)gtk_entry_get_text_length(e);
}
static void on_error(GObject *o, GParamSpec *p, gpointer data)   /* gtklock's error line */
{
	struct look *l = data;
	const char *t = gtk_label_get_text(GTK_LABEL(o));
	(void)p;
	if (!t || !*t)
		return;
	l->wrong = g_get_monotonic_time();
	if (!l->tick)
		l->tick = gtk_widget_add_tick_callback(l->area, wrong_tick, l, NULL);
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
	if (!art || !*art || !scene_load(art))
		return;
	if (S.nflames)
		flame_timer = g_timeout_add(1000 / 8, flames_tick, NULL);
	caret_timer = g_timeout_add(500, caret_tick, NULL);
}

void on_window_create(struct GtkLock *gtklock, struct Window *win)
{
	(void)gtklock;
	/* every key and click passes here first (a window's handlers run before its own) */
	g_signal_connect(win->window, "key-press-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "key-release-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "button-press-event", G_CALLBACK(on_button), win);
	g_signal_connect(win->window, "button-release-event", G_CALLBACK(on_button), win);
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
	gtk_style_context_add_class(gtk_widget_get_style_context(win->window), "kawa");
	g_signal_connect(win->input_field, "changed", G_CALLBACK(on_changed), l);
	g_signal_connect(win->input_field, "notify::has-focus", G_CALLBACK(on_state), l);
	g_signal_connect(win->input_field, "notify::sensitive", G_CALLBACK(on_state), l);
	g_signal_connect_after(win->input_field, "activate", G_CALLBACK(on_try), l);
	if (win->error_label)
		g_signal_connect(win->error_label, "notify::label", G_CALLBACK(on_error), l);
	if (!looks)
		g_signal_connect(gdk_keymap_get_for_display(gtk_widget_get_display(win->window)),
				"state-changed", G_CALLBACK(on_caps), NULL);
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
	g_free(l);
	win->module_data[self_id] = NULL;
}
