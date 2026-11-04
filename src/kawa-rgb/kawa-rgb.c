/*
 * kawa-rgb — every light in the PC breathes one ember, in the desktop's red.
 *
 * The lights speak three small protocols (the keyboard's has no other driver), so this is one
 * program with no libraries and no scanner: the motherboard's Mystic Light and the Redragon
 * K617 over hidraw feature reports, the Gigabyte card's logo over its I2C bus. Every device
 * gets the same level in the same tick, 8 times a second, so they are truly in phase: a
 * breath, not a sine (it rises faster than it falls), and redder as it dims, as an ember does.
 *
 *   kawa-rgb run [--trace FILE]   the service (kawa-rgb.service, as root without capabilities)
 *   kawa-rgb baseline             the hardware's own memory, once per change: red and breathing
 *                                 from power-on, before this program runs (read back first,
 *                                 written only when it differs: it wears flash)
 *   kawa-rgb status               what the service has found, from /run/kawa-rgb/status
 *
 * It asks nobody and nobody tells it anything: the mood from the file kawa-theme keeps for the
 * login screen, the screens from DRM. Screens off: the fire is banked, the floor held, nothing
 * sent. While the K617 is typed on it holds its breath (a report goes through the same small
 * controller that scans the keys) and comes back to the others afterwards; it never reads keys.
 * A device that fails is closed and looked for again, so a replug and a resume just work.
 *
 * The cooler's display (1a2c:4184, the "SEMICO keyboard", no keys of its own) shows the CPU's
 * temperature: the report its vendor's software sends (07 ff ff, then the digits).
 *
 * Protocol facts, none of their code: OpenRGB (the MSI and Gigabyte controllers), fizzctl (K617),
 * JL DGT 1.0.0 (the display). KAWA_RGB_ROOT prefixes every path, and regular files take the
 * writes there: tests/status/test_rgb.sh runs all of it against a made-up machine.
 * Built by theme.sh (src/kawa-rgb/Makefile), installed as /usr/local/bin/kawa-rgb.
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/hidraw.h>
#include <linux/i2c-dev.h>
#include <linux/i2c.h>
#include <math.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define TICK_NS 125000000L          /* 8 Hz: under the card's mode register's 9 updates a second */
#define TICKS_S 8
#define RESCAN_TICKS (2 * TICKS_S)  /* a missing device looked for */
#define HOLD_TICKS (2 * TICKS_S)    /* the K617 after its last key report */
#define FADE_TICKS 10               /* a mood's colours into the other's: the ink wash's 1.2 s */

/* ── the machine's paths ─────────────────────────────────────────────────────────── */
static const char *root = "";
static char *at(const char *fmt, ...)
{
    static char buf[4][512];
    static int i;
    char *b = buf[i = (i + 1) % 4], tail[448];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(tail, sizeof tail, fmt, ap);
    va_end(ap);
    snprintf(b, sizeof buf[0], "%s%s", root, tail);
    return b;
}
static const char *CONF = "/etc/fedokawaii/rgb.conf";
static const char *MOOD = "/var/lib/fedokawaii-greeter/theme";
static const char *STATUS = "/run/kawa-rgb/status";
static const char *BASE_MARK = "/var/lib/fedokawaii/rgb-baseline";

static int slurp(const char *path, char *out, size_t n)
{
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0)
        return -1;
    ssize_t r = read(fd, out, n - 1);
    close(fd);
    if (r < 0)
        return -1;
    out[r] = 0;
    return (int)r;
}

