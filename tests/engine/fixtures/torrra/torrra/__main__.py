"""torrra's command line, as a stand-in: like torrra 2.5 it stores the Prowlarr key it was
given at every start, then says what it sees (one JSON line) and exits with FAKE_RC (0)."""
import json
import os
import sys

from torrra.core.config import Config


def cli():
    cfg = Config()
    key = cfg.get("indexers.prowlarr.api_key")
    cfg.set("indexers.prowlarr.api_key", key)            # (torrra writes it back at each start)
    print(json.dumps({"argv": sys.argv, "key": key, "url": cfg.get("indexers.prowlarr.url"),
                      "default": cfg.get("indexers.default"), "theme": cfg.get("general.theme"),
                      "env_key": os.environ.get("KAWA_KEY"), "env_pak": os.environ.get("PROWLARR_API_KEY")}))
    return int(os.environ.get("FAKE_RC", "0"))
