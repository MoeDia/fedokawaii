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
 *                 sheet; KAWATHEME in it is the mood's folder (tools/build-themes.py writes it)
 *   the inks      current/firealpaca.conf: "token rrggbb" lines, from the same palette
 *   its images    QPainter::drawImage: by the class of the widget drawn on, a list's greys and
 *                 its selection's blues become the mood's ramps (white → view, black → text;
 *                 9dd1f8 → the lacquer, black → the ink on it), a slider is drawn again as the
 *                 design's meter (§4: 6 + 2 px segments, flame and vermilion at the top), the
 *                 grey round the canvas becomes the ground, the palette's rules the list's. A
 *                 layer's thumbnail, a swatch, the picture itself: left as they are
 *   its face      QFont: "MS UI Gothic" at its 10–13 px becomes Sumi UI at 14, never bold
 *   its pictures  QIcon(":/images/x.png"), QPixmap(":/images/x.png"): our own drawing of the
 *                 same name when ~/.local/share/fedokawaii/firealpaca/icons/ has one. They are
 *                 masks: an icon is painted at QIcon::pixmap in its state's ink (text, faint when
 *                 disabled, the lacquer's when checked), so a mood change needs no second set
 *   the moods     a thread waits on ~/.config/fedokawaii for the "current" link to change
 *                 (kawa-theme) and has the main thread load the new sheet and inks: FireAlpaca
 *                 changes with the desktop, a picture in work and all
 *   its panels    placed by hand in its code for a narrower face: after a panel is laid out its
 *                 children are put on the design's grid (the table PLACES); Qt's underlined
 *                 mnemonics are off (in a pixel face F_ reads E)
 *   its keys      F2 to F7 show and hide the panels kept out of the way (PANEL_KEYS)
 *   its dialogs   Open and Save are the desktop's own (kawa-pick: yazi in a small terminal, as
 *                 every other program's), the program waiting meanwhile
 *   a file        the program takes none on its command line: KAWA_FA_OPEN=FILE at its start, or
 *                 the file named in $XDG_RUNTIME_DIR/kawa-firealpaca.open while it runs
 *                 (kawa-sketch writes both), goes through its own File → Open
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
#include <sys/wait.h>
#include <unistd.h>

typedef struct { void *d; unsigned short *ptr; long size; } QString;   /* QArrayDataPointer<char16_t> */
typedef struct { void *d; void **ptr; long size; } QPtrList;           /* QList<T*> */
enum { RGB32 = 4, ARGB32 = 5 };
enum { MODE_DISABLED = 1, MODE_SELECTED = 3 };                         /* QIcon::Mode */
enum { STATE_OFF = 1 };                                                /* QIcon::State: On is 0 */
enum { KAWA_EVENT = 1731 };                                            /* QEvent::User + 731 */
#define OBJECT_BYTES 64                                                /* room for a QImage or QPixmap (32) */

static bool on;                  /* FireAlpaca itself, every symbol found, not asked to stay plain */
static pthread_t main_thread;
static char home[PATH_MAX - 128];

/* ── Qt's functions ───────────────────────────────────────────────────────────── */
static struct {
	void (*draw_image_r)(void *, const void *, const void *, const void *, int);
	void *(*device)(void *);
	const char *(*class_name)(const void *);
	int (*img_w)(const void *), (*img_h)(const void *), (*img_fmt)(const void *);
	const unsigned char *(*img_cbits)(const void *);
	unsigned char *(*img_bits)(void *);
	long (*img_bpl)(const void *);
	void (*img_wrap)(void *, unsigned char *, int, int, long, int, void *, void *);
	void (*img_free)(void *);
	void (*img_convert)(void *, const void *, int, int);
	void (*pixmap_assign)(void *, const void *);
	void (*pixmap_free)(void *);
	void (*pixmap_image)(void *, const void *);
	void (*pixmap_from)(void *, const void *, int);
	int (*pixmap_w)(const void *), (*pixmap_h)(const void *);
	long (*icon_key)(const void *);
	void (*font_family)(QString *, const void *);
	void (*font_pixels)(void *, int);
	void (*string_utf8)(QString *, long, const char *);
	void (*array_free)(void *, long, long);
	void (*set_sheet)(void *, const QString *);
	void (*all_widgets)(QPtrList *);
	void (*widget_update)(void *);
	void (*post_event)(void *, void *, int);
	void (*event_new)(void *, int);
	void *(*cxx_new)(unsigned long);
	void **app;
	void (*action_activate)(void *, int);
	void (*process_events)(int);
	void (*set_geometry)(void *, const void *);
	void (*layout_margins)(void *, int, int, int, int);
	void (*key_new)(void *, const QString *, int);
	void (*key_free)(void *);
	void (*action_key)(void *, const void *);
} qt;

