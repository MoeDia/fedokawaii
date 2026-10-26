/* tools/xconf.c — an X11 window that asks the window manager for a new size, a burst at a
 * time: on SIGUSR1, 40 configure requests (the request dwl crashed on, 26 Oct 12:22, while no
 * monitor was there). Used by tools/hotplug-test.sh; built there with `cc tools/xconf.c -lxcb`.
 * Prints "mapped", then "sent N" per burst; exits 2 when the X server is gone (its compositor
 * died with it), 1 when there is no X display to open */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <xcb/xcb.h>

static volatile sig_atomic_t burst;

static void
onusr1(int sig)
{
	(void)sig;
	burst = 1;
}

int
main(void)
{
	xcb_connection_t *c = xcb_connect(NULL, NULL);
	xcb_screen_t *s;
	xcb_window_t w;
	uint32_t bg, size[2];
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
	xcb_map_window(c, w);
	xcb_flush(c);
	signal(SIGUSR1, onusr1);
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
		/* (a round trip each tick: a dead server shows at once, not at the next request) */
		free(xcb_get_input_focus_reply(c, xcb_get_input_focus(c), NULL));
		if (xcb_connection_has_error(c))
			return 2;
	}
}
