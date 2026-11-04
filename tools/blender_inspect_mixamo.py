"""Inspect Mixamo body.fbx files — mesh/tri/bone/material/texture report."""
from __future__ import annotations

import json
from pathlib import Path

import bpy

ROOT = Path(r"W:\street-fighter-game")
MIXAMO = ROOT / "assets" / "models" / "heroes" / "mixamo"
HEROES = ("ayaan", "zara", "kabir")
OUT = ROOT / "tools" / "_mixamo_inspect.json"


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.images, bpy.data.actions):
        for b in list(coll):
            coll.remove(b)


def inspect(hid: str) -> dict:
    clear()
    path = MIXAMO / hid / "body.fbx"
    report = {"id": hid, "path": str(path), "ok": False}
    try:
        bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True)
    except Exception as e:
        report["error"] = str(e)
        return report

    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    tris = 0
    mesh_info = []
    for m in meshes:
        me = m.data
        # ensure triangles count
        me.calc_loop_triangles()
        t = len(me.loop_triangles)
        tris += t
        mats = [slot.material.name if slot.material else None for slot in m.material_slots]
        mesh_info.append({"name": m.name, "verts": len(me.vertices), "tris": t, "materials": mats})

    bones = []
    if arms:
        bones = [b.name for b in arms[0].data.bones]

    mats = []
    for mat in bpy.data.materials:
        entry = {"name": mat.name, "textures": []}
        if mat.use_nodes and mat.node_tree:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    img = n.image
                    entry["textures"].append({
                        "image": img.name,
                        "size": list(img.size) if img.size else None,
                        "filepath": img.filepath,
                        "packed": bool(img.packed_file),
                    })
        mats.append(entry)

    images = []
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}:
            continue
        images.append({
            "name": img.name,
            "size": list(img.size) if img.size else None,
            "filepath": img.filepath,
            "packed": bool(img.packed_file),
            "users": img.users,
        })

    report.update({
        "ok": True,
        "mesh_count": len(meshes),
        "triangle_count": tris,
        "armature_count": len(arms),
        "armature_name": arms[0].name if arms else None,
        "bone_count": len(bones),
        "bones": bones,
        "meshes": mesh_info,
        "materials": mats,
        "images": images,
    })
    return report


def main():
    results = [inspect(h) for h in HEROES]
    OUT.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print("WROTE", OUT, flush=True)
    for r in results:
        if not r.get("ok"):
            print(f"FAIL {r['id']}: {r.get('error')}", flush=True)
            continue
        print(f"=== {r['id']} ===", flush=True)
        print(f"  meshes={r['mesh_count']} tris={r['triangle_count']} bones={r['bone_count']}", flush=True)
        print(f"  armature={r['armature_name']}", flush=True)
        print(f"  materials={len(r['materials'])} images={len(r['images'])}", flush=True)
        for im in r["images"]:
            print(f"    tex {im['name']} size={im['size']} packed={im['packed']}", flush=True)
        mixa = [b for b in r["bones"] if "mixamo" in b.lower()]
        print(f"  mixamorig bones={len(mixa)} sample={mixa[:8]}", flush=True)


if __name__ == "__main__":
    main()
