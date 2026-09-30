"""Renders the match cast to per-frame PNGs, one set per tintable kit layer.

Run headless (it builds the players itself, see build_match_players.py):

    blender -b --factory-startup -P render_match_sprites.py -- OUT_DIR [kind] [--smoke]

Output: OUT_DIR/<kind>/<layer>/<clip>_<frame>_<dir>.png at 2x the final frame
size (assemble_match_sprites.py downsamples for clean edges).

Layers
  base   everything that is NOT kit (skin, hair, boots, trim, gloves) with the kit
         parts held out, so it is correctly occluded by them
  shirt / shorts / socks
         only that kit part, in *white*, lit like the real thing. The client draws
         it with BlendMode.modulate and the team colour, which multiplies the
         shading onto the colour — so one render serves every kit.

View: fixed ortho camera 22 degrees above the horizon, like a player billboard in
the shot game's pitch projection. 8 headings, 45 degrees apart: dir k means the
player is seen turned k*45 deg clockwise from "facing away from the camera", so
k=0 back, 2 facing screen-right, 4 facing the camera, 6 facing screen-left.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else r"C:/Users/Hasan Efe/Desktop/Workspace/ProjectSRPG/tools/blender"
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = args[0]
ONLY = [a for a in args[1:] if not a.startswith("--")]
SMOKE = "--smoke" in args

exec(open(os.path.join(HERE, "build_match_players.py"), encoding="utf-8").read())

PX_PER_M = 140.0
PITCH = math.radians(22)
SS = 2  # supersampling
FRAME_H = 176
FRAME = {"outfield": (128, FRAME_H), "keeper": (192, FRAME_H)}
DIRS = 8
LAYERS = ["base", "shirt", "shorts", "socks"]
KIT_OF = {"Shirt": "shirt", "Shorts": "shorts", "Socks": "socks"}

sc = bpy.data.scenes["MatchPlayers"]
bpy.context.window_manager  # noqa
try:
    bpy.context.window.scene = sc
except Exception:
    pass
for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        sc.render.engine = e
        break
    except TypeError:
        pass
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
try:
    sc.eevee.taa_render_samples = 24
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"

# lighting: neutral, sun up-left-front; tuned so a white surface peaks just under 1.0
sun = bpy.data.objects["Sun"]
sun.data.energy = float(os.environ.get("SUN", "1.7"))
sun.data.angle = math.radians(20)
sun.rotation_euler = (math.radians(55), 0, math.radians(35))
bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (1, 1, 1, 1)
bg.inputs[1].default_value = float(os.environ.get("AMBIENT", "0.32"))

cam = bpy.data.objects.get("SpriteCam") or bpy.data.objects.new("SpriteCam", bpy.data.cameras.new("SpriteCam"))
if cam.name not in sc.objects:
    sc.collection.objects.link(cam)
cam.data.type = "ORTHO"
sc.camera = cam

# materials ------------------------------------------------------------------
hold = bpy.data.materials.new("HOLD")
hold.use_nodes = True
hold.node_tree.nodes.clear()
_o = hold.node_tree.nodes.new("ShaderNodeOutputMaterial")
_h = hold.node_tree.nodes.new("ShaderNodeHoldout")
hold.node_tree.links.new(_h.outputs[0], _o.inputs[0])
white = bpy.data.materials.new("WHITE")
white.use_nodes = True
for n in white.node_tree.nodes:
    if n.type == "BSDF_PRINCIPLED":
        n.inputs["Base Color"].default_value = (1, 1, 1, 1)
        n.inputs["Roughness"].default_value = 0.9
        for k in ("Specular IOR Level", "Specular"):
            if k in n.inputs:
                n.inputs[k].default_value = 0.0


def strip(n):
    return n.rstrip("0123456789").rstrip(".")


def descendants(o):
    for c in o.children:
        yield c
        yield from descendants(c)


def joints(root):
    return {strip(o.name): o for o in descendants(root) if o.type == "EMPTY"}


def meshes(root):
    return [(o, o.data.materials[0]) for o in descendants(root) if o.type == "MESH"]


def kit_layer(mat):
    name = strip(mat.name)
    for k, layer in KIT_OF.items():
        if name.endswith("_" + k):
            return layer
    return None


def set_layer(parts, layer):
    for o, orig in parts:
        kl = kit_layer(orig)
        if layer == "base":
            m = hold if kl else orig
        else:
            m = white if kl == layer else hold
        o.data.materials[0] = m


def restore(parts):
    for o, orig in parts:
        o.data.materials[0] = orig


# poses ----------------------------------------------------------------------
D = math.radians


def reset(J):
    for o in J.values():
        o.rotation_euler = (0, 0, 0)
    J["Body"].location = (0, 0, 0)


def ground(J, root, extra=0.0):
    """Drop the body so the lowest boot vertex sits on z=0 (+extra hop)."""
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    low = 9.0
    for o in descendants(root):
        if o.type == "MESH" and strip(o.name).startswith(("Boot", "Sole")):
            ev = o.evaluated_get(dg)
            mw = ev.matrix_world
            for v in ev.data.vertices:
                low = min(low, (mw @ v.co).z)
    b = J["Body"]
    b.location.z -= low - root.location.z
    b.location.z += extra


def lift(J, root, floor=0.05):
    """Raise the body until no part of any mesh is below [floor] metres."""
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    low = 9.0
    for o in descendants(root):
        if o.type == "MESH":
            ev = o.evaluated_get(dg)
            mw = ev.matrix_world
            for v in ev.data.vertices:
                low = min(low, (mw @ v.co).z)
    if low < floor:
        J["Body"].location.z += floor - low


def pose_stand(J, root):
    reset(J)
    J["Shoulder_L"].rotation_euler.y = D(-7)
    J["Shoulder_R"].rotation_euler.y = D(7)
    for s in "LR":
        J[f"Elbow_{s}"].rotation_euler.x = D(-12)
        J[f"Hip_{s}"].rotation_euler.y = D(-3 if s == "L" else 3)
    ground(J, root)


def pose_run(J, root, i, n=8):
    reset(J)
    ph = 2 * math.pi * i / n
    A, K, B = D(50), D(72), D(48)
    for s, off in (("L", 0.0), ("R", math.pi)):
        p = ph + off
        hip = -A * math.sin(p)
        knee = D(14) + K * max(0.0, math.cos(p))
        J[f"Hip_{s}"].rotation_euler.x = hip
        J[f"Knee_{s}"].rotation_euler.x = knee
        J[f"Ankle_{s}"].rotation_euler.x = -(hip + knee) * 0.45
        arm = B * math.sin(ph) * (1 if s == "L" else -1)
        J[f"Shoulder_{s}"].rotation_euler.x = arm
        J[f"Shoulder_{s}"].rotation_euler.y = D(-8 if s == "L" else 8)
        J[f"Elbow_{s}"].rotation_euler.x = D(-70) - D(18) * max(0.0, -math.sin(ph) * (1 if s == "L" else -1))
    J["Chest"].rotation_euler.x = D(11)
    J["Chest"].rotation_euler.z = D(9) * math.sin(ph)
    J["Head"].rotation_euler.x = D(-7)
    J["Head"].rotation_euler.z = -D(9) * math.sin(ph)
    ground(J, root, extra=0.03 * max(0.0, -math.cos(2 * ph)))


def pose_ready(J, root):
    reset(J)
    for s, sx in (("L", 1), ("R", -1)):
        J[f"Hip_{s}"].rotation_euler.x = D(-22)
        J[f"Hip_{s}"].rotation_euler.y = D(-13) * sx
        J[f"Knee_{s}"].rotation_euler.x = D(42)
        J[f"Ankle_{s}"].rotation_euler.x = D(-14)
        J[f"Shoulder_{s}"].rotation_euler.x = D(-38)
        J[f"Shoulder_{s}"].rotation_euler.y = D(-42) * sx
        J[f"Elbow_{s}"].rotation_euler.x = D(-58)
    J["Chest"].rotation_euler.x = D(16)
    J["Head"].rotation_euler.x = D(-12)
    ground(J, root)


def pose_dive(J, root, i, side, n=4):
    """side +1 dives toward the keeper's left (+X in model space), -1 to his right."""
    reset(J)
    u = (i + 1) / n
    e = u * u * (3 - 2 * u)  # ease
    b = D(82) * e * side
    # pivot at the waist so the body swings over rather than around the feet
    pz = 0.5
    J["Body"].rotation_euler.y = b
    J["Body"].location = (-pz * math.sin(b) - 0.10 * e * side,
                          0,
                          pz - pz * math.cos(b) - 0.14 * e)
    for s, sx in (("L", 1), ("R", -1)):
        J[f"Hip_{s}"].rotation_euler.x = D(-10) * e
        J[f"Hip_{s}"].rotation_euler.y = D(-10) * sx * e
        J[f"Knee_{s}"].rotation_euler.x = D(28) * e
        J[f"Shoulder_{s}"].rotation_euler.x = D(-172) * e
        J[f"Shoulder_{s}"].rotation_euler.y = D(8) * sx * e
        J[f"Elbow_{s}"].rotation_euler.x = D(-8) * e
    J["Head"].rotation_euler.x = D(-14) * e
    lift(J, root)


