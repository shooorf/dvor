extends Node

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))

	var ps := load("res://src/world/arena_level.tscn") as PackedScene
	var arena := ps.instantiate()
	add_child(arena)

	for ch in arena.get_children():
		if ch is CanvasLayer:
			(ch as CanvasLayer).visible = false

	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.current = true
	arena.add_child(cam)

	var stalk_target := Vector3(-68.0, TerrainBuilder.get_height(-68.0, 22.0), 22.0)
	var stalks_group := arena.find_child("MeadowSeedStalks", true, false)
	if stalks_group != null and stalks_group.get_child_count() > 0:
		for mch in stalks_group.get_children():
			if mch is MultiMeshInstance3D:
				var mmi := mch as MultiMeshInstance3D
				if mmi.multimesh != null and mmi.multimesh.instance_count > 12:
					for idx in range(mmi.multimesh.instance_count):
						var xf := mmi.multimesh.get_instance_transform(idx)
						var wp := mmi.global_position + xf.origin
						if wp.x < -62.0 and wp.x > -80.0 and absf(wp.z) < 42.0:
							stalk_target = wp
							break
					if stalk_target.x != -68.0:
						break

	print("Found stalk_target at: ", stalk_target)

	var out_dir := "C:/Users/sh/.gemini/antigravity/brain/22e343fd-2a33-40fe-ad8b-72d46221857f/scratch"
	var shots := [
		{
			"file": "verify_1_border_fence.png",
			"pos": Vector3(-80.5, TerrainBuilder.get_height(-80.5, 14.0) + 1.65, 14.0),
			"look": Vector3(-94.0, TerrainBuilder.get_height(-94.0, 5.0) + 3.0, 5.0),
		},
		{
			"file": "verify_2_meadow_overview.png",
			"pos": Vector3(-35.5, TerrainBuilder.get_height(-35.5, 29.0) + 3.6, 29.0),
			"look": Vector3(-40.5, TerrainBuilder.get_height(-40.5, 24.5) + 0.20, 24.5),
		},
		{
			"file": "verify_3_golden_stalks.png",
			"pos": stalk_target + Vector3(2.35, 1.25, 1.95),
			"look": stalk_target + Vector3(0.0, 0.45, 0.0),
		},
		{
			"file": "verify_4_meadow_to_border.png",
			"pos": Vector3(-58.0, TerrainBuilder.get_height(-58.0, -16.0) + 2.1, -16.0),
			"look": Vector3(-92.0, TerrainBuilder.get_height(-92.0, -24.0) + 3.2, -24.0),
		},
	]

	for _f in range(6):
		await get_tree().process_frame

	for s in shots:
		cam.global_position = s["pos"]
		cam.look_at(s["look"], Vector3.UP)
		for _w in range(4):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s" % [out_dir, s["file"]])
		print("Saved ", s["file"])

	get_tree().quit(0)
