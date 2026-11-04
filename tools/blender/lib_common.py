"""Shared Blender helpers for enemy creature + Mixamo export pipelines."""
from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"W:\street-fighter-game")
ENEMIES = ROOT / "assets" / "models" / "enemies"


def log(msg: str):
    print(msg, flush=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (
        bpy.data.meshes, bpy.data.materials, bpy.data.armatures,
        bpy.data.images, bpy.data.actions, bpy.data.cameras, bpy.data.lights,
    ):
        for b in list(coll):
            try:
                coll.remove(b)
            except Exception:
                pass


def mat(name, color, metallic=0.0, roughness=0.5, emission=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    c = list(color)
    if len(c) == 3:
        c.append(alpha)
    else:
        c[3] = alpha
    bsdf.inputs["Base Color"].default_value = tuple(c)
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = emission
        if "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = 3.0
    elif emission is not None and "Emission" in bsdf.inputs:
        bsdf.inputs["Emission"].default_value = emission
    if alpha < 1.0:
        m.blend_method = "HASHED"
        if "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = alpha
    return m


def uv_sphere(name, r, loc, material, segs=16, rings=10, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=loc, segments=segs, ring_count=rings)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def cylinder(name, r, depth, loc, material, verts=12, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Euler(rot, "XYZ")
    o.scale = scale
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def cone(name, r, depth, loc, material, verts=10, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=r, depth=depth, location=loc, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Euler(rot, "XYZ")
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    return o


def cube(name, size, loc, material, scale=(1, 1, 1), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=size, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = Euler(rot, "XYZ")
    o.data.materials.append(material)
    return o


def join_meshes(name, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o


def make_armature(name, bone_defs):
    """bone_defs: list of (name, head, tip, parent_name|None)"""
    arm_data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    created = {}
    for bn, head, tip, parent in bone_defs:
        b = eb.new(bn)
        b.head = Vector(head)
        b.tail = Vector(tip)
        if parent:
            b.parent = created[parent]
        created[bn] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def parent_with_auto_weights(mesh, arm):
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def ensure_anim_data(arm):
    if arm.animation_data is None:
        arm.animation_data_create()


def new_action(arm, name, frame_end=40):
    ensure_anim_data(arm)
    act = bpy.data.actions.new(name)
    # Blender 5 may need layered assign; try classic first
    try:
        arm.animation_data.action = act
    except Exception:
        arm.animation_data.action = act
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frame_end
    return act


def key_bone(arm, bone, frame, loc=None, rot=None):
    pb = arm.pose.bones.get(bone)
    if pb is None:
        return
    if loc is not None:
        pb.location = Vector(loc)
        pb.keyframe_insert(data_path="location", frame=frame)
    if rot is not None:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = Euler(rot, "XYZ")
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)


def push_nla(arm, action, name):
    ensure_anim_data(arm)
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    start = int(action.frame_range[0]) if hasattr(action, "frame_range") else 1
    track.strips.new(name, start, action)


def setup_lights():
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 350
    key.data.size = 2.5
    key.location = (2.2, -2.0, 2.4)
    key.rotation_euler = Euler((math.radians(55), 0, math.radians(40)), "XYZ")
    bpy.context.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 90
    fill.data.size = 3.0
    fill.location = (-2.0, 1.2, 1.6)
    bpy.context.collection.objects.link(fill)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.04, 0.04, 0.06, 1)
    bg.inputs[1].default_value = 0.35


def render_preview(path: Path, cam_loc=(1.8, -2.6, 1.3), look=(0, 0, 0.6)):
    for o in list(bpy.data.objects):
        if o.type == "CAMERA":
            bpy.data.objects.remove(o, do_unlink=True)
    cam_data = bpy.data.cameras.new("PrevCam")
    cam = bpy.data.objects.new("PrevCam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam_data.lens = 45
    cam.location = cam_loc
    direction = Vector(look) - Vector(cam_loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export_glb(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "ARMATURE"}:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_nla_strips=True,
        export_force_sampling=True,
        export_anim_single_armature=True,
    )


def count_tris() -> int:
    t = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            t += len(o.data.loop_triangles)
    return t


def decimate_to(target: int):
    cur = count_tris()
    if cur <= target:
        return
    ratio = max(0.2, min(0.95, target / float(cur)))
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        mod = o.modifiers.new("Dec", type="DECIMATE")
        mod.ratio = ratio
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception:
            pass
        o.select_set(False)
