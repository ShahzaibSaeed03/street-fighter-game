"""Build the 9 non-Mixamo enemy creatures (dark / dangerous look)."""
from __future__ import annotations

import math
import sys
from pathlib import Path

# allow `blender --python make_bat.py` from tools/blender
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib_common import (  # noqa: E402
    ENEMIES, clear_scene, mat, uv_sphere, cylinder, cone, cube, join_meshes,
    make_armature, parent_with_auto_weights, new_action, key_bone, push_nla,
    setup_lights, render_preview, export_glb, count_tris, decimate_to, log,
)


def _finish(species: str, arm, mesh, anim_builders, target_tris=5500):
    parent_with_auto_weights(mesh, arm)
    for name, builder in anim_builders:
        act = new_action(arm, name, 48)
        builder(arm)
        push_nla(arm, act, name)
    decimate_to(target_tris)
    setup_lights()
    out = ENEMIES / species
    out.mkdir(parents=True, exist_ok=True)
    glb = out / "model.glb"
    prev = out / "preview.png"
    export_glb(glb)
    render_preview(prev)
    log(f"[OK] {species} tris={count_tris()} glb={glb.stat().st_size/1e6:.2f}MB")
    return glb


def _quad_idle_move_attack(arm, leg_bones, attack_bone="Head"):
    def idle(a):
        for f in (1, 24, 48):
            amp = 0.02 if f == 24 else 0.0
            key_bone(a, "Spine", f, loc=(0, 0, amp))
            key_bone(a, "Head", f, rot=(amp * 2, 0, 0))
    def move(a):
        for i, f in enumerate((1, 12, 24, 36, 48)):
            phase = (i % 4) * 0.5
            for j, b in enumerate(leg_bones):
                sign = 1 if j % 2 == 0 else -1
                key_bone(a, b, f, rot=(sign * 0.45 * math.sin(phase + j), 0, 0))
            key_bone(a, "Spine", f, loc=(0, 0.02 * math.sin(phase), 0))
    def attack(a):
        key_bone(a, attack_bone, 1, rot=(0, 0, 0))
        key_bone(a, attack_bone, 12, rot=(-0.8, 0, 0))
        key_bone(a, attack_bone, 20, rot=(0.6, 0, 0.2))
        key_bone(a, attack_bone, 36, rot=(0, 0, 0))
        key_bone(a, "Spine", 12, loc=(0, 0.05, 0))
        key_bone(a, "Spine", 36, loc=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0))
        key_bone(a, "Spine", 8, rot=(0.4, 0.3, 0))
        key_bone(a, "Spine", 24, rot=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0))
        key_bone(a, "Spine", 30, rot=(1.4, 0, 0), loc=(0, 0, -0.2))
        key_bone(a, "Head", 30, rot=(0.8, 0, 0))
    return [
        ("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death),
    ]


def build_bat():
    clear_scene()
    m_body = mat("BatBody", (0.12, 0.08, 0.08), metallic=0.05, roughness=0.7)
    m_wing = mat("BatWing", (0.18, 0.05, 0.05), metallic=0.0, roughness=0.55)
    m_eye = mat("BatEye", (0.05, 0.0, 0.0), metallic=0.0, roughness=0.3, emission=(1.0, 0.05, 0.02, 1))
    m_fang = mat("BatFang", (0.85, 0.85, 0.8), metallic=0.1, roughness=0.25)
    body = uv_sphere("Body", 0.22, (0, 0, 0.7), m_body, scale=(0.85, 1.1, 0.9))
    head = uv_sphere("Head", 0.14, (0, 0.18, 0.95), m_body)
    ear_l = cone("EarL", 0.05, 0.14, (-0.08, 0.12, 1.12), m_body, rot=(0.3, 0, -0.4))
    ear_r = cone("EarR", 0.05, 0.14, (0.08, 0.12, 1.12), m_body, rot=(0.3, 0, 0.4))
    eye_l = uv_sphere("EyeL", 0.03, (-0.05, 0.28, 0.98), m_eye)
    eye_r = uv_sphere("EyeR", 0.03, (0.05, 0.28, 0.98), m_eye)
    fang_l = cone("FangL", 0.015, 0.06, (-0.03, 0.28, 0.88), m_fang, rot=(2.4, 0, 0))
    fang_r = cone("FangR", 0.015, 0.06, (0.03, 0.28, 0.88), m_fang, rot=(2.4, 0, 0))
    wing_l = cube("WingL", 0.4, (-0.45, 0, 0.75), m_wing, scale=(1.4, 0.08, 0.7), rot=(0.2, 0, 0.5))
    wing_r = cube("WingR", 0.4, (0.45, 0, 0.75), m_wing, scale=(1.4, 0.08, 0.7), rot=(0.2, 0, -0.5))
    mesh = join_meshes("BatMesh", [body, head, ear_l, ear_r, eye_l, eye_r, fang_l, fang_r, wing_l, wing_r])
    arm = make_armature("BatArm", [
        ("Root", (0, 0, 0.4), (0, 0, 0.55), None),
        ("Spine", (0, 0, 0.55), (0, 0, 0.85), "Root"),
        ("Head", (0, 0, 0.85), (0, 0.1, 1.05), "Spine"),
        ("Wing_L", (0, 0, 0.75), (-0.55, 0, 0.75), "Spine"),
        ("Wing_R", (0, 0, 0.75), (0.55, 0, 0.75), "Spine"),
    ])
    def idle(a):
        for f, z in ((1, 0), (24, 0.03), (48, 0)):
            key_bone(a, "Spine", f, loc=(0, 0, z))
            key_bone(a, "Wing_L", f, rot=(0, 0, 0.15 if f == 24 else 0))
            key_bone(a, "Wing_R", f, rot=(0, 0, -0.15 if f == 24 else 0))
    def move(a):
        for i, f in enumerate((1, 12, 24, 36, 48)):
            flap = 0.7 if i % 2 else -0.5
            key_bone(a, "Wing_L", f, rot=(0, 0, flap))
            key_bone(a, "Wing_R", f, rot=(0, 0, -flap))
            key_bone(a, "Spine", f, loc=(0, 0, 0.04 * math.sin(i)))
    def attack(a):
        key_bone(a, "Head", 1, rot=(0, 0, 0))
        key_bone(a, "Head", 15, rot=(-0.9, 0, 0))
        key_bone(a, "Head", 28, rot=(0.5, 0, 0))
        key_bone(a, "Head", 40, rot=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 10, rot=(0.5, 0.4, 0)); key_bone(a, "Spine", 30, rot=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 35, rot=(1.6, 0, 0), loc=(0, 0, -0.3))
    return _finish("bat", arm, mesh, [("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death)])


def build_crab():
    clear_scene()
    m_shell = mat("CrabShell", (0.45, 0.18, 0.10), metallic=0.15, roughness=0.45)
    m_claw = mat("CrabClaw", (0.55, 0.22, 0.12), metallic=0.2, roughness=0.4)
    m_leg = mat("CrabLeg", (0.35, 0.12, 0.08), metallic=0.1, roughness=0.55)
    m_eye = mat("CrabEye", (0.02, 0.02, 0.02), metallic=0.0, roughness=0.2, emission=(0.9, 0.15, 0.05, 1))
    shell = uv_sphere("Shell", 0.35, (0, 0, 0.35), m_shell, scale=(1.3, 1.0, 0.65))
    barn = uv_sphere("Barn", 0.06, (0.15, -0.1, 0.5), m_shell)
    body = uv_sphere("Body", 0.2, (0, 0.1, 0.25), m_claw)
    claw_l = cube("ClawL", 0.25, (-0.45, 0.25, 0.35), m_claw, scale=(1.2, 0.45, 0.5), rot=(0, 0, 0.4))
    claw_r = cube("ClawR", 0.25, (0.45, 0.25, 0.35), m_claw, scale=(1.2, 0.45, 0.5), rot=(0, 0, -0.4))
    pincer_l = cone("PinL", 0.08, 0.22, (-0.65, 0.35, 0.35), m_claw, rot=(0, 1.2, 0.5))
    pincer_r = cone("PinR", 0.08, 0.22, (0.65, 0.35, 0.35), m_claw, rot=(0, -1.2, -0.5))
    eyes = [uv_sphere(f"E{i}", 0.035, (sx * 0.08, 0.28, 0.48), m_eye) for i, sx in enumerate((-1, 1))]
    legs = []
    for i, sx in enumerate((-1, -1, -1, 1, 1, 1)):
        z = 0.12
        y = -0.05 + (i % 3) * 0.08
        x = sx * (0.25 + (i % 3) * 0.05)
        legs.append(cylinder(f"Leg{i}", 0.03, 0.28, (x, y, z), m_leg, rot=(1.0, 0, sx * 0.6)))
    mesh = join_meshes("CrabMesh", [shell, barn, body, claw_l, claw_r, pincer_l, pincer_r] + eyes + legs)
    arm = make_armature("CrabArm", [
        ("Root", (0, 0, 0.05), (0, 0, 0.2), None),
        ("Spine", (0, 0, 0.2), (0, 0, 0.4), "Root"),
        ("Head", (0, 0.1, 0.4), (0, 0.25, 0.5), "Spine"),
        ("Claw_L", (0, 0.1, 0.35), (-0.55, 0.3, 0.35), "Spine"),
        ("Claw_R", (0, 0.1, 0.35), (0.55, 0.3, 0.35), "Spine"),
        ("Leg1", (0, 0, 0.15), (-0.35, -0.1, 0.05), "Root"),
        ("Leg2", (0, 0, 0.15), (0.35, -0.1, 0.05), "Root"),
        ("Leg3", (0, 0, 0.15), (-0.3, 0.05, 0.05), "Root"),
        ("Leg4", (0, 0, 0.15), (0.3, 0.05, 0.05), "Root"),
    ])
    return _finish("crab", arm, mesh, _quad_idle_move_attack(arm, ["Leg1", "Leg2", "Leg3", "Leg4"], "Claw_R"))


def build_hound():
    clear_scene()
    m_fur = mat("HoundFur", (0.25, 0.12, 0.08), metallic=0.0, roughness=0.75)
    m_skin = mat("HoundSkin", (0.45, 0.2, 0.15), metallic=0.0, roughness=0.55)
    m_eye = mat("HoundEye", (0.1, 0, 0), metallic=0.0, roughness=0.25, emission=(1.0, 0.2, 0.05, 1))
    m_tooth = mat("Tooth", (0.9, 0.88, 0.8), metallic=0.05, roughness=0.3)
    m_metal = mat("Collar", (0.4, 0.4, 0.45), metallic=0.85, roughness=0.35)
    torso = uv_sphere("Torso", 0.28, (0, 0, 0.55), m_fur, scale=(0.7, 1.3, 0.75))
    chest = uv_sphere("Chest", 0.22, (0, 0.25, 0.6), m_skin, scale=(0.8, 0.9, 0.85))
    head = uv_sphere("Head", 0.16, (0, 0.55, 0.7), m_fur, scale=(0.85, 1.1, 0.8))
    snout = uv_sphere("Snout", 0.09, (0, 0.72, 0.62), m_skin, scale=(0.7, 1.0, 0.6))
    jaw = cube("Jaw", 0.12, (0, 0.68, 0.52), m_skin, scale=(0.7, 0.9, 0.35))
    ears = [cone(f"Ear{sx}", 0.04, 0.1, (sx * 0.08, 0.5, 0.88), m_fur, rot=(0.2, 0, sx * 0.3)) for sx in (-1, 1)]
    eyes = [uv_sphere(f"Eye{sx}", 0.025, (sx * 0.05, 0.65, 0.75), m_eye) for sx in (-1, 1)]
    fangs = [cone(f"F{sx}", 0.015, 0.05, (sx * 0.03, 0.78, 0.55), m_tooth, rot=(2.5, 0, 0)) for sx in (-1, 1)]
    collar = cylinder("Collar", 0.12, 0.04, (0, 0.4, 0.72), m_metal, rot=(1.2, 0, 0))
    spike = cone("Spike", 0.03, 0.08, (0, 0.4, 0.82), m_metal)
    legs = []
    for name, loc in (("FL", (-0.12, 0.25, 0.25)), ("FR", (0.12, 0.25, 0.25)), ("BL", (-0.12, -0.25, 0.25)), ("BR", (0.12, -0.25, 0.25))):
        legs.append(cylinder(name, 0.05, 0.35, loc, m_fur))
        legs.append(cube(f"{name}Paw", 0.08, (loc[0], loc[1] + 0.02, 0.05), m_skin, scale=(1, 1.3, 0.4)))
    tail = cylinder("Tail", 0.04, 0.35, (0, -0.55, 0.55), m_fur, rot=(1.0, 0, 0))
    scar = cube("Scar", 0.15, (0.1, 0.15, 0.7), m_skin, scale=(0.15, 1.2, 0.08), rot=(0, 0, 0.5))
    mesh = join_meshes("HoundMesh", [torso, chest, head, snout, jaw, collar, spike, tail, scar] + ears + eyes + fangs + legs)
    arm = make_armature("HoundArm", [
        ("Root", (0, 0, 0.1), (0, 0, 0.3), None),
        ("Spine", (0, 0, 0.3), (0, 0.2, 0.55), "Root"),
        ("Head", (0, 0.35, 0.65), (0, 0.65, 0.75), "Spine"),
        ("Leg_FL", (0, 0.2, 0.4), (-0.12, 0.25, 0.05), "Spine"),
        ("Leg_FR", (0, 0.2, 0.4), (0.12, 0.25, 0.05), "Spine"),
        ("Leg_BL", (0, -0.1, 0.4), (-0.12, -0.25, 0.05), "Root"),
        ("Leg_BR", (0, -0.1, 0.4), (0.12, -0.25, 0.05), "Root"),
        ("Tail", (0, -0.3, 0.5), (0, -0.65, 0.4), "Spine"),
    ])
    return _finish("hound", arm, mesh, _quad_idle_move_attack(arm, ["Leg_FL", "Leg_FR", "Leg_BL", "Leg_BR"], "Head"))


def build_scorpion():
    clear_scene()
    m_ch = mat("Chitin", (0.35, 0.08, 0.05), metallic=0.25, roughness=0.35)
    m_dark = mat("ChitinDark", (0.15, 0.04, 0.03), metallic=0.2, roughness=0.4)
    m_eye = mat("ScEye", (0, 0, 0), metallic=0.0, roughness=0.2, emission=(1.0, 0.4, 0.05, 1))
    segs = []
    for i in range(5):
        segs.append(uv_sphere(f"Seg{i}", 0.14 - i * 0.01, (0, -0.12 * i, 0.25), m_ch if i % 2 == 0 else m_dark, scale=(1.1, 0.9, 0.7)))
    head = uv_sphere("Head", 0.13, (0, 0.25, 0.28), m_ch, scale=(1.2, 1.0, 0.75))
    eyes = [uv_sphere(f"E{i}", 0.025, (sx * 0.06, 0.35, 0.35), m_eye) for sx in (-1, 1)]
    claw_l = cube("CL", 0.2, (-0.35, 0.3, 0.3), m_ch, scale=(1.3, 0.4, 0.45), rot=(0, 0, 0.5))
    claw_r = cube("CR", 0.2, (0.35, 0.3, 0.3), m_ch, scale=(1.3, 0.4, 0.45), rot=(0, 0, -0.5))
    sting_base = cylinder("StingBase", 0.05, 0.5, (0, -0.55, 0.55), m_dark, rot=(0.9, 0, 0))
    stinger = cone("Stinger", 0.04, 0.18, (0, -0.75, 0.85), m_ch, rot=(-0.5, 0, 0))
    legs = []
    for i in range(8):
        sx = -1 if i < 4 else 1
        y = 0.15 - (i % 4) * 0.12
        legs.append(cylinder(f"L{i}", 0.025, 0.28, (sx * 0.22, y, 0.12), m_dark, rot=(1.1, 0, sx * 0.7)))
    mesh = join_meshes("ScorpMesh", segs + [head, claw_l, claw_r, sting_base, stinger] + eyes + legs)
    arm = make_armature("ScorpArm", [
        ("Root", (0, 0, 0.05), (0, 0, 0.2), None),
        ("Spine", (0, 0, 0.2), (0, -0.2, 0.25), "Root"),
        ("Head", (0, 0.1, 0.25), (0, 0.3, 0.3), "Spine"),
        ("Claw_L", (0, 0.15, 0.28), (-0.4, 0.3, 0.3), "Head"),
        ("Claw_R", (0, 0.15, 0.28), (0.4, 0.3, 0.3), "Head"),
        ("Tail", (0, -0.25, 0.3), (0, -0.7, 0.8), "Spine"),
        ("Leg1", (0, 0.05, 0.15), (-0.3, 0.1, 0.05), "Root"),
        ("Leg2", (0, 0.05, 0.15), (0.3, 0.1, 0.05), "Root"),
        ("Leg3", (0, -0.1, 0.15), (-0.3, -0.15, 0.05), "Root"),
        ("Leg4", (0, -0.1, 0.15), (0.3, -0.15, 0.05), "Root"),
    ])
    anims = _quad_idle_move_attack(arm, ["Leg1", "Leg2", "Leg3", "Leg4"], "Claw_L")
    # override attack to use stinger
    def attack(a):
        key_bone(a, "Tail", 1, rot=(0, 0, 0))
        key_bone(a, "Tail", 14, rot=(-1.0, 0, 0))
        key_bone(a, "Tail", 22, rot=(0.3, 0, 0))
        key_bone(a, "Tail", 40, rot=(0, 0, 0))
    anims[2] = ("attack", attack)
    return _finish("scorpion", arm, mesh, anims)


def build_shroom():
    clear_scene()
    m_cap = mat("Cap", (0.55, 0.12, 0.15), metallic=0.05, roughness=0.55, emission=(0.4, 0.05, 0.08, 1))
    m_stem = mat("Stem", (0.75, 0.7, 0.55), metallic=0.0, roughness=0.65)
    m_spot = mat("Spot", (0.9, 0.85, 0.4), metallic=0.0, roughness=0.4, emission=(0.8, 0.7, 0.2, 1))
    m_eye = mat("ShEye", (0.05, 0.05, 0.02), metallic=0.0, roughness=0.3, emission=(0.2, 1.0, 0.3, 1))
    stem = cylinder("Stem", 0.16, 0.55, (0, 0, 0.35), m_stem)
    cap = uv_sphere("Cap", 0.38, (0, 0, 0.75), m_cap, scale=(1.2, 1.2, 0.55))
    spots = [uv_sphere(f"S{i}", 0.05, (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.85), m_spot) for i, a in enumerate([0, 1.2, 2.4, 3.6, 4.8])]
    eyes = [uv_sphere(f"E{sx}", 0.04, (sx * 0.07, 0.14, 0.45), m_eye) for sx in (-1, 1)]
    mouth = cube("Mouth", 0.1, (0, 0.15, 0.35), mat("Mouth", (0.2, 0.05, 0.05), 0, 0.5), scale=(1.2, 0.3, 0.4))
    spores = [uv_sphere(f"Sp{i}", 0.03, (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.0), m_spot) for i, a in enumerate([0.5, 2.0, 3.5])]
    mesh = join_meshes("ShroomMesh", [stem, cap, mouth] + spots + eyes + spores)
    arm = make_armature("ShroomArm", [
        ("Root", (0, 0, 0.05), (0, 0, 0.2), None),
        ("Spine", (0, 0, 0.2), (0, 0, 0.55), "Root"),
        ("Head", (0, 0, 0.55), (0, 0, 0.85), "Spine"),
    ])
    def idle(a):
        for f, z in ((1, 0), (24, 0.04), (48, 0)):
            key_bone(a, "Head", f, loc=(0, 0, z)); key_bone(a, "Spine", f, rot=(0, z * 2, 0))
    def move(a):
        for i, f in enumerate((1, 16, 32, 48)):
            key_bone(a, "Spine", f, rot=(0.15 * math.sin(i), 0, 0.1 * math.cos(i)), loc=(0, 0.02 * math.sin(i), 0))
    def attack(a):
        key_bone(a, "Head", 1, loc=(0, 0, 0)); key_bone(a, "Head", 12, loc=(0, 0.1, 0.05)); key_bone(a, "Head", 20, loc=(0, 0.15, -0.02)); key_bone(a, "Head", 40, loc=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 10, rot=(0.3, 0.4, 0)); key_bone(a, "Spine", 28, rot=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 35, rot=(1.2, 0, 0), loc=(0, 0, -0.25))
    return _finish("shroom", arm, mesh, [("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death)])


def build_slime():
    clear_scene()
    m_slime = mat("Slime", (0.15, 0.55, 0.2, 0.55), metallic=0.0, roughness=0.25, alpha=0.55, emission=(0.05, 0.25, 0.08, 1))
    m_bone = mat("Bone", (0.85, 0.82, 0.7), metallic=0.0, roughness=0.45)
    m_eye = mat("SlEye", (0.9, 0.95, 0.3), metallic=0.0, roughness=0.2, emission=(0.8, 1.0, 0.2, 1))
    blob = uv_sphere("Blob", 0.4, (0, 0, 0.35), m_slime, scale=(1.15, 1.15, 0.85), segs=20, rings=12)
    drip = uv_sphere("Drip", 0.12, (0.15, 0.1, 0.08), m_slime, scale=(1, 1, 0.6))
    bones = [
        cylinder("Rib", 0.03, 0.25, (0, 0, 0.4), m_bone, rot=(0.5, 0.3, 0)),
        cube("Skull", 0.1, (-0.08, 0.05, 0.45), m_bone, scale=(0.9, 0.8, 1.0)),
        cone("Bone2", 0.03, 0.18, (0.1, -0.05, 0.35), m_bone, rot=(1.0, 0, 0.4)),
    ]
    eyes = [uv_sphere(f"E{sx}", 0.05, (sx * 0.1, 0.25, 0.5), m_eye) for sx in (-1, 1)]
    mesh = join_meshes("SlimeMesh", [blob, drip] + bones + eyes)
    arm = make_armature("SlimeArm", [
        ("Root", (0, 0, 0.05), (0, 0, 0.2), None),
        ("Spine", (0, 0, 0.2), (0, 0, 0.45), "Root"),
        ("Head", (0, 0, 0.45), (0, 0.1, 0.6), "Spine"),
    ])
    def idle(a):
        for f, s in ((1, 0), (24, 0.06), (48, 0)):
            key_bone(a, "Spine", f, loc=(0, 0, s), rot=(0, s, 0))
    def move(a):
        for i, f in enumerate((1, 12, 24, 36, 48)):
            key_bone(a, "Spine", f, loc=(0.04 * math.sin(i), 0.05 * math.cos(i), 0.02 * math.sin(i * 2)), rot=(0.1 * math.sin(i), 0, 0))
    def attack(a):
        key_bone(a, "Head", 1, loc=(0, 0, 0)); key_bone(a, "Head", 14, loc=(0, 0.15, 0.05)); key_bone(a, "Head", 40, loc=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, loc=(0, 0, 0)); key_bone(a, "Spine", 8, loc=(0.1, 0, 0)); key_bone(a, "Spine", 24, loc=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, loc=(0, 0, 0)); key_bone(a, "Spine", 35, loc=(0, 0, -0.25), rot=(0.8, 0, 0))
    return _finish("slime", arm, mesh, [("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death)], target_tris=4500)


def build_spider():
    clear_scene()
    m_body = mat("SpBody", (0.12, 0.08, 0.06), metallic=0.05, roughness=0.7)
    m_leg = mat("SpLeg", (0.18, 0.1, 0.06), metallic=0.05, roughness=0.65)
    m_eye = mat("SpEye", (0.6, 0.05, 0.02), metallic=0.0, roughness=0.2, emission=(1.0, 0.1, 0.02, 1))
    m_fang = mat("SpFang", (0.7, 0.7, 0.65), metallic=0.1, roughness=0.3)
    abdomen = uv_sphere("Abd", 0.28, (0, -0.2, 0.35), m_body, scale=(1.0, 1.2, 0.85))
    cephal = uv_sphere("Ceph", 0.18, (0, 0.2, 0.35), m_body)
    fangs = [cone(f"F{sx}", 0.03, 0.1, (sx * 0.05, 0.35, 0.28), m_fang, rot=(2.2, 0, sx * 0.2)) for sx in (-1, 1)]
    eyes = []
    for i, (x, y, z) in enumerate([(-0.06, 0.32, 0.42), (0.06, 0.32, 0.42), (-0.1, 0.28, 0.4), (0.1, 0.28, 0.4), (-0.04, 0.3, 0.45), (0.04, 0.3, 0.45)]):
        eyes.append(uv_sphere(f"E{i}", 0.02, (x, y, z), m_eye))
    legs = []
    for i in range(8):
        sx = -1 if i < 4 else 1
        y = 0.15 - (i % 4) * 0.1
        legs.append(cylinder(f"Leg{i}", 0.025, 0.45, (sx * 0.35, y, 0.25), m_leg, rot=(0.9, 0, sx * (0.5 + (i % 4) * 0.15))))
    hair = [cylinder(f"H{i}", 0.008, 0.08, (math.cos(a) * 0.2, -0.2 + math.sin(a) * 0.1, 0.5), m_leg, rot=(0.3, 0, a)) for i, a in enumerate([0, 1, 2, 3, 4, 5])]
    mesh = join_meshes("SpiderMesh", [abdomen, cephal] + fangs + eyes + legs + hair)
    arm = make_armature("SpiderArm", [
        ("Root", (0, 0, 0.1), (0, 0, 0.25), None),
        ("Spine", (0, 0, 0.25), (0, -0.1, 0.35), "Root"),
        ("Head", (0, 0.1, 0.35), (0, 0.3, 0.4), "Spine"),
        ("Leg1", (0, 0.05, 0.3), (-0.4, 0.15, 0.1), "Root"),
        ("Leg2", (0, 0.05, 0.3), (0.4, 0.15, 0.1), "Root"),
        ("Leg3", (0, -0.05, 0.3), (-0.4, -0.1, 0.1), "Root"),
        ("Leg4", (0, -0.05, 0.3), (0.4, -0.1, 0.1), "Root"),
    ])
    return _finish("spider", arm, mesh, _quad_idle_move_attack(arm, ["Leg1", "Leg2", "Leg3", "Leg4"], "Head"))


def build_vulture():
    clear_scene()
    m_feather = mat("Feather", (0.2, 0.12, 0.08), metallic=0.0, roughness=0.7)
    m_rot = mat("Rot", (0.35, 0.2, 0.1), metallic=0.0, roughness=0.6)
    m_skin = mat("NeckSkin", (0.55, 0.35, 0.28), metallic=0.0, roughness=0.5)
    m_beak = mat("Beak", (0.7, 0.55, 0.2), metallic=0.15, roughness=0.4)
    m_eye = mat("VEye", (0.05, 0.05, 0.02), metallic=0.0, roughness=0.25, emission=(0.9, 0.7, 0.1, 1))
    body = uv_sphere("Body", 0.28, (0, 0, 0.55), m_feather, scale=(0.75, 1.1, 0.85))
    neck = cylinder("Neck", 0.06, 0.28, (0, 0.25, 0.75), m_skin, rot=(0.8, 0, 0))
    head = uv_sphere("Head", 0.1, (0, 0.42, 0.95), m_skin)
    beak = cone("Beak", 0.04, 0.16, (0, 0.55, 0.9), m_beak, rot=(1.8, 0, 0))
    eye = uv_sphere("Eye", 0.025, (0.05, 0.48, 0.98), m_eye)
    wing_l = cube("WL", 0.5, (-0.45, 0, 0.6), m_feather, scale=(1.5, 0.12, 0.55), rot=(0.15, 0, 0.35))
    wing_r = cube("WR", 0.5, (0.45, 0, 0.6), m_feather, scale=(1.5, 0.12, 0.55), rot=(0.15, 0, -0.35))
    patch = cube("RotPatch", 0.15, (0.1, -0.15, 0.65), m_rot, scale=(0.8, 0.5, 0.3))
    legs = [cylinder(f"Leg{sx}", 0.03, 0.25, (sx * 0.08, -0.05, 0.25), m_skin) for sx in (-1, 1)]
    mesh = join_meshes("VultureMesh", [body, neck, head, beak, eye, wing_l, wing_r, patch] + legs)
    arm = make_armature("VultureArm", [
        ("Root", (0, 0, 0.2), (0, 0, 0.4), None),
        ("Spine", (0, 0, 0.4), (0, 0.1, 0.65), "Root"),
        ("Head", (0, 0.2, 0.75), (0, 0.4, 0.95), "Spine"),
        ("Wing_L", (0, 0, 0.6), (-0.6, 0, 0.6), "Spine"),
        ("Wing_R", (0, 0, 0.6), (0.6, 0, 0.6), "Spine"),
        ("Leg_L", (0, 0, 0.35), (-0.08, -0.05, 0.05), "Root"),
        ("Leg_R", (0, 0, 0.35), (0.08, -0.05, 0.05), "Root"),
    ])
    def idle(a):
        for f, z in ((1, 0), (24, 0.02), (48, 0)):
            key_bone(a, "Head", f, rot=(z * 3, 0, 0)); key_bone(a, "Wing_L", f, rot=(0, 0, 0.05 if f == 24 else 0)); key_bone(a, "Wing_R", f, rot=(0, 0, -0.05 if f == 24 else 0))
    def move(a):
        for i, f in enumerate((1, 12, 24, 36, 48)):
            flap = 0.6 if i % 2 else -0.4
            key_bone(a, "Wing_L", f, rot=(0, 0, flap)); key_bone(a, "Wing_R", f, rot=(0, 0, -flap))
            key_bone(a, "Spine", f, loc=(0, 0, 0.03 * math.sin(i)))
    def attack(a):
        key_bone(a, "Head", 1, rot=(0, 0, 0)); key_bone(a, "Head", 12, rot=(-1.0, 0, 0)); key_bone(a, "Head", 22, rot=(0.4, 0, 0)); key_bone(a, "Head", 40, rot=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 10, rot=(0.4, 0.3, 0)); key_bone(a, "Spine", 28, rot=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 35, rot=(1.5, 0, 0), loc=(0, 0, -0.3)); key_bone(a, "Wing_L", 35, rot=(0, 0, 1.2)); key_bone(a, "Wing_R", 35, rot=(0, 0, -1.2))
    return _finish("vulture", arm, mesh, [("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death)])


def build_wasp():
    clear_scene()
    m_arm = mat("WaspArmor", (0.7, 0.55, 0.1), metallic=0.35, roughness=0.35)
    m_black = mat("WaspBlack", (0.08, 0.08, 0.06), metallic=0.1, roughness=0.45)
    m_wing = mat("WaspWing", (0.7, 0.8, 0.85, 0.35), metallic=0.0, roughness=0.2, alpha=0.35)
    m_eye = mat("WaspEye", (0.05, 0.02, 0.0), metallic=0.0, roughness=0.25, emission=(1.0, 0.3, 0.0, 1))
    m_sting = mat("Sting", (0.3, 0.3, 0.35), metallic=0.7, roughness=0.3)
    head = uv_sphere("Head", 0.14, (0, 0.35, 0.7), m_black)
    thorax = uv_sphere("Thorax", 0.18, (0, 0.05, 0.6), m_arm, scale=(0.9, 1.0, 0.85))
    abdomen = uv_sphere("Abd", 0.22, (0, -0.3, 0.55), m_arm, scale=(0.85, 1.2, 0.8))
    stripe = cube("Stripe", 0.3, (0, -0.3, 0.55), m_black, scale=(1.0, 0.25, 0.9))
    eyes = [uv_sphere(f"E{sx}", 0.05, (sx * 0.08, 0.45, 0.75), m_eye) for sx in (-1, 1)]
    wing_l = cube("WL", 0.35, (-0.3, 0.05, 0.75), m_wing, scale=(1.3, 0.05, 0.5), rot=(0.2, 0, 0.4))
    wing_r = cube("WR", 0.35, (0.3, 0.05, 0.75), m_wing, scale=(1.3, 0.05, 0.5), rot=(0.2, 0, -0.4))
    stinger = cone("Stinger", 0.04, 0.2, (0, -0.55, 0.45), m_sting, rot=(1.8, 0, 0))
    legs = [cylinder(f"Leg{i}", 0.02, 0.22, (sx * 0.12, 0.0 - i * 0.05, 0.4), m_black, rot=(1.0, 0, sx * 0.5)) for i, sx in enumerate([-1, -1, -1, 1, 1, 1])]
    mesh = join_meshes("WaspMesh", [head, thorax, abdomen, stripe, wing_l, wing_r, stinger] + eyes + legs)
    arm = make_armature("WaspArm", [
        ("Root", (0, 0, 0.3), (0, 0, 0.45), None),
        ("Spine", (0, 0, 0.45), (0, 0.05, 0.6), "Root"),
        ("Head", (0, 0.2, 0.65), (0, 0.4, 0.75), "Spine"),
        ("Wing_L", (0, 0.05, 0.7), (-0.4, 0.05, 0.75), "Spine"),
        ("Wing_R", (0, 0.05, 0.7), (0.4, 0.05, 0.75), "Spine"),
        ("Tail", (0, -0.15, 0.55), (0, -0.55, 0.4), "Spine"),
    ])
    def idle(a):
        for f, z in ((1, 0), (16, 0.03), (32, 0), (48, 0.03)):
            key_bone(a, "Spine", f, loc=(0, 0, z)); key_bone(a, "Wing_L", f, rot=(0, 0, 0.2 if f in (16, 48) else -0.1)); key_bone(a, "Wing_R", f, rot=(0, 0, -0.2 if f in (16, 48) else 0.1))
    def move(a):
        for i, f in enumerate((1, 8, 16, 24, 32, 40, 48)):
            flap = 0.9 if i % 2 else -0.6
            key_bone(a, "Wing_L", f, rot=(0, 0, flap)); key_bone(a, "Wing_R", f, rot=(0, 0, -flap))
            key_bone(a, "Spine", f, loc=(0, 0.02 * math.sin(i), 0.02))
    def attack(a):
        key_bone(a, "Tail", 1, rot=(0, 0, 0)); key_bone(a, "Tail", 12, rot=(-0.8, 0, 0)); key_bone(a, "Tail", 20, rot=(0.5, 0, 0)); key_bone(a, "Tail", 40, rot=(0, 0, 0))
        key_bone(a, "Head", 12, rot=(-0.3, 0, 0)); key_bone(a, "Head", 40, rot=(0, 0, 0))
    def hit(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 10, rot=(0.35, 0.4, 0)); key_bone(a, "Spine", 28, rot=(0, 0, 0))
    def death(a):
        key_bone(a, "Spine", 1, rot=(0, 0, 0)); key_bone(a, "Spine", 35, rot=(1.4, 0, 0), loc=(0, 0, -0.25)); key_bone(a, "Wing_L", 35, rot=(0, 0, 1.0)); key_bone(a, "Wing_R", 35, rot=(0, 0, -1.0))
    return _finish("wasp", arm, mesh, [("idle", idle), ("move", move), ("attack", attack), ("hit", hit), ("death", death)])


BUILDERS = {
    "bat": build_bat,
    "crab": build_crab,
    "hound": build_hound,
    "scorpion": build_scorpion,
    "shroom": build_shroom,
    "slime": build_slime,
    "spider": build_spider,
    "vulture": build_vulture,
    "wasp": build_wasp,
}
