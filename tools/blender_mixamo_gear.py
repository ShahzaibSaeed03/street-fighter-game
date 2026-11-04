"""
Raasta 2: Import Mixamo body.fbx (+ optional anim FBXs), attach hero gear, export GLB.

Expects:
  assets/models/heroes/mixamo/<id>/body.fbx
  optional: idle.fbx walk.fbx run.fbx slash.fbx dodge.fbx (without skin)

Run:
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --python tools/blender_mixamo_gear.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"W:\street-fighter-game")
MIXAMO = ROOT / "assets" / "models" / "heroes" / "mixamo"
EXPORT = ROOT / "assets" / "models" / "heroes" / "export"
DEMO = Path(
    r"C:\Users\Lenovo\AppData\Local\Cursor\AgentStores"
    r"\cursor_agent_stores\bc-48639f76-0ccf-453b-ab26-427fc18e94d1\files"
    r"\media\heroes-3d"
)

HEROES = {
    "ayaan": {
        "cape": (0.12, 0.12, 0.14, 1.0),
        "accent": (0.55, 0.12, 0.12, 1.0),
        "steel": (0.55, 0.58, 0.62, 1.0),
        "leather": (0.18, 0.12, 0.08, 1.0),
        "kind": "rogue",  # sword + dark cape
    },
    "zara": {
        "cape": (0.22, 0.45, 0.28, 1.0),
        "accent": (0.75, 0.72, 0.55, 1.0),
        "steel": (0.45, 0.40, 0.32, 1.0),
        "leather": (0.28, 0.18, 0.10, 1.0),
        "kind": "archer",  # bow + quiver
    },
    "kabir": {
        "cape": (0.55, 0.08, 0.08, 1.0),
        "accent": (0.70, 0.15, 0.12, 1.0),
        "steel": (0.50, 0.52, 0.58, 1.0),
        "leather": (0.16, 0.10, 0.07, 1.0),
        "kind": "guard",  # heavy pauldrons + red cape
    },
}

ANIMS = ("idle", "walk", "run", "slash", "dodge")


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.actions, bpy.data.cameras, bpy.data.lights):
        for b in list(coll):
            coll.remove(b)


def mat(name, color, metallic=0.0, roughness=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = roughness
    return m


def find_armature():
    for obj in bpy.context.scene.objects:
        if obj.type == "ARMATURE":
            return obj
    return None


def bone_world(arm, bone_name_candidates):
    """Return world-space head of first matching bone."""
    for name in bone_name_candidates:
        # Mixamo often uses mixamorig:Name or mixamorig_Name
        for b in arm.pose.bones:
            if b.name == name or b.name.endswith(name) or name in b.name:
                return arm.matrix_world @ b.head, b.name
    return None, None


def parent_to_bone(obj, arm, bone_name):
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    # Keep roughly at bone tip in local bone space
    obj.location = (0.0, 0.0, 0.0)
    obj.rotation_euler = (0, 0, 0)


def add_gear(arm, cfg):
    m_steel = mat("Steel", cfg["steel"], metallic=0.9, roughness=0.32)
    m_leather = mat("Leather", cfg["leather"], metallic=0.0, roughness=0.72)
    m_cape = mat("Cape", cfg["cape"], metallic=0.02, roughness=0.78)
    m_accent = mat("Accent", cfg["accent"], metallic=0.1, roughness=0.55)
    m_wood = mat("Wood", (0.35, 0.22, 0.10, 1.0), metallic=0.0, roughness=0.65)
    m_blade = mat("Blade", (0.78, 0.82, 0.88, 1.0), metallic=1.0, roughness=0.15)

    _, chest = bone_world(arm, ["Spine2", "Spine1", "Spine", "mixamorig:Spine2"])
    _, head = bone_world(arm, ["Head", "mixamorig:Head"])
    _, hand_r = bone_world(arm, ["RightHand", "mixamorig:RightHand"])
    _, hand_l = bone_world(arm, ["LeftHand", "mixamorig:LeftHand"])
    _, shoulder_l = bone_world(arm, ["LeftShoulder", "LeftArm", "mixamorig:LeftShoulder"])
    _, shoulder_r = bone_world(arm, ["RightShoulder", "RightArm", "mixamorig:RightShoulder"])
    _, hips = bone_world(arm, ["Hips", "mixamorig:Hips"])

    gear = []

    # Pauldrons
    if shoulder_l:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, 0, 0))
        p = bpy.context.active_object
        p.name = "Pauldron_L"
        p.data.materials.append(m_steel)
        parent_to_bone(p, arm, shoulder_l)
        p.location = (0.05, 0.0, 0.05)
        gear.append(p)
    if shoulder_r:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(0, 0, 0))
        p = bpy.context.active_object
        p.name = "Pauldron_R"
        p.data.materials.append(m_steel)
        parent_to_bone(p, arm, shoulder_r)
        p.location = (-0.05, 0.0, 0.05)
        gear.append(p)

    # Cape on chest/spine
    if chest:
        bpy.ops.mesh.primitive_cube_add(size=0.4, location=(0, 0, 0))
        cape = bpy.context.active_object
        cape.name = "Cape"
        cape.scale = (0.9, 0.08, 1.4)
        cape.data.materials.append(m_cape)
        parent_to_bone(cape, arm, chest)
        cape.location = (0.0, -0.12, -0.35)
        cape.rotation_euler = Euler((0.35, 0, 0), "XYZ")
        gear.append(cape)

        # Neck scarf / cowl
        bpy.ops.mesh.primitive_torus_add(major_radius=0.09, minor_radius=0.035, location=(0, 0, 0))
        cowl = bpy.context.active_object
        cowl.name = "Cowl"
        cowl.data.materials.append(m_accent if cfg["kind"] == "guard" else m_cape)
        parent_to_bone(cowl, arm, chest)
        cowl.location = (0.0, 0.02, 0.22)
        gear.append(cowl)

    # Belt
    if hips:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.16, depth=0.05, location=(0, 0, 0))
        belt = bpy.context.active_object
        belt.name = "Belt"
        belt.data.materials.append(m_leather)
        parent_to_bone(belt, arm, hips)
        belt.location = (0.0, 0.0, 0.05)
        gear.append(belt)

    kind = cfg["kind"]
    if kind == "rogue" and hand_r:
        # Sword
        bpy.ops.mesh.primitive_cube_add(size=0.08, location=(0, 0, 0))
        blade = bpy.context.active_object
        blade.name = "SwordBlade"
        blade.scale = (0.15, 0.05, 2.8)
        blade.data.materials.append(m_blade)
        parent_to_bone(blade, arm, hand_r)
        blade.location = (0.0, 0.15, 0.35)
        blade.rotation_euler = Euler((1.1, 0, 0), "XYZ")
        gear.append(blade)

        bpy.ops.mesh.primitive_cylinder_add(radius=0.02, depth=0.14, location=(0, 0, 0))
        grip = bpy.context.active_object
        grip.name = "SwordGrip"
        grip.data.materials.append(m_leather)
        parent_to_bone(grip, arm, hand_r)
        grip.location = (0.0, 0.05, 0.02)
        gear.append(grip)

    if kind == "archer" and hand_l:
        # Bow
        bpy.ops.mesh.primitive_torus_add(major_radius=0.28, minor_radius=0.015, location=(0, 0, 0))
        bow = bpy.context.active_object
        bow.name = "Bow"
        bow.scale = (0.35, 1.0, 1.2)
        bow.data.materials.append(m_wood)
        parent_to_bone(bow, arm, hand_l)
        bow.location = (0.0, 0.12, 0.05)
        bow.rotation_euler = Euler((0, 1.2, 0.3), "XYZ")
        gear.append(bow)

        if chest:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.06, depth=0.35, location=(0, 0, 0))
            quiver = bpy.context.active_object
            quiver.name = "Quiver"
            quiver.data.materials.append(m_leather)
            parent_to_bone(quiver, arm, chest)
            quiver.location = (0.15, -0.12, -0.15)
            quiver.rotation_euler = Euler((0.4, 0, 0.5), "XYZ")
            gear.append(quiver)

    if kind == "guard":
        # Extra chest plate
        if chest:
            bpy.ops.mesh.primitive_cube_add(size=0.28, location=(0, 0, 0))
            plate = bpy.context.active_object
            plate.name = "ChestPlate"
            plate.scale = (1.0, 0.25, 1.1)
            plate.data.materials.append(m_steel)
            parent_to_bone(plate, arm, chest)
            plate.location = (0.0, 0.10, 0.0)
            gear.append(plate)
        # Knee-ish pads on calves if bones exist
        for side, names in (("L", ["LeftLeg", "mixamorig:LeftLeg"]), ("R", ["RightLeg", "mixamorig:RightLeg"])):
            _, bn = bone_world(arm, names)
            if not bn:
                continue
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.07, location=(0, 0, 0))
            pad = bpy.context.active_object
            pad.name = f"Knee_{side}"
            pad.scale = (1.0, 0.7, 1.1)
            pad.data.materials.append(m_steel)
            parent_to_bone(pad, arm, bn)
            pad.location = (0.0, 0.05, 0.15)
            gear.append(pad)

    return gear


def import_fbx(path: Path, anim=False):
    before = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(
        filepath=str(path),
        automatic_bone_orientation=True,
        ignore_leaf_bones=False,
        use_anim=True,
    )
    new_objs = [o for o in bpy.data.objects if o not in before]
    new_actions = [a for a in bpy.data.actions if a not in before_actions]
    return new_objs, new_actions


def push_action_to_nla(arm, action, name):
    if arm.animation_data is None:
        arm.animation_data_create()
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    start = int(action.frame_range[0])
    track.strips.new(name, start, action)
    arm.animation_data.action = None


def setup_lights():
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 350
    key.data.size = 2.0
    key.location = (2.2, -2.0, 2.8)
    key.rotation_euler = Euler((math.radians(55), 0, math.radians(35)), "XYZ")
    bpy.context.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 100
    fill.data.size = 2.5
    fill.location = (-2.0, 1.2, 1.8)
    bpy.context.collection.objects.link(fill)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.06, 0.07, 0.10, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.5


def render_preview(path: Path):
    for obj in list(bpy.data.objects):
        if obj.type == "CAMERA":
            bpy.data.objects.remove(obj, do_unlink=True)
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam_data.lens = 50
    cam.location = (1.6, -2.6, 1.4)
    cam.rotation_euler = Euler((math.radians(75), 0, math.radians(32)), "XYZ")
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 640
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export_glb(path: Path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"MESH", "ARMATURE"}:
            obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=False,
        export_animations=True,
        export_nla_strips=True,
    )


def process_hero(hid: str, cfg: dict) -> bool:
    folder = MIXAMO / hid
    body = folder / "body.fbx"
    if not body.exists():
        # also accept any single .fbx named differently
        candidates = list(folder.glob("*.fbx")) + list(folder.glob("*.FBX"))
        if not candidates:
            print(f"[SKIP] {hid}: no body.fbx in {folder}", flush=True)
            return False
        body = candidates[0]
        print(f"[INFO] {hid}: using {body.name} as body", flush=True)

    clear_scene()
    print(f"[BUILD] {hid} from {body}", flush=True)
    import_fbx(body)
    arm = find_armature()
    if arm is None:
        print(f"[FAIL] {hid}: no armature in FBX", flush=True)
        return False

    # Scale Mixamo (often cm) toward ~1.8m if huge
    # Mixamo usually comes in ~1.6–1.9 Blender units already when apply_scale works; leave as-is.

    add_gear(arm, cfg)

    # Import anims without skin and push to NLA
    for aname in ANIMS:
        ap = folder / f"{aname}.fbx"
        if not ap.exists():
            continue
        print(f"  + anim {aname}", flush=True)
        # Import into temp, steal action, delete extra armatures
        before_arms = {o.name for o in bpy.data.objects if o.type == "ARMATURE"}
        before_actions = set(bpy.data.actions)
        import_fbx(ap, anim=True)
        new_actions = [a for a in bpy.data.actions if a not in before_actions]
        # Remove extra armatures/meshes from anim-only import
        for obj in list(bpy.data.objects):
            if obj.type == "ARMATURE" and obj.name not in before_arms and obj != arm:
                bpy.data.objects.remove(obj, do_unlink=True)
            elif obj.type == "MESH" and obj.parent and obj.parent.type == "ARMATURE" and obj.parent != arm:
                bpy.data.objects.remove(obj, do_unlink=True)
        if new_actions:
            act = new_actions[-1]
            act.name = aname
            push_action_to_nla(arm, act, aname)

    setup_lights()
    EXPORT.mkdir(parents=True, exist_ok=True)
    DEMO.mkdir(parents=True, exist_ok=True)
    out = EXPORT / f"{hid}.glb"
    export_glb(out)
    render_preview(DEMO / f"{hid}_mixamo_preview.png")
    print(f"[OK] {out}", flush=True)
    return True


def main():
    EXPORT.mkdir(parents=True, exist_ok=True)
    found = 0
    done = 0
    for hid, cfg in HEROES.items():
        folder = MIXAMO / hid
        folder.mkdir(parents=True, exist_ok=True)
        has = any(folder.glob("*.fbx")) or any(folder.glob("*.FBX"))
        if has:
            found += 1
            if process_hero(hid, cfg):
                done += 1
        else:
            print(f"[WAIT] Put Mixamo FBX in {folder}", flush=True)
    print(f"DONE found={found} exported={done}", flush=True)
    if found == 0:
        print("No Mixamo FBX yet. Follow assets/models/heroes/mixamo/README_DOWNLOAD.md", flush=True)
        sys.exit(2)


if __name__ == "__main__":
    main()