/* ── the moods (rgb.conf: NAME HEX FLOOR% PEAK% RISE_S FALL_S) ───────────────────── */
struct mood {
    double rgb[3];          /* the accent in linear light: LEDs are linear, the palette is sRGB */
    double floor, peak;
    double rise, fall;
};
static struct mood moods[2];
static bool mood_read(const char *line, struct mood *m)
{
    unsigned v;
    double fl, pk, rise, fall;
    if (sscanf(line, "%*s %6x %lf %lf %lf %lf", &v, &fl, &pk, &rise, &fall) != 5)
        return false;
    for (int i = 0; i < 3; i++)
        m->rgb[i] = 255.0 * pow(((v >> (16 - 8 * i)) & 255) / 255.0, 2.2);
    m->floor = fl / 100;
    m->peak = pk / 100;
    m->rise = rise;
    m->fall = fall;
    return rise > 0 && fall > 0 && fl >= 0 && pk <= 100 && fl <= pk;
}
static void conf_load(void)
{
    char buf[1024], *line, *save;
    if (slurp(at("%s", CONF), buf, sizeof buf) < 0) {
        fprintf(stderr, "kawa-rgb: cannot read %s: %s\n", CONF, strerror(errno));
        exit(1);
    }
    int seen = 0;
    for (line = strtok_r(buf, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        if (!strncmp(line, "dark ", 5) && mood_read(line, &moods[0]))
            seen |= 1;
        else if (!strncmp(line, "light ", 6) && mood_read(line, &moods[1]))
            seen |= 2;
    }
    if (seen != 3) {
        fprintf(stderr, "kawa-rgb: %s needs a dark and a light line: NAME HEX FLOOR%% PEAK%% RISE_S FALL_S\n", CONF);
        exit(1);
    }
}
static int mood_now(int was)
{
    char buf[16];
    if (slurp(at("%s", MOOD), buf, sizeof buf) < 0)
        return was;
    return !strncmp(buf, "light", 5);
}

/* ── the transports: real ioctls, or plain writes into a test's files ────────────── */
static bool regular(int fd)
{
    struct stat st;
    return fstat(fd, &st) == 0 && S_ISREG(st.st_mode);
}
static int appended(int fd, const uint8_t *buf, size_t n)
{
    lseek(fd, 0, SEEK_END);
    return write(fd, buf, n) == (ssize_t)n ? 0 : -1;
}
static int feature_set(int fd, const uint8_t *buf, size_t n)
{
    if (regular(fd))
        return appended(fd, buf, n);
    uint8_t tmp[1100];
    memcpy(tmp, buf, n);
    return ioctl(fd, HIDIOCSFEATURE(n), tmp) < 0 ? -1 : 0;
}
static int feature_get(int fd, uint8_t rid, uint8_t *buf, size_t n)
{
    memset(buf, 0, n);
    buf[0] = rid;
    if (regular(fd))
        return pread(fd, buf, n, 0) > 0 ? (int)n : -1;
    return ioctl(fd, HIDIOCGFEATURE(n), buf);
}
static int report_out(int fd, const uint8_t *buf, size_t n)
{
    if (regular(fd))
        return appended(fd, buf, n);
    return write(fd, buf, n) == (ssize_t)n ? 0 : -1;
}
static int i2c_xfer(int fd, uint16_t addr, uint16_t flags, uint8_t *buf, uint16_t n)
{
    if (regular(fd))
        return flags & I2C_M_RD ? (memcpy(buf, "\x01\x01\x01\x01", n < 4 ? n : 4), 0) : appended(fd, buf, n);
    struct i2c_msg msg = {.addr = addr, .flags = flags, .len = n, .buf = buf};
    struct i2c_rdwr_ioctl_data rd = {.msgs = &msg, .nmsgs = 1};
    return ioctl(fd, I2C_RDWR, &rd) < 0 ? -1 : 0;
}

/* a hidraw node by its USB ids and interface: /dev/hidrawN, and its name in *found */
static int hidraw_find(unsigned vid, unsigned pid, int iface, char *found, size_t n)
{
    char want[32], tail[16], buf[512];
    snprintf(want, sizeof want, "0003:%08X:%08X", vid, pid);
    snprintf(tail, sizeof tail, "input%d\n", iface);
    DIR *d = opendir(at("/sys/class/hidraw"));
    if (!d)
        return -1;
    int fd = -1;
    for (struct dirent *e; fd < 0 && (e = readdir(d));) {
        if (strncmp(e->d_name, "hidraw", 6))
            continue;
        if (slurp(at("/sys/class/hidraw/%s/device/uevent", e->d_name), buf, sizeof buf) < 0 || !strstr(buf, want))
            continue;
        char *phys = strstr(buf, "HID_PHYS=");
        char *end = phys ? strchr(phys, '\n') : NULL;
        if (!end || (size_t)(end + 1 - phys) < strlen(tail) || strncmp(end + 1 - strlen(tail), tail, strlen(tail)))
            continue;
        fd = open(at("/dev/%s", e->d_name), O_RDWR | O_CLOEXEC | O_NONBLOCK);
        if (fd >= 0)
            snprintf(found, n, "%.31s", e->d_name);
    }
    closedir(d);
    return fd;
}

/* ── the lights ──────────────────────────────────────────────────────────────────── */
struct light {
    const char *name;
    int fd;
    bool dirty;             /* its state may be lost: sent again, even if unchanged */
    int sent[3];            /* the last colour it took */
    double level;           /* where its breath is: follows the one breath, at a limited speed */
    int (*open)(struct light *);
    int (*send)(struct light *, const uint8_t rgb[3]);
    /* the K617's typing watch */
    int urbs;               /* fd of its USB device's urbnum */
    unsigned long seen;     /* urbnum at the last look */
    int hold;               /* ticks left of holding its breath */
    unsigned own;           /* URBs of our own since the last look */
    uint8_t tmpl[185];      /* the motherboard's packet as it came */
};

/* Mystic Light, 185-byte feature report 0x52, zone-based on this board: one colour per zone, so
 * a chain of any length on JARGB_V2 takes the one colour. Never save_data here: it would wear
 * flash at 8 Hz. The real headers are JRGB1 and JARGB_V2_1 (rainbow 1); the others (the same
 * packet's phantom zones) take the same colour, harmless */
static const uint8_t MSI_ZONES[] = {1, 11, 21, 31, 42, 74, 174};
static int msi_open(struct light *l)
{
    char name[32];
    l->fd = hidraw_find(0x0DB0, 0x0076, 0, name, sizeof name);
    if (l->fd < 0)
        return -1;
    if (feature_get(l->fd, 0x52, l->tmpl, sizeof l->tmpl) != (int)sizeof l->tmpl) {
        close(l->fd);
        l->fd = -1;
        return -1;
    }
    return 0;
}
static void msi_zones(uint8_t *p, const uint8_t rgb[3], uint8_t effect, uint8_t bright, uint8_t speed)
{
    for (size_t i = 0; i < sizeof MSI_ZONES; i++) {
        uint8_t *z = p + MSI_ZONES[i];
        z[0] = effect;
        memcpy(z + 1, rgb, 3);
        z[4] = (uint8_t)(bright << 2 | speed);
        memcpy(z + 5, rgb, 3);
        z[8] = 0x80;        /* the custom colour */
    }
}
static int msi_send(struct light *l, const uint8_t rgb[3])
{
    uint8_t p[185];
    memcpy(p, l->tmpl, sizeof p);
    msi_zones(p, rgb, 1, 10, 0);
    p[184] = 0;
    return feature_set(l->fd, p, sizeof p);
}

/* The K617 Fizz, live frame: 382-byte feature report, 96 RGB triplets, volatile. Interface 1 also
 * carries a keyboard report, which nothing here reads (the fd is only ever ioctl'd); whether it
 * is being typed on comes from its USB device's URB count, which says nothing of what */
static int k617_open(struct light *l)
{
    char name[32];
    l->fd = hidraw_find(0x258A, 0x0049, 1, name, sizeof name);
    if (l->fd < 0)
        return -1;
    l->urbs = open(at("/sys/class/hidraw/%s/device/../../urbnum", name), O_RDONLY | O_CLOEXEC);
    l->own = 0;
    l->seen = 0;
    return 0;
}
static int k617_send(struct light *l, const uint8_t rgb[3])
{
    uint8_t f[382];
    memset(f, 0, sizeof f);
    f[0] = 0x08; f[1] = 0x0a; f[2] = 0x7a; f[3] = 0x01;
    for (int i = 0; i < 96; i++)
        memcpy(f + 4 + i * 3, rgb, 3);
    l->own++;
    return feature_set(l->fd, f, sizeof f);
}
static bool k617_typing(struct light *l)
{
    char buf[32];
    if (l->urbs < 0)
        return false;
    ssize_t r = pread(l->urbs, buf, sizeof buf - 1, 0);
    if (r <= 0)
        return false;
    buf[r] = 0;
    unsigned long now = strtoul(buf, NULL, 10);
    bool moved = l->seen && now - l->seen > l->own;
    l->seen = now;
    l->own = 0;
    return moved;
}

/* The Gigabyte RX 9060 XT: its RGB controller at 0x75 on the card's OEM I2C bus. A 64-byte write
 * takes the kernel 9 ms of busy wait (100 kHz, polled): only the logo's zone is streamed */
#define GPU_ADDR 0x75
#define GPU_ZONE 3
static int gpu_write(int fd, const uint8_t *head, size_t n)
{
    uint8_t p[64];
    memset(p, 0, sizeof p);
    memcpy(p, head, n);
    return i2c_xfer(fd, GPU_ADDR, 0, p, sizeof p);
}
static int gpu_open(struct light *l)
{
    DIR *d = opendir(at("/sys/class/i2c-dev"));
    if (!d)
        return -1;
    char buf[128];
    l->fd = -1;
    for (struct dirent *e; l->fd < 0 && (e = readdir(d));) {
        if (strncmp(e->d_name, "i2c-", 4))
            continue;
        if (slurp(at("/sys/class/i2c-dev/%s/name", e->d_name), buf, sizeof buf) < 0 || strncmp(buf, "AMDGPU DM i2c OEM bus", 21))
            continue;
        if (slurp(at("/sys/class/i2c-dev/%s/device/../subsystem_vendor", e->d_name), buf, sizeof buf) < 0 || strncmp(buf, "0x1458", 6))
            continue;
        if (slurp(at("/sys/class/i2c-dev/%s/device/../subsystem_device", e->d_name), buf, sizeof buf) < 0 || strncmp(buf, "0x2429", 6))
            continue;
        l->fd = open(at("/dev/%s", e->d_name), O_RDWR | O_CLOEXEC);
    }
    closedir(d);
    if (l->fd < 0)
        return -1;
    /* the controller's own presence answer: 01 (01|02) 01 xx */
    uint8_t ask[] = {0x10, 0x01}, got[4] = {0};
    if (gpu_write(l->fd, ask, sizeof ask) || i2c_xfer(l->fd, GPU_ADDR, I2C_M_RD, got, sizeof got)
            || got[0] != 1 || (got[1] != 1 && got[1] != 2) || got[2] != 1) {
        close(l->fd);
        l->fd = -1;
        return -1;
    }
    return 0;
}
static int gpu_send(struct light *l, const uint8_t rgb[3])
{
    uint8_t h[] = {0x12, 0x01, 0x01, 0x01, 0x0a, rgb[0], rgb[1], rgb[2], 0x00, GPU_ZONE, 0x00};
    return gpu_write(l->fd, h, sizeof h);
}

static struct light lights[] = {
    {.name = "motherboard", .fd = -1, .urbs = -1, .open = msi_open, .send = msi_send},
    {.name = "keyboard", .fd = -1, .urbs = -1, .open = k617_open, .send = k617_send},
    {.name = "card", .fd = -1, .urbs = -1, .open = gpu_open, .send = gpu_send},
};
#define NLIGHTS (sizeof lights / sizeof lights[0])
#define KEYBOARD (&lights[1])

/* ── the cooler's display: the CPU's temperature, its own report ─────────────────── */
static int disp_fd = -1, temp_fd = -1, disp_shown = -1000;
static double temp_avg = -1000;
static void temp_find(void)
{
    char buf[64];
    DIR *d = opendir(at("/sys/class/hwmon"));
    if (!d)
        return;
    for (struct dirent *e; temp_fd < 0 && (e = readdir(d));) {
        if (strncmp(e->d_name, "hwmon", 5))
            continue;
        if (slurp(at("/sys/class/hwmon/%s/name", e->d_name), buf, sizeof buf) >= 0 && !strncmp(buf, "k10temp", 7))
            temp_fd = open(at("/sys/class/hwmon/%s/temp1_input", e->d_name), O_RDONLY | O_CLOEXEC);
    }
    closedir(d);
}
static void disp_tick(void)
{
    char buf[32], name[32];
    if (disp_fd < 0)
        disp_fd = hidraw_find(0x1A2C, 0x4184, 1, name, sizeof name);
    if (disp_fd < 0)
        return;
    if (temp_fd < 0)
        temp_find();
    if (temp_fd < 0)
        return;
    ssize_t r = pread(temp_fd, buf, sizeof buf - 1, 0);
    if (r <= 0)
        return;
    buf[r] = 0;
    double t = strtol(buf, NULL, 10) / 1000.0;
    temp_avg = temp_avg < -999 ? t : temp_avg + (t - temp_avg) * 0.25;   /* Tctl jumps: a few seconds' average */
    int v = (int)lround(temp_avg);
    if (v < 0)
        v = 0;
    if (v > 999)
        v = 999;
    disp_shown = v;
    uint8_t rep[64] = {0x07, 0xff, 0xff, (uint8_t)(v / 100), (uint8_t)(v / 10 % 10), (uint8_t)(v % 10)};
    if (report_out(disp_fd, rep, sizeof rep)) {
        close(disp_fd);
        disp_fd = -1;
    }
}

/* ── the breath ──────────────────────────────────────────────────────────────────── */
static double breath(double t, const struct mood *m)
{
    double p = fmod(t, m->rise + m->fall);
    double c = p < m->rise ? 0.5 - 0.5 * cos(M_PI * p / m->rise)
                           : 0.5 + 0.5 * cos(M_PI * (p - m->rise) / m->fall);
    return m->floor + (m->peak - m->floor) * c;
}
/* the colour at a level: the red falls with the level, green and blue faster, so it reddens */
static void ember(const double rgb[3], double level, uint8_t out[3])
{
    static const double fall[3] = {1.0, 1.5, 2.0};
    for (int i = 0; i < 3; i++) {
        double v = rgb[i] * pow(level, fall[i]);
        out[i] = v >= 255 ? 255 : (uint8_t)lround(v);
    }
}

/* ── the screens, from DRM: lit while any connected screen is on ─────────────────── */
static bool screens_on(void)
{
    char buf[32];
    DIR *d = opendir(at("/sys/class/drm"));
    if (!d)
        return false;
    bool on = false;
    for (struct dirent *e; !on && (e = readdir(d));) {
        if (strncmp(e->d_name, "card", 4) || !strchr(e->d_name, '-'))
            continue;
        if (slurp(at("/sys/class/drm/%s/status", e->d_name), buf, sizeof buf) < 0 || strncmp(buf, "connected", 9))
            continue;
        if (slurp(at("/sys/class/drm/%s/dpms", e->d_name), buf, sizeof buf) >= 0 && !strncmp(buf, "On", 2))
            on = true;
    }
    closedir(d);
    return on;
}

/* ── what it found, for `kawa-rgb status`: rewritten only when it changes ────────── */
static void status_write(int mood, bool lit)
{
    static char last[512];
    char now[512];
    int n = snprintf(now, sizeof now, "mood %s\nscreens %s\n", mood ? "light" : "dark", lit ? "on" : "off");
    for (size_t i = 0; i < NLIGHTS; i++)
        n += snprintf(now + n, sizeof now - (size_t)n, "%s %s\n", lights[i].name, lights[i].fd >= 0 ? "ok" : "missing");
    n += snprintf(now + n, sizeof now - (size_t)n, "display %s\n", disp_fd >= 0 ? "ok" : "missing");
    if (!strcmp(now, last))
        return;
    memcpy(last, now, sizeof last);
    char tmp[512];
    snprintf(tmp, sizeof tmp, "%s", at("%s.new", STATUS));
    int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0)
        return;
    if (write(fd, now, (size_t)n) == n)
        rename(tmp, at("%s", STATUS));
    close(fd);
}