static bool
resolve(void)
{
	struct { void *slot; const char *name; } t[] = {
#define S(field, sym) { &qt.field, sym }
		S(draw_image_r, "_ZN8QPainter9drawImageERK6QRectFRK6QImageS2_6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(device, "_ZNK8QPainter6deviceEv"),
		S(class_name, "_ZNK11QMetaObject9classNameEv"),
		S(img_w, "_ZNK6QImage5widthEv"), S(img_h, "_ZNK6QImage6heightEv"), S(img_fmt, "_ZNK6QImage6formatEv"),
		S(img_cbits, "_ZNK6QImage4bitsEv"), S(img_bits, "_ZN6QImage4bitsEv"), S(img_bpl, "_ZNK6QImage12bytesPerLineEv"),
		S(img_wrap, "_ZN6QImageC1EPhiixNS_6FormatEPFvPvES2_"), S(img_free, "_ZN6QImageD1Ev"),
		S(img_convert, "_ZNK6QImage22convertToFormat_helperENS_6FormatE6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(pixmap_assign, "_ZN7QPixmapaSERKS_"), S(pixmap_free, "_ZN7QPixmapD1Ev"),
		S(pixmap_image, "_ZNK7QPixmap7toImageEv"),
		S(pixmap_from, "_ZN7QPixmap9fromImageERK6QImage6QFlagsIN2Qt19ImageConversionFlagEE"),
		S(pixmap_w, "_ZNK7QPixmap5widthEv"), S(pixmap_h, "_ZNK7QPixmap6heightEv"),
		S(icon_key, "_ZNK5QIcon8cacheKeyEv"),
		S(font_family, "_ZNK5QFont6familyEv"), S(font_pixels, "_ZN5QFont12setPixelSizeEi"),
		S(string_utf8, "_ZN7QString8fromUtf8E14QByteArrayView"),
		S(array_free, "_ZN10QArrayData10deallocateEPS_xx"),
		S(set_sheet, "_ZN12QApplication13setStyleSheetERK7QString"),
		S(all_widgets, "_ZN12QApplication10allWidgetsEv"), S(widget_update, "_ZN7QWidget6updateEv"),
		S(post_event, "_ZN16QCoreApplication9postEventEP7QObjectP6QEventi"), S(event_new, "_ZN6QEventC1ENS_4TypeE"),
		S(cxx_new, "_Znwm"), S(app, "_ZN16QCoreApplication4selfE"),
		S(action_activate, "_ZN7QAction8activateENS_11ActionEventE"),
		S(process_events, "_ZN16QCoreApplication13processEventsE6QFlagsIN10QEventLoop17ProcessEventsFlagEE"),
		S(set_geometry, "_ZN7QWidget11setGeometryERK5QRect"),
		S(layout_margins, "_ZN7QLayout18setContentsMarginsEiiii"),
		S(key_new, "_ZN12QKeySequenceC1ERK7QStringNS_14SequenceFormatE"), S(key_free, "_ZN12QKeySequenceD1Ev"),
		S(action_key, "_ZN7QAction11setShortcutERK12QKeySequence"),
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
	case 0xf3f9fe:                                   /* the row under the pointer */
		return ink.key;
	case 0xff0000:                                   /* a brush's size changed from its own */
		return ink.accent;
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
enum kind { PLAIN, LIST, BRUSHES, LAYERS, PALETTE, METER, SURROUND, NAVI };

static enum kind
kind_of_class(const char *c)
{
	static const struct { const char *name; enum kind k; } t[] = {
		{ "WidgetBrushList", BRUSHES }, { "WidgetLayerList", LAYERS }, { "WidgetPaletteList", PALETTE }, { "WidgetBrushSize", LIST },
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

/* A layer's row is 40 px between its dark rules: the eye's cell, then the thumbnail, its shape the
 * picture's, in the 50 px after it (the name starts past them). The thumbnail, a framed rectangle
 * (all four corners drawn), stays the picture's own; a folder's mask has corners of the row's fill.
 * Rows hang lower with each folder they are in: the eye's cell says where. */
static void
layer_row(uint32_t *dst, const uint32_t *src, int w, int h, long stride, int top)
{
	int probe = top + 2 >= 0 ? top + 2 : top + 42, eye = -1;
	int x0 = -1, x1 = -1, y0 = -1, y1 = -1;
	int ya = top + 2 > 0 ? top + 2 : 0, yb = top + 38 < h ? top + 38 : h;
	uint32_t fill;

	if (probe >= h || ya >= yb)
		return;
	for (int x = 0; x < w / 2; x++)                      /* the last rule before the name: the eye's cell ends there */
		if ((src[probe * stride + x] & 0xffffff) == 0x202020)
			eye = x;
	if (eye < 0 || eye + 53 > w)
		return;
	fill = src[probe * stride + eye + 52];
	/* the frame's sides: the outermost columns drawn for 12 rows and more */
	for (int x = eye + 3; x < eye + 52; x++) {
		int drawn = 0;
		for (int y = ya; y < yb; y++)
			drawn += src[y * stride + x] != fill;
		if (drawn >= 12) {
			x0 = x0 < 0 ? x : x0;
			x1 = x;
		}
	}
	if (x0 < 0 || x1 - x0 < 8)
		return;
	/* its top and foot: the outermost rows drawn from side to side (a checked thumbnail's inside is not) */
	for (int y = ya; y < yb; y++) {
		int drawn = 0;
		for (int x = x0; x <= x1; x++)
			drawn += src[y * stride + x] != fill;
		if (drawn * 10 >= (x1 - x0 + 1) * 9) {
			y0 = y0 < 0 ? y : y0;
			y1 = y;
		}
	}
	/* a frame is a mid grey over the picture's edge; our folder's mask, drawn the same shape, pure black */
	if (y0 < 0 || y1 - y0 < 8 || !(src[y0 * stride + (x0 + x1) / 2] & 0xffffff))
		return;
	for (int y = y0; y <= y1; y++)
		memcpy(dst + y * stride + x0, src + y * stride + x0, (size_t)(x1 - x0 + 1) * 4);
}

static void
layer_thumbs(uint32_t *dst, const uint32_t *src, int w, int h, long stride)
{
	int last = -1;

	for (int y = 0; y < h; y++)
		if ((src[y * stride + w - 3] & 0xffffff) == 0x202020 && (src[y * stride + w / 2] & 0xffffff) == 0x202020) {
			if (last < 0 && y >= 40)
				continue;
			if (last < 0 && y > 0)
				layer_row(dst, src, w, h, stride, y - 40);      /* (the row scrolled partly away) */
			layer_row(dst, src, w, h, stride, y);
			last = y;
		}
}

/* The palette: its cells keep their colours (a swatch may be any colour); the rules between them
 * (e7e7e7) and the checks of the empty places (e8e8e8 and white, in fours) are the list's ground, the
 * picked cell's frame the words' ink round the ground's, seen on any colour. */
static void
palette_pixels(uint32_t *dst, const uint32_t *src, int w, int h, long stride)
{
	for (int y = 0; y < h; y++)
		for (int x = 0; x < w; x++) {
			uint32_t p = src[y * stride + x], q = p & 0xffffff;
			if (q == 0xe7e7e7 || q == 0xe8e8e8)
				p = ink.view;
			else if (q == 0xffffff && ((x + 4 < w && (src[y * stride + x + 4] & 0xffffff) == 0xe8e8e8)
						|| (x >= 4 && (src[y * stride + x - 4] & 0xffffff) == 0xe8e8e8)))
				p = ink.view;
			else if (q == 0xf93535)
				p = ink.strong;
			else if (q == 0xc40000)
				p = ink.ground;
			dst[y * stride + x] = p | 0xff000000u;
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
	} else if (k == PALETTE) {
		palette_pixels(dst, (const uint32_t *)bits, w, h, stride);
	} else {
		const uint32_t *src = (const uint32_t *)bits;
		for (int y = 0; y < h; y++)
			for (int x = 0, lacquer = 0; x < w; x++) {
				uint32_t p = src[y * stride + x];
				if ((p & 0xffffff) == 0x9dd1f8)
					lacquer = x + 1;
				/* (a row of the selection: its black words and marks in the lacquer's ink. The row's
				 * pixels left of its first blue are looked at again below) */
				dst[y * stride + x] = k == LAYERS && (p & 0xffffff) == 0x202020 ? ink.edge
					: lacquer && ((p & 0xc0c0c0) == 0 || (p & 0xffffff) == 0xff0000) ? ink.on_select
					: lacquer && (p & 0xffffff) == 0x808080 ? mix(ink.on_select, ink.select, 128)    /* the gear, at rest */
					: list_cached(p);
			}
		if (k == LAYERS)
			layer_thumbs(dst, src, w, h, stride);
		if (k == BRUSHES && w > 18)                  /* the program's little colour chip by each name: its row's own ground */
			for (int y = 0; y < h; y++)
				for (int x = 2; x < 18; x++)
					dst[y * stride + x] = dst[y * stride + 18];
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
	if (!strcmp(name, "fa_128.png")) {                   /* (its logo on a document's tab: nothing there) */
		strcpy(name, "firealpaca24.png");
		h = 5381;
		for (i = 0; name[i]; i++)
			h = h * 33 + (unsigned char)name[i];
	}
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
	c = mode == MODE_DISABLED ? ink.faint : state == STATE_OFF && mode != MODE_SELECTED ? ink.text : ink.on_select;
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
/* The sheet from the current mood's folder, KAWATHEME in it made absolute (each mood its own path:
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
		char *at = strstr(p, "KAWATHEME");
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
		p = at + 9;
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

/* ── a file to open, through the program's own File → Open ─────────────────────── */
static void *action_open;        /* QAction action_FileOpen */
static void *action_fit;         /* QAction FIT_NAME: the page, whole, in its window */
#define FIT_NAME "action_ViewZoomAdjust"
#define FIT_NAME_LEN 21
static char *open_file;          /* what its next Open dialog answers, unasked */
/* The panels kept out of the way, one key each (its own shortcut settings cannot reach these; Tab, all of them) */
static struct { const char *action, *key; void *ptr; } PANEL_KEYS[] = {
	{ "action_WindowNavigator", "F2", NULL }, { "action_WindowBrushSize", "F3", NULL },
	{ "action_WindowBrushPreview", "F4", NULL }, { "action_WindowColorHistory", "F5", NULL },
	{ "action_WindowReference", "F6", NULL }, { "action_WindowStatus", "F7", NULL },
};
static bool panel_keys_set;
static bool wanted_mood, wanted_open;
static int fit_left;             /* a file just opened: its page fitted again as its window settles */

void
_ZN7QObject13setObjectNameE14QAnyStringView(void *self, const void *data, size_t tagged)
{
	static void (*real)(void *, const void *, size_t);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN7QObject13setObjectNameE14QAnyStringView");
	if (on && !(tagged >> 63) && (tagged & ~(3ul << 62)) == 15 && !memcmp(data, "action_FileOpen", 15))
		action_open = self;
	if (on && !(tagged >> 63) && (tagged & ~(3ul << 62)) == FIT_NAME_LEN && !memcmp(data, FIT_NAME, FIT_NAME_LEN))
		action_fit = self;
	if (on && !(tagged >> 63))
		for (size_t i = 0; i < sizeof PANEL_KEYS / sizeof *PANEL_KEYS; i++)
			if ((tagged & ~(3ul << 62)) == strlen(PANEL_KEYS[i].action) && !memcmp(data, PANEL_KEYS[i].action, tagged & ~(3ul << 62)))
				PANEL_KEYS[i].ptr = self;
	real(self, data, tagged);
}

static char *
read_request(void)
{
	char path[PATH_MAX], *line = NULL, *rt = getenv("XDG_RUNTIME_DIR");
	size_t cap = 0;
	FILE *f;

	if (!rt || snprintf(path, sizeof path, "%s/kawa-firealpaca.open", rt) >= (int)sizeof path || !(f = fopen(path, "re")))
		return NULL;
	if (getline(&line, &cap, f) > 0)
		line[strcspn(line, "\n")] = 0;
	fclose(f);
	unlink(path);
	return line;
}

/* ── the dialogs: the desktop's own ───────────────────────────────────────────── */
static bool in_dialog;           /* input to the program is dropped while its dialog is out */

static char *
to_utf8(const QString *s)
{
	char *o = malloc((s->size > 0 ? (size_t)s->size : 0) * 3 + 1), *p = o;

	if (!o)
		return NULL;
	for (long i = 0; i < s->size; i++) {
		unsigned c = s->ptr[i];
		if (c < 0x80)
			*p++ = (char)c;
		else if (c < 0x800) {
			*p++ = (char)(0xc0 | c >> 6);
			*p++ = (char)(0x80 | (c & 63));
		} else {
			*p++ = (char)(0xe0 | c >> 12);
			*p++ = (char)(0x80 | (c >> 6 & 63));
			*p++ = (char)(0x80 | (c & 63));
		}
	}
	*p = 0;
	return o;
}

static bool
helper_exists(char *out, size_t n)
{
	return snprintf(out, n, "%s/.local/bin/kawa-pick", home) < (int)n && access(out, X_OK) == 0;
}

/* kawa-pick MULTIPLE 0 SAVE START OUT, the program's events going on meanwhile. The answer: the first
 * line of OUT, or NULL (cancelled). For a save, kawa-pick wants the file there already: its stand-in. */
static char *
pick(const char *pickbin, bool save, const char *start)
{
	char out[PATH_MAX], line[PATH_MAX], *rt = getenv("XDG_RUNTIME_DIR"), *answer = NULL;
	int fd, status = 0;
	pid_t pid;
	FILE *f;

	if (snprintf(out, sizeof out, "%s/kawa-firealpaca.pick.XXXXXX", rt ? rt : "/tmp") >= (int)sizeof out || (fd = mkstemp(out)) < 0)
		return NULL;
	close(fd);
	if (save && access(start, F_OK) != 0 && (f = fopen(start, "wxe"))) {
		fputs("the file being saved\n", f);
		fclose(f);
	}
	pid = fork();
	if (pid == 0) {
		execl(pickbin, pickbin, "0", "0", save ? "1" : "0", start, out, (char *)NULL);
		_exit(127);
	}
	if (pid > 0) {
		in_dialog = true;
		while (waitpid(pid, &status, WNOHANG) == 0) {
			qt.process_events(0);
			usleep(16000);
		}
		in_dialog = false;
		if ((f = fopen(out, "re"))) {
			if (fgets(line, sizeof line, f)) {
				line[strcspn(line, "\n")] = 0;
				if (line[0])
					answer = strdup(line);
			}
			fclose(f);
		}
	}
	unlink(out);
	return answer;
}

/* Where a dialog starts: the folder the program named, or home; for a save with the name it suggests
 * (its filter's first extension), never over a file that is there. */
static char *
start_of(const QString *dir, const QString *filter, bool save)
{
	char *d = dir && dir->size > 0 ? to_utf8(dir) : strdup(home), *out = NULL, ext[16] = "mdp";
	struct stat st;

	if (!d)
		return NULL;
	if (!save) {
		if (stat(d, &st) == 0 && S_ISDIR(st.st_mode))
			return d;
		char *cut = strrchr(d, '/');
		if (cut && cut != d)
			*cut = 0;
		return d;
	}
	{
		char *f = filter ? to_utf8(filter) : NULL, *star = f ? strstr(f, "*.") : NULL;
		char *slash = strrchr(d, '/');
		bool folder = stat(d, &st) == 0 && S_ISDIR(st.st_mode);
		if (star) {
			size_t k = 0;
			star += 2;
			while (k + 1 < sizeof ext && star[k] && star[k] != ')' && star[k] != ' ' && star[k] != ';')
				k++;
			memcpy(ext, star, k);
			ext[k] = 0;
		}
		free(f);
		if (folder || !strchr(slash ? slash : d, '.')) {       /* a folder, or a name with no extension of its own */
			if (asprintf(&out, folder ? "%s/untitled.%s" : "%s.%s", d, ext) < 0)
				out = NULL;
			free(d);
			d = out;
		}
	}
	if (d && access(d, F_OK) == 0) {               /* a name of its own: "name (1).ext", as the desktop's */
		char *dot = strrchr(d, '.'), *slash = strrchr(d, '/'), *free_name = NULL;
		const char *tail = dot && slash && dot > slash ? dot : "";
		size_t stem = strlen(d) - strlen(tail);
		for (int n = 1; n < 1000; n++) {
			if (asprintf(&free_name, "%.*s (%d)%s", (int)stem, d, n, tail) < 0)
				break;
			if (access(free_name, F_OK) != 0)
				break;
			free(free_name);
			free_name = NULL;
		}
		if (free_name) {
			free(d);
			d = free_name;
		}
	}
	return d;
}

void
_ZN11QFileDialog15getOpenFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE(QString *ret, void *parent,
		const QString *caption, const QString *dir, const QString *filter, QString *selected, int options)
{
	static void (*real)(QString *, void *, const QString *, const QString *, const QString *, QString *, int);
	char pickbin[PATH_MAX];

	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN11QFileDialog15getOpenFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE");
	if (on && open_file) {
		qt.string_utf8(ret, (long)strlen(open_file), open_file);
		free(open_file);
		open_file = NULL;
		return;
	}
	if (on && helper_exists(pickbin, sizeof pickbin)) {
		char *start = start_of(dir, filter, false), *got = start ? pick(pickbin, false, start) : NULL;
		qt.string_utf8(ret, got ? (long)strlen(got) : 0, got ? got : "");
		free(start);
		free(got);
		return;
	}
	real(ret, parent, caption, dir, filter, selected, options);
}

void
_ZN11QFileDialog15getSaveFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE(QString *ret, void *parent,
		const QString *caption, const QString *dir, const QString *filter, QString *selected, int options)
{
	static void (*real)(QString *, void *, const QString *, const QString *, const QString *, QString *, int);
	char pickbin[PATH_MAX];

	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN11QFileDialog15getSaveFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE");
	if (on && helper_exists(pickbin, sizeof pickbin)) {
		char *start = start_of(dir, filter, true), *got = start ? pick(pickbin, true, start) : NULL;
		qt.string_utf8(ret, got ? (long)strlen(got) : 0, got ? got : "");
		free(start);
		free(got);
		return;
	}
	real(ret, parent, caption, dir, filter, selected, options);
}

/* ── mnemonics hidden: an underline under F reads E in a pixel face; Alt+letter still works ── */
void
_ZN8QPainter8drawTextERK5QRectiRK7QStringPS0_(void *self, const void *rect, int flags, const QString *text, void *bound)
{
	static void (*real)(void *, const void *, int, const QString *, void *);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN8QPainter8drawTextERK5QRectiRK7QStringPS0_");
	if (on && flags & 0x0800)                            /* Qt::TextShowMnemonic → Qt::TextHideMnemonic */
		flags = (flags & ~0x0800) | 0x8000;
	real(self, rect, flags, text, bound);
}

void
_ZN8QPainter8drawTextERK6QRectFiRK7QStringPS0_(void *self, const void *rect, int flags, const QString *text, void *bound)
{
	static void (*real)(void *, const void *, int, const QString *, void *);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN8QPainter8drawTextERK6QRectFiRK7QStringPS0_");
	if (on && flags & 0x0800)
		flags = (flags & ~0x0800) | 0x8000;
	real(self, rect, flags, text, bound);
}

/* ── words its hand-placed panels have no room for ────────────────────────────── */
static const struct { const char *from, *to; } WORDS[] = {
	{ "Show only Active Layer", "Active only" },
	{ "Add Below", "Below" },
	{ "FireAlpaca (64bit)", "FireAlpaca" },
};
static QString word_to[sizeof WORDS / sizeof *WORDS];

static const QString *
worded(const QString *s)
{
	for (size_t i = 0; i < sizeof WORDS / sizeof *WORDS; i++)
		if (string_is(s, WORDS[i].from)) {
			if (!word_to[i].ptr)
				qt.string_utf8(&word_to[i], (long)strlen(WORDS[i].to), WORDS[i].to);
			return &word_to[i];
		}
	return s;
}

void
_ZN15QAbstractButton7setTextERK7QString(void *self, const QString *text)
{
	static void (*real)(void *, const QString *);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN15QAbstractButton7setTextERK7QString");
	real(self, on ? worded(text) : text);
}

/* (the bar shows a window's title: it has no use for "(64bit)") */
void
_ZN7QWidget14setWindowTitleERK7QString(void *self, const QString *title)
{
	static void (*real)(void *, const QString *);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN7QWidget14setWindowTitleERK7QString");
	real(self, on ? worded(title) : title);
}

void
_ZN9QCheckBoxC1ERK7QStringP7QWidget(void *self, const QString *text, void *parent)
{
	static void (*real)(void *, const QString *, void *);
	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN9QCheckBoxC1ERK7QStringP7QWidget");
	real(self, on ? worded(text) : text, parent);
}

/* ── the panels on the grid ───────────────────────────────────────────────────── */
/* parent class, child class, which of that class among the parent's children, then x y w h. A w of
 * 0 is "to the parent's width less x and 8"; negative x counts from the parent's right edge. */
static const struct place {
	const char *parent, *child;
	int nth, x, y, w, h;
} PLACES[] = {
	{ "WidgetBrushControl", "WidgetTrackbarSimple2", 0, 8, 2, 214, 16 },
	{ "WidgetBrushControl", "QLineEdit", 0, 230, 0, 42, 20 },
	{ "WidgetBrushControl", "WidgetTrackbarSimple", 0, 8, 22, 214, 16 },
	{ "WidgetBrushControl", "QLabel", 0, 234, 22, 38, 16 },
	{ "WidgetBrushControl", "QLabel", 1, 8, 48, 96, 20 },
	{ "WidgetBrushControl", "QComboBox", 0, 104, 48, 168, 20 },
	{ "WidgetBrushControl", "QLabel", 2, 8, 76, 96, 20 },
	{ "WidgetBrushControl", "QComboBox", 1, 104, 76, 168, 20 },
	{ "WidgetLayerPanel", "QLabel", 0, 0, 2, 64, 16 },
	{ "WidgetLayerPanel", "WidgetTrackbarSimple", 0, 64, 2, 150, 16 },
	{ "WidgetLayerPanel", "MyLabel", 0, 222, 2, 42, 16 },
	{ "WidgetLayerPanel", "QLabel", 1, 0, 22, 64, 20 },
	{ "WidgetLayerPanel", "QComboBox", 0, 64, 22, 200, 20 },
	{ "WidgetLayerPanel", "QCheckBox", 0, 0, 48, 116, 16 },
	{ "WidgetLayerPanel", "QCheckBox", 1, 120, 48, 88, 16 },
	{ "WidgetLayerPanel", "QCheckBox", 2, 208, 48, 56, 16 },
	{ "WidgetLayerPanel", "QCheckBox", 3, 0, 68, 116, 16 },
	{ "WidgetLayerPanel", "QCheckBox", 4, 120, 68, 88, 16 },
	{ "WidgetLayerPanel", "QCheckBox", 5, 208, 68, 56, 16 },
	{ "WidgetBrushTop", "QCheckBox", 0, 0, 5, 100, 16 },
	{ "WidgetBrushTop", "QLineEdit", 0, 104, 3, 96, 20 },
	{ "WidgetBrushTop", "QPushButton", 0, 208, 3, 56, 20 },
	{ "WidgetColorInfo", "WidgetForeBG", 0, 0, 2, 30, 30 },
	{ "WidgetColorInfo", "WidgetToumei", 0, 36, 2, 30, 30 },
	{ "WidgetColorInfo", "WidgetRGBCode", 0, 0, 40, 66, 92 },
};
/* the panels that do have a layout: the content one cell in from the panel's edges */
static const char *const CELL_IN[] = { "WidgetColor", "WidgetPalette", "WidgetBrush", "WidgetLayer", "WidgetNavi", "WidgetBrushSize", "WidgetReference" };

static void
place_children(void *parent, const char *cls)
{
	char *d = *(char **)((char *)parent + 8);        /* QObject: d_ptr → QObjectData */
	void **kids = *(void ***)(d + 32);               /* its children: QList's data … */
	long n = *(long *)(d + 40);                      /* … and size */

	for (size_t t = 0; t < sizeof CELL_IN / sizeof *CELL_IN; t++) {
		if (strcmp(CELL_IN[t], cls))
			continue;
		for (long i = 0; i < n; i++) {
			const char *c = qt.class_name(((const void *(*)(void *))(*(void ***)kids[i])[0])(kids[i]));
			if (strstr(c, "Layout"))
				qt.layout_margins(kids[i], 8, 0, 8, 0);
		}
	}
	for (size_t t = 0; t < sizeof PLACES / sizeof *PLACES; t++) {
		const struct place *e = &PLACES[t];
		int seen = 0;
		if (strcmp(e->parent, cls))
			continue;
		for (long i = 0; i < n; i++) {
			const void *meta = ((const void *(*)(void *))(*(void ***)kids[i])[0])(kids[i]);
			if (strcmp(qt.class_name(meta), e->child))
				continue;
			if (seen++ == e->nth) {
				int r[4] = { e->x, e->y, e->x + e->w - 1, e->y + e->h - 1 };
				qt.set_geometry(kids[i], r);
				break;
			}
		}
	}
}

/* ── the watcher, and what the main thread does for it ────────────────────────── */
static void
post_to_main(void)
{
	void *ev;

	if (!*qt.app)
		return;
	ev = qt.cxx_new(OBJECT_BYTES);
	qt.event_new(ev, KAWA_EVENT);
	qt.post_event(*qt.app, ev, 0);
}

/* Waits for kawa-theme to turn the "current" link, and for kawa-sketch's request */
static void *
watcher(void *unused)
{
	char dir[PATH_MAX], buf[4096], *rt = getenv("XDG_RUNTIME_DIR");
	int fd = inotify_init1(IN_CLOEXEC);

	(void)unused;
	if (fd < 0 || snprintf(dir, sizeof dir, "%s/.config/fedokawaii", home) >= (int)sizeof dir
			|| inotify_add_watch(fd, dir, IN_MOVED_TO | IN_CREATE) < 0)
		return NULL;
	if (rt)
		inotify_add_watch(fd, rt, IN_MOVED_TO);
	for (;;) {
		ssize_t n = read(fd, buf, sizeof buf);
		bool post = false;
		if (n < 0 && errno == EINTR)
			continue;
		if (n <= 0)
			return NULL;
		for (char *p = buf; p < buf + n;) {
			struct inotify_event *e = (struct inotify_event *)p;
			if (e->len && !strcmp(e->name, "current")) {
				__atomic_store_n(&wanted_mood, true, __ATOMIC_RELEASE);
				post = true;
			} else if (e->len && !strcmp(e->name, "kawa-firealpaca.open")) {
				__atomic_store_n(&wanted_open, true, __ATOMIC_RELEASE);
				post = true;
			}
			p += sizeof *e + e->len;
		}
		if (post)
			post_to_main();
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
	unsigned short type = *(unsigned short *)((char *)event + 8);
	bool done;

	if (!real)
		real = dlsym(RTLD_NEXT, "_ZN12QApplication6notifyEP7QObjectP6QEvent");
	if (!on || !pthread_equal(pthread_self(), main_thread))
		return real(self, receiver, event);
	if (type == KAWA_EVENT) {
		if (!panel_keys_set) {
			panel_keys_set = true;
			for (size_t i = 0; i < sizeof PANEL_KEYS / sizeof *PANEL_KEYS; i++) {
				unsigned char seq[OBJECT_BYTES];
				QString k = { 0 };
				if (!PANEL_KEYS[i].ptr)
					continue;
				qt.string_utf8(&k, (long)strlen(PANEL_KEYS[i].key), PANEL_KEYS[i].key);
				qt.key_new(seq, &k, 1);              /* QKeySequence::PortableText */
				qt.action_key(PANEL_KEYS[i].ptr, seq);
				qt.key_free(seq);
				string_drop(&k);
			}
		}
		if (__atomic_exchange_n(&wanted_mood, false, __ATOMIC_ACQ_REL)) {
			load_mood();
			repaint_all();
		}
		if (__atomic_exchange_n(&wanted_open, false, __ATOMIC_ACQ_REL)) {
			char *req = read_request();
			if (req) {
				free(open_file);
				open_file = req;
			}
		}
		if (open_file && action_open) {
			qt.action_activate(action_open, 0);
			fit_left = 4;
		} else if (fit_left && action_fit) {
			fit_left--;
			qt.action_activate(action_fit, 0);
		}
		return true;
	}
	if (in_dialog)
		switch (type) {
		case 2: case 3: case 4: case 5:              /* the mouse */
		case 6: case 7:                              /* the keys */
		case 31:                                     /* the wheel */
		case 87: case 92: case 93:                   /* the pen */
			return true;
		}
	done = real(self, receiver, event);
	if (type == 14 || type == 17 || type == 76) {        /* Resize, Show, LayoutRequest: it has laid it out */
		const void *meta = ((const void *(*)(void *))(*(void ***)receiver)[0])(receiver);
		const char *cls = qt.class_name(meta);
		if (type == 17 && (open_file || !panel_keys_set) && !strcmp(cls, "MainWindow"))
			post_to_main();                      /* its first window: the keys, the file asked for */
		if (fit_left && type == 14 && !strcmp(cls, "WidgetCanvas"))
			post_to_main();
		if (cls[0] == 'W')
			place_children(receiver, cls);
	}
	return done;
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
	if (getenv("KAWA_FA_OPEN")) {
		open_file = strdup(getenv("KAWA_FA_OPEN"));
		unsetenv("KAWA_FA_OPEN");
	}
	on = true;
}
