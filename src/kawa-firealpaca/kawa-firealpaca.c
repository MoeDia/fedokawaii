/*
 * kawa-firealpaca — FireAlpaca, the official Linux build, dressed as part of the desktop.
 *
 * FireAlpaca is closed, and no theme file of its own exists: its menus and dialogs are plain
 * Qt widgets, which a style sheet reaches, but its lists (brushes, layers, sizes) and sliders are
 * pixels it writes into images of its own, its words there are a fixed face and its pictures
 * are inside the binary. This little library, loaded into it by kawa-sketch (LD_PRELOAD), sits
 * between the program and Qt's public functions and changes nothing but how things look; what
 * is drawn on the canvas, the files and the pen are never touched.
 *
 *   the sheet     ~/.config/fedokawaii/current/firealpaca.qss, set as the application's style
 *                 sheet; @THEME@ in it is the mood's folder (tools/build-themes.py writes it)
 *   the inks      current/firealpaca.conf: "token rrggbb" lines, from the same palette
 *   its images    QPainter::drawImage: by the class of the widget drawn on, a list's greys and
 *                 its selection's blues become the mood's ramps (white → view, black → text;
 *                 9dd1f8 → the lacquer, black → the ink on it), a slider is drawn again as the
 *                 design's meter (§4: 6 + 2 px segments, flame and vermilion at the top), the
 *                 grey round the canvas becomes the ground. A layer's thumbnail, a swatch, the
 *                 picture itself: left as they are
 *   its face      QFont: "MS UI Gothic" at its 10–13 px becomes Sumi UI at 14, never bold
 *   its pictures  QIcon(":/images/x.png"), QPixmap(":/images/x.png"): our own drawing of the
 *                 same name when ~/.local/share/fedokawaii/firealpaca/icons/ has one. They are
 *                 masks: an icon is painted at QIcon::pixmap in its state's ink (text, faint when
 *                 disabled, the lacquer's when checked), so a mood change needs no second set
 *   the moods     a thread waits on ~/.config/fedokawaii for the "current" link to change
 *                 (kawa-theme) and has the main thread load the new sheet and inks: FireAlpaca
 *                 changes with the desktop, a picture in work and all
 *
 * Nothing is written anywhere. KAWA_FA_PLAIN=1 leaves the program as it comes. A symbol missing
 * from a later Qt turns the whole of it off, never a crash; a class it does not know is left
 * as drawn. Its children (the web view's processes, a browser it opens) do not inherit it.
 * Built by theme.sh (src/kawa-firealpaca/Makefile), no Qt headers: the few Qt objects used are
 * opaque buffers, reached through their exported functions only.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <limits.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/inotify.h>
#include <sys/stat.h>
#include <unistd.h>

typedef struct { void *d; unsigned short *ptr; long size; } QString;   /* QArrayDataPointer<char16_t> */
typedef struct { void *d; void **ptr; long size; } QPtrList;           /* QList<T*> */
enum { RGB32 = 4, ARGB32 = 5 };
enum { MODE_NORMAL, MODE_DISABLED, MODE_ACTIVE, MODE_SELECTED };
enum { KAWA_EVENT = 1731 };                                            /* QEvent::User + 731 */
#define OBJECT_BYTES 64                                                /* room for a QImage or QPixmap (32) */

static bool on;                  /* FireAlpaca itself, every symbol found, not asked to stay plain */
static pthread_t main_thread;
static char home[PATH_MAX - 128];

