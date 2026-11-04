"""World 2 (Whispering Mire) + World 3 (Crystal Deep) kits.
Same helpers as emberfall_kit.py. Own geo for mushrooms, crystals, geodes, swamp trees.
Run: blender --background --python tools/blender/env/build_mire_crystal.py
"""
from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler

ROOT = Path(r"W:\street-fighter-game")
spec = importlib.util.spec_from_file_location("ef", ROOT / "tools" / "blender" / "env" / "emberfall_kit.py")
ef = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ef)

NATURE = ROOT / "assets" / "models" / "env_cc0" / "kenney_nature-kit"
# nature glbs may be nested
def find_glb(name: str) -> Path | None:
    hits = list(NATURE.rglob(name))
    return hits[0] if hits else None


def build_world(world_id: str, tex_root: Path, extras):
    ef.TEX = tex_root
    out = ROOT / "assets" / "models" / "env" / world_id
    ef.OUT = out
    out.mkdir(parents=True, exist_ok=True)
    ef.log(f"\n==== {world_id} ====")
    for name, fn in extras:
        ef.clear_scene()
        obj = fn()
        if obj is None:
            ef.log(f"  skip {name}")
            continue
        ef.export_glb(obj, out / f"{name}.glb")
        tris = 0
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris = len(obj.data.loop_triangles)
        ef.log(f"  {name}.glb tris~{tris}")
    # kit preview
    ef.render_preview(out / "preview_kit.png", None)
    total = sum(p.stat().st_size for p in out.glob("*.glb"))
    ef.log(f"{world_id} GLB total {total/1e6:.2f} MB")


