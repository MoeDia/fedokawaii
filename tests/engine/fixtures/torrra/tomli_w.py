"""tomli_w, as setup.sh's settings writer uses it: dump(dict, binary file) — tables, strings,
numbers and booleans, enough for torrra's config.toml."""


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
        out += f"\n[{prefix}{k}]\n" + _dump(v, f"{prefix}{k}.")
    return out


def dump(d, f):
    f.write(_dump(d).encode())
