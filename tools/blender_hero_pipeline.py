"""
STEP 2 — Mixamo → optimized distinct heroes → GLB + preview.

Usage:
  blender --background --python tools/blender_hero_pipeline.py
"""
from __future__ import annotations

import math
import re
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

ROOT = Path(r"W:\street-fighter-game")
MIXAMO = ROOT / "assets" / "models" / "heroes" / "mixamo"
FINAL = ROOT / "assets" / "models" / "heroes" / "final"
ANIMS = ("idle", "walk", "run", "slash", "dodge")

HERO_CFG = {
    "ayaan": {  # Jake — shadow knight (Adam tracksuit → dark charcoal + red trim)
        "tint_mul": (0.18, 0.18, 0.20),
        "tint_add": (0.04, 0.0, 0.0),
        "metal": 0.15,
        "rough": 0.62,
        "accent": (0.75, 0.08, 0.10, 1.0),
        "cape": (0.05, 0.05, 0.06, 1.0),
        "leather": (0.10, 0.08, 0.07, 1.0),
        "kind": "rogue",
        "target_tris": 10000,
        "tex_max": 512,
    },
    "zara": {  # Maya — archer
        "tint_mul": (0.45, 0.70, 0.55),
        "tint_add": (0.0, 0.05, 0.02),
        "metal": 0.15,
        "rough": 0.55,
        "accent": (0.20, 0.55, 0.40, 1.0),
        "cape": (0.15, 0.35, 0.28, 1.0),
        "leather": (0.22, 0.35, 0.22, 1.0),
        "kind": "archer",
        "target_tris": 12000,
        "tex_max": 512,
    },
    "kabir": {  # Marcus — iron guard
        "tint_mul": (0.62, 0.64, 0.70),
        "tint_add": (0.05, 0.05, 0.02),
        "metal": 0.85,
        "rough": 0.30,
        "accent": (0.85, 0.68, 0.22, 1.0),
        "cape": (0.55, 0.08, 0.10, 1.0),
        "leather": (0.18, 0.12, 0.08, 1.0),
        "kind": "guard",
        "target_tris": 14000,
        "tex_max": 1024,
    },
}


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


def bone_suffix(name: str) -> str:
    if ":" in name:
        return name.split(":", 1)[1]
    return name


def normalize_bone_names(arm):
    """Rename mixamorigN:Bone → mixamorig:Bone for consistent anim retarget."""
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    mapping = {}
    for eb in arm.data.edit_bones:
        suf = bone_suffix(eb.name)
        new = f"mixamorig:{suf}"
        if eb.name != new:
            mapping[eb.name] = new
            eb.name = new
    bpy.ops.object.mode_set(mode="OBJECT")
    return mapping


def find_armature():
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            return o
    return None


def count_tris() -> int:
    total = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            total += len(o.data.loop_triangles)
    return total


def import_fbx(path: Path):
    before_obj = set(bpy.data.objects)
    before_act = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(
        filepath=str(path),
        automatic_bone_orientation=True,
        ignore_leaf_bones=False,
        use_anim=True,
    )
    new_objs = [o for o in bpy.data.objects if o not in before_obj]
    new_acts = [a for a in bpy.data.actions if a not in before_act]
    return new_objs, new_acts


