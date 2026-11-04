"""Render a sample Emberfall room from exported kit GLBs for approval screenshots."""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"W:\street-fighter-game")
KIT = ROOT / "assets" / "models" / "env" / "emberfall"
OUT = ROOT / "media" / "env-3d" / "emberfall"
OUT.mkdir(parents=True, exist_ok=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def load_at(path: Path, loc, rot_z=0.0, scale=1.0):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    if not new:
        return None
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
    return o


def main():
    clear()
    # Floor grid 6x4
    for y in range(4):
        for x in range(6):
            name = ["floor_a.glb", "floor_b.glb", "floor_c.glb"][(x + y) % 3]
            load_at(KIT / name, (x * 2.0, y * 2.0, 0))
    # Walls
    for x in range(6):
        load_at(KIT / "wall_straight.glb", (x * 2.0, -1.0, 0))
        load_at(KIT / "wall_straight.glb", (x * 2.0, 8.0, 0), math.pi)
    for y in range(4):
        load_at(KIT / "wall_straight.glb", (-1.0, y * 2.0, 0), math.pi * 0.5)
        load_at(KIT / "wall_straight.glb", (12.0, y * 2.0, 0), -math.pi * 0.5)
    # Props
    load_at(KIT / "pillar.glb", (2.0, 2.0, 0))
    load_at(KIT / "pillar.glb", (8.0, 2.0, 0))
    load_at(KIT / "pillar.glb", (2.0, 6.0, 0))
    load_at(KIT / "pillar.glb", (8.0, 6.0, 0))
    load_at(KIT / "brazier.glb", (0.5, 0.5, 0), 0, 1.0)
    load_at(KIT / "brazier.glb", (10.5, 0.5, 0), 0, 1.0)
    load_at(KIT / "brazier.glb", (0.5, 7.0, 0), 0, 1.0)
    load_at(KIT / "lava_plane.glb", (5.0, 4.0, 0.05), 0, 1.6)
    load_at(KIT / "rubble.glb", (4.0, 1.5, 0))
    load_at(KIT / "bone_pile.glb", (7.0, 5.5, 0))
    load_at(KIT / "cracked_statue.glb", (9.5, 3.5, 0), 0.6)
    load_at(KIT / "gate.glb", (5.0, -0.9, 0), 0, 1.0)

    # Lights
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 250
    key.data.color = (1.0, 0.55, 0.3)
    key.data.size = 5
    key.location = (6, -4, 8)
    bpy.context.collection.objects.link(key)
    for loc in ((0.5, 0.5, 1.8), (10.5, 0.5, 1.8), (0.5, 7.0, 1.8)):
        omni = bpy.data.objects.new("T", bpy.data.lights.new("T", "POINT"))
        omni.data.energy = 80
        omni.data.color = (1.0, 0.4, 0.12)
        omni.location = loc
        bpy.context.collection.objects.link(omni)
    world = bpy.context.scene.world or bpy.data.worlds.new("W")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.08, 0.03, 0.02, 1)
    bg.inputs[1].default_value = 0.25

    cam_data = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam.location = (5.5, -9.5, 9.5)
    cam.rotation_euler = Euler((math.radians(52), 0, 0), "XYZ")
    sc = bpy.context.scene
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception: sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 1280
    sc.render.resolution_y = 720
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = str(OUT / "level01_room_preview.png")
    bpy.ops.render.render(write_still=True)

    # Boss-ish denser lava + more braziers
    load_at(KIT / "lava_plane.glb", (3.0, 3.0, 0.05), 0, 1.2)
    load_at(KIT / "lava_plane.glb", (7.5, 5.0, 0.05), 0, 1.3)
    load_at(KIT / "brazier.glb", (5.5, 7.2, 0))
    cam.location = (5.5, -8.0, 10.5)
    sc.render.filepath = str(OUT / "boss_arena_preview.png")
    bpy.ops.render.render(write_still=True)
    print("ROOM PREVIEWS DONE", OUT)


if __name__ == "__main__":
    main()
