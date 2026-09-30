"""Builds the six relationship busts in Blender, with a rigged face.

Source art: assets/images/portraits/<relationship_id>.png (pixel-art busts). Each one is
rebuilt as a low-poly, flat-shaded 3D bust in the same style as build_match_players.py
(big head, no outlines, palette read off the portrait). Run inside Blender (exec the
file); it makes its own scene "RelationshipPortraits" and leaves whatever else is open
untouched. Then call `export_all()` to write the .blend and one .glb per character into
assets/models/relationship_portraits/.

Every character lives under a root empty `Portrait_<id>` and is built facing -Y.
The face is animated three ways, so both Blender and a glTF consumer can drive it:

* shape keys (glTF morph targets)
    Mouth     MouthOpen, Smile, Frown, Pucker
    Eyelids   BlinkL, BlinkR
    Brows     BrowUp, BrowAngry, BrowSad
* eye pivots `EyePivot_L/R_<id>` — rotate the eyeball + iris (look direction)
* a control empty `Face_<id>` whose custom properties drive all of the above through
  drivers: MouthOpen, Smile, Frown, Pucker, BlinkL, BlinkR, BrowUp, BrowAngry, BrowSad,
  LookX, LookY. The action "Talk_<id>" keys those properties (blink + speech flaps).
"""
import math
import os
import bpy
import bmesh
from mathutils import Vector

try:
    OUT_DIR
except NameError:
    OUT_DIR = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "..",
        "assets", "models", "relationship_portraits")
OUT_DIR = os.path.abspath(OUT_DIR)


def srgb(r, g, b):
    """Palette values are written as 0-255 sRGB (what the portrait shows) and
    converted, since Blender materials are linear."""
    f = lambda v: ((v / 255 + 0.055) / 1.055) ** 2.4 if v / 255 > 0.04045 else v / 255 / 12.92
    return (f(r), f(g), f(b), 1)


def tone(rgb, k):
    return tuple(max(0, min(255, round(c * k))) for c in rgb)


# id -> look, sampled from the portrait pngs. `hair` picks the hair builder,
# `push` is how far the mouth floats in front of the skull (a beard needs room).
CAST = {
    "coach": dict(skin=(160, 100, 70), hair_c=(45, 30, 25), shirt=(55, 80, 140),
                  hair="flat", push=0.004, iris=(40, 28, 22)),
    "team": dict(skin=(215, 160, 120), hair_c=(70, 45, 35), shirt=(150, 65, 40),
                 hair="bun", beard=(60, 40, 30), glasses=(40, 40, 45), tee=(235, 235, 235),
                 push=0.022, iris=(50, 35, 28)),
    "media": dict(skin=(225, 165, 125), hair_c=(110, 75, 55), shirt=(225, 225, 230),
                  hair="ponytail", inner=(235, 225, 190), blazer=True, push=0.004,
                  iris=(60, 40, 30)),
    "fans": dict(skin=(215, 160, 125), hair_c=(95, 60, 45), shirt=(30, 30, 35),
                 hair="mohawk", glasses=(235, 235, 240), push=0.004, iris=(50, 38, 30)),
    "partner": dict(skin=(225, 170, 135), hair_c=(70, 45, 40), shirt=(45, 70, 120),
                    hair="long", necklace=(200, 200, 210), push=0.004, iris=(45, 30, 25)),
    "family": dict(skin=(95, 55, 40), hair_c=(25, 30, 45), shirt=(200, 140, 50),
                   hair="curly", glasses=(220, 170, 60), push=0.004, iris=(30, 20, 18)),
}

# --- scene ------------------------------------------------------------------
scene = bpy.data.scenes.get("RelationshipPortraits") or bpy.data.scenes.new("RelationshipPortraits")
try:
    bpy.context.window.scene = scene
except Exception:
    pass
for o in list(scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)


def mat(name, rgb, rough=0.9):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(*rgb)
    bsdf.inputs["Roughness"].default_value = rough
    # no sheen on cloth/skin: a white ambient reflecting off it only washes the colour out
    for k in ("Specular IOR Level", "Specular"):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = 0.0
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    m.diffuse_color = srgb(*rgb)
    return m


