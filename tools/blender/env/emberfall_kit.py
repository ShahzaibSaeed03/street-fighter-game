"""Build Emberfall (World 1) modular kit with Poly Haven volcanic PBR.
Imports Kenney dungeon/cave templates for scale reference, replaces materials,
adds custom lava/brazier/rubble/bones, exports GLBs + preview_kit.png.

Run: blender --background --python tools/blender/env/emberfall_kit.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"W:\street-fighter-game")
DUNGEON = ROOT / "assets" / "models" / "env_cc0" / "kenney_modular-dungeon-kit_1.0" / "Models" / "GLB format"
CAVE = ROOT / "assets" / "models" / "env_cc0" / "kenney_modular-cave-kit_1.0" / "Models" / "GLB format"
TEX = ROOT / "assets" / "textures" / "env_cc0" / "polyhaven_w1_emberfall"
OUT = ROOT / "assets" / "models" / "env" / "emberfall"
TILE = 2.0  # meters


def log(m): print(m, flush=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for b in list(coll):
            try: coll.remove(b)
            except Exception: pass


def load_img(path: Path):
    img = bpy.data.images.load(str(path))
    img.colorspace_settings.name = "sRGB" if "Diffuse" in path.name or "diff" in path.name.lower() else "Non-Color"
    if "Diffuse" not in path.name and "diff" not in path.name.lower():
        img.colorspace_settings.name = "Non-Color"
    if "Diffuse" in path.name:
        img.colorspace_settings.name = "sRGB"
    return img


def pbr_mat(name: str, folder: str, scale: float = 1.0, emission=None, emission_strength=0.0):
    base = TEX / folder
    diffs = list(base.glob("*Diffuse*.jpg")) + list(base.glob("*diffuse*.jpg"))
    nors = list(base.glob("*nor*.jpg"))
    roughs = list(base.glob("*Rough*.jpg")) + list(base.glob("*rough*.jpg"))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

    def img_node(path, non_color=False):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = load_img(path)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        nt.links.new(mapping.outputs["Vector"], n.inputs["Vector"])
        return n

    if diffs:
        d = img_node(diffs[0], False)
        nt.links.new(d.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (0.25, 0.12, 0.08, 1)
    if nors:
        n = img_node(nors[0], True)
        normal = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(n.outputs["Color"], normal.inputs["Color"])
        nt.links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if roughs:
        r = img_node(roughs[0], True)
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Roughness"].default_value = 0.75
    if emission is not None and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def simple_mat(name, color, roughness=0.6, emission=None, strength=0.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    c = list(color)
    if len(c) == 3:
        c.append(1.0)
    bsdf.inputs["Base Color"].default_value = tuple(c)
    bsdf.inputs["Roughness"].default_value = roughness
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if emission and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def apply_mat(obj, mat):
    if obj.type != "MESH":
        return
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def bevel(obj, width=0.02, segments=2):
    if obj.type != "MESH":
        return
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        pass


def displace_noise(obj, strength=0.015):
    if obj.type != "MESH":
        return
    bpy.context.view_layer.objects.active = obj
    tex = bpy.data.textures.new(f"Noise_{obj.name}", "CLOUDS")
    tex.noise_scale = 0.7
    mod = obj.modifiers.new("Disp", "DISPLACE")
    mod.texture = tex
    mod.strength = strength
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        pass


def decimate(obj, target=1400):
    if obj.type != "MESH":
        return
    obj.data.calc_loop_triangles()
    cur = len(obj.data.loop_triangles)
    if cur <= target:
        return
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Dec", "DECIMATE")
    mod.ratio = max(0.15, target / float(cur))
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        pass


def smart_uv(obj):
    if obj.type != "MESH":
        return
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    except Exception:
        bpy.ops.uv.unwrap(margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")


def resize_images(max_dim=512):
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}:
            continue
        w, h = img.size
        if w <= 0 or max(w, h) <= max_dim:
            continue
        s = max_dim / float(max(w, h))
        try:
            img.scale(max(1, int(w * s)), max(1, int(h * s)))
        except Exception:
            pass


def export_glb(obj_or_list, path: Path):
    resize_images(512)
    bpy.ops.object.select_all(action="DESELECT")
    objs = obj_or_list if isinstance(obj_or_list, (list, tuple)) else [obj_or_list]
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=True, export_animations=False,
    )


def make_floor(name, mat, detail=0):
    bpy.ops.mesh.primitive_plane_add(size=TILE, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    if detail:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.subdivide(number_cuts=2 + detail)
        bpy.ops.object.mode_set(mode="OBJECT")
        displace_noise(o, 0.02 + detail * 0.01)
    apply_mat(o, mat)
    smart_uv(o)
    bevel(o, 0.01, 1)
    decimate(o, 900)
    return o


def make_wall(name, mat, length=TILE, height=2.4, thickness=0.35):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, height * 0.5))
    o = bpy.context.active_object
    o.name = name
    o.scale = (length, thickness, height)
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=2)
    bpy.ops.object.mode_set(mode="OBJECT")
    displace_noise(o, 0.025)
    apply_mat(o, mat)
    smart_uv(o)
    bevel(o, 0.03, 2)
    decimate(o, 1200)
    return o


def make_wall_corner(mat):
    a = make_wall("tmpA", mat, TILE, 2.4, 0.35)
    b = make_wall("tmpB", mat, TILE, 2.4, 0.35)
    b.rotation_euler = Euler((0, 0, math.radians(90)), "XYZ")
    b.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    a.name = "wall_corner"
    decimate(a, 1400)
    return a


def make_pillar(mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=2.5, location=(0, 0, 1.25), vertices=12)
    o = bpy.context.active_object
    o.name = "pillar"
    apply_mat(o, mat)
    smart_uv(o)
    bevel(o, 0.02, 2)
    # cracked capital
    bpy.ops.mesh.primitive_cube_add(size=0.7, location=(0, 0, 2.45))
    cap = bpy.context.active_object
    cap.scale = (1, 1, 0.25)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(cap, mat)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True); cap.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.join()
    o.name = "pillar"
    decimate(o, 1000)
    return o


def make_door_frame(mat):
    # U shape
    parts = []
    for loc, sc in (
        ((-0.7, 0, 1.2), (0.25, 0.4, 2.4)),
        ((0.7, 0, 1.2), (0.25, 0.4, 2.4)),
        ((0, 0, 2.5), (1.65, 0.4, 0.3)),
    ):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        p = bpy.context.active_object
        p.scale = sc
        bpy.ops.object.transform_apply(scale=True)
        apply_mat(p, mat)
        parts.append(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "door_frame"
    smart_uv(parts[0])
    decimate(parts[0], 800)
    return parts[0]


def make_door(wood_mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 1.1))
    o = bpy.context.active_object
    o.name = "door"
    o.scale = (1.2, 0.12, 2.2)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(o, wood_mat)
    smart_uv(o)
    bevel(o, 0.015, 1)
    decimate(o, 600)
    return o


def make_stairs(mat):
    parts = []
    for i in range(5):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -i * 0.35, i * 0.28 + 0.14))
        s = bpy.context.active_object
        s.scale = (TILE * 0.9, 0.35, 0.28)
        bpy.ops.object.transform_apply(scale=True)
        apply_mat(s, mat)
        parts.append(s)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "stairs"
    smart_uv(parts[0])
    decimate(parts[0], 1200)
    return parts[0]


def make_ceiling(mat):
    bpy.ops.mesh.primitive_plane_add(size=TILE, location=(0, 0, 2.6))
    o = bpy.context.active_object
    o.name = "ceiling"
    o.rotation_euler = Euler((math.pi, 0, 0), "XYZ")
    apply_mat(o, mat)
    smart_uv(o)
    decimate(o, 200)
    return o


def make_arch(mat):
    # simple arch from scaled torus chunk + pillars
    left = make_wall("archL", mat, 0.35, 2.0, 0.35)
    left.location = (-0.9, 0, 0)
    right = make_wall("archR", mat, 0.35, 2.0, 0.35)
    right.location = (0.9, 0, 0)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 2.15))
    top = bpy.context.active_object
    top.scale = (2.2, 0.35, 0.35)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(top, mat)
    bpy.ops.object.select_all(action="DESELECT")
    for o in (left, right, top):
        o.select_set(True)
    bpy.context.view_layer.objects.active = left
    bpy.ops.object.join()
    left.name = "arch"
    decimate(left, 1100)
    return left


def make_lava():
    mat = simple_mat("Lava", (0.55, 0.08, 0.01), 0.45, emission=(1.0, 0.22, 0.04, 1), strength=12.0)
    bpy.ops.mesh.primitive_plane_add(size=TILE * 0.95, location=(0, 0, 0.05))
    o = bpy.context.active_object
    o.name = "lava_plane"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=3)
    bpy.ops.object.mode_set(mode="OBJECT")
    displace_noise(o, 0.04)
    apply_mat(o, mat)
    smart_uv(o)
    decimate(o, 800)
    return o


def make_brazier():
    metal = simple_mat("BrazierMetal", (0.15, 0.12, 0.1), 0.45, metallic=0.7)
    fire = simple_mat("BrazierFire", (0.9, 0.25, 0.02), 0.35, emission=(1.0, 0.28, 0.04, 1), strength=14.0)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.7, location=(0, 0, 0.35), vertices=10)
    bowl = bpy.context.active_object
    apply_mat(bowl, metal)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 0.85), segments=10, ring_count=8)
    flame = bpy.context.active_object
    flame.scale = (1, 1, 1.4)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(flame, fire)
    bpy.ops.object.select_all(action="DESELECT")
    bowl.select_set(True); flame.select_set(True)
    bpy.context.view_layer.objects.active = bowl
    bpy.ops.object.join()
    bowl.name = "brazier"
    decimate(bowl, 900)
    return bowl


def make_rubble(mat):
    parts = []
    for i, (loc, sc) in enumerate([
        ((0, 0, 0.2), (0.8, 0.6, 0.4)),
        ((0.35, 0.1, 0.35), (0.4, 0.35, 0.45)),
        ((-0.3, -0.15, 0.25), (0.45, 0.4, 0.3)),
    ]):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        p = bpy.context.active_object
        p.scale = sc
        p.rotation_euler = Euler((0.2 * i, 0.1, 0.4 * i), "XYZ")
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        displace_noise(p, 0.05)
        apply_mat(p, mat)
        parts.append(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "rubble"
    smart_uv(parts[0])
    decimate(parts[0], 1000)
    return parts[0]


def make_bones():
    bone = simple_mat("Bone", (0.85, 0.8, 0.7), 0.55)
    parts = []
    for i in range(4):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.55, location=(i * 0.12 - 0.2, (i % 2) * 0.1, 0.08), vertices=6)
        p = bpy.context.active_object
        p.rotation_euler = Euler((1.2, 0.3 * i, 0.5 * i), "XYZ")
        bpy.ops.object.transform_apply(rotation=True)
        apply_mat(p, bone)
        parts.append(p)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(0.1, 0, 0.15), segments=8, ring_count=6)
    skull = bpy.context.active_object
    apply_mat(skull, bone)
    parts.append(skull)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "bone_pile"
    decimate(parts[0], 700)
    return parts[0]


def make_broken_statue(mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.25, depth=1.4, location=(0, 0, 0.7), vertices=10)
    body = bpy.context.active_object
    apply_mat(body, mat)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0.15, 0, 1.55), segments=8, ring_count=6)
    head = bpy.context.active_object  # toppled
    apply_mat(head, mat)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True); head.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "cracked_statue"
    displace_noise(body, 0.03)
    decimate(body, 900)
    return body


def make_gate(mat):
    return make_door_frame(mat)  # reuse; rename
    # overwritten below


def import_kenney_retarget(src: Path, name: str, mat, scale: float):
    """Import a Kenney piece, uniform-scale, replace materials, decimate."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(src))
    new = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in new if o.type == "MESH"]
    if not meshes:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(o, mat)
    smart_uv(o)
    bevel(o, 0.015, 1)
    displace_noise(o, 0.012)
    decimate(o, 1500)
    # delete empties leftover
    for x in list(bpy.data.objects):
        if x != o and x in new:
            try: bpy.data.objects.remove(x, do_unlink=True)
            except Exception: pass
    return o


