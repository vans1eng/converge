extends Node

const SAVE_PATH := "user://perfect_completion_test.cfg"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	var progress := PlayerProgress.new(SAVE_PATH)
	assert(progress.get_perfect_count() == 0 and not progress.is_perfect("1-1"))
	assert(progress.complete_level("1-2", 0) == ERR_INVALID_PARAMETER)
	assert(progress.complete_level("1-1", 1) == OK)
	var saved := ConfigFile.new()
	assert(saved.load(SAVE_PATH) == OK)
	assert(not saved.has_section("last_time_seconds"))
	assert(progress.is_completed("1-1") and not progress.is_perfect("1-1"))
	assert(progress.complete_level("1-1", 0) == OK)
	assert(progress.is_perfect("1-1") and progress.get_perfect_count() == 1)
	assert(progress.complete_level("1-1", 0) == OK)
	assert(progress.get_perfect_count() == 1)
	assert(progress.complete_level("1-1", 2) == OK)
	progress = PlayerProgress.new(SAVE_PATH)
	assert(progress.is_perfect("1-1") and progress.get_perfect_count() == 1)
	assert(progress.complete_level("1-2", 0) == OK)
	assert(progress.get_perfect_count() == 2)
	var config := ConfigFile.new()
	assert(config.load(SAVE_PATH) == OK)
	assert(config.get_value("stats", "perfect_count") == 2)
	assert(config.get_value("perfect", "1-1") and config.get_value("perfect", "1-2"))

	# An older save can prove a perfect clear only if it records zero mistakes.
	config = ConfigFile.new()
	config.set_value("catalog", "version", "red_green_chapter_v1")
	config.set_value("completed", "1-1", true)
	config.set_value("last_mistakes", "1-1", 0)
	config.set_value("completed", "1-2", true)
	assert(config.save(SAVE_PATH) == OK)
	progress = PlayerProgress.new(SAVE_PATH)
	assert(progress.is_perfect("1-1") and not progress.is_perfect("1-2"))
	assert(progress.get_perfect_count() == 1)

	var page = preload("res://scenes/level_select.tscn").instantiate()
	page._progress = progress
	add_child(page)
	var original_dark := ThemeManager.is_dark
	for dark in [false, true]:
		ThemeManager.is_dark = dark
		assert(page._levels[0].perfect and page._level_color(0) == ThemeManager.get_palette().blue)
		assert(not page._levels[1].perfect and page._level_color(1) == ThemeManager.get_palette().red)
		assert(page._level_color(2) == ThemeManager.get_palette().gray)
	ThemeManager.is_dark = original_dark
	await get_tree().create_timer(1.5).timeout
	page.queue_free()
	await get_tree().process_frame

	# Exercise actual completion, result buttons, replay and non-perfect replay.
	DirAccess.remove_absolute(SAVE_PATH)
	progress = PlayerProgress.new(SAVE_PATH)
	get_tree().set_meta("selected_level", "1-1")
	var main = preload("res://scenes/main.tscn").instantiate()
	main._progress = progress
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await main.board_controller.board_view.entrance_finished
	assert(not main.guide_button.visible)
	assert(main.hud_controller.get_node_or_null("TimerLabel") == null)
	assert(main.restart_button.position == Vector2(28, 28))
	var mistakes_label: Label = main.hud_controller.get_node("MistakesLabel")
	assert(mistakes_label.anchor_left == 1.0 and mistakes_label.anchor_right == 1.0)
	assert(mistakes_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT)
	assert(main.level_complete.get_node_or_null("MarginContainer/VBoxContainer/Center/Content/Time") == null)
	main.level_controller.verify_color(main.level_controller.board_state.level.cells[0].id, "red")
	assert(PlayerProgress.new(SAVE_PATH).is_perfect("1-1"))
	await get_tree().create_timer(2.0).timeout
	var result = main.level_complete
	assert(main.waiting_for_next_level and result._perfect)
	assert(result.title_label.text == tr("RESULT_PERFECT"))
	assert(result.replay_button.text == tr("RESULT_REPLAY"))
	assert(result.replay_button.visible and result.continue_button.visible)
	var footer = result.back_button.get_parent()
	var pause_footer = main.pause_menu.restart_button.get_parent()
	assert(footer.get_child(0) == result.back_button)
	assert(footer.get_child(1) == result.replay_button)
	assert(footer.get_child(2) == result.continue_button)
	assert(footer.get_theme_constant("separation") == pause_footer.get_theme_constant("separation"))
	for dark in [false, true]:
		ThemeManager.is_dark = dark
		result._apply_palette()
		assert(result.title_label.get_theme_color("font_color") == ThemeManager.get_palette().blue)
	ThemeManager.is_dark = original_dark
	result._apply_palette()
	result.replay_button.pressed.emit()
	main._replay_after_completion() # Duplicate input must be ignored.
	await get_tree().create_timer(1.5).timeout
	assert(not result.visible and not main.waiting_for_next_level)
	assert(main.current_level_index == 0 and main.level_controller.board_state.level.id == "1-1")
	assert(main.level_controller.board_state.mistakes == 0 and not main.level_controller.board_state.is_complete())
	assert(main.input_controller.gameplay_input_enabled and main.hud_controller.visible)
	main.level_controller.board_state.mistakes = 1
	main.level_controller.verify_color(main.level_controller.board_state.level.cells[0].id, "green")
	await get_tree().create_timer(2.0).timeout
	assert(not result._perfect and result.title_label.text == tr("RESULT_TITLE"))
	assert(PlayerProgress.new(SAVE_PATH).is_perfect("1-1"))
	result.show_result("1-20", 0, false)
	assert(result.replay_button.visible and not result.continue_button.visible)
	main.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(SAVE_PATH)
	DirAccess.remove_absolute(SAVE_PATH + ".tmp")
	print("PASS: perfect detection, persistent unique counts, retained awards, old saves, light/dark blue selection and result, three-button layout, replay reset and final-level replay.")
	get_tree().quit()
