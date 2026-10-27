/* ═══════════════════════════════════════════════════════════════════════════
 *  dwl config.h — for dwl v0.9 (wlroots 0.20) with src/dwl/dwl.patch applied (gappx,
 *  full window borders, the spiral and columns layouts, centred floating windows, popups
 *  that close when they lose the focus, windows shown once drawn, games that
 *  take the keyboard, FreeSync, keybindings that ignore the Arabic layout, the keyboard
 *  layout for the bar, menus that close on a click outside, the pointers loaded again
 *  when the theme switches, the borders in the theme's colours, a drawing tablet's pen as a pen,
 *  windows that unroll, roll up and slide).
 *  Installed by theme.sh into ~/.local/src/dwl/config.h, then rebuilt.
 *  Keybinding reference: Super+/
 * ═══════════════════════════════════════════════════════════════════════════ */

#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }
/* (premultiplied, as the scene draws a see-through rect) */
#define PCOLOR(hex)   { ((hex >> 24) & 0xFF) / 255.0f * ((hex & 0xFF) / 255.0f), \
                        ((hex >> 16) & 0xFF) / 255.0f * ((hex & 0xFF) / 255.0f), \
                        ((hex >> 8) & 0xFF) / 255.0f * ((hex & 0xFF) / 255.0f), \
                        (hex & 0xFF) / 255.0f }

/* ── colours ─────────────────────────────────────────────────────────────────
 * The desktop's own (tools/build-themes.py). Every window wears the frame everything that
 * floats wears (docs/design-system.md §4, §12): a 1 px hairline, its corners left out —
 * vermilion round the focused one, the hairline's ink round the others, asagi round one that
 * asks for attention — and the shadow under it and at its right. These are the dark theme's;
 * the theme in use replaces them from its dwl.colors, at dwl's start and at every switch
 * (dwl.patch: loadcolours). */
#define SUMI      0x181715ff   /* ink: behind the wallpaper, seen only before it loads */
#define HAIR      0xd4bf9a80   /* the other windows: the hairline's ink (text at 50 %) */
#define SHU       0xeb5324ff   /* the focused window: vermilion                        */
#define ASAGI     0x82c1b4ff   /* a window asking for attention: asagi                 */
#define SHADOW1   0x111314aa   /* the shadow's first row: Black at 67 %                */
#define SHADOW2   0x11131450   /* its second row and its column: at 31 %               */

/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx         = 1;  /* the hairline (dwl.patch: applyframe draws it and its shadow) */
static const unsigned int gappx            = 8;  /* gap between windows (dwl.patch) */
static const unsigned int outergappx       = 8;  /* …and from the screen's edges and the bar's hairline
                                                    (its exclusive zone ends there: waybar's margin-bottom
                                                    -2 leaves the shadow out): the windows' outer edges on
                                                    x 8 and 1911, the bar's outer tiles' hairlines, and
                                                    their tops on y 33 (dwl.patch) */
static const unsigned int snap             = 16; /* snap pixel */
static const float rootcolor[]             = COLOR(SUMI);
/* { the hairline, the shadow's first row, its second row and column } */
static float bordercolor[3][4]             = { PCOLOR(HAIR), PCOLOR(SHADOW1), PCOLOR(SHADOW2) };
static float focuscolor[3][4]              = { PCOLOR(SHU), PCOLOR(SHADOW1), PCOLOR(SHADOW2) };
static float urgentcolor[3][4]             = { PCOLOR(ASAGI), PCOLOR(SHADOW1), PCOLOR(SHADOW2) };
static const float fullscreen_bg[]         = {0.059f, 0.055f, 0.047f, 1.0f};

/* animations (dwl.patch; docs/design-system.md §11 — playful pixel): a new window dissolves
 * in — cell by cell, cells of the wallpapers' pixel (3 × 3 at 1080p), in a 4 × 4 Bayer
 * matrix's order — rising its last anim_rise px to its place; a closed one dissolves out,
 * sinking as much; a workspace switch dissolves the windows out as they drift anim_drift px
 * to one side, and the next ones in from the other, the two overlapping — every frame the
 * screen shows, drawn for the moment that frame reaches the screen, the movement eased out
 * and the cells on a smoothstep; never a full-screen window; unlocked, the lock screen
 * dissolves off the desktop (locking: at once). No edge sweeps across the screen (a moving
 * cut reads as a tear), nothing is ever half-transparent. 0: everything at once */
