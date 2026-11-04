"""STEP 1: Inspect Mixamo enemy body.fbx + shared anims. Writes REPORT.md."""
from __future__ import annotations

import json
from pathlib import Path

import bpy

ROOT = Path(r"W:\street-fighter-game")
EN = ROOT / "assets" / "models" / "enemies"
BODIES = ("skeleton", "ghoul", "golem", "imp", "wraith", "yeti", "knight")
ANIMS = ("idle", "walk", "attack", "death", "hit", "run", "slash")
OUT_JSON = ROOT / "tools" / "_enemy_inspect.json"
OUT_MD = EN / "REPORT.md"


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.images, bpy.data.actions):
        for b in list(coll):
            try:
                coll.remove(b)
            except Exception:
                pass


def fbx_magic(path: Path) -> bool:
    raw = path.read_bytes()[:64]
    return b"Kaydara FBX Binary" in raw


def inspect_body(species: str) -> dict:
    clear()
    path = EN / species / "body.fbx"
    r = {"species": species, "path": str(path), "exists": path.exists(), "ok": False}
    if not path.exists():
        r["error"] = "missing"
        return r
    r["bytes"] = path.stat().st_size
    r["mb"] = round(r["bytes"] / 1e6, 2)
    r["kaydara"] = fbx_magic(path)
    try:
        bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True)
    except Exception as e:
        r["error"] = str(e)
        return r
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    tris = 0
    mesh_info = []
    for m in meshes:
        m.data.calc_loop_triangles()
        t = len(m.data.loop_triangles)
        tris += t
        mesh_info.append({"name": m.name, "verts": len(m.data.vertices), "tris": t})
    bones = [b.name for b in arms[0].data.bones] if arms else []
    images = []
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}:
            continue
        images.append({
            "name": img.name,
            "size": list(img.size) if img.size else None,
            "packed": bool(img.packed_file),
        })
    mats = [m.name for m in bpy.data.materials]
    r.update({
        "ok": True,
        "mesh_count": len(meshes),
        "triangle_count": tris,
        "armature": arms[0].name if arms else None,
        "bone_count": len(bones),
        "bones_sample": bones[:12],
        "mixamo_bones": sum(1 for b in bones if "mixamo" in b.lower()),
        "materials": mats,
        "images": images,
        "meshes": mesh_info,
    })
    return r


def inspect_anims() -> list:
    rows = []
    for a in ANIMS:
        p = EN / "shared" / f"{a}.fbx"
        row = {"name": a, "path": str(p), "exists": p.exists()}
        if p.exists():
            row["bytes"] = p.stat().st_size
            row["mb"] = round(row["bytes"] / 1e6, 3)
            row["kaydara"] = fbx_magic(p)
        rows.append(row)
    return rows


def write_md(bodies: list, anims: list):
    lines = [
        "# Mixamo enemies — STEP 1 report",
        "",
        "## Bodies",
        "",
        "| Species | MB | Kaydara | Meshes | Tris | Bones | Textures |",
        "|---|---:|:---:|---:|---:|---:|---|",
    ]
    for b in bodies:
        if not b.get("ok"):
            lines.append(f"| {b['species']} | - | - | - | - | - | ERROR: {b.get('error')} |")
            continue
        tex = ", ".join(f"{i['name']} {i['size']}" for i in b["images"]) or "(none)"
        lines.append(
            f"| {b['species']} | {b['mb']} | {b['kaydara']} | {b['mesh_count']} | "
            f"{b['triangle_count']} | {b['bone_count']} | {tex} |"
        )
    lines += ["", "## Shared animations", "", "| Anim | MB | Kaydara |", "|---|---:|:---:|"]
    for a in anims:
        if not a.get("exists"):
            lines.append(f"| {a['name']} | MISSING | - |")
        else:
            lines.append(f"| {a['name']} | {a['mb']} | {a['kaydara']} |")
    lines += [
        "",
        "## Notes",
        "- Bone prefixes may be `mixamorig:` or `mixamorigN:` — normalize in export pipeline.",
        "- `wraith` GLB will also cover game species `ghost`.",
        "- Missing (non-Mixamo): bat, crab, hound, scorpion, shroom, slime, spider, vulture, wasp.",
        "",
    ]
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")


def main():
    bodies = [inspect_body(s) for s in BODIES]
    anims = inspect_anims()
    OUT_JSON.write_text(json.dumps({"bodies": bodies, "anims": anims}, indent=2), encoding="utf-8")
    write_md(bodies, anims)
    print("WROTE", OUT_MD, flush=True)
    for b in bodies:
        if b.get("ok"):
            print(f"  {b['species']}: tris={b['triangle_count']} mb={b['mb']} bones={b['bone_count']}", flush=True)
        else:
            print(f"  FAIL {b['species']}: {b.get('error')}", flush=True)
    for a in anims:
        print(f"  anim {a['name']}: exists={a.get('exists')} kaydara={a.get('kaydara')}", flush=True)


if __name__ == "__main__":
    main()
