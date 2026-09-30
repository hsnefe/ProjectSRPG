"""Builds the match mini-game cast in Blender: outfield player + goalkeeper.

Style follows assets/images/sprites/footballer_run (low-poly, flat-shaded, big head,
no outlines). Run inside Blender (exec the file); it makes its own scene
"MatchPlayers" and leaves whatever else is open untouched.

Kit colours are driven by custom properties on the `KitControl_*` empties
(shirt / shorts / socks / trim / gloves as RGBA). Change them and every material
of that player follows through drivers, so one model serves teammate, rival and
keeper kits. Each player lives under a root empty `Player_Outfield` /
`Player_Keeper` whose joints are empties (hip, knee, shoulder, elbow) so a pose or
an animation is just a rotation on those.
"""
import math
import bpy
import bmesh
from mathutils import Matrix, Vector

def srgb(r, g, b):
    """Palette values are written as 0-255 sRGB (what the sprite sheet shows) and
    converted, since Blender materials are linear."""
    f = lambda v: ((v / 255 + 0.055) / 1.055) ** 2.4 if v / 255 > 0.04045 else v / 255 / 12.92
    return (f(r), f(g), f(b), 1)


SKIN = srgb(241, 204, 168)
HAIR = srgb(92, 64, 50)
BOOT = srgb(58, 58, 68)

# --- scene ------------------------------------------------------------------
scene = bpy.data.scenes.get("MatchPlayers") or bpy.data.scenes.new("MatchPlayers")
try:
    bpy.context.window.scene = scene
except Exception:
    pass
for o in list(scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)


def link(o):
    scene.collection.objects.link(o)
    return o


def mat(name, rgba, rough=0.85):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.name = "KitColor"
    rgb.outputs[0].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    # no sheen on cloth/skin: a white ambient reflecting off it only washes the colour out
    for k in ("Specular IOR Level", "Specular"):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = 0.0
    nt.links.new(rgb.outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    m.diffuse_color = rgba
    return m


def drive(m, ctrl, prop):
    """Drive material's KitColor RGB node from ctrl[prop] (RGBA array)."""
    rgb = m.node_tree.nodes["KitColor"]
    for i in range(4):
        fc = rgb.outputs[0].driver_add("default_value", i)
        fc.driver.type = "AVERAGE"
        v = fc.driver.variables.new()
        v.name = "c"
        v.targets[0].id = ctrl
        v.targets[0].data_path = f'["{prop}"][{i}]'
    # viewport colour too, so solid mode shows the kit
    for i in range(4):
        fc = m.driver_add("diffuse_color", i)
        fc.driver.type = "AVERAGE"
        v = fc.driver.variables.new()
        v.name = "c"
        v.targets[0].id = ctrl
        v.targets[0].data_path = f'["{prop}"][{i}]'


def finish(o, m, parent, smooth=False):
    o.data.materials.clear()
    o.data.materials.append(m)
    for p in o.data.polygons:
        p.use_smooth = smooth
    o.parent = parent
    return o


def box(name, size, loc, m, parent, bevel=0.012, taper_bottom=None):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
    if taper_bottom:
        for v in bm.verts:
            if v.co.z < 0:
                v.co.x *= taper_bottom
                v.co.y *= taper_bottom
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.location = loc
    return finish(o, m, parent)


def prism(name, r_top, r_bot, h, loc, m, parent, sides=6, scale=(1, 1, 1)):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=sides, radius1=r_bot, radius2=r_top, depth=h)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.location = loc
    o.scale = scale
    return finish(o, m, parent)


def blob(name, radius, loc, m, parent, scale=(1, 1, 1), subdiv=2):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.location = loc
    o.scale = scale
    return finish(o, m, parent)


def empty(name, loc, parent, size=0.04, kind="PLAIN_AXES"):
    e = bpy.data.objects.new(name, None)
    e.empty_display_type = kind
    e.empty_display_size = size
    e.location = loc
    e.parent = parent
    return link(e)


