// tools/vpointer.c — a virtual pointer that scrolls as a real device does under wlroots
// (zwlr_virtual_pointer_v1, tools/protocols/wlr-virtual-pointer-unstable-v1.xml — wlr-protocols, MIT):
//   vpointer wheel N     N notches of a mouse wheel (N < 0: up): per notch axis_source(wheel),
//                        axis_discrete(15 px, 1 step), frame — what libinput + wlroots send for a mouse
//   vpointer finger DY   a touchpad's part: axis_source(finger), axis(DY), frame, then a stop frame
//   vpointer move X Y    the pointer to X Y (absolute, on a 1920x1080 extent)
// wlrctl's scroll is a touchpad's smooth parts only: this is how a test sends a real wheel notch
// (the master's T23 review 4 wrote it). Only for a headless dwl (tools/hl-dwl.sh, tools/kit.sh).
// Build: wayland-scanner client-header tools/protocols/wlr-virtual-pointer-unstable-v1.xml vp-protocol.h
//        wayland-scanner private-code  tools/protocols/wlr-virtual-pointer-unstable-v1.xml vp-protocol.c
//        cc -O2 -o vpointer tools/vpointer.c vp-protocol.c -I. $(pkg-config --cflags --libs wayland-client)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include "vp-protocol.h"

static struct zwlr_virtual_pointer_manager_v1 *mgr;
static struct wl_seat *seat;

static uint32_t now_ms(void) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint32_t)(ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}
static void global_add(void *d, struct wl_registry *r, uint32_t id, const char *iface, uint32_t ver) {
    (void)d;
    if (!strcmp(iface, zwlr_virtual_pointer_manager_v1_interface.name))
        mgr = wl_registry_bind(r, id, &zwlr_virtual_pointer_manager_v1_interface, 1);
    else if (!strcmp(iface, wl_seat_interface.name) && !seat)
        seat = wl_registry_bind(r, id, &wl_seat_interface, ver < 5 ? ver : 5);
}
static void global_rm(void *d, struct wl_registry *r, uint32_t id) { (void)d; (void)r; (void)id; }
static const struct wl_registry_listener reg = { global_add, global_rm };

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "vp wheel N | finger DY | move X Y\n"); return 2; }
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fprintf(stderr, "vp: no display\n"); return 1; }
    struct wl_registry *r = wl_display_get_registry(dpy);
    wl_registry_add_listener(r, &reg, NULL);
    wl_display_roundtrip(dpy);
    if (!mgr) { fprintf(stderr, "vp: no virtual pointer manager\n"); return 1; }
    struct zwlr_virtual_pointer_v1 *p = zwlr_virtual_pointer_manager_v1_create_virtual_pointer(mgr, seat);
    wl_display_roundtrip(dpy);
    if (!strcmp(argv[1], "wheel")) {
        int n = atoi(argv[2]), up = n < 0; if (up) n = -n;
        for (int i = 0; i < n; i++) {
            zwlr_virtual_pointer_v1_axis_source(p, WL_POINTER_AXIS_SOURCE_WHEEL);
            zwlr_virtual_pointer_v1_axis_discrete(p, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL,
                                                  wl_fixed_from_double(up ? -15.0 : 15.0), up ? -1 : 1);
            zwlr_virtual_pointer_v1_frame(p);
            wl_display_flush(dpy);
            if (i + 1 < n) usleep(120000);
        }
    } else if (!strcmp(argv[1], "finger")) {
        double dy = atof(argv[2]);
        zwlr_virtual_pointer_v1_axis_source(p, WL_POINTER_AXIS_SOURCE_FINGER);
        zwlr_virtual_pointer_v1_axis(p, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(dy));
        zwlr_virtual_pointer_v1_frame(p);
        wl_display_flush(dpy);
        usleep(20000);
        zwlr_virtual_pointer_v1_axis_source(p, WL_POINTER_AXIS_SOURCE_FINGER);
        zwlr_virtual_pointer_v1_axis_stop(p, now_ms(), WL_POINTER_AXIS_VERTICAL_SCROLL);
        zwlr_virtual_pointer_v1_frame(p);
    } else if (!strcmp(argv[1], "move") && argc >= 4) {
        zwlr_virtual_pointer_v1_motion_absolute(p, now_ms(), atoi(argv[2]), atoi(argv[3]), 1920, 1080);
        zwlr_virtual_pointer_v1_frame(p);
    } else { fprintf(stderr, "vp: bad use\n"); return 2; }
    wl_display_roundtrip(dpy);
    zwlr_virtual_pointer_v1_destroy(p);
    wl_display_roundtrip(dpy);
    wl_display_disconnect(dpy);
    return 0;
}
