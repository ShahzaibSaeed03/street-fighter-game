"""Decimate Kenney CC0 props and drop their atlas so Godot can retexture them.

Wall modules stay out of this pass: one Kenney wall is 400+ tris, and a room
needs dozens of them, which breaks the 15k triangle cap.
"""
from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(r"W:\street-fighter-game")
KITS = ROOT / "assets" / "models" / "env_cc0"
OUT = ROOT / "assets" / "models" / "env"

PIRATE = KITS / "kenney_pirate-kit" / "Models" / "GLB format"
CASTLE = KITS / "kenney_castle-kit" / "Models" / "GLB format"
TOWN = KITS / "kenney_fantasy-town-kit_2.0" / "Models" / "GLB format"
NATURE = KITS / "kenney_nature-kit" / "Models" / "GLTF format"
GRAVE = KITS / "kenney_graveyard-kit_5.0" / "Models" / "GLB format"

# world, filename, source, triangle cap, target height in metres.
# Focal wall pieces stay under 500 tris and are not used for every segment.
JOBS = [
    ("emberfall", "crate", PIRATE / "crate.glb", 420, 1.15),
    ("emberfall", "barrel", PIRATE / "barrel.glb", 420, 1.25),
    ("emberfall", "pillar", TOWN / "pillar-stone.glb", 420, 2.3),
    ("emberfall", "statue", NATURE / "statue_columnDamaged.glb", 500, 2.2),
    ("emberfall", "rubble", CASTLE / "rocks-small.glb", 320, 0.85),
    ("emberfall", "banner", CASTLE / "flag-banner-short.glb", 280, 2.3),
    ("emberfall", "doorway", CASTLE / "wall-doorway.glb", 500, 2.7),
    ("emberfall", "corner_tower", CASTLE / "wall-corner.glb", 500, 2.8),
    ("emberfall", "arch", CASTLE / "tower-square-arch.glb", 500, 2.6),
    ("whispering_mire", "log", CASTLE / "tree-log.glb", 360, 0.9),
    ("whispering_mire", "swamp_tree", TOWN / "tree-crooked.glb", 500, 3.4),
    ("whispering_mire", "grave", GRAVE / "grave.glb", 400, 1.35),
    ("whispering_mire", "gravestone", GRAVE / "gravestone-broken.glb", 320, 1.45),
    ("whispering_mire", "reeds", NATURE / "grass_large.glb", 280, 1.15),
    ("whispering_mire", "plants", NATURE / "plant_flatTall.glb", 280, 1.35),
    ("whispering_mire", "roots", CASTLE / "tree-trunk.glb", 360, 1.15),
    ("whispering_mire", "glow_mushroom", NATURE / "mushroom_redGroup.glb", 400, 1.25),
    ("whispering_mire", "doorway", CASTLE / "wall-doorway.glb", 500, 2.7),
    ("whispering_mire", "corner_tower", CASTLE / "wall-corner.glb", 500, 2.8),
    ("whispering_mire", "arch", CASTLE / "tower-square-arch.glb", 500, 2.6),
    ("crystal_deep", "cave_rock", CASTLE / "rocks-large.glb", 400, 1.4),
    ("crystal_deep", "pillar", TOWN / "pillar-stone.glb", 420, 2.3),
    ("crystal_deep", "statue", NATURE / "statue_obelisk.glb", 400, 2.3),
    ("crystal_deep", "doorway", CASTLE / "wall-doorway.glb", 500, 2.7),
    ("crystal_deep", "corner_tower", CASTLE / "wall-corner.glb", 500, 2.8),
    ("crystal_deep", "arch", CASTLE / "tower-square-arch.glb", 500, 2.6),
]


def log(m):
    print(m, flush=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images):
        for b in list(coll):
            try:
                coll.remove(b)
            except Exception:
                pass


def bounds(obj):
    pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def prep(src: Path, dest: Path, target: int, height: float):
    if not src.exists():
        log(f"MISSING {src}")
        return
    clear()
    bpy.ops.import_scene.gltf(filepath=str(src))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        log(f"NO MESH {src.name}")
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    minx, maxx, miny, maxy, minz, maxz = bounds(obj)
    obj.location = (-(minx + maxx) * 0.5, -(miny + maxy) * 0.5, -minz)
    bpy.ops.object.transform_apply(location=True)
    _, _, _, _, minz, maxz = bounds(obj)
    h = max(maxz - minz, 0.001)
    s = height / h
    obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(scale=True)
    obj.data.calc_loop_triangles()
    tris = len(obj.data.loop_triangles)
    if tris > target:
        mod = obj.modifiers.new("Dec", "DECIMATE")
        mod.ratio = max(0.05, target / float(tris))
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.data.calc_loop_triangles()
        tris = len(obj.data.loop_triangles)
    mat = bpy.data.materials.new("Retexture")
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    obj.name = dest.stem
    dest.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(dest),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    log(f"  {dest.relative_to(OUT)} tris={tris}")


def main():
    for world, name, src, target, height in JOBS:
        prep(src, OUT / world / f"{name}.glb", target, height)
    log("KENNEY PROPS DONE")


if __name__ == "__main__":
    main()