/* ── Qt's functions ───────────────────────────────────────────────────────────── */
static struct {
	void (*draw_image_r)(void *, const void *, const void *, const void *, int);
	void (*draw_image_p)(void *, const void *, const void *);
	void *(*device)(void *);
	const char *(*class_name)(const void *);
	int (*img_w)(const void *), (*img_h)(const void *), (*img_fmt)(const void *);
	const unsigned char *(*img_cbits)(const void *);
	unsigned char *(*img_bits)(void *);
	long (*img_bpl)(const void *);
	void (*img_wrap)(void *, unsigned char *, int, int, long, int, void *, void *);
	void (*img_free)(void *);
	void (*img_convert)(void *, const void *, int, int);
	void (*icon_new)(void *, const QString *);
	void (*pixmap_new)(void *, const QString *, const char *, int);
	void (*pixmap_copy)(void *, const void *);
	void (*pixmap_assign)(void *, const void *);
	void (*pixmap_free)(void *);
	void (*pixmap_image)(void *, const void *);
	void (*pixmap_from)(void *, const void *, int);
	int (*pixmap_w)(const void *), (*pixmap_h)(const void *);
	long (*icon_key)(const void *);
	void (*icon_pixmap)(void *, const void *, const void *, double, int, int);
	void (*icon_pixmap2)(void *, const void *, const void *, int, int);
	void (*icon_pixmap3)(void *, const void *, void *, const void *, int, int);
	void (*font_new)(void *, const QString *, int, int, bool);
	void (*font_family)(QString *, const void *);
	void (*font_pixels)(void *, int);
	void (*font_points)(void *, int);
	void (*font_weight)(void *, int);
	void (*string_utf8)(QString *, long, const char *);
	void (*array_free)(void *, long, long);
	bool (*notify)(void *, void *, void *);
	void (*set_sheet)(void *, const QString *);
	void (*all_widgets)(QPtrList *);
	void (*widget_update)(void *);
	void (*post_event)(void *, void *, int);
	void (*event_new)(void *, int);
	void *(*cxx_new)(unsigned long);
	void **app;
} qt;

