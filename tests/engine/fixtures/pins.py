"""pins.py CONSTRAINTS SITE — every library CONSTRAINTS pins, there in SITE at its pin (a
dist-info of its own: what pipx's install leaves), any other version of it gone."""
import glob, os, shutil, sys

for line in open(sys.argv[1]):
    if line.strip() and not line.startswith("#"):
        n, v = line.strip().split("==")
        d_ = n.replace("-", "_")                          # (a dist-info's name: as pip writes it)
        for d in glob.glob(os.path.join(sys.argv[2], f"{d_}-[0-9]*.dist-info")):
            shutil.rmtree(d)
        os.makedirs(os.path.join(sys.argv[2], f"{d_}-{v}.dist-info"))
        with open(os.path.join(sys.argv[2], f"{d_}-{v}.dist-info", "METADATA"), "w") as f:
            f.write(f"Metadata-Version: 2.1\nName: {n}\nVersion: {v}\n")
