# lane-review: the strip's three fixes, as exact replacements in a private dwl.c
import sys
p = sys.argv[1]
s = open(p).read()
def sub(a, b):
    global s
    assert s.count(a) == 1, a
    s = s.replace(a, b)
# 1. the seam of the next workspace lies beyond the last window of the one in front
sub("""/* a move in direction dir begins on m: all of the strip is one body. The workspace in front stands at X, moving
 * at V (a switch during a move; at rest both 0); the next one lies a strip's length beyond it, and all of
 * it, whatever is on it, moves by the same way at the same speed until that one is on its place */
static void
stripstart(Monitor *m, int dir)
{
	double t = nowms(), X = 0.0, V = 0.0;
""", """/* a move in direction dir begins on m: all of the strip is one body. The workspace in front (was) stands at X,
 * moving at V (a switch during a move; at rest both 0), the farthest of its windows on the way the next one
 * lies (the wave leaves some behind the strip's clock); the next one lies a strip's length beyond it, and all
 * of it, whatever is on it, moves at the same speed until that one is on its place */
static void
stripstart(Monitor *m, int dir, uint32_t was)
{
	double t = nowms(), X = 0.0, V = 0.0;
	Client *c;
""")
sub("""		X = tagat(m->stripx0, 0, m->stripv, p);
		V = tagspeed(m->stripx0, 0, m->stripv, p);
	}
""", """		X = tagat(m->stripx0, 0, m->stripv, p);
		V = tagspeed(m->stripx0, 0, m->stripv, p);
		wl_list_for_each(c, &clients, link)
			if (c->mon == m && (c->tags & was) && (c->anim == AnimIn || c->anim == AnimOut)) {
				double x = tagat(c->tagx0, c->tagx1, c->tagv, tagprogress(c, t - c->animt0));
				X = dir > 0 ? MAX(X, x) : MIN(X, x);
			}
	}
""")
sub("		stripstart(m, dir);\n", "		stripstart(m, dir, was);\n")
# 2. a window going out ends off the screen: whole strips off its place, whatever the wave left it
sub("""					int x;
					c->animp = tagprogress(c, nowms() - c->animt0);   /* (its place now, not at the last frame) */
					x = tagdx(c);
					tagmove(c, after ? AnimIn : AnimOut, x, after ? 0 : x + m->stripd, m->stripv, 0);
""", """					int x, w = stripw(m);
					c->animp = tagprogress(c, nowms() - c->animt0);   /* (its place now, not at the last frame) */
					x = tagdx(c);
					/* (whole strips off its place, whatever the wave left it: off the screen at the end) */
					tagmove(c, after ? AnimIn : AnimOut, x, after ? 0 : (int)lround((double)(x + m->stripd) / w) * w,
							m->stripv, 0);
""")
# 3. the strip's clock waits with its monitor, as its windows' and rails'
sub("""	wl_list_for_each_safe(r, rtmp, &rails, link) {
		if (r->mon != m)
			continue;
		if (held) {
			r->t0 += now - r->last;
			r->last = now;
			continue;
		}
""", """	if (held)                          /* (the strip's clock with them: its rails were last stamped together) */
		wl_list_for_each(r, &rails, link)
			if (r->mon == m) {
				m->stript0 += now - r->last;
				break;
			}
	wl_list_for_each_safe(r, rtmp, &rails, link) {
		if (r->mon != m)
			continue;
		if (held) {
			r->t0 += now - r->last;
			r->last = now;
			continue;
		}
""")
open(p, "w").write(s)
