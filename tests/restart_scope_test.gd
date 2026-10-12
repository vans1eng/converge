extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var main := preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await main.board_controller.board_view.entrance_finished
	assert(main.level_controller.load_level("2-4"))
	var board: HexBoardView = main.board_controller.board_view
	await board.entrance_finished
	var state: BoardState = main.level_controller.board_state
	var known: Array[CellDefinition] = []
	var target: CellDefinition
	for cell in state.level.cells:
		if cell.is_editable():
			target = cell
		elif not cell.is_black():
			known.append(cell)
	assert(known.size() >= 2 and target != null)
	for cell in known.slice(0, 2):
		var event := InputEventMouseButton.new()
		event.position = board._cell_views[cell.id].global_position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		board._unhandled_input(event)
		assert(board._neighbor_masks_enabled.size() == 1)
		assert(_active_scopes(board) == 1)
		assert(not board._cell_views[cell.id].scope_overlay.outlines.is_empty())
	main.board_controller.select_cell(target.id)
	main.board_controller.pick_selected_color(target.candidate_types[0])
	assert(_active_scopes(board) == 1)
	var view: HexCellView = board._cell_views[target.id]
	assert(view._fill_color() == ThemeManager.get_palette().gray)
	main.board_controller.pick_selected_color(target.answer_type)
	main.level_controller.verify_selected()
	assert(state.get_runtime(target.id).solved)
	assert(view._fill_color() == view._brick_color(target.answer_type))
	assert(view._target_state_mask_opacity() == HexCellView.SOLVED_MASK_OPACITY)
	state.mistakes = 3
	var old_state := state
	# The HUD button resets data before outgoing bricks finish shrinking.
	main.restart_button.pressed.emit()
	assert(main._restart_active and board._exit_active)
	assert(main.level_controller.board_state != old_state)
	assert(main.level_controller.board_state.mistakes == 0)
	assert(board.board_state == old_state)
	main._restart_level() # repeated requests must not start another transition
	await board.entrance_finished
	await get_tree().process_frame
	assert(not main._restart_active)
	assert(board.board_state == main.level_controller.board_state)
	assert(main.input_controller.gameplay_input_enabled)
	assert(_active_scopes(board) == 0)
	state = main.level_controller.board_state
	state.mistakes = 5
	main.pause_menu.open()
	await get_tree().create_timer(0.25).timeout
	main.pause_menu.restart_button.pressed.emit()
	assert(main.pause_menu._is_closing and main.pause_menu.visible)
	assert(main.level_controller.board_state == state and state.mistakes == 5)
	assert(not board._exit_active)
	assert(not board.visible)
	await get_tree().create_timer(0.1).timeout
	assert(main.pause_menu.visible and not board.visible)
	assert(main.level_controller.board_state == state)
	await board.entrance_finished
	await get_tree().process_frame
	assert(not get_tree().paused and not main.pause_menu.visible)
	assert(board.visible)
	assert(main.level_controller.board_state.mistakes == 0)
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	main._unhandled_input(key)
	assert(main._restart_active and board._exit_active)
	await board.entrance_finished
	await get_tree().process_frame
	assert(not main._restart_active and main.input_controller.gameplay_input_enabled)
	print("PASS: single outlined scope, neutral candidates, immediate HUD/button/R reset, pause fade before reset, exit/entrance ordering and repeated restart guard.")
	get_tree().quit()


func _active_scopes(board: HexBoardView) -> int:
	var count := 0
	for view in board._cell_views.values():
		if view.scope_overlay.target_amount > 0.0:
			count += 1
	return count
