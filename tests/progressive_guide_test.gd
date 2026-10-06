extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	AudioManager.bgm.stop()
	AudioManager.set_sound_enabled(false)
	get_tree().set_meta("selected_level", "1-1")
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	game.level_controller.level_completed.disconnect(game._on_level_completed)
	var legend: VBoxContainer = game.legend_panel.get_node("Legend")
	var samples := {
		1: [false, false, false, false],
		5: [false, false, false, false],
		6: [true, false, false, false],
		10: [true, true, false, false],
		12: [true, true, true, false],
		20: [true, true, true, true],
		30: [true, true, true, true],
	}
	for number in samples:
		game.current_level_index = game.LEVEL_IDS.find("1-%d" % number)
		game._load_current_level()
		var expected: Array = samples[number]
		for index in 4:
			assert(legend.get_node(["Black", "Radius2", "Radius3", "Purple"][index]).visible == expected[index], "Wrong guide section at 1-%d" % number)
		assert(legend.get_node("Red").visible and legend.get_node("Green").visible)
		assert(not legend.get_node("Yellow").visible)
		assert(legend.get_node("Black/Label").text == "LEGEND_BLACK")
		if number == 6:
			assert(game.level_controller.board_state.level.tutorial.floating.left.size() == 8)
	# Replaying an early level must not expose later concepts.
	game.current_level_index = 0
	game._load_current_level()
	assert(not legend.get_node("Black").visible and not legend.get_node("Purple").visible)
	await get_tree().create_timer(1.3).timeout
	var board: BoardController = game.board_controller
	var id: String = board.board_state.level.cells[0].id
	board.select_cell(id)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	game.input_controller._input(wheel)
	assert(board.board_state.get_runtime(id).candidate_pick == "red")
	var arrow := _key(KEY_DOWN)
	game.input_controller._input(arrow)
	assert(board.board_state.get_runtime(id).candidate_pick == "green")
	for code in [KEY_R, KEY_G, KEY_P, KEY_Y, KEY_SPACE]:
		game.input_controller._input(_key(code))
		assert(board.board_state.get_runtime(id).candidate_pick == "green")
		assert(not board.board_state.is_complete() and board.board_state.mistakes == 0)
	game.input_controller._input(_key(KEY_ENTER))
	assert(board.board_state.is_complete())
	game._load_current_level()
	await get_tree().create_timer(1.3).timeout
	board.select_cell(id)
	board.pick_selected_color("red")
	board._on_cell_clicked(id, MOUSE_BUTTON_RIGHT)
	assert(board.board_state.is_complete())
	# Hidden chapter two introduces yellow and the extra wall/ray explanation.
	assert(game.level_controller.load_level("2-1"))
	assert(legend.get_node("Yellow").visible)
	assert(legend.get_node("Black/Label").text == "LEGEND_BLACK_RAYS")
	var hints := 0
	for locale in SettingsManager.LANGUAGES:
		TranslationServer.set_locale(locale)
		await get_tree().process_frame
		for key in ["LEGEND_SCOPE", "LEGEND_RADIUS_2", "LEGEND_RADIUS_3", "LEGEND_BLACK", "LEGEND_BLACK_RAYS", "LEGEND_INPUT", "TUTORIAL_WALL_LEFT", "TUTORIAL_WALL_RIGHT"]:
			var text := tr(key)
			assert(text != key and not text.is_empty(), "%s missing %s" % [key, locale])
			assert("R/G/P/Y" not in text and "Space" not in text and "空格" not in text)
			for character in text:
				if character in [" ", "\n", "\r", "\t"]:
					continue
				var code := character.unicode_at(0)
				assert(SettingsManager.UI_FONT.has_char(code) or SettingsManager.KOREAN_FONT.has_char(code), "%s/%s missing glyph %s" % [key, locale, character])
			hints += 1
	print("PASS: progressive and replay guide sections; walls/radii/purple/yellow milestones; removed letter/Space controls; arrows/wheel/Enter/right click; %d translated help strings and font coverage" % hints)
	game.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event
