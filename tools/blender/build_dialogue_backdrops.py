"""Renders the dialogue backdrops (assets/images/backgrounds/*.jpg).

Run headless — every image is built from scratch, nothing is kept between renders:

    blender -b --factory-startup -P build_dialogue_backdrops.py -- OUT_DIR [scene[:tier] ...]
            [--times=day,dusk,night] [--smoke]

`--smoke` renders small and fast for checking a layout. With no scene names every scene
is rendered.

Look: soft-lit low-poly, the same shape language as the portrait busts
(build_relationship_portraits.py) but with area lights, soft sun shadows and a shallow
depth of field, so a flat character bust sits convincingly in front of it.

Framing: 2.4:1. The dialogue panel is 260 px tall and full width, drawn with BoxFit.cover,
so the top and bottom get cropped on wide windows — landmarks live in the middle band and
the lower middle stays calm, because the character stands there.

File names: <scene>[_<tier>][_<time>].jpg. A scene only gets `_<time>` when daylight
reaches it (windows / outdoors); windowless rooms are rendered once.
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = _args[0] if _args else os.path.join(
    os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else ".", "out")
ONLY = [a for a in _args[1:] if not a.startswith("--")]
SMOKE = "--smoke" in _args
TIME_ARG = next((a.split("=", 1)[1].split(",") for a in _args if a.startswith("--times=")), None)

RES = (960, 400) if SMOKE else (1920, 800)
SAMPLES = 16 if SMOKE else 96


def srgb(r, g, b):
    f = lambda v: ((v / 255 + 0.055) / 1.055) ** 2.4 if v / 255 > 0.04045 else v / 255 / 12.92
    return (f(r), f(g), f(b), 1)


# Light per time of day. `lamp` scales every artificial light (bulbs are on in the
# evening, barely noticed at noon); `flood` the stadium floodlights; `win` the colour
# and strength of the daylight that comes through windows.
TIMES = {
    "day": dict(top=(40, 104, 236), hor=(178, 214, 250), amb=(244, 240, 232), amb_s=0.85,
                sun_e=4.5, sun_c=(255, 240, 214), sun_el=48, win=(255, 248, 236), win_s=1.0,
                lamp=0.45, flood=0.0, street=0.0, dome=1.15, stars=False, fillk=1.0),
    "dusk": dict(top=(58, 52, 128), hor=(255, 138, 72), amb=(255, 170, 150), amb_s=0.55,
                 sun_e=2.4, sun_c=(255, 146, 70), sun_el=8, win=(255, 150, 90), win_s=0.75,
                 lamp=1.0, flood=0.55, street=1.0, dome=0.9, stars=False, fillk=0.75),
    "night": dict(top=(3, 6, 20), hor=(18, 28, 66), amb=(90, 115, 215), amb_s=0.30,
                  sun_e=0.45, sun_c=(140, 165, 255), sun_el=36, win=(40, 60, 130), win_s=0.30,
                  lamp=1.9, flood=1.0, street=1.9, dome=0.85, stars=True, fillk=0.4),
}


class Ctx:
    pass


C = Ctx()


def reset(tname):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    C.sc = bpy.context.scene
    C.mats = {}
    C.accs = {}
    C.T = TIMES[tname]
    C.tname = tname


# --- materials & geometry ----------------------------------------------------
def mat(name, rgb, rough=0.7, metal=0.0, emit=None, alpha=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = srgb(*rgb)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = srgb(*emit[0])
        b.inputs["Emission Strength"].default_value = emit[1]
    if alpha is not None:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = srgb(*rgb)
    C.mats[name] = m
    return m


def glow(name, rgb, strength, lamp=True):
    """Emissive material. `lamp` ties it to the artificial-light factor of the time."""
    mat(name, rgb, 0.5, emit=(rgb, strength * (C.T["lamp"] if lamp else 1.0)))


class Acc:
    """Accumulates many primitives into ONE mesh per material — a scene is a few dozen
    objects, not thousands."""

    # Each primitive is built in its own tiny bmesh and then copied into plain lists:
    # bmesh.ops.* walk the whole mesh they're given, so piling thousands of
    # primitives (a stadium crowd) into one bmesh is quadratic.
    def __init__(self, name, flat=False):
        self.name, self.flat = name, flat
        self.co, self.fc = [], []

    def _take(self, bm):
        bm.verts.index_update()
        base = len(self.co)
        self.co.extend(tuple(v.co) for v in bm.verts)
        self.fc.extend(tuple(v.index + base for v in f.verts) for f in bm.faces)
        bm.free()

    @staticmethod
    def _xf(bm, c, rot, scale):
        bmesh.ops.transform(bm, matrix=Matrix.LocRotScale(Vector(c), Euler(rot, "XYZ"), Vector(scale)),
                            verts=bm.verts)

    def box(self, c, s, rot=(0, 0, 0), bevel=0.0):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        self._xf(bm, c, rot, s)
        if bevel > 0:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(s) * 0.35), segments=2,
                            affect="EDGES")
        self._take(bm)

    def bb(self, xa, xb, ya, yb, za, zb, bevel=0.0):
        """Axis-aligned box from bounds."""
        self.box(((xa + xb) / 2, (ya + yb) / 2, (za + zb) / 2),
                 (abs(xb - xa), abs(yb - ya), abs(zb - za)), bevel=bevel)

    def cyl(self, c, r, h, rot=(0, 0, 0), segs=14, r2=None, squash=(1, 1)):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r,
                              radius2=r if r2 is None else r2, depth=h)
        self._xf(bm, c, rot, (squash[0], squash[1], 1))
        self._take(bm)

    def sph(self, c, r, scale=(1, 1, 1), segs=12, rings=8, rot=(0, 0, 0)):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
        self._xf(bm, c, rot, (r * scale[0], r * scale[1], r * scale[2]))
        self._take(bm)

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.co, [], self.fc)
        mesh.update()
        if not self.flat:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            for f in bm.faces:
                f.smooth = True
            for e in bm.edges:
                if len(e.link_faces) == 2 and e.calc_face_angle(0) > 0.75:
                    e.smooth = False
            bm.to_mesh(mesh)
            bm.free()
        mesh.materials.append(C.mats[self.name])
        o = bpy.data.objects.new(self.name, mesh)
        C.sc.collection.objects.link(o)


def A(name, flat=False):
    if name not in C.accs:
        C.accs[name] = Acc(name, flat)
    return C.accs[name]


def flush():
    for a in C.accs.values():
        a.finish()


# --- lights ------------------------------------------------------------------
def _aim(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat("-Z", "Y").to_euler()


def area(loc, size, energy, rgb, target, size_y=None, spot=None):
    ld = bpy.data.lights.new("area", "AREA")
    ld.shape = "RECTANGLE"
    ld.size, ld.size_y = size, size_y or size
    ld.energy = energy
    ld.color = srgb(*rgb)[:3]
    o = bpy.data.objects.new("area", ld)
    o.location = loc
    C.sc.collection.objects.link(o)
    _aim(o, target)
    return o


def point(loc, energy, rgb, radius=0.15):
    ld = bpy.data.lights.new("pt", "POINT")
    ld.energy, ld.shadow_soft_size = energy, radius
    ld.color = srgb(*rgb)[:3]
    o = bpy.data.objects.new("pt", ld)
    o.location = loc
    C.sc.collection.objects.link(o)


def fill(energy=900, at=(0, -5, 3.0), target=(0, 6, 1.2), size=8):
    """Big soft key from behind the camera, so the back of a room reads."""
    area(at, size, energy * C.T["fillk"], (255, 244, 232), target, size_y=size * 0.6)


def lamp_l(x):
    return x * C.T["lamp"]


# --- environment -------------------------------------------------------------
def env(indoor, sun_az=-35.0, sun_boost=1.0, amb_boost=1.0, sun_soft=5.0):
    """World ambient, sky dome (what windows and outdoors show), sun and stars."""
    T = C.T
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = srgb(*T["amb"])
    bg.inputs[1].default_value = T["amb_s"] * (0.3 if indoor else 1.0) * amb_boost
    C.sc.world = w

    # sky dome: emissive gradient on height, the horizon colour at the bottom
    R = 420.0
    mat("skydome", T["hor"], 1.0)
    dm = C.mats["skydome"]
    nt = dm.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    mr = nt.nodes.new("ShaderNodeMapRange")
    pw = nt.nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 0.55
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mr.inputs[1].default_value, mr.inputs[2].default_value = 0.0, R * 0.75
    mr.inputs[3].default_value, mr.inputs[4].default_value = 0.0, 1.0
    mr.clamp = True
    mix.inputs[6].default_value = srgb(*T["hor"])
    mix.inputs[7].default_value = srgb(*T["top"])
    em.inputs[1].default_value = T["dome"]
    nt.links.new(geo.outputs["Position"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], mr.inputs[0])
    nt.links.new(mr.outputs[0], pw.inputs[0])
    nt.links.new(pw.outputs[0], mix.inputs[0])
    nt.links.new(mix.outputs[2], em.inputs[0])
    nt.links.new(em.outputs[0], out.inputs[0])
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=R)
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("skydome")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(dm)
    C.sc.collection.objects.link(bpy.data.objects.new("skydome", mesh))

    # sun / moon: azimuth measured from +Y (the direction the camera looks)
    az, el = math.radians(sun_az), math.radians(T["sun_el"])
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    sl = bpy.data.lights.new("sun", "SUN")
    sl.energy = T["sun_e"] * sun_boost
    sl.color = srgb(*T["sun_c"])[:3]
    sl.angle = math.radians(sun_soft)
    so = bpy.data.objects.new("sun", sl)
    so.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    C.sc.collection.objects.link(so)
    # visible disc (only ever in frame when the sun is ahead of the camera)
    mat("sundisc", T["sun_c"], 1.0, emit=(T["sun_c"], 30.0 if C.tname != "night" else 6.0))
    A("sundisc").sph(d * 380, 14 if C.tname == "dusk" else 7, segs=16, rings=10)

    if T["stars"]:
        rng = random.Random(7)
        mat("star", (255, 255, 255), 1.0, emit=((255, 255, 255), 6.0))
        for _ in range(320):
            a, e = rng.uniform(0, math.tau), rng.uniform(0.12, 1.3)
            p = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * 395
            A("star", True).sph(p, rng.uniform(0.35, 0.8), segs=4, rings=3)


def ground(rgb, rough=0.95, z=0.0, size=1500.0, name="ground"):
    mat(name, rgb, rough)
    A(name, True).bb(-size, size, -size * 0.2, size, z - 0.3, z)


# --- shared building blocks --------------------------------------------------
def wall_y(y0, y1, x0, x1, z0, z1, openings, m="wall"):
    """A wall in the XZ plane with rectangular openings (xa, xb, za, zb)."""
    cur = x0
    for xa, xb, za, zb in sorted(openings):
        if xa > cur:
            A(m).bb(cur, xa, y0, y1, z0, z1)
        if za > z0:
            A(m).bb(xa, xb, y0, y1, z0, za)
        if z1 > zb:
            A(m).bb(xa, xb, y0, y1, zb, z1)
        cur = xb
    if x1 > cur:
        A(m).bb(cur, x1, y0, y1, z0, z1)


def room(W, D, H, openings=(), front=-7.0, t=0.3, floor="floor", ceil="ceil", base=None):
    """Open-fronted box: the camera stands where the front wall would be."""
    A(floor).bb(-W / 2 - t, W / 2 + t, front, D + t, -0.2, 0)
    A(ceil).bb(-W / 2 - t, W / 2 + t, front, D + t, H, H + t)
    A("wall").bb(-W / 2 - t, -W / 2, front, D + t, -0.2, H + t)
    A("wall").bb(W / 2, W / 2 + t, front, D + t, -0.2, H + t)
    wall_y(D, D + t, -W / 2, W / 2, -0.2, H, openings)
    A("wall").bb(-W / 2, W / 2, D, D + t, H, H + t)
    if openings:
        if "frame" not in C.mats:
            mat("frame", (236, 236, 232), 0.5)
        for xa, xb, za, zb in openings:
            for bx in ((xa, xa + 0.07), (xb - 0.07, xb)):
                A("frame").bb(bx[0], bx[1], D - 0.04, D + 0.06, za, zb)
            for bz in ((za, za + 0.07), (zb - 0.07, zb)):
                A("frame").bb(xa, xb, D - 0.04, D + 0.06, bz[0], bz[1])
            if xb - xa > 2.2:
                A("frame").bb((xa + xb) / 2 - 0.035, (xa + xb) / 2 + 0.035, D - 0.04, D + 0.06, za, zb)
    if base:
        A(base).bb(-W / 2, W / 2, D - 0.03, D, 0, 0.14)
        A(base).bb(-W / 2, -W / 2 + 0.03, 0, D, 0, 0.14)
        A(base).bb(W / 2 - 0.03, W / 2, 0, D, 0, 0.14)


def win_light(xa, xb, za, zb, D, strength=1.0, depth=0.4):
    """Daylight coming in through an opening: a soft area light just inside it."""
    T = C.T
    cx, cz = (xa + xb) / 2, (za + zb) / 2
    area((cx, D - depth, cz), max(xb - xa, zb - za) * 0.9, 700 * T["win_s"] * strength,
         T["win"], (cx, D - 4.0, cz - 1.0), size_y=(zb - za) * 0.9)


def city(y, x0=-70, x1=70, seed=3, hmin=8, hmax=40, base_z=-2.0):
    """Distant skyline seen through windows; lit windows at dusk / night."""
    rng = random.Random(seed)
    # the haze tint keeps far buildings from going black against a bright sky
    mat("bld_a", (96, 108, 130), 0.9, emit=(C.T["hor"], 0.55))
    mat("bld_b", (122, 132, 152), 0.9, emit=(C.T["hor"], 0.4))
    glow("bld_lit", (255, 214, 140), 9.0, lamp=False)
    C.mats["bld_lit"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        9.0 * min(C.T["street"], 1.2)
    x = x0
    while x < x1:
        w = rng.uniform(4, 10)
        h = rng.uniform(hmin, hmax)
        yy = y + rng.uniform(0, 14)
        A("bld_a" if rng.random() < 0.5 else "bld_b").bb(x, x + w, yy, yy + w * 0.9, base_z, h)
        if C.T["street"] > 0:
            for _ in range(int(h * w * 0.22)):
                wx = x + rng.uniform(0.4, w - 0.6)
                wz = rng.uniform(1.0, h - 0.6)
                if rng.random() < 0.55:
                    A("bld_lit", True).bb(wx, wx + 0.5, yy - 0.05, yy, wz, wz + 0.7)
        x += w + rng.uniform(0.3, 2.0)


# people: blobs with a head and hair, enough to read as a crowd
def people_mats():
    shirts = [(40, 84, 160), (236, 236, 240), (196, 52, 52), (30, 34, 44), (236, 170, 40),
              (60, 140, 90), (120, 70, 150), (226, 120, 60)]
    for i, c in enumerate(shirts):
        mat(f"sh{i}", c, 0.85)
    for i, c in enumerate([(236, 190, 160), (196, 140, 106), (120, 76, 54)]):
        mat(f"skin{i}", c, 0.7)
    for i, c in enumerate([(40, 28, 22), (96, 64, 40), (210, 170, 90), (24, 24, 28)]):
        mat(f"hair{i}", c, 0.9)
    mat("pants", (38, 42, 56), 0.9)


def person(x, y, zf, rng, s=1.0, seated=False, shirt=None, arms_up=False, face=-1.0):
    """zf is the feet (standing) or the seat (seated)."""
    sh = shirt or f"sh{rng.randrange(8)}"
    if seated:
        zt = zf
    else:
        zt = zf + 0.85 * s
        A("pants").cyl((x, y, zf + 0.43 * s), 0.17 * s, 0.86 * s, segs=8, squash=(1.0, 0.75))
    A(sh).cyl((x, y, zt + 0.3 * s), 0.21 * s, 0.6 * s, segs=8, squash=(1.0, 0.72))
    A(f"skin{rng.randrange(3)}").sph((x, y, zt + 0.74 * s), 0.125 * s, segs=8, rings=6)
    A(f"hair{rng.randrange(4)}").sph((x, y - face * 0.025 * s, zt + 0.775 * s), 0.13 * s,
                                      scale=(1, 1, 0.85), segs=8, rings=6)
    if arms_up:
        for sgn in (-1, 1):
            A(sh).cyl((x + sgn * 0.3 * s, y, zt + 0.72 * s), 0.05 * s, 0.6 * s,
                      rot=(0, sgn * 0.35, 0), segs=6)


def pitch_stripes(y0, y1, step, x=200.0, z=0.0, a="grassA", b="grassB"):
    y, i = y0, 0
    while y < y1:
        A(a if i % 2 == 0 else b, True).bb(-x, x, y, min(y + step, y1), z - 0.3, z)
        y += step
        i += 1


def line_y(y, x0, x1, z=0.0, w=0.14, m="white"):
    A(m, True).bb(x0, x1, y - w / 2, y + w / 2, z, z + 0.012)


def line_x(x, y0, y1, z=0.0, w=0.14, m="white"):
    A(m, True).bb(x - w / 2, x + w / 2, y0, y1, z, z + 0.012)


def ring_line(cx, cy, r, z=0.0, w=0.14, n=64, arc=(0, math.tau), m="white"):
    for i in range(n):
        a0 = arc[0] + (arc[1] - arc[0]) * i / n
        a1 = arc[0] + (arc[1] - arc[0]) * (i + 1) / n
        am = (a0 + a1) / 2
        seg = r * (a1 - a0) * 1.05
        A(m, True).box((cx + math.cos(am) * r, cy + math.sin(am) * r, z + 0.006),
                       (seg, w, 0.012), rot=(0, 0, am + math.pi / 2))


def tree(x, y, h, rng, leaf="leaf", trunk="trunk", r=None):
    r = r or h * 0.32
    A(trunk).cyl((x, y, h * 0.3), h * 0.045, h * 0.6, segs=8)
    for _ in range(4):
        A(leaf).sph((x + rng.uniform(-r, r) * 0.6, y + rng.uniform(-r, r) * 0.6, h * 0.68 + rng.uniform(-0.15, 0.2) * h),
                    r * rng.uniform(0.8, 1.15), scale=(1, 1, 0.9), segs=10, rings=7)


def chair(x, y, rot=0.0, m="wood", seat="cushion", h=0.46):
    """A simple four-legged chair facing -Y before rotation about Z."""
    c, s = math.cos(rot), math.sin(rot)

    def P(dx, dy):
        return (x + dx * c - dy * s, y + dx * s + dy * c)

    for dx, dy in ((-0.19, -0.19), (0.19, -0.19), (-0.19, 0.19), (0.19, 0.19)):
        px, py = P(dx, dy)
        A(m).cyl((px, py, h / 2), 0.022, h, segs=6)
    sx, sy = P(0, 0)
    A(seat).box((sx, sy, h + 0.03), (0.46, 0.46, 0.06), rot=(0, 0, rot), bevel=0.02)
    bx, by = P(0, 0.22)
    A(m).box((bx, by, h + 0.3), (0.44, 0.05, 0.5), rot=(0, 0, rot), bevel=0.015)


def round_table(x, y, r=0.42, h=0.76, top="wood", leg="steel"):
    A(leg).cyl((x, y, h / 2), 0.04, h, segs=8)
    A(leg).cyl((x, y, 0.02), r * 0.5, 0.04, segs=16)
    A(top).cyl((x, y, h), r, 0.04, segs=24)


def set_camera(cam):
    cd = bpy.data.cameras.new("cam")
    cd.lens = cam.get("lens", 28)
    cd.sensor_width = 36
    cd.clip_end = 2000
    cd.dof.use_dof = True
    cd.dof.aperture_fstop = cam.get("fstop", 4.0)
    o = bpy.data.objects.new("cam", cd)
    o.location = cam["loc"]
    C.sc.collection.objects.link(o)
    _aim(o, cam["tgt"])
    if "focus" in cam:
        cd.dof.focus_distance = cam["focus"]
    C.sc.camera = o


def setup_render(path):
    sc = C.sc
    for e in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = e
            break
        except TypeError:
            pass
    ee = sc.eevee
    for attr, val in (("taa_render_samples", SAMPLES), ("use_raytracing", True), ("use_shadows", True),
                      ("use_gtao", True), ("gtao_distance", 1.2), ("use_soft_shadows", True),
                      ("shadow_ray_count", 3), ("shadow_step_count", 8), ("use_bloom", False)):
        if hasattr(ee, attr):
            try:
                setattr(ee, attr, val)
            except Exception:
                pass
    # dozens of area lights at 1920 px overflow the default shadow pool and drop shadows
    for pool in ("1024", "512", "256"):
        try:
            ee.shadow_pool_size = pool
            break
        except (TypeError, AttributeError):
            pass
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.resolution_percentage = 100
    rs = sc.render.image_settings
    rs.file_format = "JPEG"
    rs.quality = 90
    try:
        sc.view_settings.view_transform = "AgX"
        sc.view_settings.look = "Medium High Contrast"
    except Exception:
        pass
    sc.render.filepath = path


# === the scenes ==============================================================
def sc_locker_room(tier):
    mat("wall", (176, 190, 198), 0.9)
    mat("floor", (58, 62, 70), 0.5)
    mat("ceil", (220, 224, 228), 0.9)
    mat("lockA", (44, 78, 140), 0.4, 0.25)
    mat("lockB", (214, 218, 224), 0.4, 0.25)
    mat("dark", (20, 22, 28), 0.8)
    mat("bench", (158, 112, 70), 0.6)
    mat("steel", (150, 156, 168), 0.3, 0.9)
    mat("redj", (206, 62, 52), 0.8)
    mat("whitej", (235, 235, 238), 0.8)
    mat("bag", (40, 44, 52), 0.8)
    mat("bagR", (180, 50, 50), 0.8)
    mat("towel", (240, 240, 236), 0.95)
    mat("ball", (245, 245, 245), 0.5)
    mat("board", (240, 242, 244), 0.5)
    mat("pitchg", (60, 130, 80), 0.8)
    mat("stripe", (44, 78, 140), 0.7)
    mat("white", (250, 250, 250), 0.7)
    glow("tube", (255, 248, 235), 12.0)
    W, D, H = 13, 7, 3.2
    room(W, D, H, base="dark")
    n, lw = 15, 0.8
    for i in range(n):
        x = (i - (n - 1) / 2) * lw
        m = "lockA" if i % 2 == 0 else "lockB"
        A(m).bb(x - lw / 2 + 0.02, x + lw / 2 - 0.02, D - 0.65, D - 0.05, 0.12, 2.35, bevel=0.02)
        for k in range(3):
            A("dark").bb(x - 0.22, x + 0.22, D - 0.68, D - 0.64, 1.95 + k * 0.07, 1.98 + k * 0.07)
        A("steel").bb(x + 0.22, x + 0.26, D - 0.70, D - 0.66, 1.15, 1.45)
        if i % 4 == 1:  # an open locker with a shirt hanging in it
            A("dark").bb(x - 0.3, x + 0.3, D - 0.68, D - 0.6, 0.35, 2.2)
            A("redj" if i % 8 == 1 else "whitej").bb(x - 0.2, x + 0.2, D - 0.73, D - 0.69, 1.25, 2.0, bevel=0.02)
            A("redj" if i % 8 == 1 else "whitej").bb(x - 0.3, x + 0.3, D - 0.73, D - 0.69, 1.75, 1.95)
    A("stripe").bb(-W / 2, W / 2, D - 0.04, D, 2.45, 2.65)
    for bx in (-4.0, 0.0, 4.0):
        A("bench").bb(bx - 1.6, bx + 1.6, D - 2.05, D - 1.55, 0.42, 0.47, bevel=0.012)
        for lx in (bx - 1.45, bx + 1.45):
            for ly in (D - 2.0, D - 1.6):
                A("steel").bb(lx - 0.025, lx + 0.025, ly - 0.025, ly + 0.025, 0, 0.42)
    A("towel").bb(-4.6, -4.1, D - 2.0, D - 1.6, 0.47, 0.53, bevel=0.02)
    A("towel").bb(1.0, 1.5, D - 2.0, D - 1.62, 0.47, 0.6, bevel=0.03)
    A("ball").sph((-3.2, D - 1.8, 0.65), 0.11)
    A("bag").bb(3.2, 3.9, D - 2.0, D - 1.6, 0.47, 0.75, bevel=0.06)
    A("bagR").bb(-0.9, -0.3, D - 2.0, D - 1.6, 0.47, 0.72, bevel=0.06)
    A("board").bb(W / 2 - 0.08, W / 2 - 0.02, 2.0, 4.8, 1.0, 2.15, bevel=0.01)
    A("pitchg").bb(W / 2 - 0.09, W / 2 - 0.08, 2.1, 4.7, 1.1, 2.05)
    line_ = lambda ya, yb, za, zb: A("white", True).bb(W / 2 - 0.095, W / 2 - 0.09, ya, yb, za, zb)
    line_(2.1, 4.7, 1.55, 1.58)
    line_(3.38, 3.42, 1.1, 2.05)
    for (yy, zz) in ((2.7, 1.8), (4.0, 1.3), (3.4, 1.75)):
        A("white", True).bb(W / 2 - 0.095, W / 2 - 0.09, yy - 0.08, yy + 0.08, zz - 0.03, zz + 0.03)
    for y in (1.5, 3.5, 5.5):
        A("tube", True).bb(-2.6, 2.6, y - 0.09, y + 0.09, H - 0.06, H - 0.02)
        area((0, y, H - 0.3), 4.5, lamp_l(650), (255, 246, 232), (0, y, 0), size_y=1.0)
    fill(700, size=10)
    env(True)
    return dict(loc=(0, -5.5, 1.45), tgt=(0, D, 1.3), lens=26, focus=9.0)


def sc_training_ground(tier):
    rng = random.Random(11)
    mat("grassA", (82, 150, 66), 0.95)
    mat("grassB", (92, 162, 74), 0.95)
    mat("white", (250, 250, 250), 0.8)
    mat("leaf", (62, 120, 64), 0.9)
    mat("leaf2", (84, 140, 58), 0.9)
    mat("trunk", (98, 70, 48), 0.9)
    mat("hill", (112, 150, 146), 1.0)
    mat("hill2", (134, 164, 166), 1.0)
    mat("cone", (250, 120, 30), 0.6)
    mat("ball", (245, 245, 245), 0.5)
    mat("steel", (170, 176, 186), 0.4, 0.8)
    mat("red", (210, 60, 52), 0.6)
    mat("net", (240, 244, 248), 0.9, alpha=0.22)
    mat("conc", (150, 154, 162), 0.9)
    mat("seat", (44, 78, 140), 0.7)
    mat("roofm", (220, 224, 230), 0.6)
    mat("bench", (150, 110, 70), 0.7)
    mat("ladder", (255, 220, 60), 0.6)
    glow("flood", (255, 248, 230), 30.0, lamp=False)
    C.mats["flood"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.6 + 30.0 * C.T["flood"]
    people_mats()
    ground((86, 158, 68))
    pitch_stripes(-10, 130, 5.0)
    gy = 26                        # goal line
    line_y(gy, -50, 50)
    line_x(-20, gy - 16.5, gy)     # penalty area
    line_x(20, gy - 16.5, gy)
    line_y(gy - 16.5, -20, 20)
    line_x(-9.15, gy - 5.5, gy)    # six-yard box
    line_x(9.15, gy - 5.5, gy)
    line_y(gy - 5.5, -9.15, 9.15)
    A("white", True).cyl((0, gy - 11, 0.008), 0.15, 0.016, segs=12)
    ring_line(0, gy - 11, 9.15, arc=(math.pi + 0.93, math.tau - 0.93), n=24)
    # goal with net
    for gx in (-3.66, 3.66):
        A("white").cyl((gx, gy, 1.22), 0.06, 2.44, segs=8)
    A("white").box((0, gy, 2.44), (7.4, 0.12, 0.12), bevel=0.02)
    A("net").bb(-3.66, 3.66, gy + 1.9, gy + 1.95, 0, 2.44)
    A("net").bb(-3.66, 3.66, gy, gy + 1.95, 2.44, 2.46)
    for gx in (-3.66, 3.66):
        A("net").bb(gx, gx + 0.03, gy, gy + 1.95, 0, 2.44)
    # cones slalom, balls, hurdles, agility ladder
    for i in range(7):
        A("cone").cyl((-14 + i * 1.7, 7 + (i % 2) * 1.2, 0.17), 0.02, 0.34, segs=10, r2=0.17)
    for b in range(9):
        A("ball").sph((8 + rng.uniform(0, 2.5), 8 + rng.uniform(0, 2), 0.11), 0.11)
    for i in range(4):
        x = 11 + i * 1.6
        A("steel").cyl((x - 0.5, 13, 0.3), 0.02, 0.6, segs=6)
        A("steel").cyl((x + 0.5, 13, 0.3), 0.02, 0.6, segs=6)
        A("red").bb(x - 0.5, x + 0.5, 12.97, 13.03, 0.56, 0.62)
    for i in range(8):
        A("ladder").bb(-24 + i * 0.5, -23.94 + i * 0.5, 9, 10.0, 0, 0.012)
    A("ladder").bb(-24, -20.06, 8.97, 9.03, 0, 0.012)
    A("ladder").bb(-24, -20.06, 9.97, 10.03, 0, 0.012)
    # low stand behind the goal + dugout
    for r in range(5):
        A("conc").bb(-30, 30, 44 + r * 0.9, 45 + r * 0.9, 0, 0.9 + r * 0.5)
        A("seat").bb(-30, 30, 44.1 + r * 0.9, 44.6 + r * 0.9, 0.9 + r * 0.5, 0.94 + r * 0.5)
        for k in range(int(rng.uniform(6, 16))):
            person(rng.uniform(-29, 29), 44.7 + r * 0.9, 0.98 + r * 0.5, rng, seated=True)
    A("roofm").bb(-30, 30, 44, 51, 4.2, 4.3)
    for px in (-30, 30):
        A("steel").bb(px - 0.1, px + 0.1, 48, 48.2, 0, 4.2)
    A("bench").bb(24, 29, 9, 9.6, 0.4, 0.46)
    # floodlight masts
    for mx in (-40, 42):
        A("steel").cyl((mx, 46, 13), 0.3, 26, segs=8)
        A("flood", True).bb(mx - 2.4, mx + 2.4, 44.8, 45.2, 25, 27.5)
    if C.T["flood"] > 0:
        area((-40, 42, 24), 4, 3500 * C.T["flood"], (255, 248, 232), (0, 16, 0), size_y=3)
        area((42, 42, 24), 4, 3500 * C.T["flood"], (255, 248, 232), (0, 16, 0), size_y=3)
    # trees and hills far away
    for x in range(-150, 150, 11):
        tree(x + rng.uniform(-3, 3), rng.uniform(70, 95), rng.uniform(7, 12), rng,
             leaf="leaf" if rng.random() < 0.6 else "leaf2")
    for x in range(-260, 260, 60):
        A("hill").sph((x + rng.uniform(-10, 10), 300, -10), 75, scale=(1.6, 0.8, 0.5), segs=16, rings=10)
        A("hill2").sph((x + 30, 380, -20), 90, scale=(1.8, 0.8, 0.55), segs=16, rings=10)
    env(False, sun_az=-115, sun_boost=1.5, amb_boost=1.5, sun_soft=6)
    if C.tname == "night":
        area((0, -6, 14), 30, 4500, (190, 210, 255), (0, 26, 0), size_y=16)
    return dict(loc=(0, -6, 1.7), tgt=(0, gy, 1.5), lens=30, focus=30.0, fstop=6.0)


def sc_stadium(tier):
    rng = random.Random(21)
    full = tier != "empty"
    mat("grassA", (74, 146, 62), 0.95)
    mat("grassB", (86, 160, 72), 0.95)
    mat("white", (250, 250, 250), 0.8)
    mat("conc", (150, 154, 162), 0.9)
    mat("seatA", (40, 76, 146), 0.7)
    mat("seatB", (232, 232, 236), 0.7)
    mat("roofm", (206, 210, 218), 0.6)
    mat("roofdark", (40, 44, 54), 0.8)
    mat("steel", (170, 176, 186), 0.4, 0.8)
    mat("net", (240, 244, 248), 0.9, alpha=0.2)
    glow("ad1", (236, 72, 72), 2.2, lamp=False)
    glow("ad2", (250, 210, 60), 2.2, lamp=False)
    glow("ad3", (60, 140, 230), 2.2, lamp=False)
    glow("flood", (255, 248, 230), 30.0, lamp=False)
    C.mats["flood"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.6 + 30.0 * C.T["flood"]
    glow("score", (255, 190, 70), 6.0, lamp=False)
    people_mats()
    # pitch
    A("grassA").bb(-200, 200, -40, 0, -0.3, 0)
    ground((74, 146, 62))
    pitch_stripes(-12, 31, 4.3)
    line_y(28, -60, 60)
    line_x(-22, 4, 28)
    line_x(22, 4, 28)
    ring_line(0, 28, 10, arc=(math.pi, math.tau), n=48)
    # advertising boards
    for i, x in enumerate(range(-60, 60, 6)):
        A(f"ad{i % 3 + 1}", True).bb(x, x + 5.8, 31.6, 31.8, 0.05, 1.05)
    # the stand
    rows, step_h, step_d = 22, 0.52, 0.85
    y0 = 33.0
    A("conc").bb(-62, 62, 32, y0, 0, 1.0)
    for r in range(rows):
        y, z = y0 + r * step_d, 1.0 + r * step_h
        A("conc").bb(-62, 62, y, y + step_d, 0, z)
        for sx in range(-60, 60, 12):
            A("seatA" if (sx // 12) % 2 == 0 else "seatB", True).bb(sx + 1.3, sx + 12, y + 0.05, y + 0.55, z, z + 0.05)
        dens = (0.93 if r > 1 else 0.85) if full else 0.04
        for x in [i * 0.55 - 60 for i in range(218)]:
            if ((x + 60) % 12) < 1.3:
                continue
            if rng.random() < dens:
                person(x, y + 0.5, z + 0.06, rng, seated=True, arms_up=rng.random() < 0.05 and full)
    # roof canopy, scoreboard, light rigs
    zr = 1.0 + rows * step_h + 5
    A("roofdark").bb(-62, 62, y0 + 6, y0 + rows * step_d + 12, zr, zr + 0.6)
    A("roofm").bb(-62, 62, y0 + 6, y0 + 7, zr - 4, zr + 0.6)
    A("score", True).bb(-7, 7, y0 + 5.6, y0 + 5.8, zr - 3.6, zr - 0.6)
    A("roofdark").bb(-7.3, 7.3, y0 + 5.5, y0 + 5.6, zr - 3.9, zr - 0.3)
    for mx in (-58, 58):
        A("steel").cyl((mx, y0 + 4, 14), 0.4, 28, segs=8)
        A("flood", True).bb(mx - 3, mx + 3, y0 + 2.6, y0 + 3.0, 26, 29.5)
    A("roofm").bb(-62, 62, 31.5, 32, 1.0, 1.06)
    # goal in the near-left, for scale
    # (off-frame on purpose: the camera looks straight at the stand)
    if C.T["flood"] > 0:
        for lx in (-50, 50):
            area((lx, y0 + 2, 26), 8, 12000 * C.T["flood"], (255, 250, 240), (0, 10, 0), size_y=5)
    env(False, sun_az=-140, sun_boost=1.0, amb_boost=1.0, sun_soft=5)
    if C.tname == "night":
        area((0, -8, 16), 40, 7000, (190, 210, 255), (0, 34, 4), size_y=18)
    return dict(loc=(0, -4, 1.45), tgt=(0, 40, 9.5), lens=26, focus=40.0, fstop=8.0)


def sc_cafe(tier):
    rng = random.Random(5)
    mat("wall", (226, 204, 176), 0.9)
    mat("floor", (152, 108, 70), 0.55)
    mat("ceil", (232, 222, 206), 0.9)
    mat("wood", (122, 82, 50), 0.6)
    mat("darkw", (70, 46, 32), 0.6)
    mat("cushion", (190, 70, 60), 0.85)
    mat("steel", (190, 194, 202), 0.3, 0.9)
    mat("pot", (150, 96, 70), 0.8)
    mat("plant", (70, 130, 70), 0.85)
    mat("cup", (245, 245, 240), 0.4)
    mat("glass", (200, 230, 240), 0.1, alpha=0.18)
    mat("board", (34, 42, 40), 0.9)
    mat("chalk", (238, 238, 232), 0.9)
    mat("cake", (232, 170, 120), 0.8)
    glow("pend", (255, 200, 130), 9.0)
    glow("bulb", (255, 214, 150), 14.0)
    W, D, H = 10, 8, 3.4
    ops = [(-4.0, -0.9, 0.7, 2.9), (0.9, 4.0, 0.7, 2.9)]
    room(W, D, H, openings=ops, base="darkw")
    for o in ops:
        win_light(*o, D, 1.0)
    city(D + 20, seed=4)
    # wooden plank stripes
    for i in range(10):
        A("darkw", True).bb(-W / 2, W / 2, i * 0.8, i * 0.8 + 0.012, 0.001, 0.004)
    # counter on the right, with machine and cake case
    A("wood").bb(3.0, 4.2, 2.4, 7.4, 0, 1.05, bevel=0.03)
    A("darkw").bb(2.95, 4.25, 2.35, 7.45, 1.05, 1.12, bevel=0.02)
    A("steel").bb(3.3, 4.0, 5.0, 5.9, 1.12, 1.55, bevel=0.03)
    A("steel").bb(3.3, 4.0, 5.3, 5.6, 1.55, 1.7)
    for i in range(3):
        A("cup").cyl((3.5, 3.0 + i * 0.3, 1.17), 0.06, 0.1, segs=10)
    A("glass").bb(3.15, 4.05, 6.2, 7.2, 1.12, 1.55)
    A("cake").cyl((3.6, 6.7, 1.3), 0.22, 0.12, segs=14)
    for i, zz in enumerate((1.6, 2.0)):
        A("wood").bb(4.2, 4.3, 3.0, 7.0, zz, zz + 0.05)
    for i in range(4):
        A("cup").cyl((4.22, 3.3 + i * 0.9, 1.72), 0.05, 0.09, segs=8)
    for i in range(3):
        sy = 3.0 + i * 1.6
        A("steel").cyl((2.5, sy, 0.35), 0.03, 0.7, segs=8)
        A("cushion").cyl((2.5, sy, 0.72), 0.19, 0.06, segs=14)
    # menu board on the left wall
    A("board").bb(-W / 2 + 0.02, -W / 2 + 0.1, 2.4, 5.4, 1.3, 2.4, bevel=0.02)
    for k in range(6):
        A("chalk", True).bb(-W / 2 + 0.11, -W / 2 + 0.115, 2.7, 2.7 + rng.uniform(0.6, 2.0), 2.15 - k * 0.14, 2.17 - k * 0.14)
    # tables + chairs
    for tx, ty in ((-3.3, 4.2), (-1.8, 6.4), (1.3, 6.5), (-3.6, 2.4)):
        round_table(tx, ty)
        A("cup").cyl((tx + 0.1, ty, 0.81), 0.05, 0.08, segs=10)
        A("cup").cyl((tx - 0.12, ty + 0.1, 0.80), 0.04, 0.05, segs=10)
        for k, ang in enumerate((-0.5, 2.3)):
            chair(tx + math.cos(ang) * 0.75, ty + math.sin(ang) * 0.75, rot=ang + math.pi / 2)
    # plants
    for px, py in ((-4.4, 7.4), (2.6, 7.6)):
        A("pot").cyl((px, py, 0.3), 0.26, 0.6, segs=10, r2=0.2)
        for _ in range(5):
            A("plant").sph((px + rng.uniform(-0.2, 0.2), py + rng.uniform(-0.2, 0.2), 1.0 + rng.uniform(0, 0.6)),
                           rng.uniform(0.22, 0.34), segs=8, rings=6)
    # pendants
    for px, py in ((-2.6, 3.4), (-0.4, 5.6), (2.0, 4.4), (-3.6, 6.2)):
        A("steel").cyl((px, py, 2.85), 0.008, 1.1, segs=4)
        A("pend", True).sph((px, py, 2.25), 0.22, scale=(1, 1, 0.75), segs=12, rings=6)
        point((px, py, 2.1), lamp_l(120), (255, 200, 140), 0.2)
    fill(600, size=9)
    area((0, 2, 3.1), 6, lamp_l(400), (255, 214, 170), (0, 6, 1.0), size_y=3)
    env(True, sun_az=-30)
    return dict(loc=(0, -5.0, 1.4), tgt=(0, D, 1.35), lens=26, focus=8.0)


def sc_press_room(tier):
    rng = random.Random(9)
    mat("wall", (28, 38, 66), 0.85)
    mat("floor", (30, 32, 42), 0.6)
    mat("ceil", (22, 24, 32), 0.9)
    mat("table", (198, 170, 130), 0.5)
    mat("cloth", (30, 40, 70), 0.9)
    mat("dark", (16, 18, 24), 0.7)
    mat("steel", (170, 176, 188), 0.3, 0.9)
    mat("chair", (52, 58, 78), 0.85)
    mat("panelw", (238, 240, 246), 0.6)
    mat("cardw", (250, 250, 250), 0.6)
    mat("bottle", (150, 210, 235), 0.15, alpha=0.5)
    mat("cam", (36, 38, 46), 0.5, 0.4)
    mat("lens", (30, 60, 110), 0.1, 0.8)
    mat("trussm", (120, 126, 140), 0.4, 0.9)
    glow("spot", (255, 244, 224), 10.0, lamp=False)
    glow("rec", (255, 40, 40), 8.0, lamp=False)
    brand = [(230, 64, 64), (250, 190, 40), (60, 140, 230), (60, 190, 120), (170, 90, 220), (240, 120, 50)]
    for i, c in enumerate(brand):
        mat(f"brand{i}", c, 0.5)
    W, D, H = 14, 9, 4.6
    room(W, D, H, base="dark")
    # sponsor wall
    for r in range(3):
        for c in range(6):
            x = -5.6 + c * 2.25
            z = 1.2 + r * 1.2
            A("panelw").bb(x - 1.0, x + 1.0, D - 0.06, D, z, z + 1.0, bevel=0.01)
            bc = f"brand{(r * 2 + c) % 6}"
            if (r + c) % 2:
                A(bc, True).cyl((x - 0.35, D - 0.07, z + 0.5), 0.28, 0.02, rot=(math.pi / 2, 0, 0), segs=20)
                A(bc, True).bb(x - 0.0, x + 0.7, D - 0.075, D - 0.06, z + 0.4, z + 0.6)
            else:
                A(bc, True).bb(x - 0.75, x + 0.75, D - 0.075, D - 0.06, z + 0.25, z + 0.42)
                A(bc, True).bb(x - 0.75, x + 0.2, D - 0.075, D - 0.06, z + 0.55, z + 0.72)
    # table, mics, cards, bottles
    tz = 0.76
    A("table").bb(-4.2, 4.2, 5.0, 6.1, tz - 0.05, tz, bevel=0.02)
    A("cloth").bb(-4.2, 4.2, 5.0, 5.05, 0.05, tz - 0.05)
    A("cloth").bb(-4.2, -4.15, 5.0, 6.1, 0.05, tz - 0.05)
    A("cloth").bb(4.15, 4.2, 5.0, 6.1, 0.05, tz - 0.05)
    for mx in (-2.4, 0.0, 2.4):
        A("steel").cyl((mx, 5.45, tz + 0.12), 0.012, 0.24, segs=6)
        A("dark").sph((mx, 5.45, tz + 0.27), 0.04, scale=(1, 1, 1.4), segs=8, rings=6)
        A("cardw").box((mx + 0.4, 5.25, tz + 0.06), (0.22, 0.02, 0.1), rot=(-0.3, 0, 0))
        A("bottle").cyl((mx - 0.45, 5.6, tz + 0.12), 0.032, 0.24, segs=10)
        A("bottle").cyl((mx - 0.3, 5.55, tz + 0.05), 0.03, 0.1, segs=10)
        chair(mx, 6.75, rot=math.pi, m="chair", seat="chair")
    # audience chairs down the sides, cameras on tripods
    for i in range(3):
        for sx in (-1, 1):
            for k in range(3):
                chair(sx * (3.6 + k * 0.7), 0.6 + i * 1.0, rot=0, m="chair", seat="chair")
    for cx in (5.2, 6.0):
        for lx, ly in ((-0.25, -0.2), (0.25, -0.2), (0, 0.3)):
            A("steel").cyl((cx + lx * 1.0, 2.2 + ly * 1.0, 0.6), 0.015, 1.3, rot=(ly * 0.25, -lx * 0.25, 0), segs=5)
        A("cam").bb(cx - 0.18, cx + 0.18, 2.0, 2.55, 1.25, 1.5, bevel=0.03)
        A("lens").cyl((cx, 1.8, 1.38), 0.09, 0.35, rot=(math.pi / 2, 0, 0), segs=14)
        A("rec", True).sph((cx + 0.1, 2.4, 1.52), 0.015, segs=6, rings=4)
    # truss with spots, coloured rim lights on the wall
    A("trussm").bb(-6, 6, 3.0, 3.25, H - 0.6, H - 0.4)
    A("trussm").bb(-6, 6, 6.4, 6.65, H - 0.6, H - 0.4)
    for sx in range(-5, 6, 2):
        A("cam").cyl((sx, 6.52, H - 0.75), 0.11, 0.3, segs=10)
        A("spot", True).cyl((sx, 6.52, H - 0.92), 0.09, 0.03, segs=10)
        area((sx, 6.4, H - 0.9), 0.8, lamp_l(380), (255, 244, 226), (sx * 0.5, 5.5, tz), size_y=0.8)
    area((-6.5, 7.6, 3.5), 2.0, lamp_l(900), (60, 140, 255), (-3, D, 2.0), size_y=3)
    area((6.5, 7.6, 3.5), 2.0, lamp_l(900), (220, 70, 200), (3, D, 2.0), size_y=3)
    fill(500, at=(0, -5, 3.6), size=8)
    env(True)
    return dict(loc=(0, -6.0, 1.35), tgt=(0, D, 1.5), lens=26, focus=10.0)


def sc_home(tier):
    rng = random.Random(3)
    lux = tier == "luxury"
    mat("wall", (232, 224, 210) if lux else (206, 196, 176), 0.9)
    mat("floor", (196, 186, 170) if lux else (150, 132, 112), 0.5 if lux else 0.8)
    mat("ceil", (244, 242, 238), 0.9)
    mat("sofa", (224, 214, 198) if lux else (126, 84, 56), 0.85)
    mat("cushion2", (90, 122, 140) if lux else (176, 120, 70), 0.85)
    mat("wood", (122, 82, 50), 0.55)
    mat("darkw", (70, 46, 32), 0.6)
    mat("rug", (72, 98, 124) if lux else (150, 76, 60), 0.95)
    mat("steel", (190, 194, 202), 0.3, 0.9)
    mat("plant", (70, 130, 70), 0.85)
    mat("pot", (236, 232, 224) if lux else (150, 96, 70), 0.8)
    mat("frame", (236, 236, 232), 0.5)
    mat("tv", (16, 18, 22), 0.2)
    mat("art1", (214, 90, 70), 0.8)
    mat("art2", (60, 120, 170), 0.8)
    mat("art3", (238, 196, 80), 0.8)
    mat("book1", (196, 70, 60), 0.8)
    mat("book2", (60, 110, 160), 0.8)
    mat("book3", (232, 200, 100), 0.8)
    mat("ball", (245, 245, 245), 0.5)
    mat("jersey", (40, 84, 160), 0.8)
    glow("bulb", (255, 214, 150), 14.0)
    glow("shade", (255, 226, 180), 7.0)
    if lux:
        W, D, H = 12, 8, 3.4
        ops = [(-5.0, -0.2, 0.0, 3.1), (0.2, 5.0, 0.0, 3.1)]
    else:
        W, D, H = 8, 6, 2.6
        ops = [(-3.0, -1.5, 0.95, 2.05)]
    room(W, D, H, openings=ops, base="darkw")
    for o in ops:
        win_light(*o, D, 0.9 if lux else 1.0)
    if lux:
        city(D + 40, seed=8, hmin=20, hmax=90, base_z=-40)
    else:
        city(D + 18, seed=2, hmin=6, hmax=22)
        for i in range(5):  # vinyl floor seams
            A("darkw", True).bb(-W / 2, W / 2, 1.1 * i, 1.1 * i + 0.012, 0.001, 0.004)
    # seating
    if lux:
        A("sofa").bb(-5.0, -1.2, 5.6, 6.9, 0.0, 0.42, bevel=0.06)
        A("sofa").bb(-5.0, -1.2, 6.5, 6.9, 0.3, 1.05, bevel=0.08)
        A("sofa").bb(-5.0, -4.5, 5.6, 6.9, 0.3, 0.78, bevel=0.06)
        A("sofa").bb(-1.7, -1.2, 5.6, 6.9, 0.3, 0.78, bevel=0.06)
        for cx in (-4.0, -2.1):
            A("cushion2").box((cx, 6.1, 0.68), (0.5, 0.16, 0.5), rot=(-0.2, 0, 0.2), bevel=0.06)
        A("rug").bb(-5.0, 2.8, 2.6, 5.4, 0.0, 0.025)
        A("wood").bb(-3.6, -1.6, 3.4, 4.4, 0.25, 0.3, bevel=0.02)
        A("steel").bb(-3.5, -3.45, 3.5, 3.55, 0, 0.25)
        A("steel").bb(-1.75, -1.7, 4.25, 4.3, 0, 0.25)
        # the back wall is glass, so the art hangs on the left wall
        A("frame").bb(-W / 2, -W / 2 + 0.06, 2.6, 5.4, 1.2, 2.6)
        A("art1").bb(-W / 2 + 0.06, -W / 2 + 0.07, 2.7, 3.8, 1.3, 2.5)
        A("art2").bb(-W / 2 + 0.06, -W / 2 + 0.07, 3.85, 5.3, 1.3, 2.5)
        A("art3").sph((-W / 2 + 0.08, 4.5, 1.9), 0.3, scale=(0.05, 1, 1))
        for i in range(9):   # chandelier
            a = i * math.tau / 9
            A("shade", True).sph((1.8 + math.cos(a) * 0.5, 4.0 + math.sin(a) * 0.5, 2.55 + 0.1 * (i % 2)), 0.07, segs=8, rings=5)
        A("steel").cyl((1.8, 4.0, 3.0), 0.008, 0.9, segs=4)
        point((1.8, 4.0, 2.4), lamp_l(180), (255, 214, 160), 0.3)
        for px, py in ((4.8, 6.9), (-5.4, 4.0)):
            A("pot").cyl((px, py, 0.35), 0.3, 0.7, segs=12, r2=0.24)
            for _ in range(7):
                A("plant").sph((px + rng.uniform(-0.3, 0.3), py + rng.uniform(-0.3, 0.3), 1.0 + rng.uniform(0, 1.0)),
                               rng.uniform(0.25, 0.4), segs=8, rings=6)
    else:
        A("sofa").bb(0.6, 3.0, 4.2, 5.4, 0.0, 0.45, bevel=0.06)
        A("sofa").bb(0.6, 3.0, 5.0, 5.4, 0.3, 0.95, bevel=0.06)
        A("sofa").bb(0.6, 0.95, 4.2, 5.4, 0.3, 0.7, bevel=0.05)
        A("sofa").bb(2.65, 3.0, 4.2, 5.4, 0.3, 0.7, bevel=0.05)
        A("cushion2").box((1.2, 4.95, 0.65), (0.4, 0.14, 0.4), rot=(-0.2, 0, 0.3), bevel=0.05)
        A("rug").bb(-2.4, 0.6, 2.2, 4.0, 0.0, 0.02)
        A("wood").bb(-1.6, -0.4, 2.8, 3.4, 0.25, 0.3, bevel=0.015)
        for lx, ly in ((-1.55, 2.85), (-0.45, 2.85), (-1.55, 3.35), (-0.45, 3.35)):
            A("wood").bb(lx - 0.02, lx + 0.02, ly - 0.02, ly + 0.02, 0, 0.25)
        A("darkw").bb(-3.5, -1.0, D - 0.4, D - 0.02, 0, 0.55, bevel=0.02)
        A("ball").sph((-1.3, D - 0.25, 0.68), 0.11)
        A("jersey").bb(-0.6, 0.2, D - 0.06, D, 1.3, 2.0, bevel=0.01)
        A("steel").cyl((3.3, 5.6, 0.7), 0.02, 1.4, segs=6)
        A("shade", True).cyl((3.3, 5.6, 1.5), 0.2, 0.25, segs=12, r2=0.12)
        point((3.3, 5.6, 1.45), lamp_l(60), (255, 214, 150), 0.2)
        A("pot").cyl((3.2, 1.8, 0.25), 0.18, 0.5, segs=10, r2=0.14)
        for _ in range(5):
            A("plant").sph((3.2 + rng.uniform(-0.15, 0.15), 1.8 + rng.uniform(-0.15, 0.15), 0.7 + rng.uniform(0, 0.4)),
                           rng.uniform(0.15, 0.22), segs=8, rings=6)
        A("wood").bb(-3.9, -3.85, 1.0, 3.4, 1.4, 1.46)
        for k in range(6):
            A(f"book{k % 3 + 1}").bb(-3.88, -3.6, 1.2 + k * 0.3, 1.45 + k * 0.3, 1.46, 1.46 + rng.uniform(0.15, 0.3))
    fill(450 if not lux else 300, size=8)
    area((0, 2.5, H - 0.2), 3, lamp_l(350), (255, 220, 175), (0, 5, 0.5), size_y=3)
    env(True, sun_az=-25)
    if lux:
        return dict(loc=(0, -5.2, 1.5), tgt=(0, D, 1.4), lens=24, focus=9.0)
    return dict(loc=(0, -4.6, 1.4), tgt=(0, D, 1.25), lens=28, focus=7.0)


def sc_tunnel(tier):
    mat("wall", (150, 154, 162), 0.85)
    mat("floor", (44, 46, 54), 0.4)
    mat("ceil", (110, 114, 122), 0.8)
    mat("stripe", (40, 76, 146), 0.6)
    mat("stripe2", (236, 236, 240), 0.6)
    mat("steel", (170, 176, 186), 0.3, 0.9)
    mat("pipe", (120, 126, 136), 0.5, 0.7)
    mat("door", (60, 66, 82), 0.5)
    mat("yel", (250, 210, 50), 0.6)
    mat("white", (250, 250, 250), 0.7)
    glow("tube", (255, 250, 240), 9.0, lamp=False)
    glow("exit", (250, 252, 255), 9.0, lamp=False)
    mat("turf", (90, 170, 80), 0.8, emit=((90, 170, 80), 2.5))
    W, D, H = 5.2, 34.0, 3.0
    A("floor").bb(-W / 2 - 0.3, W / 2 + 0.3, -8, D, -0.2, 0)
    A("ceil").bb(-W / 2 - 0.3, W / 2 + 0.3, -8, D, H, H + 0.3)
    A("wall").bb(-W / 2 - 0.3, -W / 2, -8, D, -0.2, H + 0.3)
    A("wall").bb(W / 2, W / 2 + 0.3, -8, D, -0.2, H + 0.3)
    # exit: a bright opening onto the pitch
    A("wall").bb(-W / 2, W / 2, D, D + 0.3, -0.2, 0)
    A("exit", True).bb(-W / 2, W / 2, D + 0.2, D + 0.25, 0, 3.2)
    A("turf", True).bb(-W / 2, W / 2, D + 0.1, D + 0.2, 0, 1.0)
    for sx in (-1, 1):
        A("stripe").bb(sx * W / 2 - (0.03 if sx > 0 else 0), sx * W / 2 + (0 if sx > 0 else 0.03), -8, D, 1.0, 1.25)
        A("stripe2").bb(sx * W / 2 - (0.03 if sx > 0 else 0), sx * W / 2 + (0 if sx > 0 else 0.03), -8, D, 1.25, 1.32)
        A("wall").bb(sx * W / 2 - (0.05 if sx > 0 else 0), sx * W / 2 + (0 if sx > 0 else 0.05), -8, D, 0, 0.1)
    # ribs and ceiling lights every 4 m
    for i in range(10):
        y = 2 + i * 3.2
        A("ceil").bb(-W / 2, W / 2, y, y + 0.25, H - 0.25, H)
        A("wall").bb(-W / 2, -W / 2 + 0.22, y, y + 0.25, 0, H)
        A("wall").bb(W / 2 - 0.22, W / 2, y, y + 0.25, 0, H)
        A("tube", True).bb(-1.2, 1.2, y + 0.4, y + 0.6, H - 0.06, H - 0.02)
        area((0, y + 0.5, H - 0.2), 2.6, 300, (255, 248, 236), (0, y + 0.5, 0), size_y=0.8)
    for z in (2.3, 2.6):
        A("pipe").cyl((-W / 2 + 0.3, 10, z), 0.06, 30, rot=(math.pi / 2, 0, 0), segs=8)
    # doors on the left, club banner on the right
    for y in (6, 14):
        A("door").bb(-W / 2, -W / 2 + 0.06, y, y + 1.1, 0, 2.2, bevel=0.01)
        A("yel").bb(-W / 2 + 0.01, -W / 2 + 0.07, y + 0.3, y + 0.8, 2.4, 2.6)
    A("stripe").bb(W / 2 - 0.06, W / 2, 8, 12, 0.6, 2.6, bevel=0.01)
    A("stripe2").bb(W / 2 - 0.07, W / 2 - 0.06, 8.4, 11.6, 1.2, 2.0)
    for by in (4.0, 4.6):
        A("yel").cyl((W / 2 - 0.4, by, 0.45), 0.08, 0.9, segs=8)
    A("yel", True).bb(-0.05, 0.05, 0, D, 0.002, 0.02)
    fill(350, at=(0, -6, 2.6), target=(0, 14, 1.3), size=4)
    env(True, amb_boost=0.0)
    area((0, D - 1.5, 1.5), 3.0, 900, (235, 245, 255), (0, 8, 1.2), size_y=3)
    return dict(loc=(0, -6.0, 1.45), tgt=(0, D, 1.35), lens=28, focus=16.0, fstop=3.5)


def sc_team_bus(tier):
    rng = random.Random(12)
    mat("wall", (226, 228, 234), 0.7)
    mat("floor", (86, 92, 106), 0.85)
    mat("ceil", (238, 240, 244), 0.8)
    mat("seatf", (44, 82, 146), 0.9)
    mat("seath", (238, 238, 242), 0.85)
    mat("steel", (190, 196, 206), 0.3, 0.9)
    mat("dark", (22, 24, 30), 0.7)
    mat("rack", (200, 204, 212), 0.5)
    mat("frame", (60, 66, 80), 0.5)
    mat("bag", (196, 60, 52), 0.8)
    mat("bag2", (40, 44, 54), 0.8)
    mat("road", (54, 56, 62), 0.95)
    mat("roadl", (240, 240, 240), 0.8)
    mat("wheelw", (250, 250, 250), 0.7)
    glow("tube", (255, 248, 236), 9.0)
    W, L, H = 4.0, 12.0, 2.3
    A("floor").bb(-W / 2, W / 2, -3, L, -0.2, 0.0)
    A("ceil").bb(-W / 2 - 0.1, W / 2 + 0.1, -3, L, H, H + 0.2)
    ground((80, 130, 70), z=-1.2)
    A("road").bb(-200, 200, 4, 600, -1.2, -1.05)
    for i in range(16):
        A("roadl", True).bb(-0.15, 0.15, 10 + i * 12, 15 + i * 12, -1.04, -1.03)
    # side walls with a continuous window band
    for sx in (-1, 1):
        x0, x1 = (sx * W / 2, sx * W / 2 + sx * 0.12)
        xa, xb = (min(x0, x1), max(x0, x1))
        A("wall").bb(xa, xb, -3, L, -0.2, 0.85)
        A("wall").bb(xa, xb, -3, L, 2.0, H + 0.2)
        for k in range(14):
            A("frame").bb(xa, xb, -2 + k * 1.1, -1.9 + k * 1.1, 0.85, 2.0)
        ra, rb = (W / 2 - 0.7, W / 2) if sx > 0 else (-W / 2, -W / 2 + 0.7)
        A("rack").bb(ra, rb, -3, L, 1.95, 2.08, bevel=0.03)
        # rows of seats: pairs of two each side
        for k in range(9):
            y = 0.6 + k * 1.2
            for px in ((0.5, 1.95), (-1.95, -0.5)):
                if (px[0] > 0) != (sx > 0):
                    continue
                A("seatf").bb(px[0], px[1], y, y + 0.55, 0.38, 0.52, bevel=0.05)
                A("seatf").bb(px[0], px[1], y + 0.46, y + 0.6, 0.45, 1.25, bevel=0.05)
                for hx in (px[0] + 0.36, px[1] - 0.36):
                    A("seath").bb(hx - 0.18, hx + 0.18, y + 0.44, y + 0.6, 1.08, 1.42, bevel=0.05)
                A("dark").bb(px[0] + 0.03, px[1] - 0.03, y + 0.05, y + 0.5, 0.0, 0.38)
        if sx > 0:
            A("bag").bb(1.0, 1.7, 3.5, 4.2, 2.08, 2.4, bevel=0.06)
            A("bag2").bb(0.8, 1.6, 7.8, 8.6, 2.08, 2.35, bevel=0.06)
    for k in range(6):
        y = 0.5 + k * 2.0
        A("tube", True).bb(-0.25, 0.25, y, y + 1.2, H - 0.04, H)
        area((0, y + 0.6, H - 0.2), 1.6, lamp_l(250), (255, 248, 236), (0, y + 0.6, 0), size_y=1.2)
    # windscreen and driver
    A("wall").bb(-W / 2, W / 2, L, L + 0.15, -0.2, 0.75)
    A("wall").bb(-W / 2, W / 2, L, L + 0.15, 2.4, H + 0.2)
    A("frame").bb(-0.04, 0.04, L, L + 0.16, 0.75, 2.4)
    A("dark").bb(-0.5, 0.5, L - 0.8, L - 0.3, 0.3, 1.4, bevel=0.08)
    A("dark").bb(-0.9, -0.3, L - 0.35, L - 0.05, 0.7, 0.95, bevel=0.03)
    city(L + 60, x0=-150, x1=150, seed=6, hmin=5, hmax=22, base_z=-1.2)
    fill(450, at=(0, -3, 2.0), target=(0, 8, 1.2), size=3)
    env(True, sun_az=-20)
    area((0, L + 1, 1.6), 3.0, 600 * C.T["win_s"], C.T["win"], (0, 4, 1.2), size_y=1.4)
    return dict(loc=(0, -2.6, 1.25), tgt=(0, L, 1.3), lens=24, focus=7.0, fstop=3.5)


def sc_club_office(tier):
    rng = random.Random(14)
    mat("wall", (212, 212, 216), 0.9)
    mat("floor", (64, 66, 74), 0.95)
    mat("ceil", (238, 238, 242), 0.9)
    mat("wood", (104, 66, 42), 0.5)
    mat("wood2", (150, 104, 66), 0.55)
    mat("leather", (52, 40, 36), 0.6)
    mat("steel", (190, 194, 202), 0.3, 0.9)
    mat("gold", (236, 188, 70), 0.3, 0.9)
    mat("glass", (200, 230, 240), 0.1, alpha=0.15)
    mat("screen", (24, 34, 54), 0.2, emit=((90, 150, 230), 0.8))
    mat("paper", (245, 245, 240), 0.9)
    mat("crest", (44, 80, 150), 0.6)
    mat("crestw", (240, 240, 244), 0.6)
    mat("shirt", (196, 52, 52), 0.8)
    mat("shirt2", (40, 84, 160), 0.8)
    mat("plant", (70, 130, 70), 0.85)
    mat("pot", (236, 232, 224), 0.8)
    mat("frame", (236, 236, 232), 0.5)
    mat("grassA", (74, 146, 62), 0.95, emit=(C.T["hor"], 0.25))
    mat("grassB", (86, 160, 72), 0.95, emit=(C.T["hor"], 0.25))
    mat("roofm", (206, 210, 218), 0.6, emit=(C.T["hor"], 0.5))
    mat("conc", (150, 154, 162), 0.9, emit=(C.T["hor"], 0.5))
    mat("seat", (44, 78, 140), 0.7, emit=(C.T["hor"], 0.4))
    glow("lampg", (255, 220, 170), 10.0)
    glow("flood", (255, 248, 230), 30.0, lamp=False)
    C.mats["flood"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.6 + 30.0 * C.T["flood"]
    W, D, H = 9, 7, 3.2
    ops = [(-3.6, 3.6, 0.6, 2.8)]
    room(W, D, H, openings=ops, base="wood")
    win_light(*ops[0], D, 1.3)
    # the stadium outside: the pitch sits a few metres below the window so a green
    # band shows along its sill, with the far stand and floodlights above it
    A("grassA").bb(-120, 120, D + 8, D + 90, -4.3, -4.0)
    for i in range(8):
        A("grassB").bb(-120, 120, D + 12 + i * 10, D + 17 + i * 10, -4.0, -3.98)
    th = 0.36                                   # slope of the far stand
    A("seat").box((0, D + 92 + 18 * math.cos(th), -4 + 18 * math.sin(th)), (260, 36, 0.8), rot=(th, 0, 0))
    A("conc").box((0, D + 92.5, -3.4), (260, 1.0, 1.8))
    crowd = [(214, 216, 222), (70, 100, 160), (176, 84, 84), (206, 170, 90), (70, 74, 88), (96, 140, 110)]
    for k, c in enumerate(crowd):
        mat(f"spk{k}", c, 0.9, emit=(c, 0.3))
    rs = random.Random(2)
    for t in [0.6 + n * 0.5 for n in range(72)]:
        for x in [-125 + n * 0.85 for n in range(295)]:
            if rs.random() < 0.9:
                A(f"spk{rs.randrange(6)}", True).box(
                    (x, D + 92 + t * math.cos(th) - 0.3, -4 + t * math.sin(th) + 0.5), (0.5, 0.3, 0.4), rot=(th, 0, 0))
    A("roofm").bb(-130, 130, D + 112, D + 134, 13.0, 13.6)
    for mx in (-110, 110):
        A("steel").cyl((mx, D + 96, 12), 0.8, 32, segs=8)
        A("flood", True).bb(mx - 5, mx + 5, D + 94, D + 95, 26, 31)
    # desk, chair, laptop, lamp
    A("wood").bb(-2.2, 2.0, 3.8, 4.9, 0.7, 0.78, bevel=0.02)
    A("wood").bb(-2.1, -1.9, 3.85, 4.85, 0, 0.7)
    A("wood").bb(1.7, 1.9, 3.85, 4.85, 0, 0.7)
    A("wood").bb(-1.9, 1.7, 4.8, 4.85, 0.1, 0.7)
    A("steel").bb(-0.4, 0.4, 4.35, 4.85, 0.78, 0.8)
    A("leather").box((0.0, 4.6, 1.02), (0.78, 0.04, 0.45), rot=(0.2, 0, 0), bevel=0.015)
    A("steel").bb(-0.03, 0.03, 4.55, 4.65, 0.8, 0.95)
    A("paper").bb(-1.4, -0.8, 4.0, 4.4, 0.78, 0.79)
    A("steel").cyl((1.4, 4.4, 0.95), 0.012, 0.35, segs=5)
    A("lampg", True).sph((1.4, 4.4, 1.15), 0.12, scale=(1, 1, 0.7), segs=10, rings=6)
    point((1.4, 4.4, 1.1), lamp_l(120), (255, 220, 170), 0.15)
    A("leather").bb(-0.5, 0.5, 5.2, 5.75, 0.45, 0.6, bevel=0.06)
    A("leather").bb(-0.5, 0.5, 5.6, 5.8, 0.55, 1.45, bevel=0.08)
    A("steel").cyl((0, 5.4, 0.22), 0.03, 0.45, segs=6)
    # trophy cabinet, shelf, framed shirts, crest
    A("wood").bb(-W / 2 + 0.05, -W / 2 + 0.12, 1.4, 4.8, 0, 2.5)           # back panel
    A("wood").bb(-W / 2 + 0.05, -W / 2 + 0.6, 1.4, 1.46, 0, 2.5)           # sides, top, plinth
    A("wood").bb(-W / 2 + 0.05, -W / 2 + 0.6, 4.74, 4.8, 0, 2.5)
    A("wood").bb(-W / 2 + 0.05, -W / 2 + 0.6, 1.4, 4.8, 2.44, 2.5)
    A("wood").bb(-W / 2 + 0.05, -W / 2 + 0.6, 1.4, 4.8, 0, 0.1)
    A("glass").bb(-W / 2 + 0.585, -W / 2 + 0.6, 1.46, 4.74, 0.1, 2.44)
    for z in (0.7, 1.3, 1.9):
        A("wood").bb(-W / 2 + 0.1, -W / 2 + 0.58, 1.46, 4.74, z, z + 0.03)
        for k in range(4):
            y = 1.9 + k * 0.7
            A("gold").cyl((-W / 2 + 0.35, y, z + 0.14), 0.05, 0.22, segs=10, r2=0.02)
            A("gold").sph((-W / 2 + 0.35, y, z + 0.3), 0.07, segs=8, rings=6)
    for i, (m, y) in enumerate((("shirt", 5.2), ("shirt2", 6.0))):
        A("frame").bb(-W / 2 + 0.02, -W / 2 + 0.08, y, y + 0.7, 1.3, 2.2)
        A(m).bb(-W / 2 + 0.085, -W / 2 + 0.1, y + 0.06, y + 0.64, 1.36, 2.14)
    A("crest").sph((W / 2 - 0.07, 4.6, 1.85), 0.7, scale=(0.07, 1, 1.15), segs=16, rings=10)
    A("crestw").sph((W / 2 - 0.12, 4.6, 1.85), 0.5, scale=(0.05, 1, 1.15), segs=16, rings=10)
    for px, py in ((3.8, 6.4), (-3.9, 6.5)):
        A("pot").cyl((px, py, 0.35), 0.28, 0.7, segs=12, r2=0.22)
        for _ in range(7):
            A("plant").sph((px + rng.uniform(-0.25, 0.25), py + rng.uniform(-0.25, 0.25), 1.0 + rng.uniform(0, 0.9)),
                           rng.uniform(0.22, 0.36), segs=8, rings=6)
    fill(520, size=8)
    area((0, 3, H - 0.2), 3.5, lamp_l(360), (255, 240, 220), (0, 5, 0.5), size_y=2.5)
    env(True, sun_az=-30)
    return dict(loc=(0, -5.0, 1.45), tgt=(0, D, 1.35), lens=26, focus=8.5)


def sc_clinic(tier):
    mat("wall", (226, 238, 242), 0.9)
    mat("floor", (200, 210, 214), 0.45)
    mat("ceil", (248, 250, 250), 0.9)
    mat("bed", (232, 236, 240), 0.5)
    mat("vinyl", (60, 150, 190), 0.4)
    mat("steel", (200, 206, 214), 0.25, 0.9)
    mat("towel", (250, 250, 248), 0.95)
    mat("cab", (238, 242, 244), 0.5)
    mat("glass", (200, 230, 240), 0.1, alpha=0.18)
    mat("box", (220, 120, 110), 0.7)
    mat("box2", (90, 150, 200), 0.7)
    mat("ball", (60, 180, 170), 0.5)
    mat("band", (230, 90, 70), 0.7)
    mat("wood", (200, 170, 130), 0.6)
    mat("skin", (236, 190, 160), 0.7)
    mat("muscle", (206, 90, 80), 0.7)
    mat("poster", (250, 250, 248), 0.8)
    mat("blind", (236, 236, 232), 0.6)
    mat("plant", (70, 130, 70), 0.85)
    mat("pot", (236, 232, 224), 0.8)
    mat("screen", (24, 34, 54), 0.2, emit=((90, 150, 230), 0.9))
    mat("white", (250, 250, 250), 0.7)
    glow("panel", (255, 252, 246), 7.0)
    W, D, H = 9, 6, 3.0
    ops = [(0.8, 3.6, 0.9, 2.5)]
    room(W, D, H, openings=ops, base="cab")
    win_light(*ops[0], D, 1.3)
    city(D + 22, seed=10, hmin=5, hmax=22)
    for k in range(9):   # blinds half drawn
        A("blind", True).bb(0.85, 3.55, D - 0.1, D - 0.06, 2.45 - k * 0.055, 2.47 - k * 0.055)
    # treatment bed
    A("bed").bb(2.4, 4.3, 2.6, 4.8, 0.45, 0.65, bevel=0.06)
    A("vinyl").bb(2.35, 4.35, 2.55, 4.85, 0.55, 0.72, bevel=0.07)
    A("steel").bb(3.2, 3.5, 3.4, 3.7, 0, 0.45)
    A("towel").bb(2.5, 3.2, 3.0, 3.6, 0.72, 0.8, bevel=0.03)
    # cabinet, wall bars, poster, ball, bands
    A("cab").bb(-4.4, -3.0, D - 0.6, D - 0.05, 0, 2.2, bevel=0.02)
    A("glass").bb(-4.3, -3.1, D - 0.68, D - 0.62, 0.9, 2.1)
    for z in (1.15, 1.6, 2.0):
        for k in range(4):
            A("box" if (k + int(z * 10)) % 2 else "box2").bb(-4.25 + k * 0.3, -4.05 + k * 0.3, D - 0.58, D - 0.15, z, z + 0.25, bevel=0.01)
    for k in range(10):
        A("wood").bb(-2.6 + k * 0.17, -2.56 + k * 0.17, D - 0.12, D - 0.06, 0, 2.5)
    for z in range(6):
        A("wood").bb(-2.6, -1.0, D - 0.12, D - 0.04, 0.3 + z * 0.4, 0.33 + z * 0.4)
    A("poster").bb(-0.6, 0.5, D - 0.06, D - 0.03, 1.0, 2.3)
    A("skin").sph((-0.05, D - 0.07, 2.05), 0.12, scale=(1, 0.3, 1))
    A("muscle").bb(-0.25, 0.15, D - 0.075, D - 0.06, 1.35, 1.9, bevel=0.01)
    A("muscle").bb(-0.05, 0.05, D - 0.075, D - 0.06, 1.05, 1.35)
    A("ball").sph((-1.6, 3.6, 0.36), 0.36, segs=16, rings=10)
    A("band").cyl((-0.8, D - 0.12, 1.9), 0.012, 0.5, rot=(0, 0, 0), segs=5)
    A("steel").bb(-0.85, -0.75, D - 0.14, D - 0.06, 1.85, 1.95)
    A("pot").cyl((4.0, 5.5, 0.3), 0.22, 0.6, segs=10, r2=0.17)
    for _ in range(6):
        A("plant").sph((4.0 + (_ % 3) * 0.06, 5.5, 0.8 + 0.12 * _), 0.22, segs=8, rings=6)
    # desk with a monitor
    A("wood").bb(-3.6, -1.9, 1.0, 1.6, 0.7, 0.75, bevel=0.015)
    A("steel").bb(-3.5, -3.45, 1.05, 1.55, 0, 0.7)
    A("steel").bb(-2.05, -2.0, 1.05, 1.55, 0, 0.7)
    A("screen", True).box((-2.8, 1.45, 1.05), (0.6, 0.03, 0.36), bevel=0.01)
    for y in (1.5, 3.8):
        A("panel", True).bb(-1.0, 1.0, y, y + 1.2, H - 0.04, H)
        area((0, y + 0.6, H - 0.2), 2.4, lamp_l(450), (255, 252, 246), (0, y + 0.6, 0), size_y=1.4)
    fill(360, size=9)
    env(True, sun_az=-28)
    return dict(loc=(0, -5.0, 1.45), tgt=(0, D, 1.3), lens=26, focus=8.0)


def sc_restaurant(tier):
    rng = random.Random(17)
    mat("wall", (96, 62, 48), 0.8)
    mat("panel", (70, 44, 34), 0.6)
    mat("floor", (64, 44, 34), 0.45)
    mat("ceil", (60, 46, 40), 0.9)
    mat("wood", (74, 48, 34), 0.5)
    mat("cloth", (246, 242, 234), 0.9)
    mat("steel", (200, 204, 212), 0.3, 0.9)
    mat("glass", (220, 236, 246), 0.05, alpha=0.22)
    mat("wine", (120, 24, 40), 0.3)
    mat("plate", (250, 250, 248), 0.3)
    mat("seatr", (120, 34, 44), 0.8)
    mat("flower", (236, 100, 120), 0.8)
    mat("plant", (70, 130, 70), 0.85)
    mat("pot", (236, 232, 224), 0.8)
    mat("bottle", (40, 90, 60), 0.2)
    mat("bottle2", (120, 70, 30), 0.2)
    glow("flame", (255, 200, 110), 28.0, lamp=False)
    glow("sconce", (255, 200, 130), 9.0)
    glow("pend", (255, 196, 120), 10.0)
    glow("backlit", (255, 190, 110), 4.0)
    W, D, H = 11, 8, 3.3
    ops = [(-4.6, -1.6, 0.6, 2.8), (1.6, 4.6, 0.6, 2.8)]
    room(W, D, H, openings=ops, base="panel")
    for o in ops:
        win_light(*o, D, 0.8)
    city(D + 26, seed=15, hmin=10, hmax=48)
    # wainscot
    A("panel").bb(-W / 2, -W / 2 + 0.05, 0, D, 0, 1.0)
    A("panel").bb(W / 2 - 0.05, W / 2, 0, D, 0, 1.0)
    # booth on the left wall, bar on the right
    A("seatr").bb(-W / 2 + 0.05, -W / 2 + 0.7, 1.6, 6.8, 0.3, 0.55, bevel=0.05)
    A("seatr").bb(-W / 2 + 0.05, -W / 2 + 0.3, 1.6, 6.8, 0.5, 1.25, bevel=0.06)
    A("wood").bb(W / 2 - 1.3, W / 2 - 0.2, 2.6, 7.4, 0, 1.1, bevel=0.03)
    A("backlit", True).bb(W / 2 - 0.12, W / 2 - 0.08, 2.6, 7.2, 1.3, 2.4)
    for k in range(9):
        y = 2.8 + k * 0.46
        for z in (1.45, 1.85, 2.25):
            A("bottle" if k % 2 else "bottle2").cyl((W / 2 - 0.25, y, z + 0.14), 0.04, 0.28, segs=8)
    tables = [(-2.9, 4.0), (-0.5, 6.2), (2.6, 4.8), (-3.6, 6.3), (0.4, 2.8)]
    for tx, ty in tables:
        A("steel").cyl((tx, ty, 0.35), 0.04, 0.7, segs=8)
        A("cloth").cyl((tx, ty, 0.72), 0.46, 0.04, segs=24)
        A("plate").cyl((tx - 0.18, ty - 0.08, 0.75), 0.11, 0.01, segs=14)
        A("plate").cyl((tx + 0.18, ty + 0.08, 0.75), 0.11, 0.01, segs=14)
        A("glass").cyl((tx, ty + 0.18, 0.84), 0.035, 0.14, segs=10)
        A("wine").cyl((tx, ty + 0.18, 0.80), 0.028, 0.05, segs=10)
        A("steel").cyl((tx, ty - 0.05, 0.8), 0.018, 0.09, segs=8)
        A("flame", True).sph((tx, ty - 0.05, 0.875), 0.014, scale=(1, 1, 1.6), segs=6, rings=4)
        point((tx, ty - 0.05, 0.92), lamp_l(35), (255, 196, 120), 0.05)
        for ang in (0.8, 3.9):
            chair(tx + math.cos(ang) * 0.78, ty + math.sin(ang) * 0.78, rot=ang + math.pi / 2, m="wood", seat="seatr")
    A("pot").cyl((4.6, 7.2, 0.3), 0.26, 0.6, segs=12, r2=0.2)
    for _ in range(6):
        A("plant").sph((4.6 + rng.uniform(-0.2, 0.2), 7.2 + rng.uniform(-0.2, 0.2), 1.0 + rng.uniform(0, 0.7)), 0.3, segs=8, rings=6)
    for px, py in ((-3.4, 5.0), (0.8, 3.6), (-1.0, 7.2), (3.6, 6.5)):
        A("steel").cyl((px, py, 2.95), 0.008, 0.7, segs=4)
        A("pend", True).cyl((px, py, 2.5), 0.3, 0.3, segs=14, r2=0.06)
        point((px, py, 2.3), lamp_l(150), (255, 196, 120), 0.2)
    for sy in (2.0, 4.4, 6.6):
        A("sconce", True).sph((-W / 2 + 0.14, sy, 2.1), 0.08, scale=(0.6, 1, 1.4), segs=8, rings=6)
        point((-W / 2 + 0.3, sy, 2.1), lamp_l(40), (255, 200, 130), 0.1)
    fill(380, size=8)
    area((0, 3.5, H - 0.2), 6, lamp_l(380), (255, 200, 150), (0, 5, 0.6), size_y=4)
    env(True, sun_az=-25)
    return dict(loc=(0, -5.0, 1.4), tgt=(0, D, 1.3), lens=26, focus=8.0)


def sc_park(tier):
    rng = random.Random(23)
    mat("path", (206, 196, 176), 0.9)
    mat("pathl", (170, 160, 142), 0.9)
    mat("grass", (96, 156, 70), 0.95)
    mat("rail", (236, 236, 240), 0.5)
    mat("sea", (52, 122, 168), 0.25, emit=((150, 190, 215), 0.4))
    mat("leaf", (62, 120, 64), 0.9)
    mat("leaf2", (90, 146, 60), 0.9)
    mat("trunk", (98, 70, 48), 0.9)
    mat("hill", (96, 130, 136), 1.0)
    mat("bench", (150, 106, 68), 0.7)
    mat("steel", (60, 66, 76), 0.4, 0.8)
    mat("sail", (250, 250, 250), 0.8)
    mat("hull", (40, 76, 140), 0.7)
    mat("flower", (236, 100, 120), 0.8)
    mat("flower2", (250, 210, 60), 0.8)
    glow("lampg", (255, 220, 160), 12.0, lamp=False)
    C.mats["lampg"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.5 + 14.0 * min(C.T["street"], 1.5)
    T = C.T
    seac = {"day": (52, 122, 168), "dusk": (70, 62, 110), "night": (10, 22, 52)}[C.tname]
    C.mats["sea"].node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = srgb(*seac)
    C.mats["sea"].node_tree.nodes["Principled BSDF"].inputs["Emission Color"].default_value = srgb(*T["hor"])
    C.mats["sea"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        {"day": 0.3, "dusk": 0.2, "night": 0.1}[C.tname]
    A("sea", True).bb(-900, 900, 10, 900, -2.1, -2.0)
    A("grass", True).bb(-300, 300, -40, 9.5, -0.3, 0)
    A("path", True).bb(-300, 300, -40, 7.0, -0.05, 0.02)
    for i in range(-30, 30):
        A("pathl", True).bb(i * 2.0, i * 2.0 + 0.03, -40, 7.0, 0.02, 0.03)
    A("pathl", True).bb(-300, 300, 3.4, 3.44, 0.02, 0.03)
    # seawall + railing
    A("path", True).bb(-300, 300, 7.0, 9.5, -2.2, 0.0)
    for x in range(-60, 60):
        A("rail").cyl((x * 1.0, 8.2, 0.55), 0.03, 1.1, segs=6)
    A("rail").bb(-300, 300, 8.17, 8.23, 1.02, 1.08)
    A("rail").bb(-300, 300, 8.19, 8.21, 0.55, 0.58)
    # lamp posts and benches
    for x in (-9, 0, 9):
        A("steel").cyl((x, 6.0, 1.9), 0.06, 3.8, segs=8)
        A("lampg", True).sph((x, 6.0, 3.9), 0.22, segs=10, rings=6)
        if C.T["street"] > 0:
            point((x, 6.0, 3.6), 600 * C.T["street"], (255, 220, 160), 0.3)
    for x in (-5.0, 5.5):
        A("bench").bb(x - 0.9, x + 0.9, 5.0, 5.45, 0.42, 0.47, bevel=0.01)
        A("bench").bb(x - 0.9, x + 0.9, 5.4, 5.47, 0.47, 0.9, bevel=0.01)
        for lx in (x - 0.8, x + 0.8):
            A("steel").bb(lx - 0.03, lx + 0.03, 5.0, 5.45, 0, 0.42)
    # trees and flower beds along the near side, distant hills and a sailboat
    for tx in (-18, -13, -8, 8.5, 14, 19):
        tree(tx + rng.uniform(-1, 1), 3.0 + rng.uniform(0, 0.8), rng.uniform(7, 10), rng)
    for x in range(-500, 500, 110):
        A("hill").sph((x + rng.uniform(-20, 20), 520, -40), 120, scale=(1.8, 0.7, 0.6), segs=16, rings=10)
    A("hull").box((22, 120, -1.6), (5, 1.4, 1.2), bevel=0.2)
    A("sail").sph((22.5, 120, 2.6), 2.2, scale=(0.05, 1, 1.6), segs=10, rings=8)
    env(False, sun_az=-150 if C.tname == "day" else 160, sun_boost=1.0, amb_boost=1.0, sun_soft=6)
    if C.tname == "night":
        area((0, -6, 12), 30, 3500, (190, 210, 255), (0, 20, 0), size_y=12)
    return dict(loc=(0, -6.5, 1.55), tgt=(0, 60, 1.5), lens=28, focus=24.0, fstop=6.0)


def sc_gym(tier):
    rng = random.Random(31)
    mat("wall", (188, 192, 200), 0.85)
    mat("floor", (30, 32, 38), 0.6)
    mat("ceil", (70, 74, 84), 0.9)
    mat("stripe", (44, 78, 140), 0.6)
    mat("steel", (170, 176, 188), 0.3, 0.9)
    mat("blk", (24, 26, 32), 0.6, 0.3)
    mat("rubber", (20, 22, 26), 0.9)
    mat("redb", (200, 50, 46), 0.5, 0.3)
    mat("plate", (40, 42, 50), 0.4, 0.5)
    mat("plate2", (200, 50, 46), 0.4, 0.5)
    mat("yel", (250, 210, 50), 0.6)
    mat("pipe", (130, 136, 148), 0.5, 0.7)
    mat("screen", (20, 26, 40), 0.2, emit=((60, 160, 230), 1.0))
    mat("mirror", (200, 214, 226), 0.05, 0.6)
    mat("frame", (150, 156, 168), 0.5)
    glow("tube", (255, 250, 240), 10.0)
    W, D, H = 14, 9, 4.2
    ops = [(-6.0, -1.4, 3.0, 3.9), (1.4, 6.0, 3.0, 3.9)]
    room(W, D, H, openings=ops, base="blk")
    for o in ops:
        win_light(*o, D, 1.2)
    city(D + 24, seed=19, hmin=10, hmax=40, base_z=-2)
    A("stripe").bb(-W / 2, W / 2, D - 0.04, D, 2.6, 2.95)
    for xx in (-4.5, 0, 4.5):
        A("yel", True).bb(xx - 0.05, xx + 0.05, 0, D, 0.002, 0.012)
    # power racks with bars and plates
    for rx in (-5.3, -2.6):
        for dx in (-0.55, 0.55):
            for dy in (-0.45, 0.45):
                A("redb").bb(rx + dx - 0.04, rx + dx + 0.04, 6.5 + dy - 0.04, 6.5 + dy + 0.04, 0, 2.3)
        for dx in (-0.55, 0.55):
            A("redb").bb(rx + dx - 0.04, rx + dx + 0.04, 6.05, 6.95, 2.26, 2.3)
        A("steel").cyl((rx, 6.5, 1.25), 0.014, 2.0, rot=(0, math.pi / 2, 0), segs=8)
        for sgn in (-1, 1):
            A("plate").cyl((rx + sgn * 0.78, 6.5, 1.25), 0.22, 0.05, rot=(0, math.pi / 2, 0), segs=16)
            A("plate2").cyl((rx + sgn * 0.85, 6.5, 1.25), 0.17, 0.04, rot=(0, math.pi / 2, 0), segs=16)
        A("blk").bb(rx - 0.4, rx + 0.4, 6.1, 6.9, 0.28, 0.4, bevel=0.03)
    # dumbbell rack on the right
    for z in (0.5, 0.95):
        A("blk").bb(3.2, 5.6, 7.3, 7.9, z, z + 0.05)
        for k in range(10):
            x = 3.35 + k * 0.23
            A("steel").cyl((x, 7.6, z + 0.12), 0.012, 0.24, rot=(math.pi / 2, 0, 0), segs=6)
            for yy in (7.45, 7.75):
                A("blk").sph((x, yy, z + 0.12), 0.07, segs=8, rings=6)
    A("blk").bb(3.1, 5.7, 7.25, 7.35, 0, 1.0)
    # treadmills along the left wall
    for i in range(3):
        y = 2.0 + i * 1.6
        A("blk").bb(-6.5, -5.0, y, y + 0.7, 0.12, 0.3, bevel=0.03)
        A("rubber").bb(-6.45, -5.05, y + 0.05, y + 0.65, 0.3, 0.33)
        A("blk").bb(-6.6, -6.5, y + 0.05, y + 0.65, 0.3, 1.2)
        A("screen", True).box((-6.35, y + 0.35, 1.3), (0.05, 0.4, 0.22), rot=(0, -0.4, 0), bevel=0.01)
    # bench and kettlebells
    A("blk").bb(0.4, 1.8, 3.6, 4.1, 0.4, 0.5, bevel=0.03)
    A("steel").bb(0.6, 0.68, 3.75, 3.95, 0, 0.4)
    A("steel").bb(1.5, 1.58, 3.75, 3.95, 0, 0.4)
    for k in range(5):
        A("redb" if k % 2 else "blk").sph((-0.4 + k * 0.42, 5.2, 0.18), 0.15, segs=10, rings=8)
    # ceiling ducts and strip lights
    A("pipe").cyl((0, 4.0, H - 0.4), 0.3, W, rot=(0, math.pi / 2, 0), segs=16)
    A("pipe").cyl((0, 6.6, H - 0.5), 0.22, W, rot=(0, math.pi / 2, 0), segs=16)
    for y in (1.6, 3.6, 5.6, 7.4):
        for x in (-4, 0, 4):
            A("tube", True).bb(x - 1.0, x + 1.0, y - 0.07, y + 0.07, H - 0.06, H - 0.02)
        area((0, y, H - 0.3), 8, lamp_l(800), (255, 250, 242), (0, y, 0), size_y=0.8)
    fill(480, size=10)
    env(True, sun_az=-28)
    return dict(loc=(0, -5.5, 1.5), tgt=(0, D, 1.4), lens=26, focus=9.5)


def sc_shop(tier):
    rng = random.Random(41)
    mat("wall", (236, 236, 240), 0.9)
    mat("floor", (178, 146, 110), 0.5)
    mat("ceil", (60, 64, 76), 0.9)
    mat("shelf", (250, 250, 250), 0.6)
    mat("wood", (150, 106, 68), 0.6)
    mat("steel", (200, 204, 212), 0.3, 0.9)
    mat("blk", (28, 30, 36), 0.6)
    mat("glass", (210, 232, 242), 0.05, alpha=0.15)
    mat("white", (250, 250, 250), 0.8)
    mat("mann", (236, 232, 224), 0.7)
    mat("plant", (70, 130, 70), 0.85)
    mat("pot", (236, 232, 224), 0.8)
    shirts = [(40, 84, 160), (236, 236, 240), (196, 52, 52), (236, 170, 40), (60, 140, 90),
              (30, 34, 44), (120, 70, 150), (226, 120, 60)]
    for i, c in enumerate(shirts):
        mat(f"tshirt{i}", c, 0.85)
    shoes = [(236, 236, 240), (40, 84, 160), (250, 120, 50), (30, 34, 44)]
    for i, c in enumerate(shoes):
        mat(f"shoe{i}", c, 0.5)
    glow("neon", (255, 80, 130), 14.0)
    glow("neon2", (60, 200, 255), 14.0)
    glow("trk", (255, 244, 224), 10.0)
    W, D, H = 10, 8, 3.2
    ops = [(-4.6, -1.4, 0.3, 2.6)]
    room(W, D, H, openings=[], base="wood")
    # storefront: a glass wall on the left with the street behind it
    street_ops = [(0.6, 7.0, 0.05, 2.7)]
    A("glass").bb(-W / 2 - 0.1, -W / 2, 0.6, 7.0, 0.05, 2.7)
    for y in (0.6, 3.8, 7.0):
        A("steel").bb(-W / 2 - 0.12, -W / 2 + 0.02, y - 0.03, y + 0.03, 0, 2.7)
    # shelves on the back wall: folded shirts, shoe boxes
    for row in range(5):
        z = 0.6 + row * 0.45
        A("shelf").bb(-4.6, 4.6, D - 0.45, D - 0.02, z, z + 0.03)
        for k in range(18):
            x = -4.5 + k * 0.5
            if row < 3:
                A(f"tshirt{(k + row * 3) % 8}").bb(x, x + 0.4, D - 0.4, D - 0.06, z + 0.03, z + 0.03 + rng.uniform(0.1, 0.22), bevel=0.02)
            else:
                A(f"shoe{(k + row) % 4}").bb(x, x + 0.4, D - 0.4, D - 0.06, z + 0.03, z + 0.03 + 0.2, bevel=0.03)
    A("blk").bb(-4.7, -4.6, D - 0.45, D - 0.02, 0, 2.9)
    A("blk").bb(4.6, 4.7, D - 0.45, D - 0.02, 0, 2.9)
    # neon sign
    A("neon", True).box((0, D - 0.04, 2.95), (2.0, 0.03, 0.12), bevel=0.02)
    A("neon2", True).box((0, D - 0.04, 2.75), (1.2, 0.03, 0.08), bevel=0.02)
    point((0, D - 0.5, 2.85), lamp_l(60), (255, 120, 170), 0.2)
    # display tables and mannequins
    for tx, ty in ((-2.4, 4.6), (2.0, 5.2)):
        A("wood").bb(tx - 0.9, tx + 0.9, ty - 0.5, ty + 0.5, 0.65, 0.72, bevel=0.02)
        A("steel").bb(tx - 0.85, tx - 0.8, ty - 0.45, ty - 0.4, 0, 0.65)
        A("steel").bb(tx + 0.8, tx + 0.85, ty - 0.45, ty - 0.4, 0, 0.65)
        A("steel").bb(tx - 0.85, tx - 0.8, ty + 0.4, ty + 0.45, 0, 0.65)
        A("steel").bb(tx + 0.8, tx + 0.85, ty + 0.4, ty + 0.45, 0, 0.65)
        for k in range(4):
            A(f"shoe{k}").box((tx - 0.6 + k * 0.4, ty, 0.8), (0.3, 0.12, 0.12), rot=(0, 0, 0.2 * k), bevel=0.04)
    for mx, my, mc in ((-0.3, 6.2, 0), (0.9, 6.5, 2), (-1.5, 6.6, 3)):
        A("steel").cyl((mx, my, 0.02), 0.22, 0.04, segs=14)
        A("steel").cyl((mx, my, 0.5), 0.015, 1.0, segs=6)
        A(f"tshirt{mc}").cyl((mx, my, 1.25), 0.2, 0.55, segs=10, squash=(1, 0.65), r2=0.17)
        A("mann").sph((mx, my, 1.68), 0.1, segs=10, rings=8)
        A("mann").cyl((mx, my, 1.55), 0.05, 0.1, segs=8)
    # counter + till
    A("wood").bb(2.6, 4.5, 1.2, 2.2, 0, 1.0, bevel=0.03)
    A("blk").bb(2.7, 3.3, 1.4, 1.9, 1.0, 1.25, bevel=0.03)
    A("blk").box((3.0, 1.75, 1.45), (0.3, 0.03, 0.22), rot=(0.3, 0, 0))
    A("pot").cyl((4.3, 6.6, 0.3), 0.22, 0.6, segs=10, r2=0.17)
    for k in range(6):
        A("plant").sph((4.3 + (k % 3) * 0.05, 6.6, 0.8 + k * 0.12), 0.22, segs=8, rings=6)
    # track lights
    for x in (-2.5, 0, 2.5):
        A("blk").bb(x - 0.03, x + 0.03, 1.0, D - 0.3, H - 0.1, H - 0.05)
        for y in (2.5, 4.5, 6.5):
            A("blk").cyl((x, y, H - 0.2), 0.07, 0.18, segs=10)
            A("trk", True).cyl((x, y, H - 0.3), 0.06, 0.02, segs=10)
            area((x, y, H - 0.35), 0.5, lamp_l(150), (255, 240, 220), (x, y + 0.6, 0.6), size_y=0.5)
    # the street outside the storefront (left)
    mat("road", (54, 56, 62), 0.95)
    A("road").bb(-W / 2 - 40, -W / 2 - 3, -20, 60, -0.25, -0.05)
    bz = -0.2
    rngc = random.Random(9)
    mat("bld_a", (96, 108, 130), 0.9)
    mat("bld_b", (122, 132, 152), 0.9)
    glow("bld_lit", (255, 214, 140), 9.0, lamp=False)
    C.mats["bld_lit"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        9.0 * min(C.T["street"], 1.2)
    yb = -10
    while yb < 60:
        w = rngc.uniform(4, 9)
        h = rngc.uniform(8, 26)
        A("bld_a" if rngc.random() < 0.5 else "bld_b").bb(-W / 2 - 34, -W / 2 - 34 + 6, yb, yb + w, bz, h)
        if C.T["street"] > 0:
            for _ in range(int(h * w * 0.2)):
                wy, wz = yb + rngc.uniform(0.3, w - 0.8), rngc.uniform(1.0, h - 0.8)
                A("bld_lit", True).bb(-W / 2 - 28.05, -W / 2 - 28.0, wy, wy + 0.5, wz, wz + 0.7)
        yb += w + 0.3
    area((-W / 2 - 0.6, 3.8, 1.6), 5, 650 * C.T["win_s"], C.T["win"], (0, 4.5, 1.0), size_y=2.4)
    fill(430, size=9)
    env(True, sun_az=-70)
    return dict(loc=(0, -5.0, 1.45), tgt=(0, D, 1.3), lens=26, focus=8.0)


def sc_fan_street(tier):
    rng = random.Random(51)
    mat("road", (54, 56, 62), 0.95)
    mat("roadl", (240, 240, 240), 0.8)
    mat("pave", (170, 166, 160), 0.9)
    mat("fence", (176, 182, 192), 0.35, 0.8)
    mat("bld", (196, 200, 210), 0.8)
    mat("glassb", (70, 100, 140), 0.1, 0.4)
    mat("crest", (44, 80, 150), 0.6)
    mat("bus", (40, 76, 146), 0.5)
    mat("busw", (236, 236, 240), 0.5)
    mat("busg", (36, 44, 60), 0.15, 0.5)
    mat("tyre", (18, 18, 22), 0.9)
    mat("steel", (60, 66, 76), 0.4, 0.8)
    mat("trunk", (98, 70, 48), 0.9)
    mat("leaf", (62, 120, 64), 0.9)
    mat("flagb", (40, 84, 160), 0.8)
    mat("flagw", (240, 240, 244), 0.8)
    mat("scarf0", (40, 84, 160), 0.85)
    mat("scarf1", (240, 240, 244), 0.85)
    glow("lampg", (255, 220, 160), 12.0, lamp=False)
    C.mats["lampg"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.5 + 14.0 * min(C.T["street"], 1.5)
    glow("winlit", (255, 214, 140), 6.0, lamp=False)
    C.mats["winlit"].node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = \
        0.4 + 5.0 * min(C.T["street"], 1.3)
    people_mats()
    ground((120, 118, 116), name="pave")
    A("road").bb(-400, 400, -40, 2.5, -0.05, 0.0)
    for i in range(-20, 20):
        A("roadl", True).bb(i * 4, i * 4 + 2, -8, -7.8, 0.0, 0.01)
    A("pave").bb(-400, 400, 2.5, 60, -0.05, 0.12)
    # crowd barriers
    for i in range(-16, 16):
        x = i * 1.5
        A("fence").bb(x, x + 1.45, 5.0, 5.05, 0.9, 0.95)
        A("fence").bb(x, x + 1.45, 5.0, 5.05, 0.35, 0.4)
        for k in range(5):
            A("fence").bb(x + k * 0.36, x + k * 0.36 + 0.03, 5.0, 5.05, 0.35, 0.95)
        A("fence").bb(x, x + 0.04, 4.95, 5.1, 0, 1.0)
    # the fans
    for row in range(3):
        for _ in range(30 - row * 4):
            x = rng.uniform(-22, 22)
            y = 6.2 + row * 1.0 + rng.uniform(-0.2, 0.2)
            sc = rng.uniform(0.92, 1.05)
            person(x, y, 0.12, rng, s=sc, shirt="sh0" if rng.random() < 0.55 else "sh1" if rng.random() < 0.6 else None,
                   arms_up=rng.random() < 0.25, face=-1.0)
            A("scarf0" if rng.random() < 0.5 else "scarf1").cyl((x, y, 0.12 + 0.85 * sc + 0.62 * sc), 0.11 * sc, 0.06, segs=8)
    # flags and a banner
    for fx in (-14.0, -6.0, 3.0, 12.0, 18.0):
        A("steel").cyl((fx, 8.0, 2.4), 0.025, 4.8, segs=6)
        A("flagb" if int(fx) % 2 else "flagw").bb(fx, fx + 1.3, 7.98, 8.03, 3.6, 4.5)
        A("flagw" if int(fx) % 2 else "flagb").bb(fx, fx + 1.3, 7.97, 8.04, 4.0, 4.1)
    # training centre: long low glass building with crest
    A("bld").bb(-40, 40, 22, 36, 0, 9)
    A("glassb").bb(-34, 34, 21.8, 22.0, 1.2, 4.2)
    for k in range(-16, 17):
        A("bld").bb(k * 2.1, k * 2.1 + 0.1, 21.7, 21.9, 1.2, 4.2)
    for k in range(-14, 15):
        if rng.random() < 0.6 or C.T["street"] > 0:
            A("winlit", True).bb(k * 2.4, k * 2.4 + 1.6, 21.78, 21.79, 5.2, 7.4)
    A("crest").sph((0, 21.6, 7.4), 1.8, scale=(1, 0.08, 1.15), segs=18, rings=12)
    A("busw").sph((0, 21.5, 7.4), 1.2, scale=(1, 0.06, 1.15), segs=18, rings=12)
    # club bus parked on the right
    A("bus").bb(8, 22, 12, 14.6, 0.45, 3.3, bevel=0.25)
    A("busw").bb(8, 22, 11.95, 14.6, 1.1, 1.35)
    A("busg").bb(8.6, 21.4, 11.9, 12.0, 1.7, 2.9, bevel=0.06)
    for wx in (11, 18.5):
        A("tyre").cyl((wx, 11.9, 0.55), 0.55, 0.4, rot=(math.pi / 2, 0, 0), segs=16)
    # lamp posts, trees
    for x in (-26, -14, 16, 28):
        A("steel").cyl((x, 4.0, 3.0), 0.08, 6.0, segs=8)
        A("lampg", True).sph((x, 4.0, 6.1), 0.3, segs=10, rings=6)
        if C.T["street"] > 0:
            point((x, 4.0, 5.8), 900 * C.T["street"], (255, 220, 160), 0.3)
    for tx in (-34, -26, 30, 38):
        tree(tx, 17, rng.uniform(7, 10), rng)
    city(70, x0=-200, x1=200, seed=33, hmin=12, hmax=50, base_z=0)
    env(False, sun_az=-130, sun_boost=1.0, amb_boost=1.0, sun_soft=6)
    if C.tname == "night":
        area((0, -6, 12), 30, 3500, (190, 210, 255), (0, 12, 1), size_y=12)
    return dict(loc=(0, -6.0, 1.6), tgt=(0, 20, 2.2), lens=28, focus=14.0, fstop=5.0)


# (function, tiers, timed)
SCENES = {
    "locker_room": (sc_locker_room, [None], False),
    "training_ground": (sc_training_ground, [None], True),
    "cafe": (sc_cafe, [None], True),
    "press_room": (sc_press_room, [None], False),
    "home": (sc_home, ["modest", "luxury"], True),
    "stadium": (sc_stadium, ["full", "empty"], True),
    "tunnel": (sc_tunnel, [None], False),
    "team_bus": (sc_team_bus, [None], True),
    "club_office": (sc_club_office, [None], True),
    "clinic": (sc_clinic, [None], True),
    "restaurant": (sc_restaurant, [None], True),
    "park": (sc_park, [None], True),
    "gym": (sc_gym, [None], True),
    "shop": (sc_shop, [None], True),
    "fan_street": (sc_fan_street, [None], True),
}


def render_one(sid, tier, tname, name):
    fn = SCENES[sid][0]
    reset(tname)
    cam = fn(tier)
    flush()
    set_camera(cam)
    setup_render(os.path.join(OUT, name + ".jpg"))
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = {o.split(":")[0]: (o.split(":")[1] if ":" in o else None) for o in ONLY}
    for sid, (fn, tiers, timed) in SCENES.items():
        if wanted and sid not in wanted:
            continue
        for tier in tiers:
            if wanted.get(sid) and tier != wanted[sid]:
                continue
            for tname in (TIME_ARG or list(TIMES)) if timed else ["day"]:
                name = sid + (f"_{tier}" if tier else "") + (f"_{tname}" if timed else "")
                render_one(sid, tier, tname, name)


main()
