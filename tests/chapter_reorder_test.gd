extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/level_order.json"))
	var catalog := LevelRepository.get_catalog()
	assert(catalog.size() == 66)
	var counts := {1: 0, 2: 0}
	var sources := {}
	var validator := LevelValidator.new()
	for entry in catalog:
		var path := "res://resources/levels/%s.json" % entry.id
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var level := LevelDefinition.from_dictionary(data)
		assert(validator.validate(level), "%s: %s" % [entry.id, validator.issues])
		assert(data.id == entry.id and data.chapter_id == entry.chapter_id)
		assert(not sources.has(data.source_id))
		sources[data.source_id] = true
		counts[level.chapter_id] += 1
		if level.chapter_id == 1:
			for cell in level.cells:
				assert(cell.effective_type() in ["red", "green"] and cell.direction.is_empty())
		if str(data.source_id).begins_with("simple-toy:"):
			var source_id: String = str(data.source_id).get_slice(":", 1)
			var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/levels/archive/simple-toy-import-1-36/%s.json" % source_id))
			assert(data.cells == original.cells and data.board == original.board)
	assert(counts == {1: 20, 2: 46})
	for number in range(1, 37): assert(sources.has("simple-toy:1-%d" % number))
	var order: Array = manifest.chapters["1"]
	assert(order[0].source == "simple-toy:1-1" and order[1].source == "simple-toy:1-2")
	assert(order[2].source == "simple-toy:1-4" and order[3].source == "simple-toy:1-3")
	var bridge := LevelRepository.new().load_level("1-3")
	for cell in bridge.cells:
		assert(not cell.hidden and cell.scope_radius == 1)
	assert(LevelRepository.new().load_level("1-4").cells.any(func(c): return c.is_editable() and c.hidden))
	assert(LevelRepository.get_playable_level_ids().size() == 20)
	assert(LevelRepository.get_playable_level_ids().has("1-19"))
	assert(LevelRepository.get_playable_level_ids().has("1-20"))
	assert(LevelRepository.new().load_level("2-1").tutorial.get("hint_key", "").is_empty())
	assert(LevelRepository.new().load_level("2-17").tutorial.hint_key == "TUTORIAL_YELLOW_1")
	_test_progress_migration()
	print("PASS: all 36 source puzzles imported intact; 20 pure red/green chapter-one entries; public bridge before hidden tutorial; 46 chapter-two entries; two templates included as requested; original yellow hints; one-time progress migration and preserved old records.")
	get_tree().quit()


func _test_progress_migration() -> void:
	var path := "user://chapter_reorder_test.cfg"
	var old := ConfigFile.new()
	old.set_value("completed", "1-3", true)
	old.set_value("last_time_seconds", "1-3", 42.0)
	old.set_value("completed", "1-4", true) # Old Godot bridge differs from source bridge.
	old.set_value("completed", "1-6", true)
	old.set_value("completed", "2-5", true)
	assert(old.save(path) == OK)
	var progress := PlayerProgress.new(path)
	assert(progress.is_completed("1-4") and not progress.is_completed("1-3"))
	assert(progress.is_completed("2-1") and progress.is_completed("2-21"))
	assert(old.load(path) == OK)
	assert(old.get_value("last_time_seconds", "1-4") == 42.0)
	assert(old.get_value("before_red_green_completed", "1-4"))
	assert(old.get_value("catalog", "version") == "red_green_chapter_v1")
	progress = PlayerProgress.new(path)
	assert(progress.is_completed("1-4") and not progress.is_completed("1-3"))
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".tmp")