def empty(name, loc=(0, 0, 0), parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = "PLAIN_AXES"
    e.empty_display_size = 0.05
    e.location = loc
    scene.collection.objects.link(e)
    e.parent = parent
    return e


def to_obj(name, bm, mats, parent, loc=(0, 0, 0), rot=(0, 0, 0)):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]):
        mesh.materials.append(m)
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    return o


def blob(name, loc, radii, m, parent, segs=12, rings=8, rot=(0, 0, 0), clip=None):
    """Flat-shaded ellipsoid; `clip(p)` on the scaled local point deletes vertices."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
    if clip:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if clip(v.co)], context="VERTS")
    return to_obj(name, bm, m, parent, loc, rot)


def box(name, loc, size, m, parent, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return to_obj(name, bm, m, parent, loc, rot)


def torus(name, loc, R, r, m, parent, rot=(0, 0, 0), squash=(1, 1, 1), segs=20, sides=6):
    bm = bmesh.new()
    ring = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        row = []
        for j in range(sides):
            b = 2 * math.pi * j / sides
            rr = R + r * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a) * squash[0], rr * math.sin(a) * squash[1],
                                     r * math.sin(b) * squash[2])))
        ring.append(row)
    for i in range(segs):
        for j in range(sides):
            bm.faces.new((ring[i][j], ring[(i + 1) % segs][j],
                          ring[(i + 1) % segs][(j + 1) % sides], ring[i][(j + 1) % sides]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return to_obj(name, bm, m, parent, loc, rot)


# --- face geometry ----------------------------------------------------------
HEAD_R = (0.17, 0.15, 0.2)         # skull radii, head-local, centred on the Head empty
EYE_X, EYE_Y, EYE_Z = 0.065, -0.108, 0.02
EYE_R = 0.042
LID_R = 0.047


def surf(x, z):
    """Skull front surface (y) at x,z — features are laid onto it so they hug the head."""
    t = 1 - (x / HEAD_R[0]) ** 2 - (z / HEAD_R[2]) ** 2
    return -HEAD_R[1] * math.sqrt(max(t, 0.02))


MOUTH_COLS = 9
MOUTH_ZC = -0.085


def mouth_positions(push, o=0.0, s=0.0, f=0.0, p=0.0, hw=0.048):
    """4 rows x MOUTH_COLS: outer upper lip, inner upper, inner lower, outer lower lip.
    Every shape key is this function with different weights, so vertex order is shared."""
    rows = [[], [], [], []]
    for i in range(MOUTH_COLS):
        u = -1 + 2 * i / (MOUTH_COLS - 1)
        x = hw * u * (1 - 0.35 * p - 0.12 * o)
        curve = (s - f) * 0.016 * u * u
        w = 1 - 0.5 * u * u
        bell = max(0.0, 1 - u * u) ** 0.6
        up_in = MOUTH_ZC + curve + 0.0015 + 0.004 * o * bell
        lo_in = MOUTH_ZC + curve - 0.0015 - o * 0.045 * bell - p * 0.012 * bell
        zs = (up_in + (0.011 + 0.003 * p) * w, up_in, lo_in, lo_in - (0.013 + 0.003 * p) * w)
        for r in range(4):
            rows[r].append((x, surf(x, zs[r]) - push, zs[r]))
    return [pt for row in rows for pt in row]


def build_mouth(head, lip_m, inner_m, push):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in mouth_positions(push)]
    n = MOUTH_COLS
    for r in range(3):
        for i in range(n - 1):
            # (a, d, c, b): normal faces the viewer at -Y
            f = bm.faces.new((vs[r * n + i], vs[(r + 1) * n + i],
                              vs[(r + 1) * n + i + 1], vs[r * n + i + 1]))
            f.material_index = 1 if r == 1 else 0
    o = to_obj("Mouth", bm, [lip_m, inner_m], head)
    shape_keys(o, {
        "MouthOpen": mouth_positions(push, o=1),
        "Smile": mouth_positions(push, s=1),
        "Frown": mouth_positions(push, f=1),
        "Pucker": mouth_positions(push, o=0.3, p=1),
    })
    return o


LID_COLS = 9
LID_ROWS = 8


def lid_positions(blink_l=0.0, blink_r=0.0):
    """Skin-coloured cap sliding over the eyeball: top row is parked inside the skull,
    the bottom row travels down from it as Blink goes 0 -> 1."""
    pts = []
    for sg, blink in ((-1, blink_l), (1, blink_r)):
        c = Vector((sg * EYE_X, EYE_Y, EYE_Z))
        e_top = math.radians(72)
        e_bot = math.radians(72 - blink * 130)
        # in-between rows follow the sphere; with only two the closed lid would be a
        # chord cutting through the eyeball instead of a cap over it
        for r in range(LID_ROWS):
            e = e_top + (e_bot - e_top) * r / (LID_ROWS - 1)
            for i in range(LID_COLS):
                a = math.radians(-62 + 124 * i / (LID_COLS - 1))
                d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
                pts.append(c + LID_R * d)
    return pts


def build_lids(head, lid_m):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in lid_positions()]
    n = LID_COLS
    for side in range(2):
        base = side * LID_ROWS * n
        for r in range(LID_ROWS - 1):
            for i in range(n - 1):
                a = base + r * n + i
                bm.faces.new((vs[a], vs[a + n], vs[a + n + 1], vs[a + 1]))
    o = to_obj("Eyelids", bm, lid_m, head)
    # faces are degenerate while open: the lid is folded away inside the skull
    shape_keys(o, {"BlinkL": lid_positions(blink_l=1), "BlinkR": lid_positions(blink_r=1)})
    return o


BROW_COLS = 5


def brow_positions(up=0.0, angry=0.0, sad=0.0):
    pts = []
    for sg in (-1, 1):
        rows = ([], [])
        for i in range(BROW_COLS):
            t = i / (BROW_COLS - 1)          # 0 inner .. 1 outer
            x = sg * (0.03 + 0.07 * t)
            z = 0.078 + 0.012 * math.sin(math.pi * t) - 0.006 * t
            z += 0.014 * up - 0.014 * angry * (1 - t) + 0.004 * angry * t \
                + 0.012 * sad * (1 - t) - 0.004 * sad * t
            th = 0.013 - 0.004 * t
            rows[0].append((x, surf(x, z) - 0.003, z + th / 2))
            rows[1].append((x, surf(x, z) - 0.003, z - th / 2))
        pts += rows[0] + rows[1]
    return pts


def build_brows(head, m):
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in brow_positions()]
    n = BROW_COLS
    for side in range(2):
        base = side * 2 * n
        for i in range(n - 1):
            bm.faces.new((vs[base + i], vs[base + n + i], vs[base + n + i + 1], vs[base + i + 1]))
    o = to_obj("Brows", bm, m, head)
    shape_keys(o, {"BrowUp": brow_positions(up=1), "BrowAngry": brow_positions(angry=1),
                   "BrowSad": brow_positions(sad=1)})
    return o


def shape_keys(o, keys):
    o.shape_key_add(name="Basis")
    for name, pts in keys.items():
        sk = o.shape_key_add(name=name, from_mix=False)
        for i, p in enumerate(pts):
            sk.data[i].co = Vector(p)
        sk.slider_min, sk.slider_max = 0.0, 1.0


# --- hair -------------------------------------------------------------------
def hair_cap(head, m, grow=1.0, z_lo=-0.05, z_front=0.105, name="HairCap"):
    # front of the face below the hairline is left bare, so the forehead stays visible
    return blob(name, (0, 0.008, 0.012), (0.18 * grow, 0.16 * grow, 0.21 * grow), m, head, segs=14, rings=10,
                clip=lambda p: p.z < z_lo or (p.y < -0.05 and p.z < z_front))


def build_hair(kind, head, m):
    if kind == "flat":
        hair_cap(head, m, grow=1.03, z_lo=-0.02, z_front=0.095)
        blob("HairTop", (0, -0.005, 0.2), (0.16, 0.14, 0.06), m, head, segs=8, rings=4)
    elif kind == "bun":
        hair_cap(head, m)
        blob("HairBack", (0, 0.12, -0.08), (0.19, 0.06, 0.3), m, head)
        for sg in (-1, 1):
            blob(f"HairSide{sg}", (sg * 0.17, 0.05, -0.05), (0.04, 0.07, 0.17), m, head)
        blob("Bun", (0, 0.04, 0.26), (0.06, 0.06, 0.06), m, head)
    elif kind == "ponytail":
        hair_cap(head, m)
        blob("HairBack", (0, 0.1, -0.02), (0.18, 0.06, 0.2), m, head)
        blob("Ponytail", (0.07, 0.17, -0.1), (0.05, 0.05, 0.2), m, head, rot=(0, 0.2, 0))
    elif kind == "mohawk":
        stubble = mat("Stubble_fans", tone(CAST["fans"]["skin"], 0.72))
        hair_cap(head, stubble, grow=1.0, z_lo=0.03, z_front=0.12, name="HairStubble")
        for i, y in enumerate((-0.09, -0.04, 0.01, 0.06, 0.11)):
            blob(f"Crest{i}", (0, y, 0.2 + 0.03 * (1 - abs(i - 2) / 2)), (0.028, 0.04, 0.06), m, head, segs=8, rings=6)
    elif kind == "long":
        hair_cap(head, m)
        blob("HairBack", (0, 0.11, -0.12), (0.22, 0.08, 0.34), m, head)
        for sg in (-1, 1):
            blob(f"HairFront{sg}", (sg * 0.19, 0.0, -0.14), (0.05, 0.06, 0.3), m, head)
    elif kind == "curly":
        hair_cap(head, m, grow=1.1)
        for k in range(26):
            t = 0.15 + 0.85 * (k + 0.5) / 26
            ph = k * 2.39996
            rr = math.sqrt(1 - t * t)
            p = Vector((HEAD_R[0] * rr * math.cos(ph), HEAD_R[1] * rr * math.sin(ph), HEAD_R[2] * t)) * 1.02
            if p.y < -0.05 and p.z < 0.11:
                continue
            blob(f"Curl{k}", p + Vector((0, 0, 0.012)), (0.05, 0.05, 0.05), m, head, segs=8, rings=6)


# --- character --------------------------------------------------------------
HEAD_Z = 0.62


def build_character(cid, index):
    c = CAST[cid]
    skin, hair_c, shirt = c["skin"], c["hair_c"], c["shirt"]
    skin_m = mat(f"Skin_{cid}", skin)
    hair_m = mat(f"Hair_{cid}", hair_c)
    shirt_m = mat(f"Shirt_{cid}", shirt)
    collar_m = mat(f"Collar_{cid}", tone(shirt, 1.18))
    lid_m = mat(f"Lid_{cid}", tone(skin, 0.95))
    lip_m = mat(f"Lip_{cid}", (round(skin[0] * 0.85), round(skin[1] * 0.62), round(skin[2] * 0.62)))
    inner_m = mat(f"MouthInner_{cid}", (70, 25, 30))
    white_m = mat(f"EyeWhite_{cid}", (245, 245, 245), 0.4)
    iris_m = mat(f"Iris_{cid}", c["iris"], 0.5)
    pupil_m = mat(f"Pupil_{cid}", (12, 10, 12), 0.4)

    root = empty(f"Portrait_{cid}", (index * 0.95 - 2.375, 0, 0))
    head = empty(f"Head_{cid}", (0, 0, HEAD_Z), root)

    # body: bust crop, like the portraits
    blob(f"Torso_{cid}", (0, 0, 0.06), (0.27, 0.165, 0.27), shirt_m, root, segs=14, rings=10,
         clip=lambda p: p.z < -0.17)
    for sg in (-1, 1):
        blob(f"Shoulder{sg}_{cid}", (sg * 0.245, 0, 0.26), (0.07, 0.075, 0.07), shirt_m, root)
        blob(f"Arm{sg}_{cid}", (sg * 0.285, 0, 0.05), (0.065, 0.07, 0.22), shirt_m, root, rot=(0, -sg * 0.08, 0))
    blob(f"Neck_{cid}", (0, 0, 0.36), (0.06, 0.06, 0.1), skin_m, root)
    torus(f"Collar_{cid}", (0, 0, 0.31), 0.085, 0.02, collar_m, root, squash=(1, 0.85, 1))
    if c.get("tee"):
        box(f"Tee_{cid}", (0, -0.176, 0.12), (0.07, 0.012, 0.2), mat(f"Tee_{cid}", c["tee"]), root)
    if c.get("blazer"):
        inner_shirt = mat(f"Inner_{cid}", c["inner"])
        blob(f"Inner_{cid}", (0, -0.17, 0.15), (0.07, 0.012, 0.12), inner_shirt, root)
        for sg in (-1, 1):
            box(f"Lapel{sg}_{cid}", (sg * 0.085, -0.172, 0.15), (0.035, 0.012, 0.17),
                mat(f"Lapel_{cid}", tone(shirt, 0.88)), root, rot=(0, sg * 0.4, 0))
    if c.get("necklace"):
        nk = mat(f"Necklace_{cid}", c["necklace"], 0.3)
        torus(f"Necklace_{cid}", (0, -0.15, 0.24), 0.085, 0.004, nk, root,
              rot=(math.pi / 2 - 0.35, 0, 0), squash=(1, 1.3, 1), sides=4)
        blob(f"Pendant_{cid}", (0, -0.178, 0.135), (0.012, 0.006, 0.014), nk, root, segs=6, rings=4)

    # head
    blob(f"Skull_{cid}", (0, 0, 0), HEAD_R, skin_m, head, segs=14, rings=10)
    blob(f"Jaw_{cid}", (0, -0.01, -0.08), (0.135, 0.125, 0.12), skin_m, head, segs=12, rings=8)
    for sg in (-1, 1):
        blob(f"Ear{sg}_{cid}", (sg * 0.168, 0.01, 0.0), (0.02, 0.03, 0.045), skin_m, head, segs=8, rings=6)
    blob(f"Nose_{cid}", (0, surf(0, -0.03) - 0.008, -0.03), (0.022, 0.028, 0.035), mat(f"Nose_{cid}", tone(skin, 0.93)),
         head, segs=8, rings=6)
    if c.get("beard"):
        beard_m = mat(f"Beard_{cid}", c["beard"])
        blob(f"Beard_{cid}", (0, -0.01, -0.1), (0.155, 0.14, 0.125), beard_m, head, segs=14, rings=10,
             clip=lambda p: p.z > 0.05)  # blob-local z: keeps the beard below head z -0.05
        blob(f"Mustache_{cid}", (0, surf(0, -0.052) - 0.014, -0.052), (0.05, 0.016, 0.012), beard_m, head, segs=8, rings=6)
    build_hair(c["hair"], head, hair_m)

    # eyes: pivots rotate the eyeball + iris; lids/brows/mouth are shape-keyed meshes
    pivots = {}
    for sg, side in ((-1, "L"), (1, "R")):
        pv = empty(f"EyePivot_{side}_{cid}", (sg * EYE_X, EYE_Y, EYE_Z), head)
        blob(f"Eyeball_{side}_{cid}", (0, 0, 0), (EYE_R,) * 3, white_m, pv, segs=12, rings=8)
        blob(f"Iris_{side}_{cid}", (0, -0.0385, 0), (0.0235, 0.007, 0.0235), iris_m, pv, segs=10, rings=6)
        blob(f"Pupil_{side}_{cid}", (0, -0.0435, 0), (0.0115, 0.006, 0.0115), pupil_m, pv, segs=8, rings=6)
        blob(f"Glint_{side}_{cid}", (0.008, -0.0475, 0.009), (0.005, 0.003, 0.005), white_m, pv, segs=6, rings=4)
        pivots[side] = pv
    lids = build_lids(head, lid_m)
    brows = build_brows(head, hair_m)
    mouth = build_mouth(head, lip_m, inner_m, c["push"])
    if c.get("glasses"):
        gm = mat(f"Glasses_{cid}", c["glasses"], 0.35)
        for sg in (-1, 1):
            torus(f"Lens{sg}_{cid}", (sg * EYE_X, -0.152, EYE_Z), 0.052, 0.005, gm, head,
                  rot=(math.pi / 2, 0, 0), squash=(1.12, 1, 0.9), sides=4)
            box(f"Temple{sg}_{cid}", (sg * 0.163, -0.075, 0.03), (0.006, 0.15, 0.008), gm, head)
        box(f"Bridge_{cid}", (0, -0.152, EYE_Z + 0.01), (0.03, 0.006, 0.008), gm, head)

    rig_face(cid, root, pivots, lids, brows, mouth)
    return root


# --- rig --------------------------------------------------------------------
def drive(idblock, path, ctrl, prop, expr="v", index=-1):
    fc = idblock.driver_add(path) if index < 0 else idblock.driver_add(path, index)
    d = fc.driver
    d.type = "SCRIPTED"
    d.expression = expr
    var = d.variables.new()
    var.name = "v"
    var.targets[0].id = ctrl
    var.targets[0].data_path = f'["{prop}"]'


PROPS = {  # name -> (min, max)
    "MouthOpen": (0, 1), "Smile": (0, 1), "Frown": (0, 1), "Pucker": (0, 1),
    "BlinkL": (0, 1), "BlinkR": (0, 1),
    "BrowUp": (0, 1), "BrowAngry": (0, 1), "BrowSad": (0, 1),
    "LookX": (-1, 1), "LookY": (-1, 1),
}


def rig_face(cid, root, pivots, lids, brows, mouth):
    ctrl = empty(f"Face_{cid}", (0, -0.45, HEAD_Z), root)
    ctrl.empty_display_type = "CUBE"
    ctrl.empty_display_size = 0.04
    for k, (lo, hi) in PROPS.items():
        ctrl[k] = 0.0
        ctrl.id_properties_ui(k).update(min=lo, max=hi, soft_min=lo, soft_max=hi)
    for o, names in ((mouth, ("MouthOpen", "Smile", "Frown", "Pucker")),
                     (lids, ("BlinkL", "BlinkR")),
                     (brows, ("BrowUp", "BrowAngry", "BrowSad"))):
        for n in names:
            drive(o.data.shape_keys, f'key_blocks["{n}"].value', ctrl, n)
    for side in ("L", "R"):
        drive(pivots[side], "rotation_euler", ctrl, "LookX", "v * 0.45", 2)
        drive(pivots[side], "rotation_euler", ctrl, "LookY", "-v * 0.35", 0)
    talk_action(cid, ctrl)


def talk_action(cid, ctrl):
    """48-frame demo: one blink, a few syllables, a smile at the end."""
    def key(prop, frames):
        for f, v in frames:
            ctrl[prop] = v
            ctrl.keyframe_insert(f'["{prop}"]', frame=f)
    key("BlinkL", [(1, 0), (18, 0), (20, 1), (23, 0), (48, 0)])
    key("BlinkR", [(1, 0), (18, 0), (20, 1), (23, 0), (48, 0)])
    key("MouthOpen", [(1, 0), (4, 0.8), (7, 0.1), (10, 0.6), (13, 0.0), (16, 0.9), (20, 0.1),
                      (26, 0.0), (48, 0.0)])
    key("Smile", [(1, 0), (26, 0), (36, 0.8), (48, 0)])
    key("BrowUp", [(1, 0), (10, 0.7), (20, 0), (48, 0)])
    key("LookX", [(1, 0), (24, 0.6), (40, -0.4), (48, 0)])
    for p in PROPS:
        ctrl[p] = 0.0
    act = ctrl.animation_data.action
    act.name = f"Talk_{cid}"
    act.use_fake_user = True
    scene.frame_start, scene.frame_end = 1, 48


def build_all():
    for i, cid in enumerate(CAST):
        before = set(scene.objects)
        build_character(cid, i)
        # hair/face parts share names across the cast ("Mouth", "HairCap"): tag them
        # so the .blend and the exported glb nodes stay unambiguous
        for o in set(scene.objects) - before:
            if not o.name.endswith(f"_{cid}"):
                o.name = f"{o.name.split('.')[0]}_{cid}"
            if o.data is not None:
                o.data.name = o.name
    return [o.name for o in scene.objects if o.name.startswith("Portrait_")]


def export_all():
    os.makedirs(OUT_DIR, exist_ok=True)
    # the exporter reads the *context* scene, and forcing one with temp_override
    # crashes Blender 5.2 — so insist the caller has ours open instead
    if bpy.context.scene != scene:
        raise RuntimeError("open the 'RelationshipPortraits' scene before export_all()")
    vl = bpy.context.view_layer
    for cid in CAST:
        root = bpy.data.objects[f"Portrait_{cid}"]
        for o in scene.objects:
            o.select_set(False)
        stack = [root]
        while stack:
            o = stack.pop()
            o.select_set(True)
            stack.extend(o.children)
        vl.objects.active = root
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(OUT_DIR, f"portrait_{cid}.glb"), export_format="GLB",
            use_selection=True, export_morph=True, export_animations=False)
    # only this scene (and what it pulls in), not the rest of the open file
    bpy.data.libraries.write(os.path.join(OUT_DIR, "relationship_portraits.blend"), {scene})


build_all()
