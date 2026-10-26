/* tools/xconf.c — an X11 window for tools/hotplug-test.sh (built there: cc xconf.c -lxcb).
 *   xconf [NAME]     a 300×200 window titled NAME (default "xconf"), then on a signal:
 *     SIGUSR1  40 configure requests for new sizes (the request dwl crashed on, 26 Oct 12:22,
 *              while no monitor was there)
 *     SIGHUP   a request to move to x 300, y 200 (taken when it floats)
 *     SIGUSR2  prints "geom X Y W H" — where it is on the screen (root coordinates)
 * Prints "mapped 0x…" first, "sent N" per burst; exits 2 when the X server is gone (its
 * compositor died with it), 1 when there is no X display to open */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <xcb/xcb.h>

static volatile sig_atomic_t burst, move, tell;

static void
onsig(int sig)
{
	if (sig == SIGUSR1)
		burst = 1;
	else if (sig == SIGHUP)
		move = 1;
	else if (sig == SIGUSR2)
		tell = 1;
}

int
main(int argc, char *argv[])
{
	const char *name = argc > 1 ? argv[1] : "xconf";
	xcb_connection_t *c = xcb_connect(NULL, NULL);
	xcb_screen_t *s;
	xcb_window_t w;
	uint32_t bg, size[2], pos[2] = { 300, 200 };
	struct timespec tick = { 0, 50 * 1000 * 1000 };
	int i, sent = 0;

	if (xcb_connection_has_error(c)) {
		fprintf(stderr, "xconf: no X display to open\n");
		return 1;
	}
	s = xcb_setup_roots_iterator(xcb_get_setup(c)).data;
	w = xcb_generate_id(c);
	bg = s->white_pixel;
	xcb_create_window(c, XCB_COPY_FROM_PARENT, w, s->root, 0, 0, 300, 200, 0,
			XCB_WINDOW_CLASS_INPUT_OUTPUT, s->root_visual, XCB_CW_BACK_PIXEL, &bg);
	xcb_change_property(c, XCB_PROP_MODE_REPLACE, w, XCB_ATOM_WM_NAME, XCB_ATOM_STRING, 8,
			strlen(name), name);
	xcb_map_window(c, w);
	xcb_flush(c);
	signal(SIGUSR1, onsig);
	signal(SIGUSR2, onsig);
	signal(SIGHUP, onsig);
	printf("mapped 0x%x\n", w);
	fflush(stdout);
	for (;;) {
		nanosleep(&tick, NULL);
		if (burst) {
			burst = 0;
			for (i = 0; i < 40; i++) {
				size[0] = 300 + (uint32_t)(i % 8) * 10;
				size[1] = 200 + (uint32_t)(i % 5) * 10;
				xcb_configure_window(c, w, XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, size);
			}
			sent += 40;
			printf("sent %d\n", sent);
			fflush(stdout);
		}
		if (move) {
			move = 0;
			xcb_configure_window(c, w, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y, pos);
		}
		if (tell) {
			xcb_get_geometry_reply_t *g;
			xcb_translate_coordinates_reply_t *t;
			tell = 0;
			g = xcb_get_geometry_reply(c, xcb_get_geometry(c, w), NULL);
			t = xcb_translate_coordinates_reply(c,
					xcb_translate_coordinates(c, w, s->root, 0, 0), NULL);
			if (g && t)
				printf("geom %d %d %u %u\n", t->dst_x, t->dst_y, g->width, g->height);
			fflush(stdout);
			free(g);
			free(t);
		}
		/* (a round trip each tick: a dead server shows at once, not at the next request) */
		free(xcb_get_input_focus_reply(c, xcb_get_input_focus(c), NULL));
		if (xcb_connection_has_error(c))
			return 2;
	}
}
