extends SceneTree
## Headless-ish Emberfall capture: loads Game at level 0 / boss level 4, saves PNGs.
## godot --path . --script res://tools/screenshot_emberfall.gd

const OUT := "res://media/env-3d/emberfall/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _capture_level(0, "level01_emberfall.png")
	await _capture_level(4, "boss_emberfall.png")
	print("EMBERFALL_SHOTS_DONE")
	quit(0)


func _capture_level(idx: int, filename: String) -> void:
	Engine.set_meta("level", idx)
	Engine.set_meta("dungeon_seed", 42)
	var packed: PackedScene = load("res://Main.tscn")
	if packed == null:
		push_error("Main.tscn missing")
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	# Let Env3D build + a few frames render
	for i in 45:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		var path := ProjectSettings.globalize_path(OUT + filename)
		img.save_png(path)
		print("Saved ", path, " ", img.get_width(), "x", img.get_height())
	game.queue_free()
	await process_frame
