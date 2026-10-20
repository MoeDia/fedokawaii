/*
 * kawa-lockmod — the lock screen's own part of gtklock (a gtklock 4 module; kawa-lock loads it
 * with -m ~/.local/lib/fedokawaii/kawa-lockmod.so). Two things, on every screen's panel:
 *
 *  The keys. Under the password's box, a rule and three keys — 眠 sleep · 再 restart ·
 *  電 power off — exactly as on the login screen (kawa-greet): the key fill in a 1 px edge
 *  frame, the words accent_text under the pointer, filled vermilion under the keyboard's
 *  focus (Tab); the look is current/gtklock.css (#rule, button). Sleep is `systemctl
 *  suspend` (swayidle's before-sleep darkens the screens; the lock is already up), restart
 *  and power off `systemctl reboot` and `systemctl poweroff` (Steam is closed properly by
 *  kawa-steam --guard, which logind tells first).
 *
 *  The flavour, as on the login screen (kawa-greet): AM/PM after the big time (gtklock draws
 *  "%I:%M" at 48 px: design-system §2's display size); after the date the weekday in kanji
 *  (火曜日, accent_text), at the heading's end a stamped seal 錠 (the lock; the login's is 門);
 *  under the time a line of the season and the hour — 秋の夜 · the moon, a seal on paper — its
 *  kanji in accent_text, its words muted (VERSES: the same sixteen in kawa-greet). Read again
 *  every half minute; the look is current/gtklock.css (#weekday, #stamp, #verse-kanji, #verse).
 *
 *  The wake guard. The key that wakes the computer, or lights the dark screens, only wakes:
 *  kawa-lock notes the screens in $XDG_RUNTIME_DIR/kawa-screens — "off" before they go dark,
 *  "on" once they are lit (its time: the moment) — and while they are dark, and for 2 s after
 *  they come back, every key and click here is swallowed: an Enter that woke the machine is
 *  never a wrong password. A stale "off" (a session that ended in the dark) holds only the
 *  first 2 s of keys after it was written. And an Enter in an empty box is never a try.
 *
 * Built by theme.sh (src/kawa-lockmod/Makefile) against GTK 3's headers.
 */
#define _GNU_SOURCE
#include <fcntl.h>
#include <limits.h>
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

static void clicked(GtkButton *b, gpointer verb)
{
	(void)b;
	if (guarded())
		return;
	gchar *argv[] = { "systemctl", verb, NULL };
	g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH | G_SPAWN_STDOUT_TO_DEV_NULL |
			G_SPAWN_STDERR_TO_DEV_NULL, NULL, NULL, NULL, NULL);
}

/* ── the flavour ──────────────────────────────────────────────────────────────────── */
static const char *weekdays[] = { "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日" };
/* VERSES: a season (spring Mar–May … winter Dec–Feb), an hour (morning 5–10, day 11–16,
 * evening 17–19, night) — the same in kawa-greet */
static const char *verses[4][4][2] = {
	{ { "春の朝", "spring morning, the first thread" }, { "春の昼", "plum blossom on the sleeve" },
	  { "春の夕", "the needle rests in silk" }, { "春の夜", "a lantern, a quiet stitch" } },
	{ { "夏の朝", "cool tatami, early light" }, { "夏の昼", "cicadas behind the screen" },
	  { "夏の夕", "a fan, the river breeze" }, { "夏の夜", "fireflies between the reeds" } },
	{ { "秋の朝", "frost on the bamboo fence" }, { "秋の昼", "red leaves on still water" },
	  { "秋の夕", "crows home, the sky in ink" }, { "秋の夜", "the moon, a seal on paper" } },
	{ { "冬の朝", "snow on the temple roof" }, { "冬の昼", "a kettle sings, a quiet room" },
	  { "冬の夕", "the lamp lit early" }, { "冬の夜", "the stove's last ember" } },
};
struct flavour { GtkWidget *weekday, *ampm, *kanji, *words; };
static GList *flavours;                   /* one per window */

static void flavour_set(struct flavour *f)
{
	GDateTime *now = g_date_time_new_now_local();
	int m = g_date_time_get_month(now), h = g_date_time_get_hour(now);
	int season = m >= 3 && m <= 5 ? 0 : m >= 6 && m <= 8 ? 1 : m >= 9 && m <= 11 ? 2 : 3;
	int hour = h >= 5 && h <= 10 ? 0 : h >= 11 && h <= 16 ? 1 : h >= 17 && h <= 19 ? 2 : 3;
	gtk_label_set_text(GTK_LABEL(f->weekday), weekdays[g_date_time_get_day_of_week(now) - 1]);
	gtk_label_set_text(GTK_LABEL(f->ampm), h < 12 ? "AM" : "PM");
	gtk_label_set_text(GTK_LABEL(f->kanji), verses[season][hour][0]);
	gtk_label_set_text(GTK_LABEL(f->words), verses[season][hour][1]);
	g_date_time_unref(now);
}
static gboolean flavour_tick(gpointer data)
{
	(void)data;
	for (GList *l = flavours; l; l = l->next)
		flavour_set(l->data);
	return G_SOURCE_CONTINUE;
}
/* the stitch drawn whole (design-system §4): 3 px on, 2 off, from its left edge, ending on the
 * last whole one that fits (up to 4 px short of its right edge — never a cut one there); 1 px
 * high through the widget's middle, in its CSS colour (edge2: gtklock.css's #stitch, #rule) */
