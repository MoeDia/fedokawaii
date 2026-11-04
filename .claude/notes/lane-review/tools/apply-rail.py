#!/usr/bin/env python3
# lane-review's private trial of the rail's fix, on /dev/shm/lane-review/dwl/dwl.c
import re,sys
p="/dev/shm/lane-review/dwl/dwl.c"
s=open("/dev/shm/lane-review/dwl.c.orig").read()
def sub(a,b,n=1):
    global s
    if a not in s: sys.exit("no match: "+a[:80])
    s=s.replace(a,b,n)
# the client: the speed a re-armed move carries
sub("	int anim, slidex, slidey, tagx0, tagx1;\n	double animt0, animlast, animp, tagwave;\n",
    "	int anim, slidex, slidey, tagx0, tagx1;\n	double animt0, animlast, animp, tagwave, tagv;\n")
# the rail: a seam of the strip, riding with the workspace it leads in
m=re.search(r"typedef struct \{[^{}]*?\} Rail;",s,re.S)
print(m.group(0))
sub(m.group(0), m.group(0).replace("} Rail;","	uint32_t tags, from;         /* the workspace it leads in; the one it left */\n	int x0, x1;                  /* px off that workspace's place, from and to, as its windows */\n	double v, wave, p;           /* the speed it set out with; its wave's place; how far */\n} Rail;"))
# the spring's second half: a speed it starts with
sub("""/* (gentle at both ends) */
static double
smooth(double q)""","""/* …and what a speed v (px for the whole of p) at p = 0 adds, px per unit of v: nothing stops dead when a
 * new move takes over from one under way */
static double
springv(double p, double w, double z)
{
	double d, k;
	if (p <= 0.0 || p >= 1.0)
		return 0.0;
	k = p > 0.9 ? 1.0 - (p - 0.9) * 10.0 : 1.0;
	d = w * sqrt(1.0 - z * z);
	return k * exp(-z * w * p) * sin(d * p) / d;
}

/* (gentle at both ends) */
static double
smooth(double q)""")
# position and speed of a move
sub("""/* px off its place now */
static int
tagdx(Client *c)
{
	return c->tagx0 + (int)lround((c->tagx1 - c->tagx0) * tagease(c->animp));
}

/* a window's move begun from where it stands, wave ms late */
static void
tagmove(Client *c, int kind, int from, int to, double wave)
{
	c->anim = kind;
	c->tagx0 = from, c->tagx1 = to;
	c->tagwave = wave;
	c->animt0 = c->animlast = nowms();
	c->animp = 0;
}

/* its place in the wave of a move in direction dir: the ones nearest the way out first */
static double
tagwave(Client *c, int dir)
{
	double n = (c->geom.x + c->geom.width / 2.0 - c->mon->m.x) / c->mon->m.width;
	n = n < 0 ? 0 : n > 1 ? 1 : n;
	return anim_tag_wave * (dir > 0 ? n : 1.0 - n);
}
""","""/* where a move stands at p, and its speed there (px for the whole of p) */
static double
tagat(int x0, int x1, double v, double p)
{
	return x1 + (x0 - x1) * spring(p, TAG_W, TAG_Z) + v * springv(p, TAG_W, TAG_Z);
}

static double
tagspeed(int x0, int x1, double v, double p)
{
	return (tagat(x0, x1, v, p + 0.005) - tagat(x0, x1, v, p - 0.005)) / 0.01;
}

/* px off its place now */
static int
tagdx(Client *c)
{
	return (int)lround(tagat(c->tagx0, c->tagx1, c->tagv, c->animp));
}

/* a window's move begun from where it stands, at the speed it has, wave ms late */
static void
tagmove(Client *c, int kind, int to, double wave)
{
	int moving = c->anim == AnimIn || c->anim == AnimOut, x = moving ? tagdx(c) : 0;
	c->tagv = moving ? tagspeed(c->tagx0, c->tagx1, c->tagv, c->animp) : 0.0;
	c->tagx0 = x;
	c->anim = kind;
	c->tagx1 = to;
	c->tagwave = wave;
	c->animt0 = c->animlast = nowms();
	c->animp = 0;
}

/* its place in the wave of a move in direction dir: half the wave for the windows leaving, then the
 * rail, then the other half for those coming, each half from the way out on: the last to leave is
 * ahead of the rail, the first to come behind it, so the rail stands between them in every frame */
static double
tagwave(Client *c, int dir, int in)
{
	double n = (c->geom.x + c->geom.width / 2.0 - c->mon->m.x) / c->mon->m.width;
	n = n < 0 ? 0 : n > 1 ? 1 : n;
	return anim_tag_wave * 0.5 * (in + (dir > 0 ? n : 1.0 - n));
}
""")
# the rail placed by the same law
sub("""/* the rail of one move: dir as the move's; it goes with the windows coming in, just behind them */
static void
railplace(Rail *r, double p)
{
	Monitor *m = r->mon;
	int cell = moncell(m), s = stripw(m);
	int dx = r->dir * (s - (int)lround(s * tagease(p)));
	int x = m->m.x + (r->dir > 0 ? dx - RAIL_CELLS * cell : dx + m->m.width);
""","""/* the rail of one move: the seam of the strip, on the side of the workspace it leads in, off that
 * workspace's place by as much as its windows */
static void
railplace(Rail *r)
{
	Monitor *m = r->mon;
	int cell = moncell(m);
	int dx = (int)lround(tagat(r->x0, r->x1, r->v, r->p));
	int x = m->m.x + (r->dir > 0 ? dx - RAIL_CELLS * cell : dx + m->m.width);
""")
sub("""static void
railstart(Monitor *m, int dir)
{
	Rail *r = ecalloc(1, sizeof(*r));
	const float ink[4] = { washink[0], washink[1], washink[2], 1.0f };
	int cell = moncell(m), i;

	r->mon = m;
	r->dir = dir;
	r->t0 = r->last = nowms();
""","""/* a move from was to now on m: the rails under way go on as the windows do — from where they stand, at
 * their speed, to where the workspace they lead in is going — and a new one comes, unless this is a
 * move back: the seam it needs is the last move's rail, there already */
static void
railstart(Monitor *m, int dir, uint32_t was, uint32_t now)
{
	Rail *r;
	const float ink[4] = { washink[0], washink[1], washink[2], 1.0f };
	int cell = moncell(m), i, back = 0;
	double dx;

	wl_list_for_each(r, &rails, link) {
		if (r->mon != m)
			continue;
		back |= r->tags == was && r->from == now;
		dx = tagat(r->x0, r->x1, r->v, r->p);
		r->v = tagspeed(r->x0, r->x1, r->v, r->p);
		r->x0 = (int)lround(dx);
		r->x1 = r->tags & now ? 0 : -dir * stripw(m);
		r->wave = 0;                 /* (as the windows under way) */
		r->t0 = r->last = nowms();
		r->p = 0;
	}
	if (back)
		return;
	r = ecalloc(1, sizeof(*r));
	r->mon = m;
	r->dir = dir;
	r->tags = now, r->from = was;
	r->x0 = dir * stripw(m);
	r->wave = anim_tag_wave * 0.5;
	r->t0 = r->last = nowms();
""")
sub("""	railplace(r, 0);
	wl_list_insert(&rails, &r->link);""","""	railplace(r);
	wl_list_insert(&rails, &r->link);""")
