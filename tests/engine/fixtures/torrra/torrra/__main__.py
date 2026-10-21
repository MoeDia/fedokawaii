"""torrra's command line, as a stand-in: like torrra 2.5 it stores the Prowlarr key it was
given at every start, then says what it sees (one JSON line) and exits with FAKE_RC (0).
Its window (no --help, --version, config or download): its health check of the indexer before
it opens, its first screen (compose(), each widget's words), then a search for each of
FAKE_QUERY's words ('|' apart) — an IndexerError shown in the window as torrra shows it, the
window staying open — and the theme it would draw with.
FAKE_SAY: words it says on stderr before it exits 0 (as torrra says what stops it).
FAKE_DL: a JSON file, a list of moments 2 s apart — each the torrents its window holds then
({name, save_path, done, total, finished, paused}); at each its screen ticks, and what
$XDG_RUNTIME_DIR/kawa-downloads holds right after is written to FAKE_DL.seen.N."""
import json
import os
import sys
import time

from torrra.core.config import Config


def window(cfg, key):
    import asyncio
    import torrra.app as app
    from textual.theme import BUILTIN_THEMES
    from torrra.core.exceptions import IndexerError
    from torrra.indexers.prowlarr import ProwlarrIndexer
    from torrra.screens.welcome import SearchInput, WelcomeScreen
    idx = ProwlarrIndexer(cfg.get("indexers.prowlarr.url"), key)
    seen = {"healthy": asyncio.run(idx.healthcheck())}
    seen["welcome"] = [f"input: {w.placeholder}" if isinstance(w, SearchInput) else f"{w.id or w.classes or ''}: {w.renderable}"
                       for w in WelcomeScreen(idx).compose()]
    seen["searches"] = []
    for q in [q for q in os.environ.get("FAKE_QUERY", "").split("|") if q]:
        try:
            seen["searches"].append(asyncio.run(idx.search(q)))
        except IndexerError as e:
            seen["searches"].append(f"IndexerError: {e}")
    t = BUILTIN_THEMES.get(cfg.get("general.theme"))
    seen["drawn_with"] = None if t is None else {k: v for k, v in vars(t).items() if k != "variables"}
    seen["drawn_vars"] = None if t is None else t.variables
    seen["css"] = app.TorrraApp.CSS
    return seen


def cli():
    cfg = Config()
    key = cfg.get("indexers.prowlarr.api_key")
    cfg.set("indexers.prowlarr.api_key", key)            # (torrra writes it back at each start)
    words = [a for a in sys.argv[1:] if not a.startswith("-")]
    seen = {}
    if not {"--help", "-h", "--version"} & set(sys.argv) and (words[:1] or [""])[0] not in ("config", "download"):
        seen = window(cfg, key)
    if os.environ.get("FAKE_DL"):
        from torrra.core.download import Handle, get_download_manager
        from torrra.screens.home import HomeScreen
        screen, run = HomeScreen(), os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-downloads")
        for n, moment in enumerate(json.load(open(os.environ["FAKE_DL"]))):
            get_download_manager().torrents = {t["name"]: Handle(t) for t in moment}
            screen._update_downloads_data()
            with open(f"{os.environ['FAKE_DL']}.seen.{n}", "w") as f:
                for p in sorted(os.listdir(run)) if os.path.isdir(run) else []:
                    f.write(f"== {p.split('.')[0]}\n" + open(os.path.join(run, p)).read())
            time.sleep(2.05)
    if os.environ.get("FAKE_SAY"):
        print(os.environ["FAKE_SAY"], file=sys.stderr)
    print(json.dumps({"argv": sys.argv, "key": key, "url": cfg.get("indexers.prowlarr.url"),
                      "default": cfg.get("indexers.default"), "theme": cfg.get("general.theme"),
                      "timeout": cfg.get("general.timeout"), "max_retries": cfg.get("general.max_retries"),
                      "env_key": os.environ.get("KAWA_KEY"), "env_pak": os.environ.get("PROWLARR_API_KEY"),
                      "env_other": os.environ.get("KAWA_TEST_OTHER_KEY"), **seen}, ensure_ascii=False))
    return int(os.environ.get("FAKE_RC", "0"))
