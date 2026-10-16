"""torrra 2.5's settings, as far as kawa-torrra relies on them: a TOML file read at start,
written back by set() — the Prowlarr key included, which is why kawa-torrra steps in.
FAKE_TORRRA=nosave: a torrra that changed how it saves (no _save_config)."""
import os
import tomllib

CONFIG_FILE = os.path.join(os.environ["HOME"], ".config", "torrra", "config.toml")


def _dump(d, prefix=""):
    lines, tables = [], []
    for k, v in d.items():
        if isinstance(v, dict):
            tables.append((k, v))
        elif isinstance(v, bool):
            lines.append(f"{k} = {'true' if v else 'false'}")
        elif isinstance(v, (int, float)):
            lines.append(f"{k} = {v}")
        else:
            lines.append(f'{k} = "{v}"')
    out = "\n".join(lines) + ("\n" if lines else "")
    for k, v in tables:
        name = f"{prefix}{k}"
        out += f"\n[{name}]\n" + _dump(v, name + ".")
    return out


class Config:
    def __init__(self):
        self.config = {}
        self._load_config()

    def _load_config(self):
        try:
            with open(CONFIG_FILE, "rb") as f:
                self.config = tomllib.load(f)
        except (OSError, tomllib.TOMLDecodeError):
            self.config = {}

    def get(self, key_path, default=None):
        d = self.config
        for k in key_path.split("."):
            if not isinstance(d, dict) or k not in d:
                return default
            d = d[k]
        return d

    def set(self, key_path, value):
        *path, last = key_path.split(".")
        d = self.config
        for k in path:
            d = d.setdefault(k, {})
        d[last] = value
        self._save_config()

    def _save_config(self):
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, "w") as f:
            f.write(_dump(self.config))


if os.environ.get("FAKE_TORRRA") == "nosave":
    del Config._save_config