def mat_new(name, color, metallic=0.0, roughness=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metallic
    if "Roughness" in bsdf.inputs:
        bsdf.inputs["Roughness"].default_value = roughness
    return m


def tint_existing_materials(cfg):
    mul = cfg["tint_mul"]
    add = cfg["tint_add"]
    for mat in bpy.data.materials:
        if not mat.use_nodes or not mat.node_tree:
            continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        # Multiply base color
        base = bsdf.inputs["Base Color"]
        if not base.is_linked:
            c = list(base.default_value)
            base.default_value = (
                min(1.0, c[0] * mul[0] + add[0]),
                min(1.0, c[1] * mul[1] + add[1]),
                min(1.0, c[2] * mul[2] + add[2]),
                1.0,
            )
        else:
            # Insert Mix RGB multiply after texture
            nt = mat.node_tree
            link = base.links[0]
            from_s = link.from_socket
            nt.links.remove(link)
            try:
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs["Factor"].default_value = 0.85
                mix.inputs["B"].default_value = (mul[0], mul[1], mul[2], 1.0)
                mix.location = (from_s.node.location.x + 200, from_s.node.location.y)
                nt.links.new(from_s, mix.inputs["A"])
                nt.links.new(mix.outputs["Result"], base)
            except Exception:
                mix = nt.nodes.new("ShaderNodeMixRGB")
                mix.blend_type = "MULTIPLY"
                mix.inputs["Fac"].default_value = 0.85
                mix.inputs["Color2"].default_value = (mul[0], mul[1], mul[2], 1.0)
                mix.location = (from_s.node.location.x + 200, from_s.node.location.y)
                nt.links.new(from_s, mix.inputs["Color1"])
                nt.links.new(mix.outputs["Color"], base)
        if "Metallic" in bsdf.inputs and not bsdf.inputs["Metallic"].is_linked:
            bsdf.inputs["Metallic"].default_value = max(
                bsdf.inputs["Metallic"].default_value, cfg["metal"] * 0.5
            )
        if "Roughness" in bsdf.inputs and not bsdf.inputs["Roughness"].is_linked:
            bsdf.inputs["Roughness"].default_value = cfg["rough"]


def resize_images(max_dim: int):
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}:
            continue
        w, h = img.size
        if w <= 0 or h <= 0:
            continue
        if max(w, h) <= max_dim:
            continue
        scale = max_dim / float(max(w, h))
        nw = max(1, int(w * scale))
        nh = max(1, int(h * scale))
        try:
            img.scale(nw, nh)
            log(f"  resized {img.name} -> {nw}x{nh}")
        except Exception as e:
            log(f"  resize fail {img.name}: {e}")


def decimate_meshes(target_tris: int):
    cur = count_tris()
    if cur <= target_tris:
        log(f"  tris={cur} already under target {target_tris}")
        return
    ratio = max(0.15, min(0.95, target_tris / float(cur)))
    log(f"  decimate tris {cur} -> ~{target_tris} ratio={ratio:.3f}")
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH":
            continue
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        mod = obj.modifiers.new(name="DecimateMobile", type="DECIMATE")
        mod.ratio = ratio
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception:
            # fallback: leave modifier (export_apply may bake)
            pass
        obj.select_set(False)
    log(f"  tris after decimate={count_tris()}")


def bone_name_contains(arm, *needles):
    for b in arm.pose.bones:
        suf = bone_suffix(b.name).lower()
        for n in needles:
            if n.lower() == suf or n.lower() in suf:
                return b.name
    return None


def parent_bone(obj, arm, bone):
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)


