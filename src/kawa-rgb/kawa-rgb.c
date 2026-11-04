/*
 * kawa-rgb — every light in the PC, one steady red.
 *
 * The lights speak three small protocols (the keyboard's has no other driver), so this is one
 * program with no libraries and no scanner: the motherboard's Mystic Light and the Redragon K617
 * over hidraw feature reports, the Gigabyte card's logo over its I2C bus. Each device has its own
 * colour value (rgb.conf), so that they look the same, and nothing moves: while nothing changes
 * this sends nothing to anything. It changes on events only:
 *
 *   the lock screen up     a fade to about 30 %
 *   screens off, a sleep   off
 *   unlocked, awake        back to full
 *   the switch             on or off for everything (quick settings), kept across reboots, in the
 *                          hardware's memory too: off is off from power-on
 *
 *   kawa-rgb run [--trace FILE]   the service (kawa-rgb.service, as root without capabilities)
 *   kawa-rgb on | off | toggle    the switch (yours: a file beside the login screen's mood)
 *   kawa-rgb state                the switch, "on" or "off"
 *   kawa-rgb lock | unlock        kawa-lock: the lock screen came up, went away
 *   kawa-rgb sleep | wake         kawa-rgb-sleep.service: the machine is going to sleep, is back
 *   kawa-rgb status               what the service has found (/run/kawa-rgb/status)
 *
 * The screens come from DRM, nobody tells it. What each device does by itself, from power-on until
 * the service runs, is in its own memory: read first and written only when it differs, since flash
 * wears (the K617's blocks are read, patched and written back whole, never from a template). The
 * keyboard's node also carries its keys: nothing here ever reads them. A device that fails or goes
 * away is closed and looked for again, so a replug and a resume just work.
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

#define FADE_MS 125                 /* a step of a fade: 8 a second, the card's register takes 9 */
#define IDLE_MS 500                 /* a look at the screens and the switch while nothing moves */
#define FADE_STEP 0.125             /* of the whole way, a step: a second from full to nothing */
#define GAMMA 2.2                   /* LEDs are linear, the eye is not: a level is what it looks */

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
static const char *SWITCH = "/var/lib/fedokawaii-greeter/rgb";
static const char *LOCKED = "/var/lib/fedokawaii-greeter/rgb-locked";
static const char *STATUS = "/run/kawa-rgb/status";
static const char *SLEEPING = "/run/kawa-rgb/sleeping";
static const char *BASE_MARK = "/var/lib/kawa-rgb/card";

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
static void ms(long n)
{
    struct timespec t = {n / 1000, (n % 1000) * 1000000L};
    nanosleep(&t, NULL);
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
/* still there? A hidraw node answers this without a word on the USB; a test's file is unlinked */
static bool alive(int fd)
{
    struct hidraw_devinfo info;
    if (regular(fd)) {
        struct stat st;
        return fstat(fd, &st) == 0 && st.st_nlink > 0;
    }
    return ioctl(fd, HIDIOCGRAWINFO, &info) == 0;
}

/* a hidraw node by its USB ids and interface */
static int hidraw_find(unsigned vid, unsigned pid, int iface)
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
    }
    closedir(d);
    return fd;
}

/* ── the lights ──────────────────────────────────────────────────────────────────── */
struct light {
    const char *name;
    int fd;
    int rgb[3];             /* its red at full (rgb.conf) */
    bool dirty;             /* its state may be lost: sent again, even if unchanged */
    bool remembered;        /* its own memory looked at, for the switch as it is */
    int sent[3];            /* the last colour it took */
    double sent_at;         /* when (the monotonic clock) */
    int (*open)(struct light *);
    int (*send)(struct light *, const uint8_t rgb[3]);
    int (*remember)(struct light *, const uint8_t rgb[3]);   /* 0 as it was · 1 written · -1 not so */
};

/* Mystic Light, 185-byte feature report 0x52, zone-based on this board: one colour per zone, so a
 * chain of any length on JARGB_V2 takes the one colour. Only `remember` ever sets save_data. The
 * real headers are JRGB1 and JARGB_V2_1 (rainbow 1); the packet's phantom zones take the same */
