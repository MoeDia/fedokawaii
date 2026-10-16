/* ═══════════════════════════════════════════════════════════════════════════
 *  dwl config.h — for dwl v0.9 (wlroots 0.20) with src/dwl/dwl.patch applied (gappx,
 *  full window borders, centred floating windows, keybindings that ignore the
 *  Arabic layout, the keyboard layout for the bar, menus that close on a click outside).
 *  Installed by theme.sh into ~/.local/src/dwl/config.h, then rebuilt.
 *  Keybinding reference: Super+/
 * ═══════════════════════════════════════════════════════════════════════════ */

#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }

/* ── colours ─────────────────────────────────────────────────────────────────
 * The desktop's own (tools/build-themes.py), compiled in, so they suit both the dark
 * and the light theme. Every window has a plain, full 2 px border, one solid colour:
 * vermilion around the focused one, warm grey around the others, asagi around one that
 * asks for attention — the same frame the menus and notices wear. */
#define SUMI      0x0f0e0cff   /* ink: behind the wallpaper, seen only before it loads */
#define NEZUMI    0x877f6fff   /* the other windows: warm grey                         */
#define SHU       0xd0583aff   /* the focused window: vermilion                        */
#define ASAGI     0x7fb8b0ff   /* a window asking for attention: asagi                 */

/* appearance */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx         = 2;  /* the border (dwl.patch draws it as outline + band) */
static const unsigned int gappx            = 8;  /* gap between windows and around the edge (dwl.patch) */
static const unsigned int snap             = 16; /* snap pixel */
static const float rootcolor[]             = COLOR(SUMI);
/* { outline, band top/left, band bottom/right }: one colour each, a plain full border */
static const float bordercolor[3][4]       = { COLOR(NEZUMI), COLOR(NEZUMI), COLOR(NEZUMI) };
static const float focuscolor[3][4]        = { COLOR(SHU), COLOR(SHU), COLOR(SHU) };
static const float urgentcolor[3][4]       = { COLOR(ASAGI), COLOR(ASAGI), COLOR(ASAGI) };
static const float fullscreen_bg[]         = {0.059f, 0.055f, 0.047f, 1.0f};

/* tagging - TAGCOUNT must be no greater than 31 */
#define TAGCOUNT (9)

/* logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id                 title       tags mask     isfloating   monitor */
	/* small tools open floating and centred (dwl.patch); "float" is the app-id the
	 * menus give their terminal windows: footclient -a float … */
	{ "float",                NULL,       0,            1,           -1 },
	/* dialogs that belong to no window of their own: the file chooser every app's
	 * "Upload"/"Save as" opens through the portal, and the password prompt for admin rights */
	{ "xdg-desktop-portal-gtk", NULL,     0,            1,           -1 },
	{ "lxqt-policykit-agent", NULL,       0,            1,           -1 },
	{ "org.pulseaudio.pavucontrol", NULL, 0,            1,           -1 },
	{ "blueman-manager",      NULL,       0,            1,           -1 },
	{ "imv",                  NULL,       0,            1,           -1 },
	{ "steam",                "Steam",    1 << 8,       0,           -1 }, /* the Steam client → workspace 9; games open where you are */
	/* no catch-all { NULL, NULL, … } rule: dwl applies every rule that matches, in
	 * order, so a catch-all at the end would un-float everything above it */
};

/* layout(s) */
static const Layout layouts[] = {
	/* symbol     arrange function */
	/* dwl's own symbols; the bar (kawa-dwlstatus) draws each as a pixel icon.
	 * monocle rewrites its symbol to [n], the number of windows it stacks */
	{ "[]=",      tile },
	{ "><>",      NULL },    /* floating */
	{ "[M]",      monocle },
};