/* ── the service ─────────────────────────────────────────────────────────────────── */
static volatile sig_atomic_t stopping;
static void on_term(int s) { (void)s; stopping = 1; }

static double clock_s(clockid_t c)
{
    struct timespec t;
    clock_gettime(c, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

static int run(const char *trace_path)
{
    FILE *trace = NULL;
    conf_load();
    if (trace_path && !(trace = fopen(trace_path, "w"))) {
        fprintf(stderr, "kawa-rgb: cannot write %s: %s\n", trace_path, strerror(errno));
        return 1;
    }
    struct sigaction sa = {.sa_handler = on_term};
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);

    int mood = mood_now(0), fade = 0;
    bool lit = screens_on();
    double rgb[3], from[3];
    memcpy(rgb, moods[mood].rgb, sizeof rgb);
    memcpy(from, rgb, sizeof from);
    double base = clock_s(CLOCK_MONOTONIC);
    double slept = clock_s(CLOCK_BOOTTIME) - base;
    /* the fastest the breath itself moves in a tick, and a device's limit: a device coming back
     * (a wake, the end of a typing burst) walks to the breath instead of jumping there */
    struct timespec next;
    clock_gettime(CLOCK_MONOTONIC, &next);
    long tick = 0;

    for (size_t i = 0; i < NLIGHTS; i++) {
        lights[i].level = moods[mood].floor;
        lights[i].dirty = true;
    }
    while (!stopping) {
        const struct mood *m = &moods[mood];
        double now = clock_s(CLOCK_MONOTONIC);
        /* a suspend passed: everything's state may be gone (and USB devices renumbered) */
        double away = clock_s(CLOCK_BOOTTIME) - now;
        if (away - slept > 1.0) {
            for (size_t i = 0; i < NLIGHTS; i++) {
                struct light *l = &lights[i];
                if (l->fd >= 0)
                    close(l->fd);
                if (l->urbs >= 0)
                    close(l->urbs);
                l->fd = l->urbs = -1;
                l->dirty = true;
            }
            if (disp_fd >= 0)
                close(disp_fd);
            disp_fd = -1;
        }
        slept = away;

        if (tick % TICKS_S == 0) {
            int was = mood;
            mood = mood_now(mood);
            if (mood != was) {
                memcpy(from, rgb, sizeof from);
                fade = FADE_TICKS;
                m = &moods[mood];
            }
            lit = screens_on();
        }
        if (fade > 0)
            fade--;
        for (int i = 0; i < 3; i++)
            rgb[i] = m->rgb[i] + (from[i] - m->rgb[i]) * fade / FADE_TICKS;

        double target = lit ? breath(now - base, m) : m->floor;
        double limit = 2.5 * (m->peak - m->floor) * M_PI / (2.0 * (m->rise < m->fall ? m->rise : m->fall)) / TICKS_S;

        for (size_t i = 0; i < NLIGHTS; i++) {
            struct light *l = &lights[i];
            if (l->fd < 0) {
                if (tick % RESCAN_TICKS != 0 || l->open(l) < 0)
                    continue;
                l->dirty = true;
            }
            if (l == KEYBOARD && lit) {
                if (k617_typing(l))
                    l->hold = HOLD_TICKS;
                if (l->hold > 0) {
                    l->hold--;
                    continue;
                }
            }
            double d = target - l->level;
            l->level += d > limit ? limit : d < -limit ? -limit : d;
            uint8_t c[3];
            ember(rgb, l->level, c);
            if (!l->dirty && c[0] == l->sent[0] && c[1] == l->sent[1] && c[2] == l->sent[2])
                continue;
            if (l->send(l, c) < 0) {
                close(l->fd);
                if (l->urbs >= 0)
                    close(l->urbs);
                l->fd = l->urbs = -1;
                continue;
            }
            l->dirty = false;
            l->sent[0] = c[0]; l->sent[1] = c[1]; l->sent[2] = c[2];
        }
        if (tick % TICKS_S == 0) {
            disp_tick();
            status_write(mood, lit);
        }
        if (trace) {
            fprintf(trace, "%.3f %s %s", now - base, mood ? "light" : "dark", lit ? "lit" : "banked");
            for (size_t i = 0; i < NLIGHTS; i++)
                fprintf(trace, " %s=%d,%d,%d%s", lights[i].name, lights[i].sent[0], lights[i].sent[1], lights[i].sent[2],
                        lights[i].hold > 0 ? "H" : "");
            fprintf(trace, " display=%d\n", disp_shown);
            fflush(trace);
        }

        tick++;
        next.tv_nsec += TICK_NS;
        if (next.tv_nsec >= 1000000000L) {
            next.tv_nsec -= 1000000000L;
            next.tv_sec++;
        }
        while (clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &next, NULL) == EINTR && !stopping)
            ;
        /* (a machine that fell behind by more than a beat does not race to catch up) */
        struct timespec t;
        clock_gettime(CLOCK_MONOTONIC, &t);
        if (t.tv_sec > next.tv_sec + 1)
            next = t;
    }
    if (trace)
        fclose(trace);
    return 0;
}