static const uint8_t MSI_ZONES[] = {1, 11, 21, 31, 42, 74, 174};
static uint8_t msi_now[185], msi_kept[185];     /* the packet as sent; as last saved, or as it came */
static int msi_open(struct light *l)
{
    l->fd = hidraw_find(0x0DB0, 0x0076, 0);
    if (l->fd < 0)
        return -1;
    if (feature_get(l->fd, 0x52, msi_now, sizeof msi_now) != (int)sizeof msi_now) {
        close(l->fd);
        l->fd = -1;
        return -1;
    }
    memcpy(msi_kept, msi_now, sizeof msi_kept);
    return 0;
}
static void msi_paint(uint8_t *p, const uint8_t rgb[3])
{
    uint8_t effect = rgb[0] || rgb[1] || rgb[2];     /* 1 static, 0 off */
    for (size_t i = 0; i < sizeof MSI_ZONES; i++) {
        uint8_t *z = p + MSI_ZONES[i];
        z[0] = effect;
        memcpy(z + 1, rgb, 3);
        z[4] = 10 << 2;     /* full; the colour is the level */
        memcpy(z + 5, rgb, 3);
        z[8] = 0x80;        /* the custom colour */
    }
}
static int msi_send(struct light *l, const uint8_t rgb[3])
{
    msi_paint(msi_now, rgb);
    msi_now[184] = 0;
    return feature_set(l->fd, msi_now, sizeof msi_now);
}
static int msi_remember(struct light *l, const uint8_t rgb[3])
{
    uint8_t want[185], back[185];
    memcpy(want, msi_kept, sizeof want);
    msi_paint(want, rgb);
    want[184] = msi_kept[184] = 0;
    if (!memcmp(want, msi_kept, sizeof want))
        return 0;
    /* (as MSI's own software does: the old state, then the new, each with its save flag) */
    want[184] = msi_kept[184] = 1;
    int r = feature_set(l->fd, msi_kept, sizeof msi_kept);
    r |= feature_set(l->fd, want, sizeof want);
    if (r)
        return -1;
    ms(100);
    want[184] = 0;
    memcpy(msi_kept, want, sizeof msi_kept);
    memcpy(msi_now, want, sizeof msi_now);
    if (feature_get(l->fd, 0x52, back, sizeof back) != (int)sizeof back)
        return -1;
    return regular(l->fd) || !memcmp(back + 1, want + 1, 183) ? 1 : -1;
}

/* The K617 Fizz, live frame: 382-byte feature report, 96 RGB triplets, lost on a reconnect. Its
 * stored effect: the blocks below. Interface 1 also carries a keyboard report, which nothing here
 * reads (the fd is only ever ioctl'd) */
