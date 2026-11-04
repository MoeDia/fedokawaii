#!/usr/bin/env python3
"""tools/fake-tablet.py DWL.C — for tools/regress/sketch-pen.sh: a copy of dwl.c given a tablet of nothing,
fed through the FIFO named by $FAKE_TABLET: "i X Y" the pen near, "m X Y P" moved (pressure 0..1), "d" and "u"
the tip, "b CODE 1|0" a side button (331 BTN_STYLUS, 332 BTN_STYLUS2), "o" gone. Only ever for a private build under a headless run: the session's dwl never has it."""
import sys
p = sys.argv[1]
s = open(p).read()
code = r'''
/* ── test only: a tablet of nothing, fed through the FIFO in $FAKE_TABLET ── */
#include <wlr/interfaces/wlr_tablet_tool.h>
static struct wlr_tablet fake_tab;
static struct wlr_tablet_tool fake_tool;
static double fake_x, fake_y, fake_p;
static FILE *fake_f;
static uint32_t fake_ms(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1000 + t.tv_nsec / 1000000; }
static const struct wlr_tablet_impl fake_impl = { .name = "fake-tablet" };
static int
fake_read(int fd, uint32_t mask, void *d)
{
	char l[128];
	double x, y, p;
	while (fgets(l, sizeof l, fake_f)) {
		if (sscanf(l, "m %lf %lf %lf", &x, &y, &p) == 3) {
			struct wlr_tablet_tool_axis_event e = { .tablet = &fake_tab, .tool = &fake_tool, .time_msec = fake_ms(),
				.updated_axes = WLR_TABLET_TOOL_AXIS_X | WLR_TABLET_TOOL_AXIS_Y | WLR_TABLET_TOOL_AXIS_PRESSURE,
				.x = x / 1920.0, .y = y / 1080.0, .dx = (x - fake_x) / 1920.0, .dy = (y - fake_y) / 1080.0, .pressure = p };
			fake_x = x; fake_y = y; fake_p = p;
			wl_signal_emit_mutable(&fake_tab.events.axis, &e);
		} else if (sscanf(l, "i %lf %lf", &x, &y) == 2) {
			struct wlr_tablet_tool_proximity_event e = { .tablet = &fake_tab, .tool = &fake_tool, .time_msec = fake_ms(),
				.x = x / 1920.0, .y = y / 1080.0, .state = WLR_TABLET_TOOL_PROXIMITY_IN };
			fake_x = x; fake_y = y;
			wl_signal_emit_mutable(&fake_tab.events.proximity, &e);
		} else if (l[0] == 'o') {
			struct wlr_tablet_tool_proximity_event e = { .tablet = &fake_tab, .tool = &fake_tool, .time_msec = fake_ms(),
				.x = fake_x / 1920.0, .y = fake_y / 1080.0, .state = WLR_TABLET_TOOL_PROXIMITY_OUT };
			wl_signal_emit_mutable(&fake_tab.events.proximity, &e);
		} else if (sscanf(l, "b %lf %lf", &x, &y) == 2) {
			struct wlr_tablet_tool_button_event e = { .tablet = &fake_tab, .tool = &fake_tool, .time_msec = fake_ms(),
				.button = (uint32_t)x, .state = y > 0 ? WLR_BUTTON_PRESSED : WLR_BUTTON_RELEASED };
			wl_signal_emit_mutable(&fake_tab.events.button, &e);
		} else if (l[0] == 'd' || l[0] == 'u') {
			struct wlr_tablet_tool_tip_event e = { .tablet = &fake_tab, .tool = &fake_tool, .time_msec = fake_ms(),
				.x = fake_x / 1920.0, .y = fake_y / 1080.0, .state = l[0] == 'd' ? WLR_TABLET_TOOL_TIP_DOWN : WLR_TABLET_TOOL_TIP_UP };
			wl_signal_emit_mutable(&fake_tab.events.tip, &e);
		}
		break; /* one line a wakeup: the loop comes back while there is more */
	}
	if (feof(fake_f))
		clearerr(fake_f);
	return 0;
}
static void
fake_init(void)
{
	const char *path = getenv("FAKE_TABLET");
	if (!path)
		return;
	wlr_tablet_init(&fake_tab, &fake_impl, "fake-tablet");
	fake_tab.width_mm = 160; fake_tab.height_mm = 90;
	memset(&fake_tool, 0, sizeof fake_tool);
	fake_tool.type = WLR_TABLET_TOOL_TYPE_PEN;
	fake_tool.hardware_serial = 1; fake_tool.pressure = true;
	wl_signal_init(&fake_tool.events.destroy);
	inputdevice(NULL, &fake_tab.base);
	int fd = open(path, O_RDWR | O_NONBLOCK);
	fake_f = fdopen(fd, "r");
	setvbuf(fake_f, NULL, _IOLBF, 0);
	wl_event_loop_add_fd(wl_display_get_event_loop(dpy), fd, WL_EVENT_READABLE, fake_read, NULL);
}
'''
# the functions come before setup(); declare what they use late
marker = "\nvoid\nsetup(void)\n"
assert marker in s
s = s.replace(marker, code + marker, 1)
assert "\tsetup();\n" in s
s = s.replace("\tsetup();\n", "\tsetup();\n\tfake_init();\n", 1)
open(p, 'w').write(s)
print("patched")