static gboolean draw_stitch(GtkWidget *w, cairo_t *cr, gpointer data)
{
	GdkRGBA c;
	int width = gtk_widget_get_allocated_width(w), y = gtk_widget_get_allocated_height(w) / 2;

	(void)data;
	gtk_style_context_get_color(gtk_widget_get_style_context(w), gtk_widget_get_state_flags(w), &c);
	gdk_cairo_set_source_rgba(cr, &c);
	for (int x = 0; x + 3 <= width; x += 5)
		cairo_rectangle(cr, x, y, 3, 1);
	cairo_fill(cr);
	return FALSE;
}

static GtkWidget *named_label(const char *name)
{
	GtkWidget *l = gtk_label_new(NULL);
	gtk_widget_set_name(l, name);
	gtk_widget_set_valign(l, GTK_ALIGN_CENTER);
	return l;
}

void on_activation(struct GtkLock *gtklock, int id)
{
	(void)gtklock;
	self_id = id;
	g_timeout_add_seconds(30, flavour_tick, NULL);
	const char *run = g_getenv("XDG_RUNTIME_DIR");
	g_snprintf(screens, sizeof screens, "%s/kawa-screens", run && *run ? run : "/nonexistent");
}

void on_window_create(struct GtkLock *gtklock, struct Window *win)
{
	static const char *keys[][2] = {
		{ "眠 sleep", "suspend" }, { "再 restart", "reboot" }, { "電 power off", "poweroff" },
	};
	(void)gtklock;
	/* every key and click passes here first (a window's handlers run before its own) */
	g_signal_connect(win->window, "key-press-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "key-release-event", G_CALLBACK(on_key), win);
	g_signal_connect(win->window, "button-press-event", G_CALLBACK(on_button), win);
	g_signal_connect(win->window, "button-release-event", G_CALLBACK(on_button), win);
	if (!win->window_box || !GTK_IS_BOX(win->window_box))
		return;
	/* the heading: … the date, 火曜日, the stitch, the stamped seal 錠 */
	GtkWidget *heading = win->date_label ? gtk_widget_get_parent(win->date_label) : NULL;
	struct flavour *f = g_new0(struct flavour, 1);
	f->weekday = named_label("weekday");
	f->ampm = named_label("ampm");
	gtk_widget_set_valign(f->ampm, GTK_ALIGN_END);
	f->kanji = named_label("verse-kanji");
	f->words = named_label("verse");
	if (heading && GTK_IS_BOX(heading)) {
		gtk_box_pack_start(GTK_BOX(heading), f->weekday, FALSE, FALSE, 0);
		gtk_box_reorder_child(GTK_BOX(heading), f->weekday, 2);   /* (seal, date, here) */
		GtkWidget *stamp = named_label("stamp");
		gtk_label_set_text(GTK_LABEL(stamp), "錠");
		gtk_box_pack_end(GTK_BOX(heading), stamp, FALSE, FALSE, 0);
		gtk_widget_show(stamp);
		GList *kids = gtk_container_get_children(GTK_CONTAINER(heading));
		for (GList *k = kids; k; k = k->next)
			if (!g_strcmp0(gtk_widget_get_name(k->data), "stitch"))
				g_signal_connect(k->data, "draw", G_CALLBACK(draw_stitch), NULL);
		g_list_free(kids);
	}
	/* AM/PM after the big time, on its baseline (the face: padlock, time-box, here) */
	GtkWidget *face = win->time_box ? gtk_widget_get_parent(win->time_box) : NULL;
	if (face && GTK_IS_BOX(face)) {
		gtk_box_pack_start(GTK_BOX(face), f->ampm, FALSE, FALSE, 0);
		gtk_widget_show(f->ampm);
	}
	/* under the face: the season and the hour */
	if (win->info_box && GTK_IS_BOX(win->info_box)) {
		GtkWidget *line = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
		gtk_widget_set_name(line, "verse-line");
		gtk_widget_set_halign(line, GTK_ALIGN_CENTER);
		gtk_box_pack_start(GTK_BOX(line), f->kanji, FALSE, FALSE, 0);
		gtk_box_pack_start(GTK_BOX(line), f->words, FALSE, FALSE, 0);
		gtk_box_pack_start(GTK_BOX(win->info_box), line, FALSE, FALSE, 0);
		gtk_widget_show_all(line);
	}
	gtk_widget_show(f->weekday);
	flavour_set(f);
	win->module_data[self_id] = f;
	flavours = g_list_prepend(flavours, f);
	GtkWidget *rule = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
	gtk_widget_set_name(rule, "rule");
	g_signal_connect(rule, "draw", G_CALLBACK(draw_stitch), NULL);
	gtk_box_pack_start(GTK_BOX(win->window_box), rule, FALSE, FALSE, 0);
	GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
	gtk_box_set_homogeneous(GTK_BOX(row), TRUE);
	gtk_widget_set_name(row, "keys");
	for (size_t i = 0; i < G_N_ELEMENTS(keys); i++) {
		GtkWidget *b = gtk_button_new_with_label(keys[i][0]);
		gtk_widget_set_hexpand(b, TRUE);
		gtk_widget_set_focus_on_click(b, FALSE);   /* a click leaves the box its focus */
		g_signal_connect(b, "clicked", G_CALLBACK(clicked), (gpointer)keys[i][1]);
		gtk_box_pack_start(GTK_BOX(row), b, TRUE, TRUE, 0);
	}
	gtk_box_pack_start(GTK_BOX(win->window_box), row, FALSE, FALSE, 0);
	gtk_widget_show_all(rule);
	gtk_widget_show_all(row);
}

void on_window_destroy(struct GtkLock *gtklock, struct Window *win)
{
	(void)gtklock;
	struct flavour *f = win->module_data[self_id];
	if (f) {
		flavours = g_list_remove(flavours, f);
		g_free(f);
		win->module_data[self_id] = NULL;
	}
}
