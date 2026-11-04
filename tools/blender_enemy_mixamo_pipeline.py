"""STEP 3: Optimize Mixamo enemy bodies + shared anims → model.glb."""
from __future__ import annotations

import re
import sys
from pathlib import Path

import bpy

ROOT = Path(r"W:\street-fighter-game")
EN = ROOT / "assets" / "models" / "enemies"
BODIES = ("skeleton", "ghoul", "golem", "imp", "wraith", "yeti", "knight")
# shared anim file -> export name
ANIM_MAP = {
    "idle": "idle",
    "walk": "move",
    "run": "run",
    "attack": "attack",
    "slash": "attack",  # fallback if attack missing merge
    "hit": "hit",
    "death": "death",
}


def log(m): print(m, flush=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.images, bpy.data.actions, bpy.data.cameras, bpy.data.lights):
        for b in list(coll):
            try: coll.remove(b)
            except Exception: pass


def bone_suffix(name: str) -> str:
    return name.split(":", 1)[1] if ":" in name else name


def normalize_bones(arm):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for eb in arm.data.edit_bones:
        suf = bone_suffix(eb.name)
        new = f"mixamorig:{suf}"
        if eb.name != new:
            eb.name = new
    bpy.ops.object.mode_set(mode="OBJECT")


def find_arm():
    for o in bpy.context.scene.objects:
        if o.type == "ARMATURE":
            return o
    return None


def count_tris():
    t = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            t += len(o.data.loop_triangles)
    return t


def import_fbx(path: Path):
    before = set(bpy.data.objects)
    before_a = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True, use_anim=True)
    return [o for o in bpy.data.objects if o not in before], [a for a in bpy.data.actions if a not in before_a]


def darken_materials():
    for mat in bpy.data.materials:
        if not mat.use_nodes: continue
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf: continue
        base = bsdf.inputs["Base Color"]
        if not base.is_linked:
            c = list(base.default_value)
            base.default_value = (c[0] * 0.55, c[1] * 0.5, c[2] * 0.5, 1.0)
        else:
            nt = mat.node_tree
            link = base.links[0]
            fr = link.from_socket
            nt.links.remove(link)
            try:
                mix = nt.nodes.new("ShaderNodeMix")
                mix.data_type = "RGBA"
                mix.blend_type = "MULTIPLY"
                mix.inputs["Factor"].default_value = 0.75
                mix.inputs["B"].default_value = (0.35, 0.25, 0.22, 1)
                nt.links.new(fr, mix.inputs["A"])
                nt.links.new(mix.outputs["Result"], base)
            except Exception:
                pass
        if "Roughness" in bsdf.inputs and not bsdf.inputs["Roughness"].is_linked:
            bsdf.inputs["Roughness"].default_value = min(0.85, bsdf.inputs["Roughness"].default_value + 0.15)


def add_glow_eyes(arm):
    # small emissive spheres near head bone if present
    head = None
    for b in arm.pose.bones:
        if bone_suffix(b.name).lower() == "head":
            head = b.name
            break
    if not head:
        return
    m = bpy.data.materials.new("EnemyGlowEye")
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (0.8, 0.05, 0.02, 1)
    if "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (1.0, 0.15, 0.05, 1)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    for i, ox in enumerate((-0.04, 0.04)):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.025, location=(0, 0, 0))
        eye = bpy.context.active_object
        eye.name = f"GlowEye{i}"
        eye.data.materials.append(m)
        eye.parent = arm
        eye.parent_type = "BONE"
        eye.parent_bone = head
        eye.location = (ox, 0.08, 0.05)


def resize_images(max_dim=1024):
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}: continue
        w, h = img.size
        if w <= 0 or max(w, h) <= max_dim: continue
        s = max_dim / float(max(w, h))
        try: img.scale(max(1, int(w * s)), max(1, int(h * s)))
        except Exception: pass


def decimate(target=10000):
    cur = count_tris()
    if cur <= target: return
    ratio = max(0.2, min(0.95, target / float(cur)))
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH": continue
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        mod = o.modifiers.new("Dec", type="DECIMATE")
        mod.ratio = ratio
        try: bpy.ops.object.modifier_apply(modifier=mod.name)
        except Exception: pass
        o.select_set(False)


