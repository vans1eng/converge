extends Node

const GAME_CONFIG := preload("res://scripts/data/game_config.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_mode: bool = GAME_CONFIG.DEV_MODE
	var progress := PlayerProgress.new("user://dev_mode_test_%d.cfg" % Time.get_ticks_usec())
	GAME_CONFIG.DEV_MODE = false
	assert(LevelRepository.get_playable_level_ids().size() == LevelRepository.DEMO_LEVEL_COUNT)
	assert(progress.is_unlocked("1-1"))
	assert(not progress.is_unlocked("1-2"))
	assert(not progress.is_unlocked("2-1"))
	GAME_CONFIG.DEV_MODE = true
	progress = PlayerProgress.new("user://dev_mode_test_%d.cfg" % Time.get_ticks_usec())
	assert(LevelRepository.get_playable_level_ids().size() == LevelRepository.get_catalog().size())
	for id in LevelRepository.get_playable_level_ids():
		assert(progress.is_unlocked(id))
		assert(not progress.is_completed(id))
	assert(not progress.is_unlocked("missing-level"))
	var page := preload("res://scenes/level_select.tscn").instantiate()
	page._progress = progress
	get_tree().root.add_child(page)
	for entry in page._levels:
		assert(entry.unlocked and not entry.completed)
	page.queue_free()
	await get_tree().process_frame
	get_tree().set_meta("selected_level", "1-1")
	var main := preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await main.board_controller.board_view.entrance_finished
	assert(main.previous_level_button.visible and main.next_level_button.visible)
	assert(main.previous_level_button.disabled and not main.next_level_button.disabled)
	main.next_level_button.pressed.emit()
	assert(main.current_level_index == 1)
	assert(main.level_controller.board_state.level.id == "1-2")
	main.next_level_button.pressed.emit()
	assert(main.current_level_index == 1) # Ignore clicks during the entrance.
	await main.board_controller.board_view.entrance_finished
	main.previous_level_button.pressed.emit()
	assert(main.current_level_index == 0)
	await main.board_controller.board_view.entrance_finished
	main.current_level_index = main.LEVEL_IDS.find("2-1") - 1
	main._load_current_level()
	await main.board_controller.board_view.entrance_finished
	main.next_level_button.pressed.emit()
	assert(main.level_controller.board_state.level.id == "2-1")
	assert(get_tree().get_meta("selected_chapter") == 2)
	await main.board_controller.board_view.entrance_finished
	main.current_level_index = main.LEVEL_IDS.size() - 1
	main._load_current_level()
	await main.board_controller.board_view.entrance_finished
	assert(main.next_level_button.disabled)
	main.next_level_button.pressed.emit()
	assert(main.current_level_index == main.LEVEL_IDS.size() - 1)
	main.queue_free()
	await get_tree().process_frame
	GAME_CONFIG.DEV_MODE = false
	progress = PlayerProgress.new("user://dev_mode_test_%d.cfg" % Time.get_ticks_usec())
	assert(not progress.is_unlocked("1-2")) # Unlocking did not persist clears.
	page = preload("res://scenes/level_select.tscn").instantiate()
	page._progress = progress
	get_tree().root.add_child(page)
	assert(page.get_node_or_null("Title") == null)
	assert(page._levels.size() == 66)
	assert(page._chapter_level_counts == [20, 23, 23])
	for index in page._levels.size():
		assert(page._levels[index].number == index + 1)
	assert(page._levels[20].id == "2-1" and page._levels[20].number == 21)
	assert(page._levels[43].id == "2-24" and page._levels[43].number == 44)
	assert(page._levels[0].unlocked)
	assert(page._levels.slice(20).all(func(entry): return not entry.unlocked))
	page._cell_scales.fill(1.0)
	assert(page._level_at(page._cell_center(20)) == -1)
	assert(page._level_at(page._cell_center(43)) == -1)
	page.queue_free()
	await get_tree().process_frame
	get_tree().set_meta("selected_level", "1-1")
	main = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await main.board_controller.board_view.entrance_finished
	assert(not main.previous_level_button.visible and not main.next_level_button.visible)
	main.next_level_button.pressed.emit()
	assert(main.current_level_index == 0)
	main.queue_free()
	await get_tree().process_frame
	GAME_CONFIG.DEV_MODE = original_mode
	print("PASS: dev/normal mode, navigation, 1–66 selection numbering, original IDs, removed title and blocked locked-level clicks.")
	get_tree().quit()
