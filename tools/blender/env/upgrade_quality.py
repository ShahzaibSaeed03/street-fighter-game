"""Quality pass for Emberfall, Whispering Mire, Crystal Deep.
Replaces floor/wall/hero props so they read on gl_compatibility (no white blobs).
Bakes a cheap Cycles AO into the albedo of the main pieces.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler

ROOT = Path(r"W:\street-fighter-game")
TEX = ROOT / "assets" / "textures" / "env_cc0"
TILE = 2.0


def log(m):
    print(m, flush=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras):
        for b in list(coll):
            try:
                coll.remove(b)
            except Exception:
                pass


def load_img(path: Path, non_color=False):
    img = bpy.data.images.load(str(path), check_existing=True)
    img.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return img


def pbr(name, folder: Path, scale=1.4, tint=(1, 1, 1, 1)):
    diffs = list(folder.glob("*Diffuse*.jpg"))
    nors = list(folder.glob("*nor*.jpg"))
    roughs = list(folder.glob("*Rough*.jpg"))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (scale, scale, scale)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])  # world/object space, less obvious tiling
    if diffs:
        d = nt.nodes.new("ShaderNodeTexImage")
        d.image = load_img(diffs[0], False)
        nt.links.new(mp.outputs["Vector"], d.inputs["Vector"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 0.35
        mix.inputs["B"].default_value = tint
        nt.links.new(d.outputs["Color"], mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    if nors:
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = load_img(nors[0], True)
        nt.links.new(mp.outputs["Vector"], n.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.7
        nt.links.new(n.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if roughs and "Roughness" in bsdf.inputs:
        r = nt.nodes.new("ShaderNodeTexImage")
        r.image = load_img(roughs[0], True)
        nt.links.new(mp.outputs["Vector"], r.inputs["Vector"])
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])
    return m


def flat(name, color, rough=0.55, emission=None, strength=0.0, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = list(color) + ([1] if len(color) == 3 else [])
    b.inputs["Base Color"].default_value = tuple(c[:4])
    b.inputs["Roughness"].default_value = rough
    if "Metallic" in b.inputs:
        b.inputs["Metallic"].default_value = metallic
    if emission and "Emission Color" in b.inputs:
        b.inputs["Emission Color"].default_value = emission
        b.inputs["Emission Strength"].default_value = strength
    return m


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def uv(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=1.1, island_margin=0.03)
    except Exception:
        bpy.ops.uv.unwrap()
    bpy.ops.object.mode_set(mode="OBJECT")


def dirt_ao(obj):
    """Vertex-color AO so crevices stay dark even before the texture bake."""
    mesh = obj.data
    if not mesh.vertex_colors:
        mesh.vertex_colors.new(name="AO")
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="VERTEX_PAINT")
    try:
        bpy.ops.paint.vertex_color_dirt(dirt_angle=math.radians(75), dirt_only=True)
    except Exception:
        pass
    bpy.ops.object.mode_set(mode="OBJECT")


def bake_ao(obj):
    """Multiply a 128px Cycles AO bake into the base-color image if one exists."""
    uv(obj)
    mat = obj.data.materials[0] if obj.data.materials else None
    if mat is None or not mat.use_nodes:
        return
    img = bpy.data.images.new(obj.name + "_AOBake", 128, 128, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    nt = mat.node_tree
    node = nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    node.select = True
    nt.nodes.active = node
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.cycles.device = "CPU"
    try:
        scene.cycles.use_denoising = False
    except Exception:
        pass
    try:
        bpy.ops.object.bake(type="AO")
    except Exception as e:
        log(f"  AO bake skip {obj.name}: {e}")
        nt.nodes.remove(node)
        return
    # Multiply baked AO into the diffuse image pixels (albedo).
    target = None
    for n in nt.nodes:
        if n.type == "TEX_IMAGE" and n != node and n.image and n.image.size[0] > 8:
            if "nor" not in n.image.name.lower() and "rough" not in n.image.name.lower():
                target = n.image
                break
    if target:
        target.pixels  # load
        ao = img.pixels[:]
        px = list(target.pixels)
        # images may differ in size; sample AO coarsely
        aw, ah = img.size
        tw, th = target.size
        for y in range(th):
            for x in range(tw):
                ai = ((y * ah // th) * aw + (x * aw // tw)) * 4
                ti = (y * tw + x) * 4
                a = ao[ai]
                px[ti] *= (0.35 + 0.65 * a)
                px[ti + 1] *= (0.35 + 0.65 * a)
                px[ti + 2] *= (0.35 + 0.65 * a)
        target.pixels = px
        target.pack()
    nt.nodes.remove(node)
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        pass


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def decimate(obj, target):
    obj.data.calc_loop_triangles()
    cur = len(obj.data.loop_triangles)
    if cur <= target:
        return cur
    mod = obj.modifiers.new("Dec", "DECIMATE")
    mod.ratio = max(0.2, target / float(cur))
    bpy.context.view_layer.objects.active = obj
    try:
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except Exception:
        pass
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def export(obj, path: Path):
    for img in bpy.data.images:
        if img.size[0] > 512:
            s = 512 / float(img.size[0])
            try:
                img.scale(512, max(1, int(img.size[1] * s)))
            except Exception:
                pass
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True)


def cube(loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    assign(o, mat)
    return o


def make_floor(mat):
    bpy.ops.mesh.primitive_plane_add(size=TILE, location=(0, 0, 0))
    o = bpy.context.active_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=3)
    bm = bmesh.from_edit_mesh(o.data)
    for v in bm.verts:
        if abs(v.co.x) > 0.7 or abs(v.co.y) > 0.7:
            v.co.z -= 0.03  # worn edge
        else:
            v.co.z += (hash(v.index) % 7) * 0.004
    bmesh.update_edit_mesh(o.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    assign(o, mat)
    dirt_ao(o)
    o.name = "floor_a"
    return o


def make_wall(mat):
    body = cube((0, 0, 1.15), (TILE, 0.38, 2.3), mat)
    base = cube((0, -0.05, 0.18), (TILE * 1.02, 0.5, 0.36), mat)
    top = cube((0, -0.04, 2.4), (TILE * 1.02, 0.48, 0.22), mat)
    o = join([body, base, top], "wall_straight")
    dirt_ao(o)
    return o


def make_lava():
    crust = flat("Crust", (0.07, 0.03, 0.02), 0.85)
    crack = flat("Crack", (0.45, 0.12, 0.02), 0.4, emission=(0.85, 0.32, 0.05, 1), strength=1.6)
    bpy.ops.mesh.primitive_plane_add(size=TILE * 0.92, location=(0, 0, 0.02))
    base = bpy.context.active_object
    assign(base, crust)
    # dark rim
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.06))
    rim = bpy.context.active_object
    rim.scale = (TILE * 0.5, TILE * 0.5, 0.06)
    bpy.ops.object.transform_apply(scale=True)
    assign(rim, crust)
    bpy.ops.mesh.primitive_plane_add(size=TILE * 0.55, location=(0, 0, 0.08))
    hot = bpy.context.active_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=4)
    bpy.ops.object.mode_set(mode="OBJECT")
    assign(hot, crack)
    o = join([base, rim, hot], "lava_plane")
    return o


def make_crystal(color, emission):
    m = flat("Crystal", color, 0.18, emission=emission, strength=1.4, metallic=0.05)
    rock = flat("CBase", (0.18, 0.14, 0.16), 0.7)
    parts = []
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.35, location=(0, 0, 0.12), subdivisions=1)
    base = bpy.context.active_object
    base.scale = (1.3, 1.1, 0.4)
    bpy.ops.object.transform_apply(scale=True)
    assign(base, rock)
    parts.append(base)
    for i, (h, x) in enumerate(((0.85, -0.12), (0.6, 0.16), (0.45, 0.02))):
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.09, depth=h, location=(x, (i - 1) * 0.08, h * 0.5 + 0.1))
        p = bpy.context.active_object
        assign(p, m)
        parts.append(p)
    o = join(parts, "crystal_cluster")
    return o


def make_mushroom():
    stalk = flat("Stalk", (0.45, 0.38, 0.28), 0.65)
    cap = flat("Cap", (0.12, 0.28, 0.18), 0.4, emission=(0.15, 0.55, 0.28, 1), strength=1.2)
    gill = flat("Gill", (0.2, 0.45, 0.22), 0.5, emission=(0.1, 0.4, 0.15, 1), strength=0.6)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.09, depth=0.45, location=(0, 0, 0.22), vertices=8)
    s = bpy.context.active_object
    assign(s, stalk)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, location=(0, 0, 0.48), segments=12, ring_count=8)
    c = bpy.context.active_object
    c.scale = (1.15, 1.15, 0.42)
    bpy.ops.object.transform_apply(scale=True)
    assign(c, cap)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.2, depth=0.04, location=(0, 0, 0.4), vertices=10)
    g = bpy.context.active_object
    assign(g, gill)
    o = join([s, c, g], "glow_mushroom")
    return o


def make_torch():
    wood = flat("TorchWood", (0.2, 0.1, 0.05), 0.7)
    fire = flat("TorchFire", (0.55, 0.18, 0.03), 0.4, emission=(0.9, 0.35, 0.08, 1), strength=1.8)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.7, location=(0, 0, 0.35), vertices=6)
    s = bpy.context.active_object
    assign(s, wood)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.1, location=(0, 0, 0.75), segments=8, ring_count=6)
    f = bpy.context.active_object
    f.scale = (1, 1, 1.3)
    bpy.ops.object.transform_apply(scale=True)
    assign(f, fire)
    return join([s, f], "torch")


def make_crate(mat):
    return cube((0, 0, 0.28), (0.7, 0.55, 0.55), mat)


def make_barrel(mat):
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=0.7, location=(0, 0, 0.35), vertices=10)
    o = bpy.context.active_object
    assign(o, mat)
    o.name = "barrel"
    return o


def make_skull():
    m = flat("Skull", (0.75, 0.7, 0.6), 0.5)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.16, location=(0, 0, 0.16), segments=8, ring_count=6)
    o = bpy.context.active_object
    assign(o, m)
    o.name = "skull"
    return o


def make_banner(color):
    cloth = flat("Banner", color, 0.6)
    pole = flat("Pole", (0.15, 0.12, 0.1), 0.5, metallic=0.4)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.6, location=(0, 0, 0.8), vertices=6)
    p = bpy.context.active_object
    assign(p, pole)
    bpy.ops.mesh.primitive_plane_add(size=0.7, location=(0.28, 0, 1.15))
    c = bpy.context.active_object
    c.scale = (0.7, 1, 1.1)
    bpy.ops.object.transform_apply(scale=True)
    assign(c, cloth)
    return join([p, c], "banner")


def make_chain():
    m = flat("Chain", (0.25, 0.25, 0.27), 0.35, metallic=0.85)
    parts = []
    for i in range(5):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.06, minor_radius=0.015, major_segments=8, minor_segments=4, location=(0, 0, 1.5 - i * 0.14))
        p = bpy.context.active_object
        p.rotation_euler = Euler((0, 0, (i % 2) * 0.8), "XYZ")
        assign(p, m)
        parts.append(p)
    return join(parts, "chains")


def finish(obj, path, bake=False, target=120):
    tris = decimate(obj, target)
    if bake:
        bake_ao(obj)
    export(obj, path)
    log(f"  {path.name} tris={tris}")


def upgrade(world, tex_folder, tint, hero_fn, banner_col):
    out = ROOT / "assets" / "models" / "env" / world
    log(f"==== upgrade {world} ====")
    clear()
    mat = pbr("Floor", tex_folder, 1.6, tint)
    finish(make_floor(mat), out / "floor_a.glb", bake=True, target=48)
    clear()
    mat = pbr("Wall", tex_folder, 1.3, tint)
    finish(make_wall(mat), out / "wall_straight.glb", bake=True, target=96)
    clear()
    finish(hero_fn(), out / hero_fn.__name__.replace("make_", "") + ".glb" if False else out / {
        "emberfall": "lava_plane.glb",
        "whispering_mire": "glow_mushroom.glb",
        "crystal_deep": "crystal_cluster.glb",
    }[world], bake=False)
    # shared dressing
    clear()
    c = make_crate(flat("Wood", (0.28, 0.16, 0.08), 0.7)); c.name = "crate"; finish(c, out / "crate.glb")
    clear(); finish(make_barrel(flat("Wood2", (0.32, 0.18, 0.09), 0.65)), out / "barrel.glb")
    clear(); finish(make_torch(), out / "torch.glb")
    clear(); finish(make_skull(), out / "skull.glb")
    clear(); finish(make_banner(banner_col), out / "banner.glb")
    clear(); finish(make_chain(), out / "chains.glb")


def main():
    upgrade(
        "emberfall",
        TEX / "polyhaven_w1_emberfall" / "volcanic_rock_tiles",
        (0.85, 0.55, 0.4, 1),
        make_lava,
        (0.45, 0.08, 0.06, 1),
    )
    upgrade(
        "whispering_mire",
        TEX / "polyhaven_w2_whispering_mire" / "brown_mud_leaves_01",
        (0.7, 0.85, 0.65, 1),
        make_mushroom,
        (0.15, 0.35, 0.22, 1),
    )
    upgrade(
        "crystal_deep",
        TEX / "polyhaven_w3_crystal_deep" / "rock_05",
        (0.75, 0.7, 0.9, 1),
        lambda: make_crystal((0.28, 0.16, 0.45), (0.45, 0.25, 0.85, 1)),
        (0.25, 0.15, 0.45, 1),
    )
    log("QUALITY UPGRADE DONE")


if __name__ == "__main__":
    main()