def steal_anim(path: Path, arm, out_name: str, used_names: set):
    if out_name in used_names:
        return False
    before_arms = {o for o in bpy.data.objects if o.type == "ARMATURE"}
    before_meshes = {o for o in bpy.data.objects if o.type == "MESH"}
    before_acts = set(bpy.data.actions)
    import_fbx(path)
    new_arms = [o for o in bpy.data.objects if o.type == "ARMATURE" and o not in before_arms]
    act = None
    if new_arms:
        src = new_arms[0]
        if src.animation_data and src.animation_data.action:
            act = src.animation_data.action
        elif [a for a in bpy.data.actions if a not in before_acts]:
            act = [a for a in bpy.data.actions if a not in before_acts][-1]
            if src.animation_data is None: src.animation_data_create()
            src.animation_data.action = act
        normalize_bones(src)
        if src.animation_data and src.animation_data.action:
            act = src.animation_data.action
    for o in list(bpy.data.objects):
        if o.type == "ARMATURE" and o not in before_arms:
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type == "MESH" and o not in before_meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    if act is None:
        return False
    act2 = act.copy()
    act2.name = out_name
    if arm.animation_data is None: arm.animation_data_create()
    arm.animation_data.action = None
    track = arm.animation_data.nla_tracks.new()
    track.name = out_name
    fr = tuple(act2.frame_range) if hasattr(act2, "frame_range") else (1, 30)
    track.strips.new(out_name, int(fr[0]), act2)
    used_names.add(out_name)
    log(f"  + {out_name}")
    return True


def setup_preview():
    import math
    from mathutils import Euler, Vector
    key = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "AREA"))
    key.data.energy = 350; key.data.size = 2.5
    key.location = (2, -2, 2.4)
    key.rotation_euler = Euler((math.radians(55), 0, math.radians(35)), "XYZ")
    bpy.context.collection.objects.link(key)
    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.04, 0.05, 1)


def render_preview(path: Path):
    import math
    from mathutils import Vector
    for o in list(bpy.data.objects):
        if o.type == "CAMERA": bpy.data.objects.remove(o, do_unlink=True)
    cam_data = bpy.data.cameras.new("C"); cam = bpy.data.objects.new("C", cam_data)
    bpy.context.collection.objects.link(cam); bpy.context.scene.camera = cam
    cam.location = (1.8, -2.6, 1.4)
    cam.rotation_euler = (Vector((0, 0, 0.9)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
    sc = bpy.context.scene
    try: sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception: sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def export_glb(path: Path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type in {"MESH", "ARMATURE"}: o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True,
        export_apply=True, export_animations=True, export_nla_strips=True,
        export_force_sampling=True, export_anim_single_armature=True,
    )


def process(species: str):
    clear()
    body = EN / species / "body.fbx"
    log(f"\n==== {species} ====")
    import_fbx(body)
    arm = find_arm()
    if not arm:
        raise RuntimeError("no armature")
    normalize_bones(arm)
    used = set()
    # Prefer attack.fbx over slash for "attack"
    order = ["idle", "walk", "run", "attack", "hit", "death", "slash"]
    for aname in order:
        ap = EN / "shared" / f"{aname}.fbx"
        if not ap.exists(): continue
        out = ANIM_MAP.get(aname, aname)
        if out == "attack" and "attack" in used:
            continue
        steal_anim(ap, arm, out, used)
    darken_materials()
    add_glow_eyes(arm)
    # Mobile budget: textures 512, tris ~7k → keep GLB under ~4 MB
    resize_images(512)
    decimate(7000)
    setup_preview()
    out_dir = EN / species
    out_dir.mkdir(parents=True, exist_ok=True)
    glb = out_dir / "model.glb"
    export_glb(glb)
    render_preview(out_dir / "preview.png")
    # also map ghost -> copy wraith later
    log(f"EXPORT {species} tris={count_tris()} mb={glb.stat().st_size/1e6:.2f}")
    return glb


def main():
    only = [a for a in sys.argv[1:] if a in BODIES]
    specs = only or list(BODIES)
    ok = 0
    for s in specs:
        try:
            process(s)
            ok += 1
        except Exception as e:
            log(f"FAIL {s}: {e}")
            import traceback; traceback.print_exc()
    # ghost aliases wraith
    wraith_glb = EN / "wraith" / "model.glb"
    if wraith_glb.exists():
        ghost = EN / "ghost"
        ghost.mkdir(parents=True, exist_ok=True)
        import shutil
        shutil.copy2(wraith_glb, ghost / "model.glb")
        prev = EN / "wraith" / "preview.png"
        if prev.exists():
            shutil.copy2(prev, ghost / "preview.png")
        log("Copied wraith → ghost")
    log(f"MIXAMO ENEMIES DONE {ok}/{len(specs)}")
    if ok < len(specs):
        sys.exit(1)


if __name__ == "__main__":
    main()
