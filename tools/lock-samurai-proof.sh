#!/usr/bin/env bash
# tools/lock-samurai-proof.sh MOOD MAP — the lock's samurai in the real gtklock and the real module, in a
# headless dwl fenced off the session (own runtime dir and home, no D-Bus, its own Wayland): types, deletes, a
# wrong try, the right one. Test-only and nowhere in the install: a PAM stand-in (fake words, no real password
# is ever near it) and a second module for Enter and BackSpace (wtype's never reach GTK 3's key bindings). Every recorded frame
# is then matched against lock-samurai.png over the map: the sequence with its times, every pixel outside his
# cell and the marks' row compared with the map, the fake words looked for in everything the run wrote.
#   bash tools/lock-samurai-proof.sh dark shiro     → /dev/shm/r28/l3/dark/: report.txt, sheet.png
set -eu
mood=$1 map=$2
repo=$(cd "$(dirname "$0")/.." && pwd)
art=$repo/configs/home/.local/share/fedokawaii/$mood
W=/dev/shm/r28/l3/$mood
rm -rf "$W"
mkdir -p "$W/run" "$W/home" "$W/art" "$W/bin" "$W/mod" "$W/frames"
chmod 700 "$W/run"

cp "$art/lock-samurai.png" "$art/lock-samurai.txt" "$W/art/"
cp "$art/lock-map-$map.png" "$W/art/lock-scene.png"
python3 -B -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[1])' "$W/art/lock-scene.png"
cat >"$W/art/lock-scene.txt" <<'SCENE_EOF'
size 640 360
ground 000000
markscale 1
row 276 243 8 12
mark f8b25c f5ecc2 82241f
caps 82c1b4
caret f8b25c
plate 320 243 0
words 340 356
samurai 284 254
SCENE_EOF
: >"$W/gtklock.css"

make -s -C "$repo/src/kawa-lockmod" O="$W/mod" CFLAGS="-O2 -pipe"
cat >"$W/mod/pam.c" <<'PAM_EOF'
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
/* (PAM's ABI as _pam_types.h and pam_appl.h give it: no pam-devel on this PC) */
enum { PAM_SUCCESS = 0, PAM_AUTH_ERR = 7, PAM_PROMPT_ECHO_OFF = 1 };
typedef struct pam_handle pam_handle_t;
struct pam_message { int msg_style; const char *msg; };
struct pam_response { char *resp; int resp_retcode; };
struct pam_conv { int (*conv)(int, const struct pam_message **, struct pam_response **, void *); void *appdata_ptr; };
static struct pam_conv c;
int pam_start(const char *s, const char *u, const struct pam_conv *conv, pam_handle_t **h) { (void)s, (void)u; c = *conv; *h = (pam_handle_t *)&c; return PAM_SUCCESS; }
int pam_authenticate(pam_handle_t *h, int f) {
	struct pam_message m = { PAM_PROMPT_ECHO_OFF, "word" }; const struct pam_message *mp = &m; struct pam_response *r = NULL;
	(void)h, (void)f;
	c.conv(1, &mp, &r, c.appdata_ptr);
	int ok = r && r->resp && !strcmp(r->resp, "rightword");
	usleep(ok ? 20000 : 300000);
	return ok ? PAM_SUCCESS : PAM_AUTH_ERR;
}
int pam_setcred(pam_handle_t *h, int f) { (void)h, (void)f; return PAM_SUCCESS; }
int pam_end(pam_handle_t *h, int s) { (void)h, (void)s; return PAM_SUCCESS; }
PAM_EOF
gcc -O1 -shared -fPIC -o "$W/mod/pam.so" "$W/mod/pam.c"
cat >"$W/mod/enter.c" <<'ENTER_EOF'
#include <gtk/gtk.h>
struct Window { GdkMonitor *monitor; GtkWidget *window, *overlay, *window_box, *body_revealer, *body_grid, *input_label, *input_field; };
const gchar module_name[] = "enter";
const guint module_major_version = 4, module_minor_version = 0;
static gboolean on_key(GtkWidget *w, GdkEventKey *ev, gpointer data) {
	GtkWidget *e = ((struct Window *)data)->input_field;
	(void)w;
	int n = gtk_entry_get_text_length(GTK_ENTRY(e));
	if (ev->keyval == GDK_KEY_Return && n) { gtk_widget_activate(e); return TRUE; }
	if (ev->keyval == GDK_KEY_BackSpace && n) { gtk_editable_delete_text(GTK_EDITABLE(e), n - 1, n); return TRUE; }
	return FALSE;
}
void on_window_create(void *g, struct Window *win) { (void)g; g_signal_connect(win->window, "key-press-event", G_CALLBACK(on_key), win); }
ENTER_EOF
# shellcheck disable=SC2046
gcc -O1 -shared -fPIC -o "$W/mod/enter.so" "$W/mod/enter.c" $(pkg-config --cflags --libs gtk+-3.0)

# (the 5 s dark: only asked for, nothing to answer it here)
printf '#!/bin/sh\nexit 0\n' >"$W/bin/kawa-lock"
chmod +x "$W/bin/kawa-lock"

cat >"$W/play.sh" <<'PLAY_EOF'
#!/bin/bash
W=$1 repo=$2
wlr-randr --output HEADLESS-1 --custom-mode 1920x1080@144Hz
LD_PRELOAD=$W/mod/pam.so LANGUAGE=fk KAWA_LOCK_ART=$W/art gtklock -s "$W/gtklock.css" -x "$repo/configs/home/.config/fedokawaii/lock.ui" \
  -m "$W/mod/kawa-lockmod" -m "$W/mod/enter.so" >"$W/gtklock.log" 2>&1 &
g=$!
sleep 1.5
wf-recorder -y -o HEADLESS-1 -c libx264rgb -p crf=0 -p preset=ultrafast -f "$W/rec.mkv" >"$W/rec.log" 2>&1 &
r=$!
sleep 3
wtype -s 1000 -d 160 -- "abcdef"; sleep .6
wtype -k BackSpace; sleep .3; wtype -k BackSpace; sleep .5
wtype -d 110 -- "gh"; sleep .3
wtype -k Return; sleep 2
wtype -d 160 -- "rightword"; sleep .4
wtype -k Return
wait "$g"; echo "gtklock rc $?" >"$W/rc"
sleep .5
kill -INT "$r"; wait "$r"
PLAY_EOF

set +e
env -i HOME="$W/home" USER="$USER" LOGNAME="$USER" PATH="$W/bin:/usr/local/bin:/usr/bin" XDG_RUNTIME_DIR="$W/run" \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent WLR_BACKENDS=headless WLR_RENDERER=gles2 WLR_LIBINPUT_NO_DEVICES=1 \
  WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 XDG_CONFIG_HOME="$W/home/.config" \
  timeout -k 3 60 dwl -s "bash $W/play.sh $W $repo; touch $W/done" >"$W/dwl.log" 2>&1 &
d=$!
until [[ -e $W/done ]] || ! kill -0 "$d" 2>/dev/null; do sleep .2; done
kill "$d" 2>/dev/null
wait "$d"
set -e
cat "$W/rc"
ffmpeg -nostdin -loglevel error -i "$W/rec.mkv" -fps_mode passthrough "$W/frames/%05d.png"
ffprobe -loglevel error -select_streams v -show_entries packet=pts_time -of csv=p=0 "$W/rec.mkv" | tr -d , >"$W/times.txt"
python3 -B "$repo/tools/lock-samurai-proof.py" "$W"