static const int animations                = 1;
static const unsigned int anim_open_ms     = 420;  /* a window opening */
static const unsigned int anim_close_ms    = 400;  /* …closing */
static const unsigned int anim_tag_ms      = 420;  /* a workspace switch, all of it: */
static const unsigned int anim_tag_each_ms = 280;  /* …the windows leaving its first 280 ms,
                                                    * those coming its last 280 (140 – 420) */
static const unsigned int anim_unlock_ms   = 420;  /* the lock screen dissolving off the
                                                    * desktop once the password is right */
static const int anim_rise                 = 9;    /* px: three of the wallpapers' pixels */
static const int anim_drift                = 24;   /* px */
static const unsigned int anim_unroll_ms   = 300;  /* a warm window shown (Super+U, N, V):
                                                    * it unrolls from its top edge, its rod
                                                    * (the frame's foot) travelling down */
static const unsigned int anim_rollup_ms   = 240;  /* …put away: rolls up into its top edge */
/* layer surfaces, by their namespace (§11): the panels' menus dissolve in as they drop 4 px into
 * place, and out; a notice in and out; the level display comes at once (with its key) and
 * dissolves away; the screensaver dissolves off into what it covered (it comes in its own way).
 * Any other (the bar, the wallpaper, the wash): at once */
static const LayerAnim layeranims[] = {
	/* namespace        in ms  out ms  drop px */
	{ "kawa-panel",     200,   160,    4 },
	{ "notifications",  240,   200,    0 },
	{ "kawa-level",     0,     300,    0 },
	{ "kawa-saver",     0,     180,    0 },
};

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id                 title       tags mask     isfloating   monitor
	 * (dwl.patch: "=text" matches that exact app-id or title, plain text any that holds it) */
	/* popups open floating and centred (dwl.patch), and close when they lose the focus:
	 * "float" is the app-id kawa-term --float gives the desktop's own windows (the system menu,
	 * notes, the clipboard, books, btop …; the small menus are kawa-panel's, not windows) */
	{ "=float",               NULL,       0,            1,           -1 },
	/* dialogs that float but stay while you answer them: the file dialog (kawa-pick) every
	 * app's "Open"/"Save as" opens, and the password prompt for admin rights */
	{ "=kawa-dialog",         NULL,       0,            1,           -1 },
	{ "=lxqt-policykit-agent", NULL,      0,            1,           -1 },
	{ "=imv",                 NULL,       0,            1,           -1 },
	/* Steam: its small windows (sign in, settings, friends, news, the update box) float,
	 * centred on the screen you are on; the library window — titled exactly "Steam" —
	 * tiles. Games (app-id steam_app_…) are not Steam's: they open where you are */
	{ "=steam",               NULL,       0,            1,           -1 },
	{ "=steam",               "=Steam",   0,            0,           -1 },
	/* no catch-all { NULL, NULL, … } rule: dwl applies every rule that matches, in
	 * order, so a catch-all at the end would un-float everything above it */
};

/* layout(s) — the first is every workspace's own at the start. The bar (kawa-dwlstatus)
 * draws each symbol as a pixel icon */
static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "(@)",      spiral },  /* the golden spiral (dwl.patch): Super+S */
	{ "|||",      tile },    /* columns, left to right (dwl.patch's tile): Super+T */
	{ "><>",      NULL },    /* floating, each window centred as it opens: Super+Y */
};