# the frame
sub("""		if (now - r->t0 >= anim_tag_ms) {
			railfree(r);
		} else {
			railplace(r, (now - r->t0) / anim_tag_ms);
			left = 1;
		}""","""		if (now - r->t0 >= anim_tag_ms) {
			railfree(r);
		} else {
			r->p = (now - r->t0 - r->wave) / (anim_tag_ms - anim_tag_wave);
			r->p = r->p < 0 ? 0 : r->p > 1 ? 1 : r->p;
			railplace(r);
			left = 1;
		}""")
# the callers
sub("""	tagmove(c, kind, kind == AnimIn ? dir * stripw(c->mon) : 0, kind == AnimOut ? -dir * stripw(c->mon) : 0,
			kind == AnimIn || kind == AnimOut ? tagwave(c, dir) : 0);
""","""	c->anim = AnimNone;              /* (a move of its own, from rest) */
	tagmove(c, kind, kind == AnimOut ? -dir * stripw(c->mon) : 0,
			kind == AnimIn || kind == AnimOut ? tagwave(c, dir, kind == AnimIn) : 0);
	c->tagx0 = kind == AnimIn ? dir * stripw(c->mon) : 0;
""")
sub("""		railstart(m, dir);
""","""		railstart(m, dir, was, now);
""")
sub("""					tagmove(c, after ? AnimIn : AnimOut, tagdx(c), after ? 0 : -dir * stripw(m), 0);
""","""					tagmove(c, after ? AnimIn : AnimOut, after ? 0 : -dir * stripw(m), 0);
""")
# a move's p starts from where the old one was read: keep animp live for tagspeed
# tagease: no one left
sub("""/* how far along */
static double
tagease(double p)
{
	return 1.0 - spring(p, TAG_W, TAG_Z);
}

""","")
open(p,"w").write(s)
