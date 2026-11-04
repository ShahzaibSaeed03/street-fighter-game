"""STEP 1: Audit Kenney env GLBs. Focus detail on dungeon+cave; summarize other kits.
Run: blender --background --python tools/blender/env/audit_kits.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import bpy

ROOT = Path(r"W:\street-fighter-game")
CC0 = ROOT / "assets" / "models" / "env_cc0"
OUT = CC0 / "AUDIT.md"

FOCUS = {
    "kenney_modular-dungeon-kit_1.0": "W1 Emberfall / W8 Night Citadel",
    "kenney_modular-cave-kit_1.0": "W1 Emberfall / W3 Crystal Deep",
}
SUMMARY_KITS = {
    "kenney_graveyard-kit_5.0": "W2 / W8",
    "kenney_factory-kit_3.0": "W4 Clockwork",
    "kenney_fantasy-town-kit_2.0": "W2 / W7",
    "kenney_castle-kit": "W7 / W8",
    "kenney_pirate-kit": "W5 Coral Abyss",
    "kenney_nature-kit": "W2 / W5 / W6 / W7",
}

# Kenney modular kits: piece about 1 unit wide; we normalize so 1 tile = 2 m.
TARGET_TILE_M = 2.0


def log(m): print(m, flush=True)


def clear():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for b in list(coll):
            try: coll.remove(b)
            except Exception: pass


def count_tris(objs):
    t = 0
    for o in objs:
        if o.type != "MESH":
            continue
        o.data.calc_loop_triangles()
        t += len(o.data.loop_triangles)
    return t


def bounds(objs):
    import mathutils
    mins = [1e9, 1e9, 1e9]
    maxs = [-1e9, -1e9, -1e9]
    anyb = False
    for o in objs:
        if o.type != "MESH":
            continue
        for corner in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
            anyb = True
    if not anyb:
        return None
    return {
        "min": [round(v, 4) for v in mins],
        "max": [round(v, 4) for v in maxs],
        "size": [round(maxs[i] - mins[i], 4) for i in range(3)],
    }


def textures_used():
    names = []
    for img in bpy.data.images:
        if img.name in {"Render Result", "Viewer Node"}:
            continue
        names.append(f"{img.name} ({img.size[0]}x{img.size[1]})")
    return names


def audit_glb(path: Path) -> dict:
    clear()
    before = set(bpy.data.objects)
    try:
        bpy.ops.import_scene.gltf(filepath=str(path))
    except Exception as e:
        return {"file": path.name, "error": str(e)}
    objs = [o for o in bpy.data.objects if o not in before]
    meshes = [o for o in objs if o.type == "MESH"]
    b = bounds(meshes)
    sx = b["size"][0] if b else 0.0
    # Heuristic: Kenney modular pieces are often ~1 unit; scale to 2m tile
    scale_to_2m = (TARGET_TILE_M / sx) if sx > 0.01 else 1.0
    return {
        "file": path.name,
        "bytes": path.stat().st_size,
        "mesh_count": len(meshes),
        "tris": count_tris(meshes),
        "bounds": b,
        "textures": textures_used(),
        "suggested_scale_to_2m_tile": round(scale_to_2m, 4),
    }


def glb_files(kit: str) -> list[Path]:
    root = CC0 / kit
    return sorted(root.rglob("*.glb"))


def main():
    lines = [
        "# Environment CC0 audit",
        "",
        "Kenney kits: CC0. Normalize so **1 modular tile ≈ 2 m** in Blender/Godot.",
        "Game mapping: 64 px (TILE) → 2.0 m (`px_to_m = 2/64`).",
        "",
        "## World mapping (usable kits)",
        "",
        "| World | Kits | Poly Haven textures |",
        "|-------|------|---------------------|",
        "| 1 Emberfall | dungeon + cave | volcanic_rock_tiles, rock_boulder_cracked, volcanic_herringbone_01 |",
        "| 2 Whispering Mire | graveyard + fantasy-town + nature | mud/moss |",
        "| 3 Crystal Deep | cave | rock_05/06, boulder_dry |",
        "| 4 Clockwork | factory | rusty_metal, metal_plate, corrugated_iron |",
        "| 5 Coral Abyss | pirate + nature | sand/rocks |",
        "| 6 Frostpeak | nature | snow + rock_01 |",
        "| 7 Gilded Palace | fantasy-town + castle | sandstone/marble/sand |",
        "| 8 Night Citadel | castle + graveyard + dungeon | castle brick |",
        "",
    ]

    detail = {}
    for kit, worlds in FOCUS.items():
        log(f"=== auditing {kit} ===")
        rows = []
        for p in glb_files(kit):
            # Prefer GLB format folder pieces; skip duplicates in other formats if nested oddly
            if "FBX" in str(p) or "OBJ" in str(p):
                continue
            log(f"  {p.name}")
            rows.append(audit_glb(p))
        detail[kit] = rows
        lines.append(f"## {kit} ({worlds})")
        lines.append("")
        lines.append("| File | KB | Tris | Meshes | Size XYZ | Scale→2m | Textures |")
        lines.append("|------|----|------|--------|----------|----------|----------|")
        for r in rows:
            if "error" in r:
                lines.append(f"| {r['file']} | ERR | | | | | {r['error']} |")
                continue
            sz = r["bounds"]["size"] if r["bounds"] else [0, 0, 0]
            tex = ", ".join(r["textures"][:2]) if r["textures"] else "embedded/none"
            lines.append(
                f"| `{r['file']}` | {r['bytes']/1024:.1f} | {r['tris']} | {r['mesh_count']} | "
                f"{sz[0]:.2f}×{sz[1]:.2f}×{sz[2]:.2f} | {r['suggested_scale_to_2m_tile']} | {tex} |"
            )
        lines.append("")
        # Usable Emberfall picks
        if "dungeon" in kit:
            lines.append("**Emberfall picks:** `template-floor*`, `template-wall*`, `template-wall-corner`, "
                         "`corridor`, `corridor-corner`, `stairs`, `gate`, `gate-door`, `room-corner` "
                         "(retexture with volcanic PBR; avoid shipping raw Kenney materials).")
        if "cave" in kit:
            lines.append("**Emberfall/Crystal picks:** cave `template-*`, `gate-rock`, `ladder`, `stairs` "
                         "(pair with volcanic or crystal textures).")
        lines.append("")

    lines.append("## Other kits (file inventory — full mesh audit deferred to per-world builds)")
    lines.append("")
    for kit, worlds in SUMMARY_KITS.items():
        files = [p for p in glb_files(kit) if "FBX" not in str(p) and "OBJ" not in str(p)]
        total = sum(p.stat().st_size for p in files)
        lines.append(f"### {kit} ({worlds})")
        lines.append(f"- {len(files)} GLB, {total/1e6:.1f} MB total")
        # list first 25 names as usable candidates
        names = [p.name for p in files[:40]]
        lines.append("- Sample: " + ", ".join(f"`{n}`" for n in names))
        if len(files) > 40:
            lines.append(f"- … +{len(files)-40} more")
        lines.append("")

    lines.append("## Scale notes")
    lines.append("- Measured dungeon `template-floor.glb` / wall templates drive `suggested_scale_to_2m_tile`.")
    lines.append("- Emberfall export kit applies a uniform scale so floors sit on a 2 m grid.")
    lines.append("- Ignore `kenney_car-kit`.")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    (CC0 / "AUDIT.json").write_text(json.dumps(detail, indent=2), encoding="utf-8")
    log(f"Wrote {OUT}")


if __name__ == "__main__":
    main()