/* ── the baseline: what each device does by itself, from power-on, until the service runs ──
 * Red and breathing, in the hardware's own memory. Each is read first and written only when it
 * differs: flash wears. The K617's blocks are read, patched and written back whole, never from a
 * template: what they hold besides the effect is its own (fizzctl's frames carry someone else's) */
#define K617_BLOCK 1032
static const struct { const char *name; uint8_t select[6]; uint8_t head[5]; } K617_BLOCKS[] = {
    {"mode",    {0x05, 0x88, 0xb8, 0, 0, 0}, {0x06, 0x08, 0xb8, 0x00, 0x40}},
    {"canvas",  {0x05, 0x89, 0xbc, 0, 0, 0}, {0x06, 0x09, 0xbc, 0x00, 0x40}},
    {"routing", {0x05, 0x89, 0xc0, 0, 0, 0}, {0x06, 0x09, 0xc0, 0x00, 0x40}},
    {"exec",    {0x05, 0x83, 0xb6, 0, 0, 0}, {0x06, 0x03, 0xb6, 0x00, 0x00}},
};
#define K617_MODE 0
#define K617_EXEC 3
#define K617_RESPIRE 0x02
static void ms(long n)
{
    struct timespec t = {n / 1000, (n % 1000) * 1000000L};
    nanosleep(&t, NULL);
}
static int k617_read(int fd, uint8_t blocks[4][K617_BLOCK])
{
    for (int i = 0; i < 4; i++) {
        uint8_t raw[K617_BLOCK];
        if (feature_set(fd, K617_BLOCKS[i].select, 6))
            return -1;
        ms(60);
        int n = feature_get(fd, 0x06, raw, sizeof raw);
        if (n < 64)
            return -1;
        memset(blocks[i], 0, K617_BLOCK);
        memcpy(blocks[i], raw, (size_t)n);
        memcpy(blocks[i], K617_BLOCKS[i].head, 5);
        ms(60);
    }
    return 0;
}
static int k617_baseline(const uint8_t rgb[3])
{
    char name[32];
    int fd = hidraw_find(0x258A, 0x0049, 1, name, sizeof name);
    if (fd < 0) {
        puts("keyboard: not here");
        return 0;
    }
    static uint8_t now[4][K617_BLOCK], want[4][K617_BLOCK];
    if (k617_read(fd, now)) {
        puts("keyboard: could not read its memory, left alone");
        close(fd);
        return 1;
    }
    memcpy(want, now, sizeof want);
    uint8_t *mode = want[K617_MODE], *ex = want[K617_EXEC];
    if (ex[14] != 0x5a || ex[15] != 0xa5) {      /* (its commit mark: anything else is not this firmware's block) */
        puts("keyboard: its memory is not as expected, left alone");
        close(fd);
        return 1;
    }
    memcpy(mode + 218, rgb, 3);                  /* the single colour */
    memcpy(mode + 29, rgb, 3);
    ex[21] = K617_RESPIRE;
    ex[38 + 2 * (K617_RESPIRE - 1)] = 0x00;      /* its "many colours" flag off */
    ex[39] = 0x03;                               /* speed 1 (stored 0), brightness 3 of 4 */
    ex[39 + 2 * (K617_RESPIRE - 1)] = 0x03;
    if (!memcmp(now, want, sizeof want)) {
        puts("keyboard: as it should be");
        close(fd);
        return 0;
    }
    uint8_t init[6];
    memcpy(init, K617_BLOCKS[K617_EXEC].select, 6);
    uint8_t scratch[K617_BLOCK];
    int r = feature_set(fd, init, 6);
    ms(60);
    if (feature_get(fd, 0x06, scratch, sizeof scratch) < 0)       /* (without this read it ignores the burst) */
        r = -1;
    ms(60);
    for (int i = 0; i < 4 && !r; i++) {
        r = feature_set(fd, want[i], K617_BLOCK);
        ms(60);
    }
    if (r) {
        puts("keyboard: the write failed");
        close(fd);
        return 1;
    }
    ms(200);
    bool same = k617_read(fd, now) == 0 && !memcmp(now[K617_EXEC], want[K617_EXEC], 64)
                && !memcmp(now[K617_MODE] + 218, rgb, 3);
    puts(same ? "keyboard: written, read back equal" : "keyboard: written, but it reads back differently");
    close(fd);
    return same ? 0 : 1;
}
static int msi_baseline(const uint8_t rgb[3])
{
    struct light l = {.fd = -1, .urbs = -1};
    if (msi_open(&l)) {
        puts("motherboard: not here");
        return 0;
    }
    uint8_t want[185];
    memcpy(want, l.tmpl, sizeof want);
    msi_zones(want, rgb, 2, 10, 0);              /* breathing, slowest */
    want[184] = 0;
    if (!memcmp(want, l.tmpl, sizeof want)) {
        puts("motherboard: as it should be");
        close(l.fd);
        return 0;
    }
    want[184] = 1;                               /* save_data: to its flash */
    uint8_t old[185];
    memcpy(old, l.tmpl, sizeof old);
    old[184] = 1;
    /* (as MSI's own software does: the old state, then the new) */
    int r = feature_set(l.fd, old, sizeof old);
    r |= feature_set(l.fd, want, sizeof want);
    ms(100);
    uint8_t back[185];
    bool same = !r && feature_get(l.fd, 0x52, back, sizeof back) == (int)sizeof back && !memcmp(back + 1, want + 1, 183);
    puts(same ? "motherboard: written, read back equal" : "motherboard: written, but it reads back differently");
    close(l.fd);
    return same ? 0 : 1;
}
static int gpu_baseline(const uint8_t rgb[3])
{
    struct light l = {.fd = -1, .urbs = -1};
    if (gpu_open(&l)) {
        puts("card: not here");
        return 0;
    }
    /* it answers nothing about its colour: a mark says what it was last given */
    char mark[32], was[32] = "";
    snprintf(mark, sizeof mark, "%02x%02x%02x pulse\n", rgb[0], rgb[1], rgb[2]);
    if (slurp(at("%s", BASE_MARK), was, sizeof was) >= 0 && !strcmp(was, mark)) {
        puts("card: as it was last set");
        close(l.fd);
        return 0;
    }
    int r = 0;
    for (uint8_t z = 0; z < 6 && !r; z++) {      /* (all six, as Gigabyte's own software does) */
        uint8_t h[] = {0x12, 0x01, 0x02, 0x01, 0x0a, rgb[0], rgb[1], rgb[2], 0x00, z, 0x00};
        r = gpu_write(l.fd, h, sizeof h);
        ms(120);
    }
    uint8_t save[] = {0x13, 0x01};
    r |= gpu_write(l.fd, save, sizeof save);
    close(l.fd);
    if (r) {
        puts("card: the write failed");
        return 1;
    }
    int fd = open(at("%s", BASE_MARK), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd >= 0) {
        if (write(fd, mark, strlen(mark)) < 0)
            puts("card: its mark could not be written");
        close(fd);
    }
    puts("card: written (it answers nothing back)");
    return 0;
}
static int baseline(void)
{
    conf_load();
    uint8_t c[3];
    ember(moods[0].rgb, moods[0].peak, c);
    int r = msi_baseline(c);
    r |= gpu_baseline(c);
    r |= k617_baseline(c);
    return r ? 1 : 0;
}

static int status(void)
{
    char buf[512];
    if (slurp(at("%s", STATUS), buf, sizeof buf) < 0) {
        fprintf(stderr, "kawa-rgb: the service is not running (no %s)\n", STATUS);
        return 1;
    }
    fputs(buf, stdout);
    return 0;
}

int main(int argc, char **argv)
{
    const char *r = getenv("KAWA_RGB_ROOT");
    if (r)
        root = r;
    if (argc >= 2 && !strcmp(argv[1], "run")) {
        if (argc == 4 && !strcmp(argv[2], "--trace"))
            return run(argv[3]);
        if (argc == 2)
            return run(NULL);
    }
    if (argc == 2 && !strcmp(argv[1], "status"))
        return status();
    if (argc == 2 && !strcmp(argv[1], "baseline"))
        return baseline();
    fprintf(stderr, "usage: kawa-rgb run [--trace FILE] | baseline | status\n");
    return 2;
}
