extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# Headless tests verify gameplay independently of audio playback.
	AudioManager.bgm.stop()
	AudioManager.set_sound_enabled(false)
	var catalog := LevelRepository.get_catalog()
	assert(catalog.size() == 60)
	var counts := {1: 0, 2: 0}
	var ids := {}
	var validator := LevelValidator.new()
	for entry in catalog:
		assert(not ids.has(entry.id))
		ids[entry.id] = true
		assert(entry.file == entry.id)
		counts[entry.chapter_id] += 1
		var level := LevelRepository.new().load_level(entry.id)
		assert(validator.validate(level), "%s: %s" % [entry.id, validator.issues])
		var yellow := level.cells.any(func(c): return c.effective_type() == "yellow")
		assert(yellow == (level.chapter_id == 2))
	assert(counts == {1: 30, 2: 30})
	for chapter in [1, 2]:
		for number in range(1, 31):
			assert(ids.has("%d-%d" % [chapter, number]))
	var save_path := "user://demo_progress_test.cfg"
	DirAccess.remove_absolute(save_path)
	var progress := PlayerProgress.new(save_path)
	assert(progress.is_unlocked("1-1"))
	assert(not progress.is_completed("1-1"))
	assert(not progress.is_unlocked("1-2"))
	assert(not progress.is_unlocked("2-1"))
	assert(progress.complete_level("1-2", 1.0, 0) == ERR_INVALID_PARAMETER)
	assert(LevelRepository.get_playable_level_ids().size() == 30)
	assert(LevelRepository.get_playable_level_ids()[-1] == "1-30")
	TranslationServer.set_locale("en")
	# Stale chapter metadata must not expose chapter two in the demo.
	get_tree().set_meta("selected_chapter", 2)
	var page = load("res://scenes/level_select.tscn").instantiate()
	page._progress = progress
	get_tree().root.add_child(page)
	get_tree().current_scene = page
	assert(page._is_transitioning)
	assert(page.back_button.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	page.back_button.pressed.emit()
	await get_tree().create_timer(0.25).timeout
	assert(page._is_transitioning and page._chapter_id == 1)
	assert(get_tree().current_scene == page)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	page._unhandled_input(escape)
	assert(get_tree().current_scene == page)
	await get_tree().create_timer(0.65).timeout
	assert(not page._is_transitioning)
	assert(page.back_button.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(page._cell_tweens.all(func(tween): return not tween.is_running()))
	assert(page._levels.size() == 30 and page.title_label.text == "CHAPTER 1")
	assert(page._cell_scales.all(func(value): return is_equal_approx(value, 1.0)))
	assert(page.find_children("*", "Button", true, false).size() == 1)
	assert(page._level_at(page._cell_center(0)) == 0)
	assert(page._level_at(page._cell_center(1)) == -1)
	page._set_hovered_level(1)
	assert(page._hovered_level == -1)
	page._open_level("1-2")
	assert(not page._is_transitioning)
	assert(get_tree().current_scene == page)
	TranslationServer.set_locale("zh_CN")
	await get_tree().process_frame
	assert(page.title_label.text == "第一章")
	TranslationServer.set_locale("en")
	page.queue_free()
	await get_tree().process_frame
	# Both hidden and locked IDs are rejected at the gameplay entry point.
	for selected_id in ["2-5", "1-2"]:
		get_tree().set_meta("selected_level", selected_id)
		var rejected_game = load("res://scenes/main.tscn").instantiate()
		rejected_game._progress = progress
		get_tree().root.add_child(rejected_game)
		assert(rejected_game.level_controller.board_state.level.id == "1-1")
		await get_tree().create_timer(1.3).timeout
		rejected_game.queue_free()
		await get_tree().process_frame
	get_tree().set_meta("selected_level", "1-1")
	var game = load("res://scenes/main.tscn").instantiate()
	game._progress = progress
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(1.3).timeout
	assert(game.hud_controller.title_label.text == "1 - 1")
	for button in game.hud_controller.find_children("*", "Button", true, false):
		assert(button.text not in ["‹", "›"])
	var font: Font = game.hud_controller.title_label.get_theme_font("font")
	assert(font == SettingsManager.UI_FONT)
	game.board_controller.select_cell(game.level_controller.board_state.level.cells[0].id)
	game.board_controller.pick_selected_color("green")
	game.board_controller.request_verification()
	assert(game.level_controller.board_state.is_complete())
	# Progress is on disk before any completion animation or next-level click.
	var restored := PlayerProgress.new(save_path)
	assert(restored.is_completed("1-1") and restored.is_unlocked("1-2"))
	assert(not restored.is_unlocked("1-3"))
	var saved := ConfigFile.new()
	assert(saved.load(save_path) == OK)
	assert(saved.get_value("last_mistakes", "1-1") == 0)
	assert(saved.get_value("last_time_seconds", "1-1") > 0.0)
	await get_tree().create_timer(2.0).timeout
	assert(game.waiting_for_next_level and game.level_complete.continue_button.visible)
	game.level_complete.continue_button.pressed.emit()
	await get_tree().create_timer(1.3).timeout
	assert(game.level_controller.board_state.level.id == "1-2")
	game.queue_free()
	await get_tree().process_frame
	page = load("res://scenes/level_select.tscn").instantiate()
	page._progress = PlayerProgress.new(save_path)
	get_tree().root.add_child(page)
	await get_tree().create_timer(0.9).timeout
	assert(page._levels[0].completed and page._levels[0].unlocked)
	assert(not page._levels[1].completed and page._levels[1].unlocked)
	assert(not page._levels[2].unlocked)
	assert(page._level_at(page._cell_center(0)) == 0)
	assert(page._level_at(page._cell_center(1)) == 1)
	assert(page._level_at(page._cell_center(2)) == -1)
	page.queue_free()
	await get_tree().process_frame
	# Replays replace statistics without clearing completion or later progress.
	assert(restored.complete_level("1-1", 5.5, 2) == OK)
	assert(saved.load(save_path) == OK)
	assert(saved.get_value("last_time_seconds", "1-1") == 5.5)
	assert(saved.get_value("last_mistakes", "1-1") == 2)
	for n in range(2, 31):
		assert(restored.complete_level("1-%d" % n, 10.0, 0) == OK)
	assert(not restored.is_unlocked("2-1"))
	get_tree().set_meta("selected_level", "1-30")
	game = load("res://scenes/main.tscn").instantiate()
	game._progress = PlayerProgress.new(save_path)
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().create_timer(1.3).timeout
	game._on_level_completed()
	await get_tree().create_timer(2.0).timeout
	assert(game.waiting_for_next_level)
	assert(not game.level_complete.continue_button.visible)
	assert(game.level_controller.board_state.level.id == "1-30")
	game.queue_free()
	await get_tree().process_frame
	# Older filename-based saves retain completion and unlock the next level.
	var legacy := ConfigFile.new()
	legacy.set_value("completed", "level_001", true)
	legacy.set_value("completed", "level_026", true)
	legacy.set_value("last_time_seconds", "level_026", 42.0)
	legacy.set_value("last_mistakes", "level_026", 3)
	assert(legacy.save(save_path) == OK)
	var migrated := PlayerProgress.new(save_path)
	assert(migrated.is_completed("1-1") and migrated.is_unlocked("1-2"))
	assert(not migrated.is_unlocked("1-3"))
	assert(saved.load(save_path) == OK)
	assert(saved.get_value("completed", "2-12"))
	assert(saved.get_value("last_time_seconds", "2-12") == 42.0)
	assert(saved.get_value("last_mistakes", "2-12") == 3)
	assert(not saved.has_section_key("completed", "level_026"))
	assert(not saved.has_section_key("completed", "level_001"))
	DirAccess.remove_absolute(save_path)
	DirAccess.remove_absolute(save_path + ".tmp")
	print("PASS: full catalog validation; demo chapter limit; locked hover/click; saved completion and restart; next level; replay; legacy saves; final demo level")
	get_tree().quit()
