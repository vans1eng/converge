extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	# Include the larger chapter-two board even when the playable demo lists chapter one only.
	if not main.LEVEL_IDS.has("2-25"):
		main.LEVEL_IDS.append("2-25")
	var samples := 0
	for dark in [false, true]:
		ThemeManager.set_dark(dark, false)
		for level_id in ["1-1", "1-6", "1-20", "1-25", "1-26", "2-25"]:
			main.current_level_index = main.LEVEL_IDS.find(level_id)
			assert(main.current_level_index >= 0)
			main._load_current_level()
			await get_tree().create_timer(0.25).timeout
			await RenderingServer.frame_post_draw
			samples += _check_pixels(main, true)
			await get_tree().create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			samples += _check_pixels(main, false)
	print("PASS: %d rendered cell colors match palette during and after entrance in both themes." % samples)
	get_tree().quit()


func _check_pixels(main: Node, during_entrance: bool) -> int:
	var board: HexBoardView = main.board_controller.board_view
	var image := get_viewport().get_texture().get_image()
	var factor := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var count := 0
	for view in board._cell_views.values():
		if during_entrance and view.scale.x < 0.5:
			continue
		assert(view._current_fill == view._fill_color())
		assert(view.state_mask_opacity == 0.0)
		assert(view.scope_overlay.target_amount == 0.0)
		var point: Vector2i = Vector2i(view.to_global(Vector2(0.0, -view.radius * 0.65)) * factor)
		var actual := image.get_pixelv(point)
		var expected: Color = view._fill_color()
		assert(absf(actual.r - expected.r) < 0.012 and absf(actual.g - expected.g) < 0.012 and absf(actual.b - expected.b) < 0.012, "%s rendered %s expected %s" % [view.name, actual, expected])
		count += 1
	return count
