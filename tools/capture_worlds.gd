extends SceneTree
## Windowed Godot capture of worlds 1-3 (levels 0, 4, 5, 9, 10, 14).
## Run WITHOUT --headless, with the phone renderer:
##   Godot_v4.7.2-stable_win64.exe --path W:\street-fighter-game --rendering-method gl_compatibility --script res://tools/capture_worlds.gd

const SHOTS := [
	[0, "emberfall_level.png"],
	[4, "emberfall_boss.png"],
	[5, "mire_level.png"],
	[9, "mire_boss.png"],
	[10, "crystal_level.png"],
	[14, "crystal_boss.png"],
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://media/env-3d/godot/")
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var only := OS.get_environment("CAPTURE_ONLY")
	for shot in SHOTS:
		if only != "" and String(shot[1]) != only:
			continue
		var level := int(shot[0])
		Engine.set_meta("level", level)
		Engine.set_meta("dungeon_seed", 42)
		# Story.SKIP_SEEN skips the intro when this flag is already set.
		Engine.set_meta("story_%d_intro" % level, true)
		var packed: PackedScene = load("res://Main.tscn")
		var game: Node = packed.instantiate()
		root.add_child(game)
		for i in 30:
			await process_frame
		if level % 5 == 4 and game.get("dungeon") != null and game.get("player") != null:
			var d = game.dungeon
			var bid := String(d.boss_id())
			if bid != "":
				var c: Vector2 = d.room_center(bid)
				game.player.global_position = c
				if game.get("camera") != null:
					game.camera.global_position = c
					game.camera.reset_smoothing()
		for i in 25:
			await process_frame
		RenderingServer.force_draw(true)
		await process_frame
		var img := root.get_viewport().get_texture().get_image()
		if img:
			var path := out_dir + String(shot[1])
			img.save_png(path)
			print("SAVED ", path)
		for c in game.get_children():
			if c.has_method("grab_frame"):
				var shot3d: Image = c.grab_frame()
				if shot3d:
					var p3 := out_dir + "view3d_" + String(shot[1])
					shot3d.save_png(p3)
					print("SAVED3D ", p3)
				if c.has_method("debug_stats"):
					print("STATS ", shot[1], " ", c.debug_stats())
		print("FRAME draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			" fps=", Engine.get_frames_per_second())
		game.queue_free()
		for i in 3:
			await process_frame
	print("GODOT_CAPTURE_DONE")
	quit(0)
