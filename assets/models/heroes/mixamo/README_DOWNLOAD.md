# Mixamo download steps (Raasta 2) — aap yeh karo

Site: https://www.mixamo.com  (free Adobe account)

## Per hero — 1 character body + animations

| Hero | Folder | Mixamo tip |
|---|---|---|
| Jake | `mixamo/ayaan/` | Male, short dark hair / beard-ish if available |
| Maya | `mixamo/zara/` | Female, athletic |
| Marcus | `mixamo/kabir/` | Male, bulkier |

### A) Character (with skin) — once per hero
1. Mixamo → **Characters** → pick closest look  
2. Click **Download**  
3. Format: **FBX Binary (.fbx)**  
4. Skin: **With Skin**  
5. Pose: **T-pose** (or current)  
6. Save as:
   - `ayaan/body.fbx`
   - `zara/body.fbx`
   - `kabir/body.fbx`

### B) Animations — same for each (Without Skin, so they share the body)
For each hero folder, download these (Format FBX, **Without Skin**, 30 fps):

| File name to save | Mixamo search |
|---|---|
| `idle.fbx` | Idle / Standing Idle |
| `walk.fbx` | Walking |
| `run.fbx` | Running |
| `slash.fbx` | Sword And Shield Slash (or Standing Melee Attack Horizontal) |
| `dodge.fbx` | Dodging / Rolling |

Save inside that hero’s folder, e.g. `mixamo/ayaan/idle.fbx`.

### When done
Chat me bolo: **“mixamo files ready”**  
Phir agent Blender script chalayega → cape/armor/sword/bow add → `export/*.glb` → Godot.