#define K617_BLOCK 1032
#define K617_MODE 0
#define K617_EXEC 1
#define K617_FIXED 0x01
#define K617_OFF 0x16
/* (report 5 is also the way into its bootloader: only these selects are ever sent) */
static const uint8_t K617_SELECTS[2][6] = {{0x05, 0x88, 0xb8, 0, 0, 0}, {0x05, 0x83, 0xb6, 0, 0, 0}};
static const uint8_t K617_HEADS[2][5] = {{0x06, 0x08, 0xb8, 0x00, 0x40}, {0x06, 0x03, 0xb6, 0x00, 0x00}};
static int k617_open(struct light *l)
{
    l->fd = hidraw_find(0x258A, 0x0049, 1);
    return l->fd < 0 ? -1 : 0;
}
static int k617_send(struct light *l, const uint8_t rgb[3])
{
    uint8_t f[382];
    memset(f, 0, sizeof f);
    f[0] = 0x08; f[1] = 0x0a; f[2] = 0x7a; f[3] = 0x01;
    for (int i = 0; i < 96; i++)
        memcpy(f + 4 + i * 3, rgb, 3);
    return feature_set(l->fd, f, sizeof f);
}
static int k617_read(int fd, uint8_t blocks[2][K617_BLOCK])
{
    for (int i = 0; i < 2; i++) {
        uint8_t raw[K617_BLOCK];
        if (feature_set(fd, K617_SELECTS[i], 6))
            return -1;
        ms(60);
        int n = feature_get(fd, 0x06, raw, sizeof raw);
        if (n < 64)
            return -1;
        memset(blocks[i], 0, K617_BLOCK);
        memcpy(blocks[i], raw, (size_t)n);
        memcpy(blocks[i], K617_HEADS[i], 5);
        ms(60);
    }
    ms(100);
    return 0;
}
static int k617_remember(struct light *l, const uint8_t rgb[3])
{
    static uint8_t now[2][K617_BLOCK], want[2][K617_BLOCK];
    bool lit = rgb[0] || rgb[1] || rgb[2];
    if (k617_read(l->fd, now))
        return -1;
    memcpy(want, now, sizeof want);
    uint8_t *mode = want[K617_MODE], *ex = want[K617_EXEC];
    if (memcmp(ex + 14, "\x5a\xa5", 2) || memcmp(ex + 137, "\x5a\xa5", 2))  /* (its commit marks: else no block we know) */
        return -1;
    ex[21] = lit ? K617_FIXED : K617_OFF;
    if (lit) {
        memcpy(mode + 29, rgb, 3);               /* fixed-on's colour, the first of its palette */
        ex[38] = 0x00;                           /* its palette's first, not "random" (7) */
        ex[39] = 0x34;                           /* speed, and brightness 4 of 4: the colour is the level */
    }
    if (!memcmp(now, want, sizeof want))
        return 0;
    uint8_t scratch[K617_BLOCK];
    int r = feature_set(l->fd, K617_SELECTS[K617_EXEC], 6);
    ms(60);
    if (feature_get(l->fd, 0x06, scratch, sizeof scratch) < 0)    /* (without this read it ignores the write) */
        r = -1;
    ms(60);
    for (int i = 0; i < 2 && !r; i++) {
        r = feature_set(l->fd, want[i], K617_BLOCK);
        ms(100);
    }
    if (!regular(l->fd))
        ms(1000);           /* (a live frame too soon is lost to its new effect) */
    return r ? -1 : 1;
}

/* The Gigabyte RX 9060 XT: its RGB controller at 0x75 on the card's OEM I2C bus. It parses nothing
 * shorter than 64 bytes (a shorter write gets no answer), and a 64-byte write takes the kernel 9 ms
 * of busy wait (100 kHz, polled), and never a read that follows no write of ours. Six zones, of
 * which the logo is GPU_ZONE: in a fade only that one moves, the others take the end of it */
#define GPU_ADDR 0x75
#define GPU_ZONE 3
#define GPU_ZONES 6
#define GPU_REG_MODE 0x12
#define GPU_REG_SAVE 0x13
#define GPU_STATIC 0x01
#define GPU_OFF 0x00
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
static int gpu_zone(int fd, uint8_t zone, const uint8_t rgb[3])
{
    uint8_t mode = rgb[0] || rgb[1] || rgb[2] ? GPU_STATIC : GPU_OFF;
    uint8_t h[] = {GPU_REG_MODE, 0x01, mode, 0x01, 0x0a, rgb[0], rgb[1], rgb[2], 0x00, zone, 0x00};
    return gpu_write(fd, h, sizeof h);
}
static int card_todo;               /* zones still to take the colour the logo has */
static uint8_t card_rgb[3];
static int gpu_send(struct light *l, const uint8_t rgb[3])
{
    memcpy(card_rgb, rgb, 3);
    card_todo = GPU_ZONES;
    return gpu_zone(l->fd, GPU_ZONE, rgb);
}
static int gpu_remember(struct light *l, const uint8_t rgb[3])
{
    /* it answers nothing about its colour: a mark says what it was last given */
    char mark[16], was[16] = "";
    snprintf(mark, sizeof mark, "%02x%02x%02x\n", rgb[0], rgb[1], rgb[2]);
    if (slurp(at("%s", BASE_MARK), was, sizeof was) >= 0 && !strcmp(was, mark))
        return 0;
    int r = 0;
    for (uint8_t z = 0; z < GPU_ZONES && !r; z++) {      /* (all six, as Gigabyte's own software does) */
        r = gpu_zone(l->fd, z, rgb);
        ms(120);
    }
    uint8_t save[] = {GPU_REG_SAVE, 0x01};
    r |= gpu_write(l->fd, save, sizeof save);
    if (r)
        return -1;
    if (!regular(l->fd))
        ms(500);            /* (writing its flash, it answers nothing) */
    int fd = open(at("%s", BASE_MARK), O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd >= 0) {
        if (write(fd, mark, strlen(mark)) < 0)
            r = -1;
        close(fd);
    }
    return r ? -1 : 1;
}

