extends SceneTree
## Headless check: parse EnemyModels paths, load every GLB, print missing / anim lists.
## godot --headless --path . --script res://tools/verify_enemy_models.gd

func _init() -> void:
	print("=== ENEMY MODEL VERIFY ===")
	var species := [
		"bat", "crab", "ghost", "ghoul", "golem", "hound", "imp", "knight",
		"scorpion", "shroom", "skeleton", "slime", "spider", "vulture", "wasp",
		"wraith", "yeti",
	]
	var ok := 0
	var fail := 0
	for s in species:
		var path := "res://assets/models/enemies/%s/model.glb" % s
		if not ResourceLoader.exists(path):
			print("MISSING ", path)
			fail += 1
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			print("LOAD_FAIL ", path)
			fail += 1
			continue
		var root := packed.instantiate()
		var anim := _find_anim(root)
		var names: PackedStringArray = PackedStringArray()
		if anim:
			names = anim.get_animation_list()
		print("OK ", s, " anims=", names)
		root.free()
		ok += 1
	# Script parse smoke for new files
	for p in ["res://EnemyModels.gd", "res://EnemyLook.gd", "res://Guard.gd"]:
		var scr = load(p)
		print("SCRIPT ", p, " -> ", scr != null)
		if scr == null:
			fail += 1
	print("SUMMARY ok=", ok, " fail=", fail)
	quit(0 if fail == 0 else 1)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null
