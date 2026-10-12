extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var validator := LevelValidator.new()
	var repo := LevelRepository.new()
	for n in range(1, 21):
		var level := repo.load_level("1-%d" % n)
		assert(validator.validate(level), str(validator.issues))
		for cell in level.cells:
			assert(cell.effective_type() in ["red", "green"])
			if n < 7: assert(cell.scope_radius == 1)
	# Step paused tweens deterministically to verify each 0.3 s stagger.
	var timing = preload("res://scripts/ui/chapter_tutorial.gd").new()
	add_child(timing)
	for level_id in ["1-1", "1-2", "1-4", "1-7"]:
		timing.show_state(BoardState.new(repo.load_level(level_id)))
		for tween in timing._tweens: tween.pause(); tween.custom_step(0.6)
		if level_id == "1-1":
			assert(timing._mode_hint.modulate.a > 0 and timing._intro.modulate.a == 0 and timing._left.modulate.a == 0 and timing._right.modulate.a == 0)
		else:
			assert(timing._left.modulate.a > 0 and timing._right.modulate.a == 0 and timing._intro.modulate.a == 0)
		for tween in timing._tweens: tween.custom_step(0.3)
		if level_id == "1-1":
			assert(timing._intro.modulate.a > 0 and timing._left.modulate.a == 0 and timing._right.modulate.a == 0)
		else:
			assert(timing._right.modulate.a > 0 and timing._intro.modulate.a == 0)
		for tween in timing._tweens: tween.custom_step(0.3)
		if level_id == "1-1":
			assert(timing._left.modulate.a > 0 and timing._right.modulate.a == 0)
			for tween in timing._tweens: tween.custom_step(0.3)
			assert(timing._right.modulate.a > 0)
		else: assert(timing._intro.text.is_empty() and timing._intro.modulate.a == 0)
	timing.queue_free()
	await get_tree().process_frame
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
	assert(tutorial.get_child_count() == 4)
	assert(tutorial._left.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(tutorial._revealed == [true, true, true, true])
	assert(tutorial._left.copy_text == "左键点击灰色砖块\n直接检验红色")
	assert(tutorial._right.text == "右键点击灰色砖块\n直接检验绿色")
	assert(tutorial._intro.text == "中键选中，滚轮切换假设并查看范围\n按 R 键重玩本关")
	assert(tutorial._mode_hint.get_parsed_text() == "可在左下角或设置中\n切换谨慎／快速操作方式")
	var bounds: Rect2 = tutorial._board_bounds()
	assert(tutorial._mode_hint.get_rect().end.y < tutorial._intro.position.y)
	assert(tutorial._intro.get_rect().end.x < bounds.position.x)
	assert(tutorial._left.position.x > bounds.end.x and tutorial._right.position.x > bounds.end.x)
	assert(tutorial._left.get_rect().end.y < tutorial._right.position.y)
	var id: String = game.level_controller.board_state.level.cells[0].id
	var original_position: Vector2 = board._cell_views[id].position
	var original_radius := board.radius
	game.board_controller._on_cell_clicked(id, MOUSE_BUTTON_MIDDLE)
	assert(game.level_controller.board_state.selected_cell_id == id)
	game.board_controller.change_selected_value(1)
	assert(not game.level_controller.board_state.is_complete())
	assert(board._cell_views[id].position == original_position and board.radius == original_radius)
	game.board_controller._on_cell_clicked(id, MOUSE_BUTTON_RIGHT)
	var state: BoardState = game.level_controller.board_state
	assert(state.is_complete() and state.mistakes == 0)
	assert(board._cell_views[id]._fill_color() == ThemeManager.get_palette().green)
	await get_tree().create_timer(0.3).timeout
	assert(is_zero_approx(tutorial._left.modulate.a) and is_zero_approx(tutorial._right.modulate.a))
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._revealed == [true, true, true, true])
	game.board_controller._on_cell_clicked(id, MOUSE_BUTTON_LEFT)
	assert(game.level_controller.board_state.is_complete() and game.level_controller.board_state.mistakes == 0)
	game.current_level_index = game.LEVEL_IDS.find("1-2")
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._revealed == [true, true, false, false])
	assert(tutorial._left.copy_text == "红色数字：相邻红砖的数量\n不包括自己")
	assert(tutorial._right.text == "绿色数字：相邻绿砖的数量\n不包括自己")
	await get_tree().create_timer(0.3).timeout
	assert(tutorial._left.modulate.a == 1 and tutorial._right.modulate.a == 1)
	game.board_controller.select_cell("r0c1")
	game.board_controller.pick_selected_color("green")
	assert(tutorial._left.modulate.a == 1 and tutorial._right.modulate.a == 1)
	game._load_current_level()
	await get_tree().create_timer(1.6).timeout
	assert(tutorial._revealed == [true, true, false, false])
	game.current_level_index = game.LEVEL_IDS.find("1-7")
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial._left.copy_text.begins_with("的范围包括第一圈和第二圈") and board._body_rect().position.x == 0)
	assert(tutorial._left.scope_icon_enabled)
	game.current_level_index = game.LEVEL_IDS.find("1-3")
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	assert(tutorial.visible and tutorial._left.visible and tutorial._left.modulate.a == 1)
	assert(tutorial._left.copy_text == "点击有数字的砖块可以查看范围")
	assert(not tutorial._left.scope_icon_enabled)
	assert(not tutorial._right.visible and not tutorial._intro.visible)
	print("PASS: chapter 1 progression; red/green practice; 0.3 s staggered tutorials, rise/fade, no repeat, completion fade, reset, unchanged board layout.")
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()
