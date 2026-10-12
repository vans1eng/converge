extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	AudioManager.bgm.stop()
	AudioManager.set_sound_enabled(false)
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.level_controller.level_completed.disconnect(game._on_level_completed)
	var board: HexBoardView = game.board_controller.board_view
	await board.entrance_finished
	assert(game.level_controller.load_level("2-41"))
	await board.entrance_finished
	var state: BoardState = game.level_controller.board_state
	var red: CellDefinition
	var green: CellDefinition
	var other: CellDefinition
	var known: CellDefinition
	var wall: CellDefinition
	for cell in state.level.cells:
		if cell.is_black(): wall = cell
		elif not cell.is_editable(): known = cell
		elif cell.answer_type == "red" and red == null: red = cell
		elif cell.answer_type == "green" and green == null: green = cell
		else: other = cell
	assert(red != null and green != null and other != null and known != null and wall != null)
	# The middle button selects without verifying; scrolling is a reversible hypothesis.
	_click(board, other.id, MOUSE_BUTTON_MIDDLE)
	assert(state.selected_cell_id == other.id and state.mistakes == 0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game.input_controller._input(wheel)
	assert(state.get_runtime(other.id).candidate_pick == "red")
	assert(board._cell_views[other.id].scope_overlay.target_amount == 1.0)
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	game.input_controller._input(wheel)
	assert(state.get_runtime(other.id).candidate_pick == "green")
	assert(not state.get_runtime(other.id).solved and state.mistakes == 0)
	# Fast checks target the clicked brick, not the selected hypothesis.
	_click(board, red.id, MOUSE_BUTTON_RIGHT)
	assert(state.mistakes == 1 and not state.get_runtime(red.id).solved)
	assert(state.get_runtime(red.id).candidate_pick.is_empty())
	assert(state.selected_cell_id == other.id and state.get_runtime(other.id).candidate_pick == "green")
	_click(board, red.id, MOUSE_BUTTON_LEFT)
	assert(state.get_runtime(red.id).solved and state.get_runtime(red.id).candidate_pick == "red")
	assert(state.mistakes == 1 and state.selected_cell_id == other.id)
	_click(board, green.id, MOUSE_BUTTON_RIGHT)
	assert(state.get_runtime(green.id).solved and state.get_runtime(green.id).candidate_pick == "green")
	assert(state.mistakes == 1)
	# Wrong checks leave an existing hypothesis intact, even when the clicked color differs.
	game.board_controller.pick_selected_color(other.answer_type)
	var wrong_button := MOUSE_BUTTON_RIGHT if other.answer_type == "red" else MOUSE_BUTTON_LEFT
	_click(board, other.id, wrong_button)
	assert(state.mistakes == 2 and not state.get_runtime(other.id).solved)
	assert(state.get_runtime(other.id).candidate_pick == other.answer_type)
	assert(state.selected_cell_id == other.id)
	assert(board._cell_views[other.id].scope_overlay.target_amount == 1.0)
	_click(board, other.id, MOUSE_BUTTON_LEFT if other.answer_type == "red" else MOUSE_BUTTON_RIGHT)
	assert(state.get_runtime(other.id).solved and state.selected_cell_id.is_empty())
	# Known bricks toggle their scope; walls never count as failed answers.
	_click(board, known.id, MOUSE_BUTTON_MIDDLE)
	assert(board._neighbor_masks_enabled.has(known.id))
	_click(board, known.id, MOUSE_BUTTON_MIDDLE)
	assert(not board._neighbor_masks_enabled.has(known.id))
	_click(board, known.id, MOUSE_BUTTON_RIGHT)
	_click(board, wall.id, MOUSE_BUTTON_LEFT)
	_click(board, wall.id, MOUSE_BUTTON_RIGHT)
	assert(state.mistakes == 2)
	# Releases, middle-button toggles and wheel input never perform a check.
	var pending: CellDefinition
	for cell in state.level.cells:
		if cell.is_editable() and not state.get_runtime(cell.id).solved: pending = cell; break
	assert(pending != null)
	_click(board, pending.id, MOUSE_BUTTON_MIDDLE)
	_click(board, pending.id, MOUSE_BUTTON_MIDDLE)
	assert(state.selected_cell_id.is_empty())
	_click(board, pending.id, MOUSE_BUTTON_LEFT, false)
	_click(board, pending.id, MOUSE_BUTTON_WHEEL_UP)
	assert(not state.get_runtime(pending.id).solved and state.mistakes == 2)
	# Entrance/exit locks and pause block direct and positional mouse checks.
	game.input_controller.set_gameplay_input_enabled(false)
	_click(board, pending.id, MOUSE_BUTTON_LEFT)
	game.board_controller._on_cell_clicked(pending.id, MOUSE_BUTTON_RIGHT)
	assert(state.mistakes == 2 and not state.get_runtime(pending.id).solved)
	game.input_controller.set_gameplay_input_enabled(true)
	game.pause_menu.open()
	game.board_controller._on_cell_clicked(pending.id, MOUSE_BUTTON_LEFT)
	assert(state.mistakes == 2 and not state.get_runtime(pending.id).solved)
	await game.pause_menu.close()
	# Both buttons work in the introductory practice and preserve the accepted color.
	for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		assert(game.level_controller.load_level("1-1"))
		await board.entrance_finished
		state = game.level_controller.board_state
		_click(board, state.level.cells[0].id, button)
		assert(state.is_complete() and state.mistakes == 0)
		assert(state.get_runtime(state.level.cells[0].id).candidate_pick == ("red" if button == MOUSE_BUTTON_LEFT else "green"))
	print("PASS: left/red and right/green checks; middle selection/toggle; wheel hypotheses/scopes; independent clicked target; wrong hypothesis preservation; known clues/walls; input locks/pause; either-color practice.")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _click(board: HexBoardView, id: String, button: int, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.position = board._cell_views[id].global_position
	event.button_index = button
	event.pressed = pressed
	board._unhandled_input(event)
