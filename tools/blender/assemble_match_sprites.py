"""Packs render_match_sprites.py's frames into sheets the client loads.

    python assemble_match_sprites.py FRAMES_DIR [OUT_DIR] [--preview FILE]

Sheet layout (per kind and layer): one column per frame in `layout.json`'s clip
order, one row per heading (8 rows, see render_match_sprites.py for what a row
means). Frames are downsampled from the 2x render with Lanczos, which is what
gives the flat-shaded facets clean edges.
"""
import json
import os
import sys

from PIL import Image

LAYERS = ["base", "shirt", "shorts", "socks"]
DIRS = 8
SIZE = {"outfield": (128, 176), "keeper": (192, 176)}
CLIPS = {
    "outfield": [("idle", 1), ("run", 8)],
    "keeper": [("ready", 1), ("diveL", 4), ("diveR", 4)],
}

args = [a for a in sys.argv[1:] if not a.startswith("--")]
FRAMES = args[0]
OUT = args[1] if len(args) > 1 else os.path.join(
    os.path.dirname(__file__), "..", "..", "assets", "images", "sprites", "players")
os.makedirs(OUT, exist_ok=True)

layout = {"directions": DIRS, "layers": LAYERS, "kinds": {}}
for kind, (w, h) in SIZE.items():
    if not os.path.isdir(os.path.join(FRAMES, kind)):
        continue
    cols = []
    clips = {}
    for clip, n in CLIPS[kind]:
        clips[clip] = {"start": len(cols), "count": n}
        cols += [(clip, i) for i in range(n)]
    layout["kinds"][kind] = {"frame": [w, h], "clips": clips}
    for layer in LAYERS:
        sheet = Image.new("RGBA", (w * len(cols), h * DIRS), (0, 0, 0, 0))
        for c, (clip, i) in enumerate(cols):
            for d in range(DIRS):
                p = os.path.join(FRAMES, kind, layer, f"{clip}_{i}_{d}.png")
                if not os.path.exists(p):
                    continue
                im = Image.open(p).convert("RGBA").resize((w, h), Image.LANCZOS)
                sheet.paste(im, (c * w, d * h))
        sheet.save(os.path.join(OUT, f"{kind}_{layer}.png"), optimize=True)
with open(os.path.join(OUT, "layout.json"), "w") as f:
    json.dump(layout, f, indent=2)


def tint(im, rgb):
    r, g, b, a = im.split()
    mul = lambda ch, k: ch.point(lambda v: int(v * k / 255))
    return Image.merge("RGBA", (mul(r, rgb[0]), mul(g, rgb[1]), mul(b, rgb[2]), a))


def compose(kind, col, d, kit):
    w, h = SIZE[kind]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for layer in LAYERS:
        sheet = Image.open(os.path.join(OUT, f"{kind}_{layer}.png"))
        im = sheet.crop((col * w, d * h, (col + 1) * w, (d + 1) * h))
        if layer != "base":
            im = tint(im, kit[layer])
        out = Image.alpha_composite(out, im)
    return out


if "--preview" in sys.argv:
    target = sys.argv[sys.argv.index("--preview") + 1]
    red = {"shirt": (224, 36, 40), "shorts": (40, 76, 200), "socks": (224, 36, 40)}
    blue = {"shirt": (30, 120, 220), "shorts": (250, 250, 250), "socks": (30, 120, 220)}
    yel = {"shirt": (250, 184, 26), "shorts": (30, 30, 40), "socks": (250, 184, 26)}
    rows = []
    for kind, kit in (("outfield", red), ("outfield", blue), ("keeper", yel)):
        w, h = SIZE[kind]
        cols = len(layout["kinds"][kind]["clips"]) and sum(n for _, n in CLIPS[kind])
        for d in range(DIRS):
            if not os.path.exists(os.path.join(FRAMES, kind, "base", f"{CLIPS[kind][0][0]}_0_{d}.png")):
                continue
            strip = Image.new("RGBA", (w * cols, h), (150, 170, 150, 255))
            for c in range(cols):
                strip.alpha_composite(compose(kind, c, d, kit), (c * w, 0))
            rows.append(strip)
    W = max(r.width for r in rows)
    sheet = Image.new("RGBA", (W, sum(r.height for r in rows)), (150, 170, 150, 255))
    y = 0
    for r in rows:
        sheet.alpha_composite(r, (0, y))
        y += r.height
    sheet.save(target)
    print("preview", sheet.size)
