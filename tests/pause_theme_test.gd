extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await main.board_controller.board_view.entrance_finished
	main.current_level_index = main.LEVEL_IDS.find("1-21")
	main._load_current_level()
	var board: HexBoardView = main.board_controller.board_view
	await board.entrance_finished
	var state: BoardState = main.level_controller.board_state
	var editable: Array[CellDefinition] = []
	for cell in state.level.cells:
		if cell.is_editable():
			editable.append(cell)
	main.board_controller.select_cell(editable[0].id)
	main.board_controller.pick_selected_color(editable[0].answer_type)
	main.level_controller.verify_selected()
	main.board_controller.select_cell(editable[1].id)
	main.board_controller.pick_selected_color(editable[1].candidate_types[0])
	await get_tree().create_timer(0.5).timeout
	main.pause_menu.open()
	await get_tree().create_timer(0.25).timeout
	var elapsed := state.elapsed_seconds
	var selected := state.selected_cell_id
	var paused_pixels: Array[Color] = []
	var original_dark := ThemeManager.is_dark
	for dark in [not original_dark, original_dark]:
		ThemeManager.set_dark(dark, false)
		# The palette must be applied synchronously while gameplay is paused.
		assert(get_tree().paused)
		_check_palette(board)
		await get_tree().create_timer(0.1).timeout
		_check_palette(board)
		assert(state.elapsed_seconds == elapsed)
		assert(state.selected_cell_id == selected)
		assert(state.get_runtime(editable[0].id).solved)
		assert(not state.get_runtime(editable[1].id).solved)
		if DisplayServer.get_name() != "headless":
			paused_pixels = _sample_brick_pixels(board)
	await main.pause_menu.close()
	_check_palette(board)
	await get_tree().process_frame
	_check_palette(board)
	if not paused_pixels.is_empty():
		var resumed_pixels := _sample_brick_pixels(board)
		for index in paused_pixels.size():
			var before := paused_pixels[index]
			var after := resumed_pixels[index]
			assert(absf(before.r - after.r) < 0.02 and absf(before.g - after.g) < 0.02 and absf(before.b - after.b) < 0.02, "Rendered brick colors must already match before leaving pause.")
	print("PASS: paused theme switches update fixed/solved/candidate fills and active scopes immediately, preserving gameplay state and showing settled colors on resume.")
	AudioManager.bgm.stop()
	await get_tree().process_frame
	get_tree().quit()


func _check_palette(board: HexBoardView) -> void:
	var active := 0
	for view in board._cell_views.values():
		assert(view._current_fill == view._fill_color(), "Brick palette must already be settled during pause and on resume.")
		if view.scope_overlay.target_amount > 0.0:
			active += 1
			assert(view.scope_overlay.color == view.scope_overlay.target_color)
	assert(active == 1)


func _sample_brick_pixels(board: HexBoardView) -> Array[Color]:
	var pause_menu := get_tree().current_scene.get_node("CanvasLayer/PauseMenu") as Control
	var pause_visible := pause_menu.visible
	# Inspect the board behind the opaque pause menu without unpausing gameplay.
	pause_menu.hide()
	RenderingServer.force_draw()
	var image := get_viewport().get_texture().get_image()
	var factor := Vector2(image.get_size()) / get_viewport().get_visible_rect().size
	var pixels: Array[Color] = []
	for view in board._cell_views.values():
		var point := Vector2i(view.to_global(Vector2(0, -view.radius * 0.65)) * factor)
		pixels.append(image.get_pixelv(point))
	pause_menu.visible = pause_visible
	return pixels
