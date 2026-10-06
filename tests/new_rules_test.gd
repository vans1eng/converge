extends Node

var checked := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var loader := LevelLoader.new()
	var validator := LevelValidator.new()
	for entry in LevelRepository.get_catalog():
		var level := loader.load_file("res://resources/levels/%s.json" % entry.id)
		assert(validator.validate(level), str(validator.issues))
		for cell in level.cells:
			if cell.mode == CellDefinition.MODE_CANDIDATE:
				var expected := Array(level.allowed_colors) if not level.allowed_colors.is_empty() else ["red", "green", "purple"]
				if level.infer_yellow and cell.scope_radius == 1 and "yellow" not in expected: expected.append("yellow")
				assert(cell.candidate_types == expected)
		checked += 1
	# A hole is skipped by yellow; a wall blocks only its own ray.
	# A radius crosses both the wall and hole, including inner rings.
	var source := _cell(1, 0, "yellow", 0)
	var zero_red := _cell(1, 2, "red", 0)
	var wall := _cell(1, 3, "black", 0)
	var behind := _cell(1, 4, "green", 7)
	var grid := HexGrid.new([source, zero_red, wall, behind], 3, 5)
	assert(grid.axis_cells(source, 0) == [zero_red])
	assert(ClueRules.evaluate(source, grid) == 0)
	source.type = "purple"
	source.scope_radius = 4
	assert(ClueRules.evaluate(source, grid) == 7)
	source.type = "red"
	assert(ClueRules.evaluate(source, grid) == 1) # zero red still counts
	source.type = "yellow"
	grid = HexGrid.new([source, _cell(1, 1, "red", 2), _cell(1, 2, "green", 2), _cell(1, 3, "red", 1)], 3, 5)
	assert(ClueRules.evaluate(source, grid) == 5) # sum, not count or equal axes
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().create_timer(1.0).timeout
	# Exercise hidden chapter rules directly without changing the demo catalog.
	assert(main.level_controller.load_level("2-12"))
	await get_tree().create_timer(1.0).timeout
	main.level_controller.level_completed.disconnect(main._on_level_completed)
	var controller: BoardController = main.board_controller
	var state: BoardState = controller.board_state
	for view in controller.board_view._cell_views.values():
		assert(view._current_fill == view._fill_color())
		assert(view.state_mask_opacity == 0.0)
	var target: CellDefinition
	for cell in state.level.cells:
		if cell.is_editable():
			target = cell
			break
	controller.select_cell(target.id)
	controller.pick_selected_color("black")
	assert(state.get_runtime(target.id).candidate_pick == "")
	var wrong: String = target.candidate_types[0] if target.answer_type != target.candidate_types[0] else target.candidate_types[1]
	controller.pick_selected_color(wrong)
	var target_view: HexCellView = controller.board_view._cell_views[target.id]
	await get_tree().create_timer(1.0).timeout
	assert(target_view._current_fill == target_view._brick_color(wrong))
	main.level_controller.verify_selected()
	assert(state.mistakes == 1 and not state.get_runtime(target.id).solved)
	controller.pick_selected_color(target.answer_type)
	main.level_controller.verify_selected()
	assert(state.get_runtime(target.id).solved and state.mistakes == 1)
	for cell in state.level.cells:
		if cell.is_editable() and not state.get_runtime(cell.id).solved:
			controller.select_cell(cell.id)
			controller.pick_selected_color(cell.answer_type)
			main.level_controller.verify_selected()
	assert(state.is_complete())
	var fresh := HexCellView.new()
	add_child(fresh)
	fresh.setup(target, CellRuntimeState.new(), 32.0, 33.5)
	assert(fresh._current_fill == ThemeManager.get_palette().gray)
	print("PASS: %d reference levels; radius/axis/wall/zero rules; candidates; wrong/correct verification; completion; initial and settled fill colors." % checked)
	get_tree().quit()


func _cell(row: int, col: int, type: String, value: int) -> CellDefinition:
	return CellDefinition.from_dictionary({"id": "%d_%d" % [row, col], "row": row, "col": col, "type": type, "value": value if type != "black" else null})