def add_accessories(arm, cfg):
    m_steel = mat_new("GearSteel", (0.55, 0.58, 0.62, 1.0), metallic=0.9, roughness=0.28)
    m_gold = mat_new("GearGold", cfg["accent"], metallic=0.95, roughness=0.25)
    m_cape = mat_new("GearCape", cfg["cape"], metallic=0.02, roughness=0.75)
    m_leather = mat_new("GearLeather", cfg["leather"], metallic=0.0, roughness=0.7)
    m_blade = mat_new("GearBlade", (0.8, 0.85, 0.9, 1.0), metallic=1.0, roughness=0.12)
    m_wood = mat_new("GearWood", (0.35, 0.22, 0.1, 1.0), metallic=0.0, roughness=0.65)

    chest = bone_name_contains(arm, "Spine2", "Spine1", "Spine")
    hips = bone_name_contains(arm, "Hips")
    sh_l = bone_name_contains(arm, "LeftShoulder", "LeftArm")
    sh_r = bone_name_contains(arm, "RightShoulder", "RightArm")
    hand_r = bone_name_contains(arm, "RightHand")
    hand_l = bone_name_contains(arm, "LeftHand")
    forearm_l = bone_name_contains(arm, "LeftForeArm")
    forearm_r = bone_name_contains(arm, "RightForeArm")

    if sh_l:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08)
        p = bpy.context.active_object
        p.name = "Pauldron_L"
        p.data.materials.append(m_steel if cfg["kind"] != "guard" else m_gold)
        parent_bone(p, arm, sh_l)
        p.location = (0.04, 0.0, 0.04)
        p.scale = (1.2, 0.9, 0.85)
    if sh_r:
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.08)
        p = bpy.context.active_object
        p.name = "Pauldron_R"
        p.data.materials.append(m_steel if cfg["kind"] != "guard" else m_gold)
        parent_bone(p, arm, sh_r)
        p.location = (-0.04, 0.0, 0.04)
        p.scale = (1.2, 0.9, 0.85)

    if chest:
        bpy.ops.mesh.primitive_cube_add(size=0.35)
        cape = bpy.context.active_object
        cape.name = "Cape"
        cape.scale = (0.85, 0.06, 1.25)
        cape.data.materials.append(m_cape)
        parent_bone(cape, arm, chest)
        cape.location = (0.0, -0.10, -0.28)
        cape.rotation_euler = Euler((0.3, 0, 0), "XYZ")

        bpy.ops.mesh.primitive_torus_add(major_radius=0.08, minor_radius=0.03)
        cowl = bpy.context.active_object
        cowl.name = "Cowl"
        cowl.data.materials.append(m_cape if cfg["kind"] != "guard" else mat_new("RedCowl", cfg["accent"], 0.05, 0.7))
        parent_bone(cowl, arm, chest)
        cowl.location = (0.0, 0.02, 0.18)

    if hips:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.14, depth=0.045)
        belt = bpy.context.active_object
        belt.name = "Belt"
        belt.data.materials.append(m_leather if cfg["kind"] != "guard" else m_gold)
        parent_bone(belt, arm, hips)
        belt.location = (0.0, 0.0, 0.02)

    for side, bn in (("L", forearm_l), ("R", forearm_r)):
        if not bn:
            continue
        bpy.ops.mesh.primitive_cylinder_add(radius=0.045, depth=0.12)
        br = bpy.context.active_object
        br.name = f"Bracer_{side}"
        br.data.materials.append(m_leather if cfg["kind"] == "archer" else m_steel)
        parent_bone(br, arm, bn)
        br.location = (0.0, 0.0, 0.05)

    kind = cfg["kind"]
    if kind == "rogue" and hand_r:
        bpy.ops.mesh.primitive_cube_add(size=0.06)
        blade = bpy.context.active_object
        blade.name = "Sword"
        blade.scale = (0.12, 0.04, 2.6)
        blade.data.materials.append(m_blade)
        parent_bone(blade, arm, hand_r)
        blade.location = (0.0, 0.12, 0.32)
        blade.rotation_euler = Euler((1.05, 0, 0), "XYZ")

    if kind == "archer" and hand_l:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.25, minor_radius=0.012)
        bow = bpy.context.active_object
        bow.name = "Bow"
        bow.scale = (0.3, 1.0, 1.15)
        bow.data.materials.append(m_wood)
        parent_bone(bow, arm, hand_l)
        bow.location = (0.0, 0.1, 0.05)
        bow.rotation_euler = Euler((0, 1.1, 0.2), "XYZ")
        if chest:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.05, depth=0.32)
            q = bpy.context.active_object
            q.name = "Quiver"
            q.data.materials.append(m_leather)
            parent_bone(q, arm, chest)
            q.location = (0.12, -0.1, -0.12)
            q.rotation_euler = Euler((0.35, 0, 0.4), "XYZ")

    if kind == "guard" and chest:
        bpy.ops.mesh.primitive_cube_add(size=0.26)
        plate = bpy.context.active_object
        plate.name = "ChestPlate"
        plate.scale = (1.05, 0.22, 1.15)
        plate.data.materials.append(m_steel)
        parent_bone(plate, arm, chest)
        plate.location = (0.0, 0.09, 0.0)


def _action_frame_range(act):
    try:
        return tuple(act.frame_range)
    except Exception:
        return (1.0, 30.0)


def steal_action_from_anim_fbx(path: Path, arm, anim_name: str):
    """Import anim FBX, normalize bone names on its armature (updates action paths),
    copy action onto main armature NLA, delete temp objects.
    Compatible with Blender 5 layered Actions (no direct action.fcurves).
    """
    before_arms = {o for o in bpy.data.objects if o.type == "ARMATURE"}
    before_meshes = {o for o in bpy.data.objects if o.type == "MESH"}
    before_acts = set(bpy.data.actions)
    import_fbx(path)
    new_arms = [o for o in bpy.data.objects if o.type == "ARMATURE" and o not in before_arms]
    new_acts = [a for a in bpy.data.actions if a not in before_acts]

    act = None
    src = new_arms[0] if new_arms else None
    if src is not None:
        if src.animation_data and src.animation_data.action:
            act = src.animation_data.action
        elif new_acts:
            if src.animation_data is None:
                src.animation_data_create()
            act = new_acts[-1]
            src.animation_data.action = act
        # Rename bones while action is bound so Blender rewrites paths.
        normalize_bone_names(src)
        if src.animation_data and src.animation_data.action:
            act = src.animation_data.action
    elif new_acts:
        act = new_acts[-1]

    # Remove temp meshes/armatures from anim import
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE" and o not in before_arms:
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH" and o not in before_meshes:
            bpy.data.objects.remove(o, do_unlink=True)

    if act is None:
        log(f"  WARN no action in {path.name}")
        return False

    act_copy = act.copy()
    act_copy.name = anim_name

    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = anim_name
    fr = _action_frame_range(act_copy)
    start = int(fr[0])
    track.strips.new(anim_name, start, act_copy)
    log(f"  + anim {anim_name} frames={fr}")
    return True