def render_preview(path: Path, objs):
    # place pieces in a grid for kit preview
    clear_scene()
    # re-import exported glbs for preview
    cols = 5
    i = 0
    for glb in sorted(OUT.glob("*.glb")):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(glb))
        new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        if not new:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for o in new:
            o.select_set(True)
        bpy.context.view_layer.objects.active = new[0]
        if len(new) > 1:
            bpy.ops.object.join()
        o = bpy.context.active_object
        ox = (i % cols) * 3.2 - 6.0
        oy = (i // cols) * 3.2 - 4.0
        o.location = (ox, oy, 0)
        i += 1

    # lights + camera
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 500
    key.data.size = 4
    key.location = (4, -6, 8)
    bpy.context.collection.objects.link(key)
    world = bpy.context.scene.world or bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.08, 0.04, 0.03, 1)
    bg.inputs[1].default_value = 0.4

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (0, -14, 10)
    cam.rotation_euler = Euler((math.radians(50), 0, 0), "XYZ")
    sc = bpy.context.scene
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception: sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.film_transparent = False
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    log(f"preview -> {path}")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pieces = {}

    log("Building floors…")
    clear_scene()
    pieces["floor_a"] = make_floor("floor_a", pbr_mat("EF_Floor", "volcanic_rock_tiles", scale=2.0), 0)
    export_glb(pieces["floor_a"], OUT / "floor_a.glb")

    clear_scene()
    pieces["floor_b"] = make_floor("floor_b", pbr_mat("EF_Floor", "volcanic_rock_tiles", scale=2.2), 1)
    export_glb(pieces["floor_b"], OUT / "floor_b.glb")

    clear_scene()
    pieces["floor_c"] = make_floor("floor_c", pbr_mat("EF_FloorB", "rock_boulder_cracked", scale=1.8), 2)
    export_glb(pieces["floor_c"], OUT / "floor_c.glb")

    log("Building walls…")
    clear_scene()
    export_glb(make_wall("wall_straight", pbr_mat("EF_Wall", "volcanic_herringbone_01", scale=1.5)), OUT / "wall_straight.glb")

    clear_scene()
    export_glb(make_wall_corner(pbr_mat("EF_Wall", "volcanic_herringbone_01", scale=1.5)), OUT / "wall_corner.glb")

    clear_scene()
    export_glb(make_wall("wall_end", pbr_mat("EF_Wall", "volcanic_herringbone_01", scale=1.5), TILE * 0.5), OUT / "wall_end.glb")

    clear_scene()
    mat_wall = pbr_mat("EF_Wall", "volcanic_herringbone_01", scale=1.5)
    # T junction: straight + stub
    a = make_wall("tA", mat_wall)
    b = make_wall("tB", mat_wall, TILE * 0.5)
    b.rotation_euler = Euler((0, 0, math.radians(90)), "XYZ")
    b.location = (0, TILE * 0.25, 0)
    bpy.ops.object.select_all(action="DESELECT")
    a.select_set(True); b.select_set(True)
    bpy.context.view_layer.objects.active = a
    bpy.ops.object.join()
    a.name = "wall_t"
    export_glb(a, OUT / "wall_t.glb")

    log("Building structure…")
    for builder, fname, setup in [
        (lambda: make_door_frame(pbr_mat("EF_Wall", "volcanic_herringbone_01", 1.5)), "door_frame.glb", None),
        (lambda: make_door(simple_mat("EF_Wood", (0.22, 0.12, 0.07), 0.7)), "door.glb", None),
        (lambda: make_arch(pbr_mat("EF_Wall", "volcanic_herringbone_01", 1.5)), "arch.glb", None),
        (lambda: make_pillar(pbr_mat("EF_Rock", "rock_boulder_cracked", 1.2)), "pillar.glb", None),
        (lambda: make_stairs(pbr_mat("EF_Floor", "volcanic_rock_tiles", 2.0)), "stairs.glb", None),
        (lambda: make_ceiling(pbr_mat("EF_Wall", "volcanic_herringbone_01", 1.2)), "ceiling.glb", None),
        (make_lava, "lava_plane.glb", None),
        (make_brazier, "brazier.glb", None),
        (lambda: make_rubble(pbr_mat("EF_Rock", "rock_boulder_cracked", 1.0)), "rubble.glb", None),
        (make_bones, "bone_pile.glb", None),
        (lambda: make_broken_statue(pbr_mat("EF_Rock", "rock_boulder_cracked", 1.0)), "cracked_statue.glb", None),
    ]:
        clear_scene()
        o = builder()
        export_glb(o, OUT / fname)
        log(f"  exported {fname}")

    # Kenney-retargeted extras (scale measured ~1.0 unit pieces → 2m)
    # Audit: Kenney corridor/gate ≈ 4 units wide → scale 0.5 for 2 m tile.
    kenney_bits = [
        (DUNGEON / "gate.glb", "gate.glb", 0.5),
        (DUNGEON / "corridor.glb", "corridor_ref.glb", 0.5),
        (CAVE / "gate-rock.glb", "gate_rock.glb", 0.5),
    ]
    for src, fname, sc in kenney_bits:
        if not src.exists():
            log(f"  skip missing {src}")
            continue
        clear_scene()
        mat = pbr_mat("EF_Kenney", "volcanic_herringbone_01", 1.4)
        o = import_kenney_retarget(src, Path(fname).stem, mat, sc)
        if o:
            export_glb(o, OUT / fname)
            log(f"  kenney→ {fname}")

    # ash heap / chain / cobweb / ember rock
    clear_scene()
    ash = simple_mat("Ash", (0.2, 0.18, 0.16), 0.9)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, location=(0, 0, 0.15), segments=10, ring_count=6)
    o = bpy.context.active_object
    o.scale = (1.2, 1.0, 0.35)
    bpy.ops.object.transform_apply(scale=True)
    apply_mat(o, ash)
    o.name = "ash_heap"
    decimate(o, 500)
    export_glb(o, OUT / "ash_heap.glb")

    clear_scene()
    chain_m = simple_mat("Chain", (0.3, 0.3, 0.32), 0.4, metallic=0.85)
    parts = []
    for i in range(6):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.08, minor_radius=0.02, location=(0, 0, 1.8 - i * 0.18), major_segments=10, minor_segments=6)
        p = bpy.context.active_object
        p.rotation_euler = Euler((0, 0, (i % 2) * 0.8), "XYZ")
        apply_mat(p, chain_m)
        parts.append(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    parts[0].name = "chains"
    decimate(parts[0], 900)
    export_glb(parts[0], OUT / "chains.glb")

    clear_scene()
    rock_m = pbr_mat("EF_EmberRock", "rock_boulder_cracked", 1.0)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, location=(0, 0, 0.4), subdivisions=2)
    o = bpy.context.active_object
    o.name = "ember_rock"
    displace_noise(o, 0.08)
    apply_mat(o, rock_m)
    smart_uv(o)
    decimate(o, 800)
    export_glb(o, OUT / "ember_rock.glb")

    log("Rendering kit preview…")
    render_preview(OUT / "preview_kit.png", None)
    log("EMBERFALL KIT DONE")
    for p in sorted(OUT.glob("*")):
        log(f"  {p.name} {p.stat().st_size/1024:.1f} KB")


if __name__ == "__main__":
    main()
