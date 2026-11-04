"""Second quality pass: one baked floor/wall look per world, low-poly story props.

gl_compatibility budget: floor stays a few tris (detail is in the bake),
props stay under ~120 tris, emission stays under 1.4 so nothing clips to white.
"""
from __future__ import annotations

import math
from pathlib import Path

import bpy
import bmesh

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


def first(folder: Path, token: str):
    hits = list(folder.glob(f"*{token}*.jpg"))
    return hits[0] if hits else None


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
        b.inputs["Emission Color"].default_value = (*emission[:3], 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def cube(loc, scale, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    if mat != None:
        assign(o, mat)
    return o


def apply_tf(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def uv(obj):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    try:
        bpy.ops.uv.smart_project(angle_limit=1.05, island_margin=0.02)
    except Exception:
        bpy.ops.uv.unwrap()
    bpy.ops.object.mode_set(mode="OBJECT")


def paint_edges(obj, dark=(0.25, 0.2, 0.18, 1.0)):
    mesh = obj.data
    if not mesh.color_attributes:
        mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
    bm = bmesh.new()
    bm.from_mesh(mesh)
    layer = bm.verts.layers.float_color.active
    if layer is None:
        bm.free()
        return
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    minz, maxz = min(zs), max(zs)
    dx = max(maxx - minx, 1e-4)
    dy = max(maxy - miny, 1e-4)
    dz = max(maxz - minz, 1e-4)
    for v in bm.verts:
        nx = abs((v.co.x - minx) / dx - 0.5) * 2.0
        ny = abs((v.co.y - miny) / dy - 0.5) * 2.0
        nz = (v.co.z - minz) / dz
        edge = max(nx, ny)
        stain = 0.15 if (v.index * 17) % 5 == 0 else 0.0
        # Keep wear soft. A hard edge on every tile reads as a checkerboard grid.
        k = min(1.0, edge * 0.16 + (1.0 - nz) * 0.12 + stain)
        v[layer] = (
            1.0 - k * (1.0 - dark[0]),
            1.0 - k * (1.0 - dark[1]),
            1.0 - k * (1.0 - dark[2]),
            1.0,
        )
    bm.to_mesh(mesh)
    bm.free()


def mixed_material(name, folder_a: Path, folder_b: Path, tint):
    """One material: two tiled albedo maps mixed by noise, then by vertex color."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (2.2, 2.2, 2.2)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.5
    noise.inputs["Detail"].default_value = 6.0
    da = first(folder_a, "Diffuse") or first(folder_a, "diff")
    db = first(folder_b, "Diffuse") or first(folder_b, "diff")
    if da:
        na = nt.nodes.new("ShaderNodeTexImage")
        na.image = load_img(da, False)
        nt.links.new(mp.outputs["Vector"], na.inputs["Vector"])
        src = na.outputs["Color"]
        if db:
            nb = nt.nodes.new("ShaderNodeTexImage")
            nb.image = load_img(db, False)
            nt.links.new(mp.outputs["Vector"], nb.inputs["Vector"])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MIX"
            nt.links.new(noise.outputs["Fac"], mix.inputs["Factor"])
            nt.links.new(na.outputs["Color"], mix.inputs["A"])
            nt.links.new(nb.outputs["Color"], mix.inputs["B"])
            src = mix.outputs["Result"]
        tint_mix = nt.nodes.new("ShaderNodeMix")
        tint_mix.data_type = "RGBA"
        tint_mix.blend_type = "MULTIPLY"
        tint_mix.inputs["Factor"].default_value = 0.45
        tint_mix.inputs["B"].default_value = tint
        nt.links.new(src, tint_mix.inputs["A"])
        vcol = nt.nodes.new("ShaderNodeVertexColor")
        vcol.layer_name = "Col"
        wear = nt.nodes.new("ShaderNodeMix")
        wear.data_type = "RGBA"
        wear.blend_type = "MULTIPLY"
        wear.inputs["Factor"].default_value = 1.0
        nt.links.new(tint_mix.outputs["Result"], wear.inputs["A"])
        nt.links.new(vcol.outputs["Color"], wear.inputs["B"])
        nt.links.new(wear.outputs["Result"], bsdf.inputs["Base Color"])
    rough = first(folder_a, "Rough")
    if rough and "Roughness" in bsdf.inputs:
        rn = nt.nodes.new("ShaderNodeTexImage")
        rn.image = load_img(rough, True)
        nt.links.new(mp.outputs["Vector"], rn.inputs["Vector"])
        # Wet patches: noise lowers roughness so puddles / slag catch a little light.
        wet = nt.nodes.new("ShaderNodeMath")
        wet.operation = "MULTIPLY"
        nt.links.new(noise.outputs["Fac"], wet.inputs[0])
        wet.inputs[1].default_value = 0.35
        sub = nt.nodes.new("ShaderNodeMath")
        sub.operation = "SUBTRACT"
        nt.links.new(rn.outputs["Color"], sub.inputs[0])
        nt.links.new(wet.outputs["Value"], sub.inputs[1])
        nt.links.new(sub.outputs["Value"], bsdf.inputs["Roughness"])
    nor = first(folder_a, "nor_gl") or first(folder_a, "nor")
    if nor:
        nn = nt.nodes.new("ShaderNodeTexImage")
        nn.image = load_img(nor, True)
        nt.links.new(mp.outputs["Vector"], nn.inputs["Vector"])
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 0.65
        nt.links.new(nn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def _active_image_bake(obj, img, bake_type):
    mat = obj.data.materials[0]
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
    scene.cycles.samples = 4
    scene.cycles.device = "CPU"
    try:
        scene.cycles.use_denoising = False
    except Exception:
        pass
    scene.render.bake.margin = 6
    if bake_type == "DIFFUSE":
        scene.render.bake.use_pass_direct = False
        scene.render.bake.use_pass_indirect = False
        scene.render.bake.use_pass_color = True
    bpy.ops.object.bake(type=bake_type)
    nt.nodes.remove(node)


def bake_and_replace(obj, folder_a: Path):
    """Bake albedo (textures + vertex wear + AO) so Godot gets one cheap map."""
    uv(obj)
    albedo = bpy.data.images.new(obj.name + "_albedo", 512, 512, alpha=False)
    albedo.colorspace_settings.name = "sRGB"
    try:
        _active_image_bake(obj, albedo, "DIFFUSE")
    except Exception as e:
        log(f"  diffuse bake skip {obj.name}: {e}")
        return
    ao = bpy.data.images.new(obj.name + "_ao", 256, 256, alpha=False)
    ao.colorspace_settings.name = "Non-Color"
    try:
        _active_image_bake(obj, ao, "AO")
    except Exception as e:
        log(f"  AO bake skip {obj.name}: {e}")
        ao = None
    if ao is not None:
        ap = list(albedo.pixels)
        op = ao.pixels[:]
        aw, ah = albedo.size
        ow, oh = ao.size
        for y in range(ah):
            for x in range(aw):
                oi = ((y * oh // ah) * ow + (x * ow // aw)) * 4
                ai = (y * aw + x) * 4
                a = 0.42 + 0.58 * op[oi]
                ap[ai] *= a
                ap[ai + 1] *= a
                ap[ai + 2] *= a
        albedo.pixels = ap
    albedo.pack()
    # Replace the heavy node tree with the bake + the original roughness/normal.
    m = bpy.data.materials.new(obj.name + "_baked")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = albedo
    nt.links.new(tc.outputs["UV"], img.inputs["Vector"])
    nt.links.new(img.outputs["Color"], bsdf.inputs["Base Color"])
    rough = first(folder_a, "Rough")
    if rough and "Roughness" in bsdf.inputs:
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (2.0, 2.0, 2.0)
        nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
        rn = nt.nodes.new("ShaderNodeTexImage")
        rn.image = load_img(rough, True)
        nt.links.new(mp.outputs["Vector"], rn.inputs["Vector"])
        nt.links.new(rn.outputs["Color"], bsdf.inputs["Roughness"])
        nor = first(folder_a, "nor_gl") or first(folder_a, "nor")
        if nor:
            nn = nt.nodes.new("ShaderNodeTexImage")
            nn.image = load_img(nor, True)
            nt.links.new(mp.outputs["Vector"], nn.inputs["Vector"])
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nm.inputs["Strength"].default_value = 0.55
            nt.links.new(nn.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    assign(obj, m)
    try:
        bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        pass


def export(obj, path: Path):
    for img in bpy.data.images:
        if img.size[0] > 512:
            s = 512 / float(img.size[0])
            try:
                img.scale(512, max(1, int(img.size[1] * s)))
            except Exception:
                pass
        try:
            if img.packed_file is None and img.filepath:
                img.pack()
        except Exception:
            pass
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format="AUTO",
    )
    obj.data.calc_loop_triangles()
    log(f"  {path.name} tris={len(obj.data.loop_triangles)}")


def make_floor(folder_a, folder_b, tint, stain):
    bpy.ops.mesh.primitive_plane_add(size=TILE, location=(0, 0, 0))
    o = bpy.context.active_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.subdivide(number_cuts=1)
    bm = bmesh.from_edit_mesh(o.data)
    for v in bm.verts:
        if abs(v.co.x) > 0.85 or abs(v.co.y) > 0.85:
            v.co.z -= 0.025
    bmesh.update_edit_mesh(o.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    paint_edges(o, stain)
    assign(o, mixed_material("Floor", folder_a, folder_b, tint))
    o.name = "floor_a"
    bake_and_replace(o, folder_a)
    return o


def make_wall(folder_a, folder_b, tint, stain):
    body = cube((0, 0, 1.15), (TILE, 0.34, 2.2), None)
    base = cube((0, -0.08, 0.16), (TILE * 1.04, 0.5, 0.32), None)
    top = cube((0, -0.06, 2.32), (TILE * 1.04, 0.46, 0.18), None)
    o = join([body, base, top], "wall_straight")
    paint_edges(o, stain)
    assign(o, mixed_material("Wall", folder_a, folder_b, tint))
    bake_and_replace(o, folder_a)
    return o


def make_lava():
    crust = flat("Crust", (0.06, 0.025, 0.02), 0.9)
    parts = []
    bpy.ops.mesh.primitive_plane_add(size=TILE * 0.72, location=(0, 0, 0.04))
    hot = bpy.context.active_object
    assign(hot, crust)
    parts.append(hot)
    for loc, sc in (
        ((0, 0.82, 0.05), (TILE * 0.5, 0.16, 0.08)),
        ((0, -0.82, 0.05), (TILE * 0.5, 0.16, 0.08)),
        ((0.82, 0, 0.05), (0.16, TILE * 0.42, 0.08)),
        ((-0.82, 0, 0.05), (0.16, TILE * 0.42, 0.08)),
    ):
        parts.append(cube(loc, sc, crust))
    return join(parts, "lava_plane")


def make_crystal(name, color, emission):
    rock = flat(name + "Rock", (0.16, 0.13, 0.15), 0.75)
    gem = flat(name + "Gem", color, 0.18, emission=emission, strength=1.05, metallic=0.08)
    parts = []
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.32, location=(0, 0, 0.1), subdivisions=1)
    base = bpy.context.active_object
    base.scale = (1.35, 1.05, 0.38)
    apply_tf(base)
    assign(base, rock)
    parts.append(base)
    specs = (
        (0.95, -0.16, 0.02, 0.11),
        (0.7, 0.14, -0.06, 0.09),
        (0.5, 0.0, 0.12, 0.07),
        (0.34, 0.2, 0.08, 0.05),
        (0.22, -0.22, -0.02, 0.045),
    )
    for h, x, y, r in specs:
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=r, depth=h, location=(x, y, h * 0.45 + 0.12))
        p = bpy.context.active_object
        p.rotation_euler[0] = (x + y) * 0.4
        apply_tf(p)
        assign(p, gem)
        parts.append(p)
    return join(parts, name)


def make_mushroom():
    stalk_m = flat("Stalk", (0.42, 0.34, 0.24), 0.7)
    cap_m = flat("Cap", (0.1, 0.32, 0.2), 0.35, emission=(0.12, 0.42, 0.22, 1), strength=0.85)
    spot_m = flat("Spot", (0.55, 0.85, 0.45), 0.3, emission=(0.35, 0.7, 0.4, 1), strength=0.5)
    parts = []
    specs = ((1.0, 0.0, 0.0), (0.62, 0.28, 0.12), (0.48, -0.26, 0.08))
    for s, x, y in specs:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07 * s, depth=0.42 * s, vertices=6, location=(x, y, 0.21 * s))
        st = bpy.context.active_object
        assign(st, stalk_m)
        parts.append(st)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.26 * s, depth=0.16 * s, location=(x, y, 0.42 * s))
        cap = bpy.context.active_object
        assign(cap, cap_m)
        parts.append(cap)
        # Gills: a thin disc under the cap.
        bpy.ops.mesh.primitive_cylinder_add(radius=0.18 * s, depth=0.03 * s, vertices=8, location=(x, y, 0.35 * s))
        g = bpy.context.active_object
        assign(g, stalk_m)
        parts.append(g)
        for i in range(3):
            ang = i * 2.1
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.045 * s, location=(x + math.cos(ang) * 0.12 * s, y + math.sin(ang) * 0.1 * s, 0.48 * s), segments=6, ring_count=4)
            sp = bpy.context.active_object
            assign(sp, spot_m)
            parts.append(sp)
    return join(parts, "glow_mushroom")


def make_torch():
    wood = flat("TorchWood", (0.22, 0.1, 0.05), 0.7)
    fire = flat("TorchFire", (0.55, 0.16, 0.03), 0.4, emission=(0.85, 0.32, 0.06, 1), strength=1.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.7, location=(0, 0, 0.35), vertices=6)
    s = bpy.context.active_object
    assign(s, wood)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.09, depth=0.22, location=(0, 0, 0.78))
    f = bpy.context.active_object
    assign(f, fire)
    return join([s, f], "torch")


def make_crate():
    wood = flat("Wood", (0.3, 0.17, 0.08), 0.72)
    band = flat("Band", (0.15, 0.12, 0.1), 0.4, metallic=0.6)
    box = cube((0, 0, 0.28), (0.62, 0.5, 0.5), wood)
    b1 = cube((0, 0, 0.42), (0.66, 0.54, 0.06), band)
    b2 = cube((0, 0, 0.16), (0.66, 0.54, 0.06), band)
    return join([box, b1, b2], "crate")


def make_barrel():
    wood = flat("WoodB", (0.34, 0.2, 0.1), 0.6)
    band = flat("BandB", (0.2, 0.16, 0.12), 0.35, metallic=0.7)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.26, depth=0.62, location=(0, 0, 0.32), vertices=8)
    body = bpy.context.active_object
    assign(body, wood)
    rings = [body]
    for z in (0.18, 0.46):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.275, depth=0.05, location=(0, 0, z), vertices=8)
        r = bpy.context.active_object
        assign(r, band)
        rings.append(r)
    return join(rings, "barrel")


def make_skull():
    bone = flat("Bone", (0.78, 0.74, 0.64), 0.45)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.14, location=(0, 0, 0.16), segments=8, ring_count=5)
    head = bpy.context.active_object
    head.scale = (1.05, 0.85, 0.9)
    apply_tf(head)
    assign(head, bone)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.02, 0.05))
    jaw = bpy.context.active_object
    jaw.scale = (0.16, 0.1, 0.06)
    apply_tf(jaw)
    assign(jaw, bone)
    return join([head, jaw], "skull")


def make_banner(color):
    cloth = flat("Banner", color, 0.65)
    pole = flat("Pole", (0.12, 0.1, 0.08), 0.45, metallic=0.45)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=1.7, location=(0, 0, 0.85), vertices=5)
    p = bpy.context.active_object
    assign(p, pole)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0.32, 0, 1.2))
    c = bpy.context.active_object
    c.scale = (0.55, 0.02, 0.7)
    apply_tf(c)
    assign(c, cloth)
    return join([p, c], "banner")


def make_chain():
    m = flat("Chain", (0.22, 0.2, 0.18), 0.28, metallic=0.9)
    parts = []
    for i in range(4):
        bpy.ops.mesh.primitive_torus_add(
            major_radius=0.055, minor_radius=0.012,
            major_segments=6, minor_segments=3,
            location=(0, 0, 1.35 - i * 0.16),
        )
        p = bpy.context.active_object
        p.rotation_euler[1] = (i % 2) * 1.2
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "chains")


def make_rubble():
    m = flat("Rubble", (0.22, 0.16, 0.13), 0.85)
    parts = []
    for loc, sc in (((0, 0, 0.1), (0.45, 0.3, 0.18)), ((0.22, 0.12, 0.08), (0.22, 0.18, 0.12)), ((-0.16, 0.08, 0.06), (0.2, 0.16, 0.1))):
        parts.append(cube(loc, sc, m))
    return join(parts, "rubble")


def make_bones():
    m = flat("Bones", (0.75, 0.7, 0.6), 0.5)
    parts = []
    for i in range(4):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.32, vertices=5, location=(i * 0.08 - 0.12, 0, 0.04))
        p = bpy.context.active_object
        p.rotation_euler[1] = 1.2
        p.rotation_euler[2] = i * 0.4
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "bone_pile")


def make_weapon_rack():
    wood = flat("Rack", (0.24, 0.12, 0.06), 0.65)
    iron = flat("Blade", (0.35, 0.35, 0.38), 0.25, metallic=0.8)
    posts = []
    for x in (-0.28, 0.28):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.035, depth=0.9, vertices=5, location=(x, 0, 0.45))
        p = bpy.context.active_object
        assign(p, wood)
        posts.append(p)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.62, vertices=5, location=(0, 0, 0.72))
    bar = bpy.context.active_object
    bar.rotation_euler[1] = math.pi / 2
    apply_tf(bar)
    assign(bar, wood)
    posts.append(bar)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0.02, 0.55))
    blade = bpy.context.active_object
    blade.scale = (0.08, 0.02, 0.28)
    apply_tf(blade)
    assign(blade, iron)
    posts.append(blade)
    return join(posts, "weapon_rack")


def make_blood():
    m = flat("Blood", (0.28, 0.02, 0.02), 0.25)
    bpy.ops.mesh.primitive_plane_add(size=0.7, location=(0, 0, 0.02))
    o = bpy.context.active_object
    o.scale = (1.1, 0.7, 1)
    apply_tf(o)
    assign(o, m)
    o.name = "blood_decal"
    return o


def make_buttress():
    m = flat("Buttress", (0.2, 0.16, 0.14), 0.8)
    a = cube((0, 0, 0.7), (0.28, 0.36, 1.4), m)
    b = cube((0, -0.12, 0.35), (0.36, 0.5, 0.4), m)
    return join([a, b], "buttress")


def make_alcove():
    m = flat("Alcove", (0.08, 0.06, 0.05), 0.9)
    frame = flat("AlcoveFrame", (0.24, 0.18, 0.15), 0.75)
    back = cube((0, 0.05, 0.7), (0.7, 0.12, 1.1), m)
    lip = cube((0, -0.08, 0.2), (0.85, 0.2, 0.18), frame)
    return join([back, lip], "alcove")


def make_pillar():
    m = flat("Pillar", (0.28, 0.22, 0.18), 0.7)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=1.3, vertices=6, location=(0, 0, 0.55))
    body = bpy.context.active_object
    assign(body, m)
    cap = cube((0.05, 0, 1.15), (0.35, 0.3, 0.16), m)
    return join([body, cap], "pillar")


def make_beam():
    m = flat("Beam", (0.18, 0.1, 0.06), 0.7)
    return cube((0, 0, 0), (1.8, 0.14, 0.1), m)


def make_log():
    m = flat("Log", (0.28, 0.16, 0.08), 0.8)
    moss = flat("LogMoss", (0.15, 0.28, 0.12), 0.6)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=1.1, vertices=6, location=(0, 0, 0.16))
    body = bpy.context.active_object
    body.rotation_euler[1] = math.pi / 2
    apply_tf(body)
    assign(body, m)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0.1, 0, 0.22))
    patch = bpy.context.active_object
    patch.scale = (0.35, 0.2, 0.06)
    apply_tf(patch)
    assign(patch, moss)
    return join([body, patch], "log")


def make_reeds():
    m = flat("Reed", (0.2, 0.35, 0.16), 0.55)
    parts = []
    for i in range(5):
        bpy.ops.mesh.primitive_plane_add(size=0.5, location=((i - 2) * 0.08, 0, 0.28))
        p = bpy.context.active_object
        p.scale = (0.08, 1, 1.1)
        p.rotation_euler[1] = (i - 2) * 0.15
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "reeds")


def make_grave():
    stone = flat("Grave", (0.3, 0.32, 0.3), 0.65)
    slab = cube((0, 0, 0.45), (0.5, 0.12, 0.7), stone)
    base = cube((0, 0, 0.08), (0.7, 0.28, 0.16), stone)
    return join([slab, base], "grave")


def make_roots():
    m = flat("Root", (0.22, 0.14, 0.08), 0.85)
    parts = []
    for i, ang in enumerate((-0.6, 0.1, 0.7)):
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.8, vertices=5, location=(i * 0.1 - 0.1, 0, 0.15))
        p = bpy.context.active_object
        p.rotation_euler[1] = 1.1
        p.rotation_euler[2] = ang
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "roots")


def make_cobweb():
    m = flat("Web", (0.75, 0.75, 0.7), 0.4)
    a = cube((0, 0, 0), (0.7, 0.01, 0.7), m)
    b = cube((0, 0, 0), (0.01, 0.7, 0.7), m)
    o = join([a, b], "cobweb")
    return o


def make_puddle():
    m = flat("Puddle", (0.05, 0.12, 0.1), 0.08, metallic=0.0)
    bpy.ops.mesh.primitive_plane_add(size=0.9, location=(0, 0, 0.015))
    o = bpy.context.active_object
    o.scale = (1.2, 0.8, 1)
    apply_tf(o)
    assign(o, m)
    o.name = "puddle"
    return o


def make_cage():
    iron = flat("Cage", (0.28, 0.18, 0.1), 0.35, metallic=0.75)
    parts = []
    for x in (-0.22, 0.22):
        for y in (-0.22, 0.22):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.9, vertices=4, location=(x, y, 0.45))
            p = bpy.context.active_object
            assign(p, iron)
            parts.append(p)
    parts.append(cube((0, 0, 0.9), (0.5, 0.5, 0.04), iron))
    parts.append(cube((0, 0, 0.05), (0.5, 0.5, 0.04), iron))
    return join(parts, "cage")


def make_moss():
    m = flat("Moss", (0.12, 0.28, 0.14), 0.6, emission=(0.05, 0.2, 0.08, 1), strength=0.25)
    parts = []
    for i in range(4):
        bpy.ops.mesh.primitive_plane_add(size=0.35, location=((i - 1.5) * 0.08, 0, -0.2 * i))
        p = bpy.context.active_object
        p.scale = (0.5, 1, 1.4)
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "hanging_moss")


def make_tree():
    bark = flat("Bark", (0.2, 0.12, 0.07), 0.85)
    leaf = flat("Leaf", (0.1, 0.22, 0.1), 0.6)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=1.4, vertices=6, location=(0, 0, 0.7))
    trunk = bpy.context.active_object
    assign(trunk, bark)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.55, location=(0, 0, 1.7), subdivisions=1)
    top = bpy.context.active_object
    top.scale = (1.1, 1.1, 0.7)
    apply_tf(top)
    assign(top, leaf)
    return join([trunk, top], "swamp_tree")


def make_cauldron():
    iron = flat("Cauldron", (0.16, 0.18, 0.14), 0.3, metallic=0.7)
    brew = flat("Brew", (0.15, 0.45, 0.18), 0.2, emission=(0.2, 0.7, 0.25, 1), strength=0.9)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.38, location=(0, 0, 0.32), segments=10, ring_count=6)
    pot = bpy.context.active_object
    pot.scale = (1.1, 1.1, 0.7)
    apply_tf(pot)
    assign(pot, iron)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.06, vertices=8, location=(0, 0, 0.48))
    soup = bpy.context.active_object
    assign(soup, brew)
    leg = cube((0, 0, 0.08), (0.5, 0.5, 0.08), iron)
    return join([pot, soup, leg], "cauldron")


def make_stalactite():
    m = flat("Stal", (0.35, 0.32, 0.4), 0.55)
    tip = flat("StalTip", (0.45, 0.3, 0.7), 0.25, emission=(0.35, 0.2, 0.65, 1), strength=0.45)
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.16, depth=1.05, location=(0, 0, -0.52))
    p = bpy.context.active_object
    p.rotation_euler[0] = math.pi
    apply_tf(p)
    assign(p, m)
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.05, depth=0.22, location=(0, 0, -1.05))
    t = bpy.context.active_object
    t.rotation_euler[0] = math.pi
    apply_tf(t)
    assign(t, tip)
    return join([p, t], "stalactite")


def make_geode():
    rock = flat("GeodeRock", (0.2, 0.16, 0.22), 0.8)
    gem = flat("GeodeGem", (0.4, 0.75, 0.85), 0.15, emission=(0.3, 0.75, 0.85, 1), strength=0.9)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.4, subdivisions=1, location=(0, 0, 0.28))
    base = bpy.context.active_object
    base.scale = (1.2, 1.0, 0.7)
    apply_tf(base)
    assign(base, rock)
    inner = []
    for i in range(4):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.06, depth=0.22, location=(math.cos(i) * 0.08, math.sin(i) * 0.08, 0.42))
        c = bpy.context.active_object
        assign(c, gem)
        inner.append(c)
    return join([base] + inner, "geode")


def make_rock():
    m = flat("CaveRock", (0.22, 0.2, 0.26), 0.8)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.34, subdivisions=1, location=(0, 0, 0.22))
    o = bpy.context.active_object
    o.scale = (1.3, 1.0, 0.55)
    apply_tf(o)
    assign(o, m)
    o.name = "cave_rock"
    return o


def make_shards():
    m = flat("Shard", (0.55, 0.35, 0.75), 0.2, emission=(0.4, 0.22, 0.7, 1), strength=0.6)
    parts = []
    for i in range(4):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.04, depth=0.16, location=(i * 0.08 - 0.12, (i % 2) * 0.06, 0.06))
        p = bpy.context.active_object
        p.rotation_euler[1] = 0.8 + i * 0.2
        apply_tf(p)
        assign(p, m)
        parts.append(p)
    return join(parts, "shards")


def make_pit():
    rim = flat("PitRim", (0.18, 0.16, 0.2), 0.8)
    hole = flat("PitHole", (0.02, 0.02, 0.03), 0.95)
    ring = []
    for loc, sc in (
        ((0, 0.55, 0.04), (1.3, 0.16, 0.08)),
        ((0, -0.55, 0.04), (1.3, 0.16, 0.08)),
        ((0.55, 0, 0.04), (0.16, 1.0, 0.08)),
        ((-0.55, 0, 0.04), (0.16, 1.0, 0.08)),
    ):
        ring.append(cube(loc, sc, rim))
    bpy.ops.mesh.primitive_plane_add(size=0.9, location=(0, 0, -0.02))
    h = bpy.context.active_object
    assign(h, hole)
    ring.append(h)
    return join(ring, "pit")


def make_stairs():
    m = flat("Step", (0.25, 0.2, 0.18), 0.75)
    parts = []
    for i in range(3):
        parts.append(cube((0, i * 0.28, 0.08 + i * 0.1), (1.1, 0.3, 0.16 + i * 0.08), m))
    return join(parts, "stairs")


def make_brazier():
    iron = flat("Brazier", (0.2, 0.12, 0.08), 0.35, metallic=0.65)
    fire = flat("BrazierFire", (0.6, 0.2, 0.04), 0.4, emission=(0.85, 0.3, 0.05, 1), strength=1.25)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.7, vertices=6, location=(0, 0, 0.35))
    stem = bpy.context.active_object
    assign(stem, iron)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=0.12, vertices=8, location=(0, 0, 0.75))
    bowl = bpy.context.active_object
    assign(bowl, iron)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.1, depth=0.2, location=(0, 0, 0.9))
    flame = bpy.context.active_object
    assign(flame, fire)
    return join([stem, bowl, flame], "brazier")


def ship(obj, folder: Path, filename: str):
    obj.name = Path(filename).stem
    export(obj, folder / filename)


def build_world(world, folder_a, folder_b, tint, stain, heroes):
    out = ROOT / "assets" / "models" / "env" / world
    log(f"==== {world} ====")
    clear()
    ship(make_floor(folder_a, folder_b, tint, stain), out, "floor_a.glb")
    clear()
    ship(make_wall(folder_a, folder_b, tint, stain), out, "wall_straight.glb")
    # Shared low-poly dressing. Materials are created after each clear().
    makers = {
        "crate.glb": make_crate,
        "barrel.glb": make_barrel,
        "torch.glb": make_torch,
        "skull.glb": make_skull,
        "chains.glb": make_chain,
        "rubble.glb": make_rubble,
        "bone_pile.glb": make_bones,
        "weapon_rack.glb": make_weapon_rack,
        "blood_decal.glb": make_blood,
        "buttress.glb": make_buttress,
        "alcove.glb": make_alcove,
        "pillar.glb": make_pillar,
        "ceiling_beam.glb": make_beam,
        "cobweb.glb": make_cobweb,
        "pit.glb": make_pit,
        "stairs.glb": make_stairs,
    }
    makers.update(heroes)
    for filename, fn in makers.items():
        clear()
        ship(fn(), out, filename)


def main():
    w1 = TEX / "polyhaven_w1_emberfall"
    w2 = TEX / "polyhaven_w2_whispering_mire"
    w3 = TEX / "polyhaven_w3_crystal_deep"
    build_world(
        "emberfall",
        w1 / "volcanic_rock_tiles",
        w1 / "rock_boulder_cracked",
        (0.9, 0.55, 0.38, 1),
        (0.35, 0.16, 0.1, 1),
        {
            "lava_plane.glb": make_lava,
            "banner.glb": lambda: make_banner((0.45, 0.08, 0.05, 1)),
            "brazier.glb": make_brazier,
        },
    )
    build_world(
        "whispering_mire",
        w2 / "brown_mud_leaves_01",
        w2 / "brick_moss_001",
        (0.62, 0.78, 0.58, 1),
        (0.2, 0.32, 0.18, 1),
        {
            "banner.glb": lambda: make_banner((0.12, 0.32, 0.2, 1)),
            "glow_mushroom.glb": make_mushroom,
            "log.glb": make_log,
            "reeds.glb": make_reeds,
            "grave.glb": make_grave,
            "roots.glb": make_roots,
            "puddle.glb": make_puddle,
            "cage.glb": make_cage,
            "hanging_moss.glb": make_moss,
            "swamp_tree.glb": make_tree,
            "cauldron.glb": make_cauldron,
        },
    )
    build_world(
        "crystal_deep",
        w3 / "rock_05",
        w3 / "rock_boulder_dry",
        (0.7, 0.64, 0.9, 1),
        (0.28, 0.22, 0.4, 1),
        {
            "banner.glb": lambda: make_banner((0.28, 0.16, 0.48, 1)),
            "crystal_cluster.glb": lambda: make_crystal("crystal_cluster", (0.32, 0.16, 0.48), (0.45, 0.22, 0.75)),
            "crystal_cyan.glb": lambda: make_crystal("crystal_cyan", (0.15, 0.4, 0.48), (0.2, 0.7, 0.8)),
            "crystal_pink.glb": lambda: make_crystal("crystal_pink", (0.45, 0.18, 0.38), (0.75, 0.25, 0.5)),
            "stalactite.glb": make_stalactite,
            "geode.glb": make_geode,
            "cave_rock.glb": make_rock,
            "shards.glb": make_shards,
        },
    )
    log("PASS2 DONE")


if __name__ == "__main__":
    main()