# --- one player -------------------------------------------------------------
def build_player(kind, origin_x, shirt, shorts, socks, trim, gloves=None):
    """kind: 'Outfield' | 'Keeper'. Faces -Y (Blender front)."""
    kp = kind == "Keeper"
    root = link(bpy.data.objects.new(f"Player_{kind}", None))
    root.empty_display_type = "ARROWS"
    root.empty_display_size = 0.3
    root.location = (origin_x, 0, 0)

    ctrl = link(bpy.data.objects.new(f"KitControl_{kind}", None))
    ctrl.empty_display_type = "SPHERE"
    ctrl.empty_display_size = 0.05
    ctrl.parent = root
    ctrl.location = (0, 0, 1.25)
    for k, c in (("shirt_color", shirt), ("shorts_color", shorts), ("socks_color", socks),
                 ("trim_color", trim), ("gloves_color", gloves or trim)):
        ctrl[k] = list(c)
        ctrl.id_properties_ui(k).update(subtype="COLOR", min=0.0, max=1.0, default=list(c))

    m_shirt = mat(f"{kind}_Shirt", shirt)
    m_shorts = mat(f"{kind}_Shorts", shorts)
    m_socks = mat(f"{kind}_Socks", socks)
    m_trim = mat(f"{kind}_Trim", trim)
    m_gloves = mat(f"{kind}_Gloves", gloves or trim)
    for m, p in ((m_shirt, "shirt_color"), (m_shorts, "shorts_color"), (m_socks, "socks_color"),
                 (m_trim, "trim_color"), (m_gloves, "gloves_color")):
        drive(m, ctrl, p)
    m_skin = mat("Skin", SKIN)
    m_hair = mat(f"{kind}_Hair", HAIR)
    m_boot = mat("Boot", BOOT)
    m_dark = mat("Eye", srgb(25, 25, 32))

    # ----- body (fixed pieces) ----------------------------------------------
    body = empty("Body", (0, 0, 0), root)
    torso_w = 0.40 if kp else 0.36
    box("Torso", (torso_w, 0.22, 0.32), (0, 0, 0.60), m_shirt, body, bevel=0.02, taper_bottom=0.86)
    box("ShirtStripe", (torso_w * 1.02, 0.225, 0.045), (0, 0, 0.64), m_trim, body, bevel=0.006)
    box("Collar", (0.15, 0.13, 0.03), (0, -0.02, 0.775), m_trim, body, bevel=0.006)
    box("Shorts", (0.37, 0.24, 0.15), (0, 0, 0.395), m_shorts, body, bevel=0.02)
    box("ShortsBand", (0.375, 0.245, 0.02), (0, 0, 0.455), m_trim, body, bevel=0.004)

    head = empty("Head", (0, 0, 0.80), body)
    blob("Skull", 0.20, (0, 0, 0.19), m_skin, head, scale=(1, 0.98, 1.02))
    # hair: a shell over the crown and back, open at the face
    hair = blob("Hair", 0.212, (0, 0.012, 0.205), m_hair, head, scale=(1, 1, 1.0))
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    kill = [f for f in bm.faces
            if (f.calc_center_median().z < -0.09) or
            (f.calc_center_median().y < -0.05 and f.calc_center_median().z < 0.12)]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.to_mesh(hair.data)
    bm.free()
    for p in hair.data.polygons:
        p.use_smooth = False
    # fringe + short back tuft, chunky like the run sprite
    box("Fringe", (0.27, 0.06, 0.05), (0, -0.135, 0.325), m_hair, head, bevel=0.01)
    for sx in (-1, 1):
        blob(f"Ear{sx}", 0.04, (sx * 0.195, 0.0, 0.16), m_skin, head, scale=(0.5, 0.8, 1), subdiv=1)
        blob(f"Eye{sx}", 0.024, (sx * 0.075, -0.188, 0.19), m_dark, head, scale=(0.8, 0.5, 1.2), subdiv=1)
        box(f"Brow{sx}", (0.075, 0.02, 0.014), (sx * 0.075, -0.19, 0.245), m_hair, head, bevel=0.003)
    blob("Nose", 0.03, (0, -0.2, 0.13), m_skin, head, scale=(0.8, 1, 0.9), subdiv=1)

    # ----- arms ---------------------------------------------------------------
    sleeve_len = 0.25 if kp else 0.11
    for side, sx in (("L", 1), ("R", -1)):
        sh = empty(f"Shoulder_{side}", (sx * (torso_w / 2 + 0.05), 0, 0.73), body)
        # arm hangs down: mesh centre offset below joint
        prism(f"UpperArm_{side}", 0.058, 0.052, sleeve_len, (0, 0, -sleeve_len / 2), m_shirt, sh, sides=6)
        if not kp:
            prism(f"Cuff_{side}", 0.06, 0.06, 0.018, (0, 0, -sleeve_len + 0.01), m_trim, sh, sides=6)
        el = empty(f"Elbow_{side}", (0, 0, -0.14), sh)
        rest = 0.15 if kp else 0.15
        fore_m = m_shirt if kp else m_skin
        fore_top = -0.14 + (0.0 if kp else 0.0)
        # forearm belongs to the elbow joint
        prism(f"Forearm_{side}", 0.05, 0.043, rest, (0, 0, -rest / 2), fore_m, el, sides=6)
        hand_m = m_gloves if kp else m_skin
        hs = 1.5 if kp else 1.0
        blob(f"Hand_{side}", 0.048 * (1.25 if kp else 1), (0, 0, -rest - 0.03), hand_m, el,
             scale=(1, 0.9, 1.0), subdiv=1)
        if kp:
            box(f"GloveCuff_{side}", (0.09, 0.09, 0.03), (0, 0, -rest + 0.005), m_trim, el, bevel=0.006)

    # ----- legs ---------------------------------------------------------------
    for side, sx in (("L", 1), ("R", -1)):
        hip = empty(f"Hip_{side}", (sx * 0.09, 0, 0.36), body)
        prism(f"Thigh_{side}", 0.075, 0.062, 0.16, (0, 0, -0.06), m_skin, hip, sides=6)
        knee = empty(f"Knee_{side}", (0, 0, -0.15), hip)
        prism(f"Sock_{side}", 0.062, 0.05, 0.17, (0, 0, -0.085), m_socks, knee, sides=6)
        prism(f"SockBand_{side}", 0.066, 0.066, 0.025, (0, 0, -0.03), m_trim, knee, sides=6)
        ankle = empty(f"Ankle_{side}", (0, 0, -0.17), knee)
        box(f"Boot_{side}", (0.10, 0.20, 0.07), (0, -0.045, -0.02), m_boot, ankle, bevel=0.015)
        box(f"Sole_{side}", (0.104, 0.205, 0.012), (0, -0.045, -0.06), m_trim, ankle, bevel=0.003)

    # Chest joint: everything above the waist hangs off it, so a run can lean the
    # torso and twist the shoulders without dragging the legs along. Reparented
    # with the parent inverse so nothing moves in the rest pose.
    chest = empty("Chest", (0, 0, 0.42), body)
    inv = Matrix.Translation((0, 0, -0.42))
    for n in ("Torso", "ShirtStripe", "Collar", "Head", "Shoulder_L", "Shoulder_R"):
        o = next(c for c in body.children if c.name.startswith(n) and c.name.rstrip(".0123456789") == n)
        o.parent = chest
        o.matrix_parent_inverse = inv

    return root, ctrl


outfield, c_out = build_player("Outfield", -0.8,
                                shirt=(0.86, 0.13, 0.15, 1), shorts=(0.16, 0.30, 0.78, 1),
                                socks=(0.86, 0.13, 0.15, 1), trim=(0.97, 0.97, 0.97, 1))
keeper, c_kp = build_player("Keeper", 0.8,
                             shirt=(0.98, 0.72, 0.10, 1), shorts=(0.10, 0.10, 0.14, 1),
                             socks=(0.98, 0.72, 0.10, 1), trim=(0.10, 0.10, 0.14, 1),
                             gloves=(0.95, 0.95, 0.95, 1))

# --- floor + light + camera for previews -----------------------------------
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 2.2
sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
link(sun)
scene.world = scene.world or bpy.data.worlds.new("W")
scene.world.use_nodes = True
bg = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs[0].default_value = (0.75, 0.80, 0.85, 1)
bg.inputs[1].default_value = 0.6
scene.view_settings.view_transform = "Standard"
print("built", [o.name for o in scene.objects if o.parent is None])
