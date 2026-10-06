extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var validator := LevelValidator.new()
	var repo := LevelRepository.new()
	for n in range(1, 31):
		var level := repo.load_level("1-%d" % n)
		assert(validator.validate(level), str(validator.issues))
		for cell in level.cells:
			if n < 20: assert(cell.effective_type() in ["red", "green", "black"])
			if n < 10: assert(cell.scope_radius == 1)
		if n >= 6 and n not in [10, 12, 20]:
			assert(level.cells.any(func(cell): return cell.is_black()), "Missing walls in 1-%d" % n)
	var first := repo.load_level("1-1")
	assert(first.cells.size() == 1 and first.cells[0].candidate_types == ["red", "green"])
	var invalid := repo.load_level("1-1")
	invalid.tutorial.clear()
	assert(not validator.validate(invalid))
	get_tree().set_meta("selected_level", "1-1")
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.level_controller.level_completed.disconnect(game._on_level_completed)
	await get_tree().create_timer(1.3).timeout
	TranslationServer.set_locale("zh_CN")
	var tutorial = game.hud_controller.chapter_tutorial
	var board: HexBoardView = game.board_controller.board_view
	var body := board._body_rect()
	assert(body.position.x == 0 and body.size.x == get_viewport().get_visible_rect().size.x)
	assert(tutorial.get_child_count() == 3)
	assert(tutorial._left.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(tutorial._left.modulate.a == 0 and tutorial._right.modulate.a == 0)
	assert(tutorial._intro.text == "鼠标左键点击选中砖块")
	assert(is_equal_approx(tutorial._intro.modulate.a, 1))
	var id: String = game.level_controller.board_state.level.cells[0].id
	var original_position: Vector2 = board._cell_views[id].position
	var original_radius := board.radius
	assert(tutorial._intro.position.x > original_position.x and tutorial._intro.position.y < original_position.y)
	assert(tutorial._right.position.x > original_position.x + 100 and tutorial._right.position.y > original_position.y + 80)
	game.board_controller.select_cell(id)
	assert(tutorial._revealed == [true, false, true])
	var initial_y: float = tutorial._left.position.y
	await get_tree().create_timer(0.2).timeout
	assert(tutorial._left.modulate.a == 0 and tutorial._left.position.y == initial_y)
	await get_tree().create_timer(0.4).timeout
	assert(tutorial._left.modulate.a > 0 and tutorial._left.modulate.a < 1)
	assert(tutorial._left.position.y < initial_y)
	assert(tutorial._right.modulate.a == 0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game.input_controller._input(wheel)
	assert(tutorial._revealed == [true, true, true])
	await get_tree().create_timer(0.2).timeout
	assert(tutorial._right.modulate.a == 0)
	await get_tree().create_timer(1.3).timeout
	assert(is_equal_approx(tutorial._left.modulate.a, 1) and is_equal_approx(tutorial._right.modulate.a, 1))
	assert(tutorial._left.text == "选中砖块后使用上/下滚轮\n或方向键切换类型")
	assert(tutorial._right.text == "按下右键或Enter进行校验")
	assert(board._cell_views[id].position == original_position and board.radius == original_radius)
	assert(not tutorial._left.get_global_rect().intersects(Rect2(original_position - Vector2.ONE * board.radius, Vector2.ONE * board.radius * 2)))
	game.board_controller.change_selected_value(1)
	assert(tutorial._left.modulate.a == 1 and tutorial._right.modulate.a == 1)
	game.board_controller.pick_selected_color("green")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	game.input_controller._input(enter)
	var state: BoardState = game.level_controller.board_state
	assert(state.is_complete() and state.mistakes == 0)
	assert(board._cell_views[id]._fill_color() == ThemeManager.get_palette().green)
	await get_tree().create_timer(0.3).timeout
	assert(is_zero_approx(tutorial._left.modulate.a) and is_zero_approx(tutorial._right.modulate.a))
	game._load_current_level()
	assert(tutorial._revealed == [false, false, true])
	await get_tree().create_timer(1.3).timeout
	game.board_controller.select_cell(id)
	game.board_controller.pick_selected_color("red")
	game.board_controller.request_verification()
	assert(game.level_controller.board_state.is_complete() and game.level_controller.board_state.mistakes == 0)
	game.current_level_index = game.LEVEL_IDS.find("1-2")
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._revealed == [false, false, false])
	assert(tutorial._left.modulate.a == 0 and tutorial._right.modulate.a == 0)
	game.board_controller.select_cell("r0c1")
	assert(tutorial._revealed == [true, false, false])
	game.board_controller.pick_selected_color("green")
	assert(not tutorial._revealed[1]) # trigger is the selected brick, not its preview color
	await get_tree().create_timer(0.2).timeout
	assert(tutorial._left.modulate.a == 0)
	await get_tree().create_timer(1.3).timeout
	game.board_controller.deselect_cell()
	assert(tutorial._left.modulate.a == 1)
	game.board_controller.select_cell("r2c4")
	assert(tutorial._revealed == [true, true, false])
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._left.modulate.a == 1 and tutorial._right.modulate.a == 1)
	assert(tutorial._left.text.begins_with("红色数字") and tutorial._right.text.begins_with("绿色数字"))
	game.board_controller.select_cell("r0c1")
	assert(tutorial._left.modulate.a == 1 and tutorial._right.modulate.a == 1)
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._revealed == [false, false, false])
	game.board_controller.select_cell("r2c4")
	assert(tutorial._revealed == [false, true, false])
	game.board_controller.select_cell("r0c1")
	assert(tutorial._revealed == [true, true, false])
	game.current_level_index = game.LEVEL_IDS.find("1-10")
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._left.text.begins_with("r2") and board._body_rect().position.x == 0)
	game.current_level_index = game.LEVEL_IDS.find("1-4")
	game._load_current_level()
	assert(not tutorial.visible)
	print("PASS: chapter 1 progression; red/green practice; floating text triggers, rise/fade, no repeat, completion fade, reset, unchanged board layout.")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