static struct light lights[] = {
    {.name = "motherboard", .fd = -1, .open = msi_open, .send = msi_send, .remember = msi_remember},
    {.name = "keyboard", .fd = -1, .open = k617_open, .send = k617_send, .remember = k617_remember},
    {.name = "card", .fd = -1, .open = gpu_open, .send = gpu_send, .remember = gpu_remember},
};
#define NLIGHTS (sizeof lights / sizeof lights[0])
#define CARD (&lights[2])

/* ── rgb.conf: motherboard|keyboard|card R G B, each's red at full; dim N, the lock's level in % ── */
static double dim_level;
static void conf_load(void)
{
    char buf[1024], *line, *save;
    if (slurp(at("%s", CONF), buf, sizeof buf) < 0) {
        fprintf(stderr, "kawa-rgb: cannot read %s: %s\n", CONF, strerror(errno));
        exit(1);
    }
    unsigned seen = 0;
    int want = (1 << NLIGHTS) | ((1 << NLIGHTS) - 1);
    for (line = strtok_r(buf, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        char name[32];
        int a, b, c;
        if (sscanf(line, "dim %d", &a) == 1 && a >= 0 && a <= 100) {
            dim_level = a / 100.0;
            seen |= 1u << NLIGHTS;
            continue;
        }
        if (sscanf(line, "%31s %d %d %d", name, &a, &b, &c) != 4 || a < 0 || a > 255 || b < 0 || b > 255 || c < 0 || c > 255)
            continue;
        for (size_t i = 0; i < NLIGHTS; i++)
            if (!strcmp(name, lights[i].name)) {
                lights[i].rgb[0] = a; lights[i].rgb[1] = b; lights[i].rgb[2] = c;
                seen |= 1u << i;
            }
    }
    if ((int)seen != want) {
        fprintf(stderr, "kawa-rgb: %s needs a line for each of motherboard, keyboard, card (NAME R G B) and dim N\n", CONF);
        exit(1);
    }
}

/* ── the cooler's display: the CPU's temperature, its own report, once a second ──── */
static int disp_fd = -1, temp_fd = -1, disp_shown = -1;
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
    char buf[32];
    if (disp_fd >= 0 && !alive(disp_fd)) {
        close(disp_fd);
        disp_fd = -1;
    }
    if (disp_fd < 0)
        disp_fd = hidraw_find(0x1A2C, 0x4184, 1);
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
    double t = (double)strtol(buf, NULL, 10) / 1000.0;
    temp_avg = temp_avg < -999 ? t : temp_avg + (t - temp_avg) * 0.25;   /* Tctl jumps: a few seconds' average */
    int v = (int)lround(temp_avg);
    v = v < 0 ? 0 : v > 999 ? 999 : v;
    disp_shown = v;
    uint8_t rep[64] = {0x07, 0xff, 0xff, (uint8_t)(v / 100), (uint8_t)(v / 10 % 10), (uint8_t)(v % 10)};
    if (report_out(disp_fd, rep, sizeof rep)) {
        close(disp_fd);
        disp_fd = -1;
    }
}