static bool
resolve(void)
{
	struct { void *slot; const char *name; } t[] = {
#define S(field, sym) { &qt.field, sym }
		S(draw_image_r, "_ZN8QPainter9drawImageERK6QRectFRK6QImageS2_6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(draw_image_p, "_ZN8QPainter9drawImageERK7QPointFRK6QImage"),
		S(device, "_ZNK8QPainter6deviceEv"),
		S(class_name, "_ZNK11QMetaObject9classNameEv"),
		S(img_w, "_ZNK6QImage5widthEv"), S(img_h, "_ZNK6QImage6heightEv"), S(img_fmt, "_ZNK6QImage6formatEv"),
		S(img_cbits, "_ZNK6QImage4bitsEv"), S(img_bits, "_ZN6QImage4bitsEv"), S(img_bpl, "_ZNK6QImage12bytesPerLineEv"),
		S(img_wrap, "_ZN6QImageC1EPhiixNS_6FormatEPFvPvES2_"), S(img_free, "_ZN6QImageD1Ev"),
		S(img_convert, "_ZNK6QImage22convertToFormat_helperENS_6FormatE6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(icon_new, "_ZN5QIconC1ERK7QString"),
		S(pixmap_new, "_ZN7QPixmapC1ERK7QStringPKc6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(pixmap_copy, "_ZN7QPixmapC1ERKS_"), S(pixmap_assign, "_ZN7QPixmapaSERKS_"), S(pixmap_free, "_ZN7QPixmapD1Ev"),
		S(pixmap_image, "_ZNK7QPixmap7toImageEv"),
		S(pixmap_from, "_ZN7QPixmap9fromImageERK6QImage6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(pixmap_w, "_ZNK7QPixmap5widthEv"), S(pixmap_h, "_ZNK7QPixmap6heightEv"),
		S(icon_key, "_ZNK5QIcon8cacheKeyEv"),
		S(icon_pixmap, "_ZNK5QIcon6pixmapERK5QSizedNS_4ModeENS_5StateE"),
		S(icon_pixmap2, "_ZNK5QIcon6pixmapERK5QSizeNS_4ModeENS_5StateE"),
		S(icon_pixmap3, "_ZNK5QIcon6pixmapEP7QWindowRK5QSizeNS_4ModeENS_5StateE"),
		S(font_new, "_ZN5QFontC1ERK7QStringiib"), S(font_family, "_ZNK5QFont6familyEv"),
		S(font_pixels, "_ZN5QFont12setPixelSizeEi"), S(font_points, "_ZN5QFont12setPointSizeEi"),
		S(font_weight, "_ZN5QFont9setWeightENS_6WeightE"),
		S(string_utf8, "_ZN7QString8fromUtf8E14QByteArrayView"),
		S(array_free, "_ZN10QArrayData10deallocateEPS_xx"),
		S(notify, "_ZN12QApplication6notifyEP7QObjectP6QEvent"),
		S(set_sheet, "_ZN12QApplication13setStyleSheetERK7QString"),
		S(all_widgets, "_ZN12QApplication10allWidgetsEv"), S(widget_update, "_ZN7QWidget6updateEv"),
		S(post_event, "_ZN16QCoreApplication9postEventEP7QObjectP6QEventi"), S(event_new, "_ZN6QEventC1ENS_4TypeE"),
		S(cxx_new, "_Znwm"), S(app, "_ZN16QCoreApplication4selfE"),
#undef S
	};
	for (size_t i = 0; i < sizeof t / sizeof *t; i++) {
		void *f = dlsym(RTLD_NEXT, t[i].name);
		if (!f)
			return false;
		*(void **)t[i].slot = f;
	}
	return true;
}

/* A QString we were handed by value, let go of (its inline destructor) */
static void
string_drop(QString *s)
{
	if (s->d && !__atomic_sub_fetch((int *)s->d, 1, __ATOMIC_ACQ_REL))
		qt.array_free(s->d, 2, 16);
	s->d = NULL;
}

/* ── the inks ─────────────────────────────────────────────────────────────────── */
static struct {
	uint32_t ground, view, key, edge, edge2, faint, muted, text, strong, accent, select, on_select, asagi, flame;
} ink;
static unsigned generation;      /* what a colour worked out earlier is good for */

static void
read_inks(const char *path)
{
	FILE *f = fopen(path, "re");
	static const struct { const char *name; size_t off; } t[] = {
#define T(n, field) { n, offsetof(__typeof__(ink), field) }
		T("ground", ground), T("view", view), T("key", key), T("edge", edge), T("edge2", edge2),
		T("faint", faint), T("muted", muted), T("text", text), T("strong", strong), T("accent", accent),
		T("select", select), T("text_on_select", on_select), T("asagi", asagi), T("flame", flame),
#undef T
	};
	char name[32];
	unsigned v;

	if (!f)
		return;
	while (fscanf(f, "%31s %x", name, &v) == 2)
		for (size_t i = 0; i < sizeof t / sizeof *t; i++)
			if (!strcmp(name, t[i].name))
				*(uint32_t *)((char *)&ink + t[i].off) = v | 0xff000000u;
	fclose(f);
	generation++;
}

static inline uint32_t
mix(uint32_t a, uint32_t b, unsigned t)          /* t 0: a … 255: b */
{
	unsigned s = 255 - t;
	return 0xff000000u
		| ((((a >> 16 & 255) * s + (b >> 16 & 255) * t) / 255) << 16)
		| ((((a >> 8 & 255) * s + (b >> 8 & 255) * t) / 255) << 8)
		| (((a & 255) * s + (b & 255) * t) / 255);
}

/* A list's pixels: greys on the ramp ink → view, its selection's blues on the ramp ink → lacquer.
 * Anything else (a swatch, a colour of the user's) stays. */
static uint32_t
list_pixel(uint32_t p)
{
	unsigned r = p >> 16 & 255, g = p >> 8 & 255, b = p & 255;
	unsigned hi = r > g ? r : g, lo = r < g ? r : g;
	hi = hi > b ? hi : b;
	lo = lo < b ? lo : b;

	switch (p & 0xffffff) {
	case 0x808080: case 0x7f7f7f: case 0xf0f0f0:     /* a list's empty ground and its rules: no rules */
		return ink.view;
	case 0xd0d0d0:                                   /* a brush row's chip: light … */
		return ink.edge2;
	case 0x303030:                                   /* … and dark */
		return ink.muted;
	}
	if (hi - lo <= 6)
		return mix(ink.text, ink.view, r);
	if (b > r && g > r) {                            /* 9dd1f8 and black mixed with it (words, a gear on the row) */
		unsigned t = b * 255 / 0xf8;
		return mix(ink.on_select, ink.select, t > 255 ? 255 : t);
	}
	return p | 0xff000000u;
}

/* The same work once per colour (lists hold a few dozen): by the pixel's low bits */
static inline uint32_t
list_cached(uint32_t p)
{
	static struct { uint32_t from, to; unsigned gen; } memo[1024];
	unsigned i = (p ^ p >> 9 ^ p >> 17) & 1023;
	if (memo[i].from != p || memo[i].gen != generation) {
		memo[i].from = p;
		memo[i].to = list_pixel(p);
		memo[i].gen = generation;
	}
	return memo[i].to;
}

/* ── what each class's image is ───────────────────────────────────────────────── */
enum kind { PLAIN, LIST, LAYERS, METER, SURROUND, NAVI };

static enum kind
kind_of_class(const char *c)
{
	static const struct { const char *name; enum kind k; } t[] = {
		{ "WidgetBrushList", LIST }, { "WidgetLayerList", LAYERS }, { "WidgetBrushSize", LIST },
		{ "WidgetGradList", LIST }, { "WidgetThumbList", LIST }, { "WidgetBrushPreview", LIST },
		{ "WidgetBrushGamma", LIST }, { "WidgetBrushInputView", LIST },
		{ "WidgetTrackbarSimple", METER }, { "WidgetTrackbarSimple2", METER }, { "WidgetTrackbarStep", METER },
		{ "WidgetCanvas", SURROUND }, { "WidgetReferenceMain", SURROUND },
		{ "WidgetNaviMain", NAVI },
	};
	for (size_t i = 0; i < sizeof t / sizeof *t; i++)
		if (!strcmp(c, t[i].name))
			return t[i].k;
	return PLAIN;
}

static enum kind
kind_of_painter(void *painter)
{
	static struct { const void *meta; enum kind k; } memo[128];
	void *dev = qt.device(painter);
	void **vt, *widget;
	const void *meta;
	unsigned i;

	if (!dev)
		return PLAIN;
	vt = *(void ***)dev;                                 /* QPaintDevice: [2] devType() */
	if (((int (*)(void *))vt[2])(dev) != 1)              /* QInternal::Widget */
		return PLAIN;
	widget = (char *)dev - 16;                           /* QWidget: QObject (16 bytes), then QPaintDevice */
	meta = ((const void *(*)(void *))(*(void ***)widget)[0])(widget);    /* QObject: [0] metaObject() */
	i = ((uintptr_t)meta >> 4) % 128;
	if (memo[i].meta != meta) {
		memo[i].meta = meta;
		memo[i].k = kind_of_class(qt.class_name(meta));
	}
	return memo[i].k;
}

/* ── the images ───────────────────────────────────────────────────────────────── */
static uint32_t *scratch;
static size_t scratch_px;

static uint32_t *
scratch_for(size_t px)
{
	if (px > scratch_px) {
		uint32_t *n = realloc(scratch, px * 4);
		if (!n)
			return NULL;
		scratch = n;
		scratch_px = px;
	}
	return scratch;
}

/* A layer's thumbnail stays the picture's own: its frame (the mid greys, or the frame on the
 * lacquer) in column 30 marks the rows it covers. */
static void
list_layer_thumbs(uint32_t *dst, const uint32_t *src, int h, long stride)
{
	int y0 = -1;
	for (int y = 0; y <= h; y++) {
		uint32_t p = y < h ? src[y * stride + 29] & 0xffffff : 0;
		bool frame = p == 0x858e95 || p == 0x7f7f7f;
		if (frame && y0 < 0)
			y0 = y;
		else if (!frame && y0 >= 0) {
			for (int yy = y0; yy < y; yy++)
				memcpy(dst + yy * stride + 29, src + yy * stride + 29, 37 * 4);
			y0 = -1;
		}
	}
}

/* The design's meter (§4) over a slider's width: 6 + 2 px segments, 10 rows, centred. The level
 * is read from the slider's own picture: the columns its blue reaches, on the middle row. */
static void
draw_meter(uint32_t *dst, const uint32_t *src, int w, int h, long stride)
{
	const uint32_t *mid = src + (h / 2) * stride;
	int lit = 0, total = w - 2;
	int top = (h - 10) / 2, segs = (w + 2) / 8;

	for (int x = 1; x < w - 1; x++) {
		uint32_t p = mid[x];
		unsigned r = p >> 16 & 255, b = p & 255;
		if (b > r + 8)
			lit = x;
	}
	for (int y = 0; y < h; y++)
		for (int x = 0; x < w; x++)
			dst[y * stride + x] = ink.ground;
	for (int i = 0; i < segs; i++) {
		int x0 = i * 8, lit_rows;
		double level = total > 0 ? (double)lit / total : 0;
		double here = level * segs - i;
		uint32_t c = ink.asagi;
		if ((i + 1) * 10 > segs * 9)
			c = ink.accent;
		else if ((i + 1) * 10 > segs * 8)
			c = ink.flame;
		lit_rows = here >= 1 ? 10 : here > 0 ? (int)(here * 10 + 0.5) : 0;
		for (int r = 0; r < 10 && top + r < h; r++)
			for (int x = x0; x < x0 + 6 && x < w; x++)
				dst[(top + r) * stride + x] = r >= 10 - lit_rows ? c : ink.edge;
	}
}

/* The grey round the picture, from each end of every row, in place: the program paints only the
 * picture into this image again, and a pixel already the ground reads as more of the same. */
static void
surround_rows(uint32_t *img, int w, int h, long stride, uint32_t from)
{
	uint32_t a = from | 0xff000000u, b = from & 0xffffff, to = ink.ground, to2 = ink.ground & 0xffffff;

	for (int y = 0; y < h; y++) {
		uint32_t *row = img + y * stride;
		int x = 0, e = w - 1;
		for (; x < w; x++) {
			uint32_t p = row[x];
			if (p == a || p == b)
				row[x] = to;
			else if (p != to && p != to2)
				break;
		}
		for (; e > x; e--) {
			uint32_t p = row[e];
			if (p == a || p == b)
				row[e] = to;
			else if (p != to && p != to2)
				break;
		}
	}
}

static bool
drawn_again(void *painter, const void *rect, const void *image, const void *source, int flags)
{
	enum kind k = kind_of_painter(painter);
	int w, h, fmt;
	const unsigned char *bits;
	long bpl, stride;
	uint32_t *dst;
	unsigned char wrapper[OBJECT_BYTES];

	if (k == PLAIN)
		return false;
	fmt = qt.img_fmt(image);
	if (fmt != RGB32 && fmt != ARGB32)
		return false;
	w = qt.img_w(image);
	h = qt.img_h(image);
	bits = qt.img_cbits(image);
	bpl = qt.img_bpl(image);
	if (w <= 0 || h <= 0 || !bits || bpl % 4)
		return false;
	stride = bpl / 4;
	if (k == SURROUND) {
		surround_rows((uint32_t *)bits, w, h, stride, 0x707070);
		return false;
	}
	if (!(dst = scratch_for((size_t)stride * h)))
		return false;
	if (k == NAVI) {
		memcpy(dst, bits, (size_t)bpl * h);
		surround_rows(dst, w, h, stride, 0x808080);
		for (long i = 0; i < stride * h; i++)
			if ((dst[i] & 0xffffff) == 0xff0000)
				dst[i] = ink.accent;
	} else if (k == METER) {
		draw_meter(dst, (const uint32_t *)bits, w, h, stride);
	} else {
		const uint32_t *src = (const uint32_t *)bits;
		for (int y = 0; y < h; y++)
			for (int x = 0; x < w; x++)
				dst[y * stride + x] = list_cached(src[y * stride + x]);
		if (k == LAYERS && w >= 66)
			list_layer_thumbs(dst, src, h, stride);
	}
	qt.img_wrap(wrapper, (unsigned char *)dst, w, h, bpl, fmt, NULL, NULL);
	qt.draw_image_r(painter, rect, wrapper, source, flags);
	qt.img_free(wrapper);
	return true;
}

void
_ZN8QPainter9drawImageERK6QRectFRK6QImageS2_6QFlagsIN2Qt19ImageConversionFlagEE(void *painter, const void *rect,
		const void *image, const void *source, int flags)
{
	if (!on || !drawn_again(painter, rect, image, source, flags)) {
		if (!qt.draw_image_r)
			qt.draw_image_r = dlsym(RTLD_NEXT, "_ZN8QPainter9drawImageERK6QRectFRK6QImageS2_6QFlagsIN2Qt19ImageConversionFlagEE");
		qt.draw_image_r(painter, rect, image, source, flags);
	}
}

/* ── the face ─────────────────────────────────────────────────────────────────── */
static bool
string_is(const QString *s, const char *ascii)
{
	size_t n = strlen(ascii);
	if (!s->ptr || (size_t)s->size != n)
		return false;
	for (size_t i = 0; i < n; i++)
		if (s->ptr[i] != (unsigned char)ascii[i])
			return false;
	return true;
}

static QString sumi;             /* "Sumi UI", kept */

static bool
font_ours(const void *font)
{
	QString f = { 0 };
	bool mine;

	qt.font_family(&f, font);
	mine = string_is(&f, "Sumi UI");
	string_drop(&f);
	return mine;
}

void
_ZN5QFontC1ERK7QStringiib(void *self, const QString *family, int size, int weight, bool italic)
{
	static void (*real)(void *, const QString *, int, int, bool);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN5QFontC1ERK7QStringiib");
	if (on && string_is(family, "MS UI Gothic")) {
		real(self, &sumi, size, -1, false);
		qt.font_pixels(self, 14);
		return;
	}
	real(self, family, size, weight, italic);
}

void
_ZN5QFont12setPixelSizeEi(void *self, int size)
{
	static void (*real)(void *, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN5QFont12setPixelSizeEi");
	real(self, on && font_ours(self) ? 14 : size);
}

void
_ZN5QFont12setPointSizeEi(void *self, int size)
{
	static void (*real)(void *, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN5QFont12setPointSizeEi");
	if (on && font_ours(self))
		qt.font_pixels(self, 14);
	else
		real(self, size);
}

void
_ZN5QFont9setWeightENS_6WeightE(void *self, int weight)
{
	static void (*real)(void *, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN5QFont9setWeightENS_6WeightE");
	if (!on || !font_ours(self))
		real(self, weight);
}

/* ── the pictures ─────────────────────────────────────────────────────────────── */
/* ":/images/tool_brush.png" → our file of that name, or the program's own. Each name once. */
static const QString *
ours(const QString *path)
{
	static struct { char name[56]; QString file; bool done, found; } memo[512];
	char name[56];
	unsigned h = 5381, i;

	if (!path->ptr || path->size < 10 || path->size >= 9 + (long)sizeof name || !string_is(&(QString){ 0, path->ptr, 9 }, ":/images/"))
		return path;
	for (i = 0; i < (unsigned)path->size - 9; i++) {
		if (path->ptr[9 + i] > 126 || path->ptr[9 + i] == '/')
			return path;
		name[i] = (char)path->ptr[9 + i];
		h = h * 33 + (unsigned char)name[i];
	}
	name[i] = 0;
	for (unsigned n = 0; n < 512; n++, h++) {
		__typeof__(&memo[0]) e = &memo[h % 512];
		if (!e->done) {
			char file[PATH_MAX];
			int len = snprintf(file, sizeof file, "%s/.local/share/fedokawaii/firealpaca/icons/%s", home, name);
			snprintf(e->name, sizeof e->name, "%s", name);
			e->done = true;
			e->found = len > 0 && len < (int)sizeof file && access(file, R_OK) == 0;
			if (e->found)
				qt.string_utf8(&e->file, len, file);
		}
		if (!strcmp(e->name, name))
			return e->found ? &e->file : path;
	}
	return path;
}

/* the icons that are ours, by QIcon::cacheKey: their pixmaps get their state's ink */
static long mask_keys[1024];

static void
mask_add(long key)
{
	if (!key)
		return;
	for (unsigned n = 0; n < 1024; n++) {
		unsigned i = ((unsigned long)key >> 32 ^ (unsigned long)key) * 2654435761u % 1024 + n;
		if (!mask_keys[i % 1024] || mask_keys[i % 1024] == key) {
			mask_keys[i % 1024] = key;
			return;
		}
	}
}

static bool
mask_has(long key)
{
	for (unsigned n = 0; n < 1024; n++) {
		unsigned i = ((unsigned long)key >> 32 ^ (unsigned long)key) * 2654435761u % 1024 + n;
		if (!mask_keys[i % 1024])
			return false;
		if (mask_keys[i % 1024] == key)
			return true;
	}
	return false;
}

void
_ZN5QIconC1ERK7QString(void *self, const QString *path)
{
	static void (*real)(void *, const QString *);
	const QString *p;

	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN5QIconC1ERK7QString");
	if (!on) {
		real(self, path);
		return;
	}
	p = ours(path);
	real(self, p);
	if (p != path)
		mask_add(qt.icon_key(self));
}

void
_ZN7QPixmapC1ERK7QStringPKc6QFlagsIN2Qt19ImageConversionFlagEE(void *self, const QString *path, const char *format, int flags)
{
	static void (*real)(void *, const QString *, const char *, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN7QPixmapC1ERK7QStringPKc6QFlagsIN2Qt19ImageConversionFlagEE");
	real(self, on ? ours(path) : path, format, flags);
}

/* The state's ink on a mask, each once (key, size, ink), kept: a toolbar is painted often. */
static void
inked(void *ret, const void *icon, int mode, int state)
{
	static struct { long key; uint32_t c; int w, h; unsigned char pm[OBJECT_BYTES]; bool used; } memo[1536];
	long key = qt.icon_key(icon);
	uint32_t c;
	unsigned char img[OBJECT_BYTES], argb[OBJECT_BYTES];
	int w, h;
	long stride;
	uint32_t *px;
	unsigned slot;

	if (!mask_has(key))
		return;
	c = mode == MODE_DISABLED ? ink.faint : state == 0 && mode != MODE_SELECTED ? ink.text : ink.on_select;
	w = qt.pixmap_w(ret);
	h = qt.pixmap_h(ret);
	if (w <= 0 || h <= 0)
		return;
	slot = (unsigned)(((unsigned long)key * 31 + c) * 2654435761u + (unsigned)w * 131 + (unsigned)h) % 1536;
	for (unsigned n = 0; n < 1536; n++, slot = (slot + 1) % 1536) {
		if (memo[slot].used && memo[slot].key == key && memo[slot].c == c && memo[slot].w == w && memo[slot].h == h) {
			qt.pixmap_assign(ret, memo[slot].pm);
			return;
		}
		if (!memo[slot].used)
			break;
	}
	qt.pixmap_image(img, ret);
	qt.img_convert(argb, img, ARGB32, 0);
	qt.img_free(img);
	px = (uint32_t *)qt.img_bits(argb);
	stride = qt.img_bpl(argb) / 4;
	for (int y = 0; y < h; y++)
		for (int x = 0; x < w; x++)
			px[y * stride + x] = (px[y * stride + x] & 0xff000000u) | (c & 0xffffff);
	if (!memo[slot].used) {
		qt.pixmap_from(memo[slot].pm, argb, 0);
		memo[slot].key = key;
		memo[slot].c = c;
		memo[slot].w = w;
		memo[slot].h = h;
		memo[slot].used = true;
		qt.pixmap_assign(ret, memo[slot].pm);
	} else {                                     /* (the table full: not kept) */
		unsigned char pm[OBJECT_BYTES];
		qt.pixmap_from(pm, argb, 0);
		qt.pixmap_assign(ret, pm);
		qt.pixmap_free(pm);
	}
	qt.img_free(argb);
}

void
_ZNK5QIcon6pixmapERK5QSizedNS_4ModeENS_5StateE(void *ret, const void *self, const void *size, double dpr, int mode, int state)
{
	static void (*real)(void *, const void *, const void *, double, int, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZNK5QIcon6pixmapERK5QSizedNS_4ModeENS_5StateE");
	real(ret, self, size, dpr, mode, state);
	if (on)
		inked(ret, self, mode, state);
}

void
_ZNK5QIcon6pixmapERK5QSizeNS_4ModeENS_5StateE(void *ret, const void *self, const void *size, int mode, int state)
{
	static void (*real)(void *, const void *, const void *, int, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZNK5QIcon6pixmapERK5QSizeNS_4ModeENS_5StateE");
	real(ret, self, size, mode, state);
	if (on)
		inked(ret, self, mode, state);
}

void
_ZNK5QIcon6pixmapEP7QWindowRK5QSizeNS_4ModeENS_5StateE(void *ret, const void *self, void *window, const void *size, int mode, int state)
{
	static void (*real)(void *, const void *, void *, const void *, int, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZNK5QIcon6pixmapEP7QWindowRK5QSizeNS_4ModeENS_5StateE");
	real(ret, self, window, size, mode, state);
	if (on)
		inked(ret, self, mode, state);
}

/* ── the mood ─────────────────────────────────────────────────────────────────── */
/* The sheet from the current mood's folder, @THEME@ in it made absolute (each mood its own path:
 * Qt keeps pictures by their path), and the inks. */
static void
load_mood(void)
{
	char link[PATH_MAX], dir[PATH_MAX], file[PATH_MAX];
	FILE *f;
	long n;
	char *text, *out;
	size_t cap, used = 0;
	QString sheet = { 0 };

	if (snprintf(link, sizeof link, "%s/.config/fedokawaii/current", home) >= (int)sizeof link || !realpath(link, dir))
		return;
	if (snprintf(file, sizeof file, "%s/firealpaca.conf", dir) >= (int)sizeof file)
		return;
	read_inks(file);
	if (snprintf(file, sizeof file, "%s/firealpaca.qss", dir) >= (int)sizeof file || !(f = fopen(file, "re")))
		return;
	fseek(f, 0, SEEK_END);
	n = ftell(f);
	rewind(f);
	if (n <= 0 || !(text = malloc((size_t)n + 1))) {
		fclose(f);
		return;
	}
	n = (long)fread(text, 1, (size_t)n, f);
	fclose(f);
	text[n] = 0;
	cap = (size_t)n * 4 + 1;
	if (!(out = malloc(cap))) {
		free(text);
		return;
	}
	for (char *p = text; *p;) {
		char *at = strstr(p, "@THEME@");
		size_t len = at ? (size_t)(at - p) : strlen(p), dlen = strlen(dir);
		if (used + len + dlen + 1 >= cap) {
			char *grown = realloc(out, cap = (cap + len + dlen) * 2);
			if (!grown) {
				free(text);
				free(out);
				return;
			}
			out = grown;
		}
		memcpy(out + used, p, len);
		used += len;
		if (!at)
			break;
		memcpy(out + used, dir, dlen);
		used += dlen;
		p = at + 7;
	}
	qt.string_utf8(&sheet, (long)used, out);
	qt.set_sheet(*qt.app, &sheet);
	string_drop(&sheet);
	free(text);
	free(out);
}

static void
repaint_all(void)
{
	QPtrList l = { 0 };

	qt.all_widgets(&l);
	for (long i = 0; i < l.size; i++)
		qt.widget_update(l.ptr[i]);
	if (l.d && !__atomic_sub_fetch((int *)l.d, 1, __ATOMIC_ACQ_REL))
		qt.array_free(l.d, 8, 16);
}

/* Waits for kawa-theme to turn the "current" link; the main thread then does the work */
static void *
watcher(void *unused)
{
	char dir[PATH_MAX], buf[4096];
	int fd = inotify_init1(IN_CLOEXEC);

	(void)unused;
	if (fd < 0 || snprintf(dir, sizeof dir, "%s/.config/fedokawaii", home) >= (int)sizeof dir
			|| inotify_add_watch(fd, dir, IN_MOVED_TO | IN_CREATE) < 0)
		return NULL;
	for (;;) {
		ssize_t n = read(fd, buf, sizeof buf);
		bool ours_changed = false;
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			return NULL;
		for (char *p = buf; p < buf + n;) {
			struct inotify_event *e = (struct inotify_event *)p;
			if (e->len && !strcmp(e->name, "current"))
				ours_changed = true;
			p += sizeof *e + e->len;
		}
		if (ours_changed && *qt.app) {
			void *ev = qt.cxx_new(OBJECT_BYTES);
			qt.event_new(ev, KAWA_EVENT);
			qt.post_event(*qt.app, ev, 0);
		}
	}
}

/* The sheet before the first window (the application just made), the waiting thread with it */
static void
application_made(void)
{
	pthread_t t;
	pthread_attr_t a;

	if (!on)
		return;
	load_mood();
	pthread_attr_init(&a);
	pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
	pthread_attr_setstacksize(&a, 128 * 1024);
	pthread_create(&t, &a, watcher, NULL);
	pthread_attr_destroy(&a);
}

void
_ZN12QApplicationC2ERiPPci(void *self, int *argc, char **argv, int flags)
{
	static void (*real)(void *, int *, char **, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN12QApplicationC2ERiPPci");
	real(self, argc, argv, flags);
	application_made();
}

void
_ZN12QApplicationC1ERiPPci(void *self, int *argc, char **argv, int flags)
{
	static void (*real)(void *, int *, char **, int);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN12QApplicationC1ERiPPci");
	real(self, argc, argv, flags);
	application_made();
}

bool
_ZN12QApplication6notifyEP7QObjectP6QEvent(void *self, void *receiver, void *event)
{
	static bool (*real)(void *, void *, void *);

	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN12QApplication6notifyEP7QObjectP6QEvent");
	if (on && *(unsigned short *)((char *)event + 8) == KAWA_EVENT && pthread_equal(pthread_self(), main_thread)) {
		load_mood();
		repaint_all();
		return true;
	}
	return real(self, receiver, event);
}

__attribute__((constructor)) static void
start(void)
{
	char exe[PATH_MAX];
	ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
	const char *h = getenv("HOME");
	const char *base;

	unsetenv("LD_PRELOAD");                      /* never into what it starts */
	if (n <= 0 || !h || strlen(h) >= sizeof home)
		return;
	exe[n] = 0;
	base = strrchr(exe, '/');
	if (!base || strcmp(base + 1, "FireAlpaca"))
		return;
	if (getenv("KAWA_FA_PLAIN"))
		return;
	snprintf(home, sizeof home, "%s", h);
	main_thread = pthread_self();
	if (!resolve())
		return;
	qt.string_utf8(&sumi, 7, "Sumi UI");
	on = true;
}