/* monitors — resolution/refresh are applied by kawa-display at login (wlr-randr) */
static const MonitorRule monrules[] = {
	/* name       mfact  nmaster scale layout       rotate/reflect                x    y */
	{ NULL,       0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
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
static const char *menucmd[]     = { "fuzzel", NULL };
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
	{ MODKEY,          XKB_KEY_a,                 spawn,            SHCMD("kawa-audio") },
	{ MODKEY,          XKB_KEY_c,                 spawn,            SHCMD("kawa-calendar") },
	{ MODKEY,          XKB_KEY_slash,             spawn,            SHCMD("kawa-help") },
	{ MODKEY,          XKB_KEY_w,                 spawn,            SHCMD("kawa-wallpaper") },
	{ MODKEY|SHIFT,    XKB_KEY_w,                 spawn,            SHCMD("kawa-theme") },
	{ MODKEY,          XKB_KEY_v,                 spawn,            SHCMD("kawa-clip") },
	{ MODKEY,          XKB_KEY_r,                 spawn,            SHCMD("kawa-books") },
	{ MODKEY,          XKB_KEY_n,                 spawn,            SHCMD("kawa-notes") },
	{ MODKEY,          XKB_KEY_u,                 spawn,            SHCMD("fedokawaii --window") },
	{ MODKEY|SHIFT,    XKB_KEY_u,                 spawn,            SHCMD("kawa-config") },
	{ MODKEY|SHIFT,    XKB_KEY_n,                 spawn,            SHCMD("makoctl dismiss -a") },
	{ MODKEY,          XKB_KEY_Escape,            spawn,            SHCMD("kawa-lock") },
	{ MODKEY|SHIFT,    XKB_KEY_e,                 spawn,            SHCMD("kawa-power") },
	/* ── screenshots ── */
	{ 0,               XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot region") },
	{ SHIFT,           XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot full") },
	{ MODKEY,          XKB_KEY_Print,             spawn,            SHCMD("kawa-screenshot edit") },
	/* ── media keys, and monitor brightness over DDC/CI ── */
	{ 0,               XKB_KEY_XF86AudioRaiseVolume, spawn,         SHCMD("kawa-volume up") },
	{ 0,               XKB_KEY_XF86AudioLowerVolume, spawn,         SHCMD("kawa-volume down") },
	{ 0,               XKB_KEY_XF86AudioMute,     spawn,            SHCMD("kawa-volume mute") },
	{ 0,               XKB_KEY_XF86AudioMicMute,  spawn,            SHCMD("kawa-volume mic") },
	{ 0,               XKB_KEY_XF86AudioPlay,     spawn,            SHCMD("kawa-nowplaying play-pause") },
	{ 0,               XKB_KEY_XF86AudioNext,     spawn,            SHCMD("kawa-nowplaying next") },
	{ 0,               XKB_KEY_XF86AudioPrev,     spawn,            SHCMD("kawa-nowplaying previous") },
	{ 0,               XKB_KEY_XF86MonBrightnessUp,   spawn,        SHCMD("kawa-brightness +10") },
	{ 0,               XKB_KEY_XF86MonBrightnessDown, spawn,        SHCMD("kawa-brightness -10") },
	{ MODKEY,          XKB_KEY_bracketright,      spawn,            SHCMD("kawa-brightness +10") },
	{ MODKEY,          XKB_KEY_bracketleft,       spawn,            SHCMD("kawa-brightness -10") },
	/* ── windows ── */
	{ MODKEY,          XKB_KEY_q,                 killclient,       {0} },
	{ MODKEY,          XKB_KEY_j,                 focusstack,       {.i = +1} },
	{ MODKEY,          XKB_KEY_k,                 focusstack,       {.i = -1} },
	{ MODKEY,          XKB_KEY_h,                 setmfact,         {.f = -0.05f} },
	{ MODKEY,          XKB_KEY_l,                 setmfact,         {.f = +0.05f} },
	{ MODKEY,          XKB_KEY_i,                 incnmaster,       {.i = +1} },
	{ MODKEY,          XKB_KEY_d,                 incnmaster,       {.i = -1} },
	{ MODKEY|SHIFT,    XKB_KEY_Return,            zoom,             {0} },
	{ MODKEY,          XKB_KEY_Tab,               view,             {0} },
	{ MODKEY,          XKB_KEY_f,                 togglefullscreen, {0} },
	{ MODKEY|SHIFT,    XKB_KEY_space,             togglefloating,   {0} },
	/* ── layouts ── */
	{ MODKEY,          XKB_KEY_t,                 setlayout,        {.v = &layouts[0]} },
	{ MODKEY,          XKB_KEY_y,                 setlayout,        {.v = &layouts[1]} },
	{ MODKEY,          XKB_KEY_m,                 setlayout,        {.v = &layouts[2]} },
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
	{ MODKEY|CTRL|SHIFT, XKB_KEY_q,               quit,             {0} },   /* (the one way out: no Ctrl+Alt+BackSpace) */
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