def setup_preview_lights():
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 400
    key.data.size = 2.5
    key.location = (2.0, -2.2, 2.6)
    key.rotation_euler = Euler((math.radians(55), 0, math.radians(35)), "XYZ")
    bpy.context.collection.objects.link(key)
    fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "AREA"))
    fill.data.energy = 120
    fill.data.size = 3.0
    fill.location = (-2.0, 1.5, 1.8)
    bpy.context.collection.objects.link(fill)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.12, 0.13, 0.16, 1)
    bg.inputs[1].default_value = 0.4


def render_preview(path: Path):
    for o in list(bpy.data.objects):
        if o.type == "CAMERA":
            bpy.data.objects.remove(o, do_unlink=True)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam
    cam_data.lens = 50
    # Front view roughly looking at +Y or -Y depending on Mixamo facing
    cam.location = (0.0, -3.2, 1.35)
    cam.rotation_euler = Euler((math.radians(82), 0, 0), "XYZ")
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export_glb(path: Path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "ARMATURE"}:
            o.select_set(True)
    # Prefer active action empty; NLA strips export as named animations
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


def process_hero(hid: str) -> dict:
    cfg = HERO_CFG[hid]
    folder = MIXAMO / hid
    body = folder / "body.fbx"
    out_dir = FINAL / hid
    out_dir.mkdir(parents=True, exist_ok=True)
    report = {"id": hid, "ok": False}

    if not body.exists():
        report["error"] = f"missing {body}"
        return report

    clear_scene()
    log(f"\n==== {hid} ====")
    log(f"import body {body} ({body.stat().st_size/1e6:.1f} MB)")
    import_fbx(body)
    arm = find_armature()
    if not arm:
        report["error"] = "no armature"
        return report

    normalize_bone_names(arm)
    log(f"  bones normalized, tris={count_tris()}")

    # Import animations onto same armature
    for aname in ANIMS:
        ap = folder / f"{aname}.fbx"
        if ap.exists():
            steal_action_from_anim_fbx(ap, arm, aname)
        else:
            log(f"  WARN missing {ap.name}")

    tint_existing_materials(cfg)
    add_accessories(arm, cfg)
    resize_images(cfg["tex_max"])
    decimate_meshes(cfg["target_tris"])

    # Pack images for self-contained GLB
    for img in bpy.data.images:
        if img.packed_file is None and img.size[0] > 0:
            try:
                img.pack()
            except Exception:
                pass

    setup_preview_lights()
    glb = out_dir / "hero.glb"
    prev = out_dir / "preview.png"
    export_glb(glb)
    render_preview(prev)

    report.update({
        "ok": True,
        "glb": str(glb),
        "glb_mb": round(glb.stat().st_size / 1e6, 3) if glb.exists() else 0,
        "preview": str(prev),
        "tris": count_tris(),
        "anims": [t.name for t in (arm.animation_data.nla_tracks if arm.animation_data else [])],
    })
    log(f"  EXPORT {glb} ({report['glb_mb']} MB) tris={report['tris']} anims={report['anims']}")
    return report


def main():
    FINAL.mkdir(parents=True, exist_ok=True)
    only = [a for a in sys.argv[1:] if not a.startswith("-") and a in HERO_CFG]
    heroes = only if only else list(HERO_CFG.keys())
    results = []
    for hid in heroes:
        try:
            results.append(process_hero(hid))
        except Exception as e:
            log(f"FAIL {hid}: {e}")
            results.append({"id": hid, "ok": False, "error": str(e)})
    ok = sum(1 for r in results if r.get("ok"))
    log(f"\nPIPELINE DONE ok={ok}/{len(results)}")
    for r in results:
        log(str(r))
    if ok < len(heroes):
        sys.exit(1)


if __name__ == "__main__":
    main()
