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

# world, filename, source, triangle cap, target height in metres
JOBS = [
    ("emberfall", "crate", PIRATE / "crate.glb", 140, 1.15),
    ("emberfall", "barrel", PIRATE / "barrel.glb", 140, 1.25),
    ("emberfall", "pillar", TOWN / "pillar-stone.glb", 160, 2.4),
    ("emberfall", "statue", NATURE / "statue_columnDamaged.glb", 180, 2.3),
    ("emberfall", "rubble", CASTLE / "rocks-small.glb", 120, 0.7),
    ("emberfall", "banner", CASTLE / "flag-banner-short.glb", 100, 2.4),
    ("whispering_mire", "log", CASTLE / "tree-log.glb", 120, 0.85),
    ("whispering_mire", "swamp_tree", TOWN / "tree-crooked.glb", 220, 3.6),
    ("whispering_mire", "grave", GRAVE / "grave.glb", 140, 1.4),
    ("whispering_mire", "gravestone", GRAVE / "gravestone-broken.glb", 100, 1.5),
    ("whispering_mire", "reeds", NATURE / "plant_bush.glb", 80, 1.1),
    ("crystal_deep", "cave_rock", CASTLE / "rocks-large.glb", 140, 1.3),
    ("crystal_deep", "pillar", TOWN / "pillar-stone.glb", 160, 2.4),
    ("crystal_deep", "statue", NATURE / "statue_obelisk.glb", 140, 2.2),
    ("emberfall", "buttress", TOWN / "wall-block.glb", 80, 2.2),
    ("whispering_mire", "roots", CASTLE / "tree-trunk.glb", 100, 1.1),
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
    # Nature kit names vary. Fall back if plant_bush is absent.
    bush = list((NATURE).glob("plant_bush*.glb"))
    jobs = []
    for world, name, src, target, height in JOBS:
        if name == "reeds" and bush:
            src = bush[0]
        jobs.append((world, name, src, target, height))
    for world, name, src, target, height in jobs:
        prep(src, OUT / world / f"{name}.glb", target, height)
    log("KENNEY PROPS DONE")


if __name__ == "__main__":
    main()