/* ── what decides ────────────────────────────────────────────────────────────────── */
static bool screens_on(void)     /* lit while any connected screen is on, from DRM */
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
static double clock_s(clockid_t c)
{
    struct timespec t;
    clock_gettime(c, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}
static bool switched_on(void)
{
    char buf[8];
    return slurp(at("%s", SWITCH), buf, sizeof buf) < 0 || strncmp(buf, "off", 3);
}
/* locked: the mark is there, and from this boot (a session that died locked leaves it behind) */
static bool locked(void)
{
    struct stat st;
    if (stat(at("%s", LOCKED), &st))
        return false;
    return (double)st.st_mtime >= clock_s(CLOCK_REALTIME) - clock_s(CLOCK_BOOTTIME) - 2;
}
static bool sleeping(void)
{
    return access(at("%s", SLEEPING), F_OK) == 0;
}

/* a level (what it looks like) on a device's red */
static void paint(const struct light *l, double level, uint8_t out[3])
{
    double pwm = pow(level, GAMMA);
    for (int i = 0; i < 3; i++)
        out[i] = (uint8_t)lround(l->rgb[i] * pwm);
}

/* ── what it found, for `kawa-rgb status`: rewritten only when it changes ────────── */
static void status_write(const char *word)
{
    static char last[512];
    char now[512];
    int n = snprintf(now, sizeof now, "lights %s\n", word);
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

static void let_go(struct light *l)
{
    if (l->fd >= 0)
        close(l->fd);
    l->fd = -1;
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

    double slept = clock_s(CLOCK_BOOTTIME) - clock_s(CLOCK_MONOTONIC);
    double next_display = 0, next_check = 0, next_scan = 0;
    bool on = switched_on(), was_on = on;
    double level = -1;              /* where the fade is: at the first look, it goes there at once */

    for (size_t i = 0; i < NLIGHTS; i++)
        lights[i].dirty = true;
    while (!stopping) {
        double now = clock_s(CLOCK_MONOTONIC);
        /* a suspend passed: everything's state may be gone (and USB devices renumbered) */
        double away = clock_s(CLOCK_BOOTTIME) - now;
        if (away - slept > 1.0) {
            for (size_t i = 0; i < NLIGHTS; i++) {
                let_go(&lights[i]);
                lights[i].dirty = true;
            }
            if (disp_fd >= 0)
                close(disp_fd);
            disp_fd = -1;
            next_scan = 0;
        }
        slept = away;

        /* what it should look like now */
        on = switched_on();
        bool lit = screens_on(), asleep = sleeping();
        double target = !on || !lit || asleep ? 0 : locked() ? dim_level : 1;
        const char *word = !on ? "switched off" : asleep ? "off, asleep" : !lit ? "off, screens off" : target < 1 ? "dim" : "full";
        if (level < 0 || asleep || fabs(target - level) <= FADE_STEP)
            level = target;
        else
            level += target > level ? FADE_STEP : -FADE_STEP;

        if (on != was_on)
            for (size_t i = 0; i < NLIGHTS; i++)
                lights[i].remembered = false;
        was_on = on;

        /* the devices: gone ones looked for, each one's memory, then what has changed */
        if (now >= next_check) {
            next_check = now + 2;
            for (size_t i = 0; i < NLIGHTS; i++)
                if (&lights[i] != CARD && lights[i].fd >= 0 && !alive(lights[i].fd)) {
                    let_go(&lights[i]);
                    lights[i].dirty = true;
                }
        }
        bool scan = now >= next_scan;
        if (scan)
            next_scan = now + 2;
        for (size_t i = 0; i < NLIGHTS; i++) {
            struct light *l = &lights[i];
            if (l->fd < 0) {
                if (!scan || l->open(l) < 0)
                    continue;
                l->dirty = true;
            }
            /* each one's own memory, when the fade has ended and its last frame has settled:
             * the keyboard paints a live frame for a while after taking it, and anything said
             * to it meanwhile cuts the painting short. A write there puts its live state out:
             * sent again */
            if (!l->remembered && level == target && now - l->sent_at >= 1.0) {
                uint8_t full[3];
                paint(l, on ? 1 : 0, full);
                int w = l->remember(l, full);
                if (w < 0)
                    fprintf(stderr, "kawa-rgb: %s's memory: not as it should be\n", l->name);
                l->remembered = true;
                if (w > 0)
                    l->dirty = true;
            }
            uint8_t c[3];
            paint(l, level, c);
            if (l->dirty || c[0] != l->sent[0] || c[1] != l->sent[1] || c[2] != l->sent[2]) {
                if (l->send(l, c) < 0) {
                    fprintf(stderr, "kawa-rgb: %s: %s\n", l->name, strerror(errno));
                    let_go(l);
                    l->dirty = true;
                    continue;
                }
                l->dirty = false;
                l->sent[0] = c[0]; l->sent[1] = c[1]; l->sent[2] = c[2];
                l->sent_at = now;
            } else if (l == CARD && card_todo > 0) {
                /* the fade has ended: the card's other zones, one a step */
                card_todo--;
                if (card_todo != GPU_ZONE && gpu_zone(l->fd, (uint8_t)card_todo, card_rgb) < 0) {
                    let_go(l);
                    l->dirty = true;
                    continue;
                }
            }
        }
        if (now >= next_display) {
            next_display = now + 1;
            if (target > 0)
                disp_tick();
        }
        status_write(word);
        if (trace) {
            fprintf(trace, "%.3f %s", now, word);
            for (size_t i = 0; i < NLIGHTS; i++)
                fprintf(trace, " %s=%d,%d,%d", lights[i].name, lights[i].sent[0], lights[i].sent[1], lights[i].sent[2]);
            fprintf(trace, " display=%d\n", disp_shown);
            fflush(trace);
        }
        ms(level != target || card_todo > 0 ? FADE_MS : IDLE_MS);
    }
    if (trace)
        fclose(trace);
    return 0;
}

/* ── the small commands ──────────────────────────────────────────────────────────── */
static int put_file(const char *path, const char *text)
{
    char tmp[512];
    snprintf(tmp, sizeof tmp, "%s.%d", path, (int)getpid());
    int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (fd < 0 || write(fd, text, strlen(text)) != (ssize_t)strlen(text)) {
        fprintf(stderr, "kawa-rgb: cannot write %s: %s\n", path, strerror(errno));
        if (fd >= 0)
            close(fd);
        unlink(tmp);
        return 1;
    }
    close(fd);
    return rename(tmp, path) ? 1 : 0;
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
/* the sleep's unit: the mark, then as long as the service needs to have put everything out */
static int to_sleep(void)
{
    if (put_file(at("%s", SLEEPING), "1\n"))
        return 0;           /* (no service, nothing to tell) */
    char buf[64];
    for (int i = 0; i < 30; i++) {
        if (slurp(at("%s", STATUS), buf, sizeof buf) >= 0 && strstr(buf, "asleep"))
            break;
        ms(50);
    }
    return 0;
}

int main(int argc, char **argv)
{
    const char *r = getenv("KAWA_RGB_ROOT");
    if (r)
        root = r;
    const char *cmd = argc >= 2 ? argv[1] : "";
    if (!strcmp(cmd, "run")) {
        if (argc == 4 && !strcmp(argv[2], "--trace"))
            return run(argv[3]);
        if (argc == 2)
            return run(NULL);
    } else if (argc == 2) {
        if (!strcmp(cmd, "status"))
            return status();
        if (!strcmp(cmd, "state")) {
            puts(switched_on() ? "on" : "off");
            return 0;
        }
        if (!strcmp(cmd, "on") || !strcmp(cmd, "off"))
            return put_file(at("%s", SWITCH), !strcmp(cmd, "on") ? "on\n" : "off\n");
        if (!strcmp(cmd, "toggle"))
            return put_file(at("%s", SWITCH), switched_on() ? "off\n" : "on\n");
        if (!strcmp(cmd, "lock"))
            return put_file(at("%s", LOCKED), "1\n");
        if (!strcmp(cmd, "unlock"))
            return unlink(at("%s", LOCKED)) && errno != ENOENT ? 1 : 0;
        if (!strcmp(cmd, "sleep"))
            return to_sleep();
        if (!strcmp(cmd, "wake"))
            return unlink(at("%s", SLEEPING)) && errno != ENOENT ? 1 : 0;
    }
    fprintf(stderr, "usage: kawa-rgb run [--trace FILE] | on | off | toggle | state | lock | unlock | sleep | wake | status\n");
    return 2;
}