/* monitors — resolution/refresh are applied by kawa-display at login (wlr-randr) */
static const MonitorRule monrules[] = {
	/* name       mfact  nmaster scale layout       rotate/reflect                x    y */
	/* mfact 0.618: the golden ratio — the spiral's first window's share of the width */
	{ NULL,       0.618f, 1,     1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
};

/* keyboard — layouts/toggle come from XKB_DEFAULT_* set in /usr/local/bin/start-dwl */
static const struct xkb_rule_names xkb_rules = {
	.options = NULL,
};

static const int repeat_rate = 35;
static const int repeat_delay = 300;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
/* flat acceleration: predictable mouse for desktop + gaming */
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Super (Windows key) is the modifier */
#define MODKEY WLR_MODIFIER_LOGO
#define SHIFT  WLR_MODIFIER_SHIFT
#define CTRL   WLR_MODIFIER_CTRL

#define TAGKEYS(KEY,TAG) \
	{ MODKEY,             KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|CTRL,        KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|SHIFT,       KEY,            tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|CTRL|SHIFT,  KEY,            toggletag,       {.ui = 1 << TAG} }

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *termcmd[]     = { "footclient", NULL };
static const char *menucmd[]     = { "kawa-menu", "--launcher", NULL };   /* the torii's: one menu at a time */
static const char *browsercmd[]  = { "brave-origin", NULL };
static const char *filescmd[]    = { "footclient", "yazi", NULL };

/* A key added or changed here belongs in the help sheet too: configs/home/.config/fedokawaii/
 * keybinds.txt (Super+/ lists it). Keys are read from the first keyboard layout (us), so
 * a binding works whichever layout is active. */
static const Key keys[] = {
	/* modifier        key                        function          argument */
	/* ── launch ── */
	{ MODKEY,          XKB_KEY_Return,            spawn,            {.v = termcmd} },
	{ MODKEY,          XKB_KEY_space,             spawn,            {.v = menucmd} },
	{ MODKEY,          XKB_KEY_b,                 spawn,            {.v = browsercmd} },
	{ MODKEY,          XKB_KEY_e,                 spawn,            {.v = filescmd} },
	{ MODKEY,          XKB_KEY_x,                 spawn,            SHCMD("kawa-quick") },
	{ MODKEY,          XKB_KEY_a,                 spawn,            SHCMD("kawa-quick sound") },
	{ MODKEY,          XKB_KEY_c,                 spawn,            SHCMD("kawa-calendar") },
	{ MODKEY,          XKB_KEY_slash,             spawn,            SHCMD("kawa-help") },
	{ MODKEY,          XKB_KEY_w,                 spawn,            SHCMD("kawa-wallpaper") },
	{ MODKEY|SHIFT,    XKB_KEY_w,                 spawn,            SHCMD("kawa-theme") },
	/* warm (dwl.patch): kept running, put away — a press shows or hides it in the frame */
	{ MODKEY,          XKB_KEY_v,                 warm,             {.v = "clip"} },
	{ MODKEY,          XKB_KEY_z,                 spawn,            SHCMD("kawa-shrink") },
	{ MODKEY,          XKB_KEY_d,                 spawn,            SHCMD("kawa-file") },
	{ MODKEY,          XKB_KEY_r,                 spawn,            SHCMD("kawa-books") },
	{ MODKEY,          XKB_KEY_n,                 warm,             {.v = "notes"} },
	{ MODKEY,          XKB_KEY_u,                 warm,             {.v = "system"} },
	{ MODKEY|SHIFT,    XKB_KEY_u,                 spawn,            SHCMD("kawa-config") },
	{ MODKEY|SHIFT,    XKB_KEY_n,                 spawn,            SHCMD("makoctl dismiss -a") },
	{ MODKEY,          XKB_KEY_Escape,            spawn,            SHCMD("kawa-lock --sleep") },
	{ MODKEY|SHIFT,    XKB_KEY_e,                 spawn,            SHCMD("kawa-power") },
	/* the keyboard's sleep key (some send Sleep, some Suspend): logind leaves both to dwl (setup.sh) */
	{ 0,               XKB_KEY_XF86Sleep,         spawn,            SHCMD("kawa-power sleep") },
	{ 0,               XKB_KEY_XF86Suspend,       spawn,            SHCMD("kawa-power sleep") },
	/* ── screenshots ── */
	{ 0,               XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot region") },
	{ SHIFT,           XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot full") },
	{ MODKEY,          XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot edit") },
	{ MODKEY|SHIFT,    XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot text") },
	/* the same on a keyboard without Print (a 61-key one): Super+Shift and a letter */
	{ MODKEY|SHIFT,    XKB_KEY_s,                 spawn,            SHCMD("kawa-screenshot region") },
	{ MODKEY|SHIFT,    XKB_KEY_f,                 spawn,            SHCMD("kawa-screenshot full") },
	{ MODKEY|SHIFT,    XKB_KEY_a,                 spawn,            SHCMD("kawa-screenshot edit") },
	{ MODKEY|SHIFT,    XKB_KEY_x,                 spawn,            SHCMD("kawa-screenshot text") },
	{ MODKEY|SHIFT,    XKB_KEY_r,                 spawn,            SHCMD("kawa-record") },   /* again: stop */
	{ MODKEY|SHIFT,    XKB_KEY_p,                 spawn,            SHCMD("kawa-record pause") },   /* again: 3-2-1, on */
	/* ── media keys, and monitor brightness over DDC/CI ──
	 * spawnheld: a held key goes on repeating it (the volume, the brightness, step by step).
	 * Every other key is one press however long it is held (dwl.patch: keypress()) — so a
	 * key that opens a window closes it with the next press, however fast */
	{ 0,               XKB_KEY_XF86AudioRaiseVolume, spawnheld,     SHCMD("kawa-volume up") },
	{ 0,               XKB_KEY_XF86AudioLowerVolume, spawnheld,     SHCMD("kawa-volume down") },
	{ 0,               XKB_KEY_XF86AudioMute,     spawn,            SHCMD("kawa-volume mute") },
	{ 0,               XKB_KEY_XF86AudioMicMute,  spawn,            SHCMD("kawa-volume mic") },
	{ 0,               XKB_KEY_XF86AudioPlay,     spawn,            SHCMD("kawa-nowplaying play-pause") },
	{ 0,               XKB_KEY_XF86AudioNext,     spawn,            SHCMD("kawa-nowplaying next") },
	{ 0,               XKB_KEY_XF86AudioPrev,     spawn,            SHCMD("kawa-nowplaying previous") },
	{ 0,               XKB_KEY_XF86MonBrightnessUp,   spawnheld,    SHCMD("kawa-brightness +10") },
	{ 0,               XKB_KEY_XF86MonBrightnessDown, spawnheld,    SHCMD("kawa-brightness -10") },
	{ MODKEY,          XKB_KEY_bracketright,      spawnheld,        SHCMD("kawa-brightness +10") },
	{ MODKEY,          XKB_KEY_bracketleft,       spawnheld,        SHCMD("kawa-brightness -10") },
	/* ── windows ── */
	{ MODKEY,          XKB_KEY_q,                 killclient,       {0} },
	{ MODKEY,          XKB_KEY_j,                 focusstack,       {.i = +1} },
	{ MODKEY,          XKB_KEY_k,                 focusstack,       {.i = -1} },
	/* the spiral's first window narrower or wider (never below 600 px, nor what is beside it) */
	{ MODKEY,          XKB_KEY_h,                 setmfact,         {.f = -0.05f} },
	{ MODKEY,          XKB_KEY_l,                 setmfact,         {.f = +0.05f} },
	{ MODKEY|SHIFT,    XKB_KEY_Return,            zoom,             {0} },
	{ MODKEY,          XKB_KEY_Tab,               view,             {0} },
	{ MODKEY,          XKB_KEY_f,                 togglefullscreen, {0} },
	{ MODKEY|SHIFT,    XKB_KEY_space,             togglefloating,   {0} },
	/* ── layouts ── */
	{ MODKEY,          XKB_KEY_s,                 setlayout,        {.v = &layouts[0]} },
	{ MODKEY,          XKB_KEY_t,                 setlayout,        {.v = &layouts[1]} },
	{ MODKEY,          XKB_KEY_y,                 setlayout,        {.v = &layouts[2]} },
	{ MODKEY|SHIFT,    XKB_KEY_t,                 setlayout,        {0} },  /* toggle last layout */
	/* ── tags ── */
	{ MODKEY,          XKB_KEY_0,                 view,             {.ui = ~0} },
	{ MODKEY|SHIFT,    XKB_KEY_0,                 tag,              {.ui = ~0} },
	TAGKEYS(           XKB_KEY_1,                 0),
	TAGKEYS(           XKB_KEY_2,                 1),
	TAGKEYS(           XKB_KEY_3,                 2),
	TAGKEYS(           XKB_KEY_4,                 3),
	TAGKEYS(           XKB_KEY_5,                 4),
	TAGKEYS(           XKB_KEY_6,                 5),
	TAGKEYS(           XKB_KEY_7,                 6),
	TAGKEYS(           XKB_KEY_8,                 7),
	TAGKEYS(           XKB_KEY_9,                 8),
	/* ── monitors ── */
	{ MODKEY,          XKB_KEY_comma,             focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,          XKB_KEY_period,            focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|SHIFT,    XKB_KEY_comma,             tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|SHIFT,    XKB_KEY_period,            tagmon,           {.i = WLR_DIRECTION_RIGHT} },
	/* ── session ── */
	/* log out without the menu (the one way out: no Ctrl+Alt+BackSpace) — Steam closed properly
	   first, as the power menu's log out does (its saves to Steam Cloud); then dwl, as kawa-power ends it */
	{ MODKEY|CTRL|SHIFT, XKB_KEY_q,               spawn,            SHCMD("kawa-steam --quit logout; exec pkill -xu \"$(id -u)\" dwl") },
#define CHVT(n) { CTRL|WLR_MODIFIER_ALT, XKB_KEY_F##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};

/* Super + mouse wheel → volume */
static const Axis axes[] = {
	/* Super+scroll: the volume in 2 % steps, with the level shown and up unmuting, like the keys */
	{ MODKEY, AxisUp,   spawn, SHCMD("kawa-volume up 2") },
	{ MODKEY, AxisDown, spawn, SHCMD("kawa-volume down 2") },
};