def mire_pieces():
    floor = "brown_mud_leaves_01"
    moss = "brick_moss_001"
    rock = "brown_mud_rocks_01"

    def floor_a():
        return ef.make_floor("floor_a", ef.pbr_mat("MFloor", floor, 2.0), 1)
    def floor_b():
        return ef.make_floor("floor_b", ef.pbr_mat("MMoss", moss, 1.8), 0)
    def floor_c():
        return ef.make_floor("floor_c", ef.pbr_mat("MRock", rock, 1.6), 2)
    def wall():
        return ef.make_wall("wall_straight", ef.pbr_mat("MWall", moss, 1.4))
    def wall_c():
        return ef.make_wall_corner(ef.pbr_mat("MWall", moss, 1.4))
    def pillar():
        return ef.make_pillar(ef.pbr_mat("MPillar", rock, 1.2))
    def water():
        m = ef.simple_mat("SwampWater", (0.05, 0.18, 0.12), 0.15, emission=(0.05, 0.25, 0.1, 1), strength=0.4)
        bpy.ops.mesh.primitive_plane_add(size=ef.TILE, location=(0, 0, 0.04))
        o = bpy.context.active_object
        o.name = "swamp_water"
        ef.apply_mat(o, m)
        ef.smart_uv(o)
        return o
    def mushroom():
        stem = ef.simple_mat("Stem", (0.75, 0.7, 0.55), 0.6)
        cap = ef.simple_mat("Cap", (0.35, 0.55, 0.15), 0.45, emission=(0.3, 0.9, 0.25, 1), strength=6.0)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.12, depth=0.55, location=(0, 0, 0.28), vertices=8)
        s = bpy.context.active_object
        ef.apply_mat(s, stem)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.32, location=(0, 0, 0.62), segments=12, ring_count=8)
        c = bpy.context.active_object
        c.scale = (1.2, 1.2, 0.45)
        bpy.ops.object.transform_apply(scale=True)
        ef.apply_mat(c, cap)
        bpy.ops.object.select_all(action="DESELECT")
        s.select_set(True); c.select_set(True)
        bpy.context.view_layer.objects.active = s
        bpy.ops.object.join()
        s.name = "glow_mushroom"
        ef.decimate(s, 800)
        return s
    def tree():
        bark = ef.pbr_mat("Bark", rock, 1.5)
        leaf = ef.simple_mat("Leaf", (0.08, 0.22, 0.08), 0.7)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.18, depth=1.6, location=(0, 0, 0.8), vertices=8)
        t = bpy.context.active_object
        ef.apply_mat(t, bark)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.9, location=(0, 0, 2.1), subdivisions=2)
        l = bpy.context.active_object
        ef.apply_mat(l, leaf)
        ef.displace_noise(l, 0.08)
        bpy.ops.object.select_all(action="DESELECT")
        t.select_set(True); l.select_set(True)
        bpy.context.view_layer.objects.active = t
        bpy.ops.object.join()
        t.name = "swamp_tree"
        ef.decimate(t, 1400)
        return t
    def reeds():
        m = ef.simple_mat("Reed", (0.15, 0.35, 0.12), 0.6)
        parts = []
        for i in range(6):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.9, location=((i % 3) * 0.15, (i // 3) * 0.15, 0.45), vertices=5)
            p = bpy.context.active_object
            p.rotation_euler = Euler((0.15 * i, 0, 0.2), "XYZ")
            ef.apply_mat(p, m)
            parts.append(p)
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        parts[0].name = "reeds"
        return parts[0]
    def grave():
        m = ef.pbr_mat("Grave", moss, 1.0)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0.55))
        o = bpy.context.active_object
        o.scale = (0.7, 0.18, 1.1)
        bpy.ops.object.transform_apply(scale=True)
        ef.apply_mat(o, m)
        ef.bevel(o, 0.02, 1)
        o.name = "grave"
        return o
    def log():
        m = ef.pbr_mat("Log", rock, 2.0)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.22, depth=1.4, location=(0, 0, 0.22), vertices=8)
        o = bpy.context.active_object
        o.rotation_euler = Euler((0, math.radians(90), 0), "XYZ")
        bpy.ops.object.transform_apply(rotation=True)
        ef.apply_mat(o, m)
        ef.displace_noise(o, 0.02)
        o.name = "log"
        ef.decimate(o, 600)
        return o
    def cauldron():
        m = ef.simple_mat("Iron", (0.12, 0.13, 0.12), 0.4, metallic=0.8)
        brew = ef.simple_mat("Brew", (0.2, 0.7, 0.15), 0.3, emission=(0.3, 1.0, 0.2, 1), strength=4.0)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.4, location=(0, 0, 0.35), segments=12, ring_count=8)
        o = bpy.context.active_object
        o.scale = (1, 1, 0.7)
        bpy.ops.object.transform_apply(scale=True)
        ef.apply_mat(o, m)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.22, location=(0, 0, 0.55), segments=10, ring_count=6)
        b = bpy.context.active_object
        ef.apply_mat(b, brew)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); b.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.join()
        o.name = "cauldron"
        return o
    def rubble():
        return ef.make_rubble(ef.pbr_mat("MRub", rock, 1.0))
    def door_frame():
        return ef.make_door_frame(ef.pbr_mat("MWall", moss, 1.2))

    return [
        ("floor_a", floor_a), ("floor_b", floor_b), ("floor_c", floor_c),
        ("wall_straight", wall), ("wall_corner", wall_c), ("pillar", pillar),
        ("swamp_water", water), ("glow_mushroom", mushroom), ("swamp_tree", tree),
        ("reeds", reeds), ("grave", grave), ("log", log), ("cauldron", cauldron),
        ("rubble", rubble), ("door_frame", door_frame),
    ]