CLIPS = {
    "outfield": [("idle", 1, lambda J, r, i: pose_stand(J, r)),
                 ("run", 8, lambda J, r, i: pose_run(J, r, i))],
    "keeper": [("ready", 1, lambda J, r, i: pose_ready(J, r)),
               ("diveL", 4, lambda J, r, i: pose_dive(J, r, i, +1)),
               ("diveR", 4, lambda J, r, i: pose_dive(J, r, i, -1))],
}

# camera ---------------------------------------------------------------------


def frame_camera(w, h):
    sc.render.resolution_x = w * SS
    sc.render.resolution_y = h * SS
    cam.data.ortho_scale = max(w, h) / PX_PER_M
    # camera-space up vector; put world origin 4 px above the frame's bottom edge
    up = (0, math.sin(PITCH), math.cos(PITCH))
    k = (h / 2 - 4) / PX_PER_M
    c = tuple(u * k for u in up)
    dist = 8.0
    cam.location = (c[0], c[1] - dist * math.cos(PITCH), c[2] + dist * math.sin(PITCH))
    cam.rotation_euler = (math.pi / 2 - PITCH, 0, 0)
    cam.data.clip_end = 40


# main -----------------------------------------------------------------------
roots = {"outfield": bpy.data.objects["Player_Outfield"], "keeper": bpy.data.objects["Player_Keeper"]}
for kind, root in roots.items():
    root.location.x = 0
kinds = ONLY or ["outfield", "keeper"]
count = 0
for kind in kinds:
    root = roots[kind]
    for k2, r2 in roots.items():
        for o in [r2, *descendants(r2)]:
            o.hide_render = k2 != kind
    J = joints(root)
    parts = meshes(root)
    w, h = FRAME[kind]
    frame_camera(w, h)
    for clip, n, fn in CLIPS[kind]:
        for i in range(n):
            fn(J, root, i)
            for d in range(DIRS):
                if SMOKE and d not in (0, 2, 4):
                    continue
                root.rotation_euler.z = D(180 - 45 * d)
                bpy.context.view_layer.update()
                for layer in LAYERS:
                    set_layer(parts, layer)
                    path = os.path.join(OUT, kind, layer, f"{clip}_{i}_{d}.png")
                    os.makedirs(os.path.dirname(path), exist_ok=True)
                    sc.render.filepath = path
                    bpy.ops.render.render(write_still=True, scene=sc.name)
                    count += 1
                restore(parts)
print("RENDERED", count)
