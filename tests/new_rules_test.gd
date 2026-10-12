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
		assert(level.allowed_colors == ["red", "green"] and not level.infer_yellow)
		for cell in level.cells:
			if cell.mode == CellDefinition.MODE_CANDIDATE:
				assert(cell.candidate_types == ["red", "green"])
				assert(cell.answer_type in ["red", "green"])
			if cell.effective_type() in ["purple", "yellow"]:
				assert(cell.mode == CellDefinition.MODE_FIXED and not cell.is_editable())
		checked += 1
	_test_color_rules()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await get_tree().create_timer(1.0).timeout
	# Exercise hidden chapter rules directly without changing the demo catalog.
	assert(main.level_controller.load_level("2-28"))
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
	for forbidden in ["black", "purple", "yellow"]:
		controller.pick_selected_color(forbidden)
		assert(state.get_runtime(target.id).candidate_pick == "")
	var wrong: String = target.candidate_types[0] if target.answer_type != target.candidate_types[0] else target.candidate_types[1]
	controller.pick_selected_color(wrong)
	var target_view: HexCellView = controller.board_view._cell_views[target.id]
	await get_tree().create_timer(1.0).timeout
	assert(target_view._current_fill == ThemeManager.get_palette().gray)
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
	print("PASS: %d reference levels; radius/axis/wall/zero rules; red/green-only answers and fixed purple/yellow clues; wrong/correct verification; completion; initial and settled fill colors." % checked)
	get_tree().quit()


func _cell(row: int, col: int, type: String, value: int) -> CellDefinition:
	return CellDefinition.from_dictionary({"id": "%d_%d" % [row, col], "row": row, "col": col, "type": type, "value": value if type != "black" else null})


func _test_color_rules() -> void:
	var source := _cell(4, 4, "purple", 0)
	var red := _ray_cell(source, 0, 1, "red")
	var green := _ray_cell(source, 3, 1, "green")
	red.value = 99
	green.value = 7
	var grid := HexGrid.new([source, red, green], 9, 9)
	assert(ClueRules.evaluate(source, grid) == 0)
	green.type = "red"
	assert(ClueRules.evaluate(source, grid) == 2)
	red.type = "green"
	green.type = "green"
	assert(ClueRules.evaluate(source, grid) == 2)
	red.type = "purple"
	green.type = "yellow"
	assert(ClueRules.evaluate(source, grid) == 0)
	source.type = "yellow"
	var cells: Array[CellDefinition] = [source]
	for direction in 6:
		for distance in range(1, 4):
			cells.append(_ray_cell(source, direction, distance, "red" if direction < 3 else "green"))
	grid = HexGrid.new(cells, 9, 9)
	for radius in range(1, 4):
		source.scope_radius = radius
		assert(ClueRules.evaluate(source, grid) == radius * 3)
		assert(ClueRules.scope(source, grid).size() == radius * 6)
	source.scope_radius = 2
	var wall := grid.cell_at_direction_distance(source, 0, 1)
	wall.type = "black"
	assert(ClueRules.evaluate(source, grid) == 4)
	assert(grid.cell_at_direction_distance(source, 3, 2) in ClueRules.scope(source, grid))
	assert(grid.cell_at_direction_distance(source, 0, 2) not in ClueRules.scope(source, grid))
	wall.type = "purple"
	assert(ClueRules.evaluate(source, grid) == 5)
	wall.type = "yellow"
	assert(ClueRules.evaluate(source, grid) == 5)
	wall.type = "green"
	assert(ClueRules.evaluate(source, grid) == 5)
	cells.erase(wall)
	grid = HexGrid.new(cells, 9, 9)
	assert(ClueRules.evaluate(source, grid) == 5)
	# Unequal distances never pair.
	grid = HexGrid.new([source, _ray_cell(source, 0, 1, "red"), _ray_cell(source, 3, 2, "green")], 9, 9)
	assert(ClueRules.evaluate(source, grid) == 0)
	# Purple radius counts still cross walls.
	source.type = "purple"
	grid = HexGrid.new([source, _ray_cell(source, 0, 1, "black"), _ray_cell(source, 0, 2, "green")], 9, 9)
	assert(ClueRules.evaluate(source, grid) == 1)


func _ray_cell(source: CellDefinition, direction: int, distance: int, type: String) -> CellDefinition:
	var axial: Vector2i = HexCoordinate.offset_to_axial(source.row, source.col) + HexCoordinate.DIRECTIONS[direction] * distance
	var offset := HexCoordinate.axial_to_offset(axial)
	return _cell(offset.x, offset.y, type, 0)