def crystal_pieces():
    r5 = "rock_05"
    r6 = "rock_06"
    dry = "rock_boulder_dry"

    def floor_a():
        return ef.make_floor("floor_a", ef.pbr_mat("CFloor", r5, 1.8), 1)
    def floor_b():
        return ef.make_floor("floor_b", ef.pbr_mat("CFloor2", r6, 1.6), 2)
    def floor_c():
        return ef.make_floor("floor_c", ef.pbr_mat("CDry", dry, 1.5), 0)
    def wall():
        return ef.make_wall("wall_straight", ef.pbr_mat("CWall", r6, 1.3))
    def wall_c():
        return ef.make_wall_corner(ef.pbr_mat("CWall", r6, 1.3))
    def pillar():
        return ef.make_pillar(ef.pbr_mat("CPil", dry, 1.2))
    def crystal():
        m = ef.simple_mat("Crystal", (0.45, 0.25, 0.85), 0.2, emission=(0.55, 0.3, 1.0, 1), strength=8.0, metallic=0.1)
        parts = []
        for i, h in enumerate((0.9, 0.65, 0.5)):
            bpy.ops.mesh.primitive_cone_add(radius1=0.12 + i * 0.02, depth=h, vertices=6, location=(i * 0.18 - 0.15, (i % 2) * 0.1, h * 0.5))
            p = bpy.context.active_object
            p.rotation_euler = Euler((0.15, 0, 0.3 * i), "XYZ")
            ef.apply_mat(p, m)
            parts.append(p)
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        parts[0].name = "crystal_cluster"
        ef.decimate(parts[0], 700)
        return parts[0]
    def geode():
        rockm = ef.pbr_mat("GeodeRock", dry, 1.2)
        inn = ef.simple_mat("GeodeIn", (0.6, 0.35, 0.95), 0.25, emission=(0.5, 0.25, 1.0, 1), strength=5.0)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.55, location=(0, 0, 0.4), segments=12, ring_count=8)
        o = bpy.context.active_object
        o.scale = (1.1, 1.0, 0.75)
        bpy.ops.object.transform_apply(scale=True)
        ef.apply_mat(o, rockm)
        ef.displace_noise(o, 0.06)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=0.22, location=(0.15, -0.1, 0.45), subdivisions=1)
        g = bpy.context.active_object
        ef.apply_mat(g, inn)
        bpy.ops.object.select_all(action="DESELECT")
        o.select_set(True); g.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.join()
        o.name = "geode"
        ef.decimate(o, 1100)
        return o
    def stalactite():
        m = ef.pbr_mat("Stal", r6, 1.5)
        bpy.ops.mesh.primitive_cone_add(radius1=0.18, depth=1.1, vertices=7, location=(0, 0, 2.0))
        o = bpy.context.active_object
        o.rotation_euler = Euler((math.pi, 0, 0), "XYZ")
        ef.apply_mat(o, m)
        o.name = "stalactite"
        return o
    def rubble():
        return ef.make_rubble(ef.pbr_mat("CRub", dry, 1.0))
    def door_frame():
        return ef.make_door_frame(ef.pbr_mat("CWall", r6, 1.2))
    def cave_rock():
        src = find_glb("rock_largeA.glb")
        if src is None:
            return rubble()
        return ef.import_kenney_retarget(src, "cave_rock", ef.pbr_mat("CKen", dry, 1.2), 0.4)

    return [
        ("floor_a", floor_a), ("floor_b", floor_b), ("floor_c", floor_c),
        ("wall_straight", wall), ("wall_corner", wall_c), ("pillar", pillar),
        ("crystal_cluster", crystal), ("geode", geode), ("stalactite", stalactite),
        ("rubble", rubble), ("door_frame", door_frame), ("cave_rock", cave_rock),
    ]


def main():
    only = [a for a in sys.argv[1:] if a in ("whispering_mire", "crystal_deep")]
    tex2 = ROOT / "assets" / "textures" / "env_cc0" / "polyhaven_w2_whispering_mire"
    tex3 = ROOT / "assets" / "textures" / "env_cc0" / "polyhaven_w3_crystal_deep"
    if not only or "whispering_mire" in only:
        build_world("whispering_mire", tex2, mire_pieces())
    if not only or "crystal_deep" in only:
        build_world("crystal_deep", tex3, crystal_pieces())
    ef.log("W2+W3 KITS DONE")


if __name__ == "__main__":
    main()
