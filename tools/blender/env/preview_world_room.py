"""Render a sample room for a world kit. argv: world_id"""
from __future__ import annotations
import math, sys
from pathlib import Path
import bpy
from mathutils import Euler

ROOT = Path(r"W:\street-fighter-game")
world = "whispering_mire"
for a in sys.argv:
    if a in ("whispering_mire", "crystal_deep", "emberfall"):
        world = a
KIT = ROOT / "assets" / "models" / "env" / world
OUT = ROOT / "media" / "env-3d" / world
OUT.mkdir(parents=True, exist_ok=True)

BG = {
    "whispering_mire": (0.04, 0.08, 0.05, 1),
    "crystal_deep": (0.05, 0.03, 0.08, 1),
}.get(world, (0.06, 0.03, 0.02, 1))


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def load_at(name, loc, rot_z=0.0, scale=1.0):
    path = KIT / f"{name}.glb"
    if not path.exists():
        return
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    if not new:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in new:
        o.select_set(True)
    bpy.context.view_layer.objects.active = new[0]
    if len(new) > 1:
        bpy.ops.object.join()
    o = bpy.context.active_object
    o.location = loc
    o.rotation_euler = Euler((0, 0, rot_z), "XYZ")
    o.scale = (scale, scale, scale)


def main():
    clear()
    for y in range(4):
        for x in range(6):
            load_at(["floor_a", "floor_b", "floor_c"][(x + y) % 3], (x * 2.0, y * 2.0, 0))
    for x in range(6):
        load_at("wall_straight", (x * 2.0, -1.0, 0))
        load_at("wall_straight", (x * 2.0, 8.0, 0), math.pi)
    for y in range(4):
        load_at("wall_straight", (-1.0, y * 2.0, 0), math.pi * 0.5)
        load_at("wall_straight", (12.0, y * 2.0, 0), -math.pi * 0.5)
    load_at("pillar", (2, 2, 0)); load_at("pillar", (8, 6, 0))
    if world == "whispering_mire":
        load_at("glow_mushroom", (3, 4, 0), 0, 1.3)
        load_at("glow_mushroom", (7, 3, 0), 0.4, 1.1)
        load_at("swamp_tree", (-2.2, 1, 0), 0, 1.1)
        load_at("swamp_tree", (13.2, 5, 0), 0.3, 1.2)
        load_at("swamp_water", (14.5, 2, 0), 0, 1.6)
        load_at("reeds", (1, 6, 0))
        load_at("grave", (9, 1.5, 0))
        load_at("cauldron", (5, 4, 0))
        load_at("log", (4, 6.5, 0))
    else:
        load_at("crystal_cluster", (3, 4, 0), 0, 1.4)
        load_at("crystal_cluster", (8, 2, 0), 0.5, 1.2)
        load_at("geode", (5, 5, 0), 0, 1.3)
        load_at("stalactite", (6, 1, 0))
        load_at("cave_rock", (1, 5, 0))
        load_at("crystal_cluster", (13.5, 3, 0), 0, 1.6)
        load_at("crystal_cluster", (-2.4, 4, 0), 0, 1.5)

    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 220
    key.data.size = 6
    key.location = (6, -5, 9)
    bpy.context.collection.objects.link(key)
    worldn = bpy.context.scene.world or bpy.data.worlds.new("W")
    bpy.context.scene.world = worldn
    worldn.use_nodes = True
    bg = worldn.node_tree.nodes["Background"]
    bg.inputs[0].default_value = BG
    bg.inputs[1].default_value = 0.3
    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (5.5, -9.0, 9.2)
    cam.rotation_euler = Euler((math.radians(52), 0, 0), "XYZ")
    sc = bpy.context.scene
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception: sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = str(OUT / "level_room_preview.png")
    bpy.ops.render.render(write_still=True)
    # denser boss pass
    if world == "whispering_mire":
        load_at("glow_mushroom", (4, 3, 0), 0, 1.5)
        load_at("cauldron", (6.5, 4.5, 0), 0, 1.2)
    else:
        load_at("geode", (4, 3, 0), 0, 1.5)
        load_at("crystal_cluster", (7, 5, 0), 0, 1.6)
    sc.render.filepath = str(OUT / "boss_arena_preview.png")
    bpy.ops.render.render(write_still=True)
    print("PREVIEW DONE", world, OUT)


if __name__ == "__main__":
    main()
