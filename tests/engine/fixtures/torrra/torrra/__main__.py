"""torrra's command line, as a stand-in: like torrra 2.5 it stores the Prowlarr key it was
given at every start, then says what it sees (one JSON line) and exits with FAKE_RC (0).
FAKE_SAY: words it says on stderr before it exits 0 (as torrra says what stops it).
FAKE_DL: a JSON file, a list of moments 2 s apart — each the torrents its window holds then
({name, save_path, done, total, finished, paused}); at each its screen ticks, and what
$XDG_RUNTIME_DIR/kawa-downloads holds right after is written to FAKE_DL.seen.N."""
import json
import os
import sys
import time

from torrra.core.config import Config


def cli():
    cfg = Config()
    key = cfg.get("indexers.prowlarr.api_key")
    cfg.set("indexers.prowlarr.api_key", key)            # (torrra writes it back at each start)
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
                      "env_other": os.environ.get("KAWA_TEST_OTHER_KEY")}))
    return int(os.environ.get("FAKE_RC", "0"))
