extends RefCounted
class_name PlayerProgress

const PROGRESS_PATH := "user://color_rules_v2_progress.cfg"
const GAME_CONFIG := preload("res://scripts/data/game_config.gd")

const LEGACY_LEVEL_IDS := {
	"level_001": "1-1",
	"level_002": "1-2",
	"level_003": "1-3",
	"level_004": "1-4",
	"level_005": "1-5",
	"level_006": "1-6",
	"level_007": "1-7",
	"level_008": "1-8",
	"level_009": "1-9",
	"level_010": "1-10",
	"level_011": "1-11",
	"level_012": "1-12",
	"level_013": "1-13",
	"level_014": "1-14",
	"level_015": "1-15",
	"level_020": "2-6",
	"level_021": "2-7",
	"level_022": "2-8",
	"level_023": "2-9",
	"level_024": "2-10",
	"level_025": "2-11",
	"level_026": "2-12",
	"level_027": "2-13",
	"level_028": "2-14",
	"level_029": "2-15",
	"level_030": "2-16",
	"level_031": "2-1",
	"level_032": "2-2",
	"level_033": "2-3",
	"level_034": "2-4",
	"level_035": "2-5",
	"level_036": "1-16",
	"level_037": "1-17",
	"level_038": "1-18",
	"level_039": "1-19",
	"level_040": "1-20",
	"level_041": "1-21",
	"level_042": "1-22",
	"level_043": "1-23",
	"level_044": "1-24",
	"level_045": "1-25",
	"level_046": "1-26",
	"level_047": "1-27",
	"level_048": "1-28",
	"level_049": "1-29",
	"level_050": "1-30",
	"level_051": "2-17",
	"level_052": "2-18",
	"level_053": "2-19",
	"level_054": "2-20",
	"level_055": "2-21",
	"level_056": "2-22",
	"level_057": "2-23",
	"level_058": "2-24",
	"level_059": "2-25",
	"level_060": "2-26",
	"level_061": "2-27",
	"level_062": "2-28",
	"level_063": "2-29",
	"level_064": "2-30",
}

var _path: String
var _data := ConfigFile.new()
var _catalog: Array[Dictionary] = LevelRepository.get_playable_catalog()


func _init(path: String = PROGRESS_PATH) -> void:
	_path = path
	var error := _data.load(_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not load player progress: %s" % error_string(error))
	if error == OK:
		_migrate_legacy_ids()
	_migrate_chapter_order(error == OK)
	_migrate_perfect_records(error == OK)


func _migrate_legacy_ids() -> void:
	var changed := false
	for section in ["completed", "last_time_seconds", "last_mistakes", "perfect"]:
		for old_id in LEGACY_LEVEL_IDS:
			if not _data.has_section_key(section, old_id):
				continue
			var level_id: String = LEGACY_LEVEL_IDS[old_id]
			# A canonical record takes precedence over an older record.
			if not _data.has_section_key(section, level_id):
				_data.set_value(section, level_id, _data.get_value(section, old_id))
			_data.erase_section_key(section, old_id)
			changed = true
	if changed:
		_save()


func is_completed(level_id: String) -> bool:
	return bool(_data.get_value("completed", level_id, false))


func is_perfect(level_id: String) -> bool:
	return is_completed(level_id) and bool(_data.get_value("perfect", level_id, false))


func get_perfect_count() -> int:
	var count := 0
	for entry in _catalog:
		if is_perfect(entry.id): count += 1
	return count


func is_unlocked(level_id: String) -> bool:
	for index in _catalog.size():
		if _catalog[index].id == level_id:
			return GAME_CONFIG.DEV_MODE or index == 0 or is_completed(level_id) or is_completed(_catalog[index - 1].id)
	return false


func complete_level(level_id: String, mistakes: int) -> Error:
	if not is_unlocked(level_id):
		return ERR_INVALID_PARAMETER
	_data.set_value("completed", level_id, true)
	_data.set_value("last_mistakes", level_id, mistakes)
	if mistakes == 0:
		_data.set_value("perfect", level_id, true)
	_data.set_value("stats", "perfect_count", get_perfect_count())
	return _save()


func _save() -> Error:
	# Write separately so an interrupted write cannot truncate the existing save.
	var temporary_path := _path + ".tmp"
	var error := _data.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(temporary_path, _path)
	if error != OK:
		push_warning("Could not save player progress: %s" % error_string(error))
	return error


func _migrate_chapter_order(existing_save: bool) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/level_order.json"))
	var version: String = manifest.version
	var saved_version := str(_data.get_value("catalog", "version", ""))
	if saved_version == version: return
	if existing_save:
		var mapping: Dictionary = manifest.old_to_new
		var version_migrations: Dictionary = manifest.get("version_migrations", {})
		if version_migrations.has(saved_version):
			mapping = version_migrations[saved_version]
		for section in ["completed", "last_time_seconds", "last_mistakes", "perfect"]:
			if not _data.has_section(section): continue
			var moved := {}
			for old_id in _data.get_section_keys(section):
				if not mapping.has(old_id): continue
				var value: Variant = _data.get_value(section, old_id)
				_data.set_value("before_red_green_" + section, old_id, value)
				_data.erase_section_key(section, old_id)
				if mapping[old_id] != null: moved[str(mapping[old_id])] = value
			for new_id in moved: _data.set_value(section, new_id, moved[new_id])
	_data.set_value("catalog", "version", version)
	if existing_save: _save()


func _migrate_perfect_records(existing_save: bool) -> void:
	if _data.get_value("stats", "perfect_version", 0) == 1: return
	# Recover zero-mistake clears when an older save contains their result.
	for entry in _catalog:
		if is_completed(entry.id) and _data.has_section_key("last_mistakes", entry.id) and int(_data.get_value("last_mistakes", entry.id)) == 0:
			_data.set_value("perfect", entry.id, true)
	_data.set_value("stats", "perfect_version", 1)
	_data.set_value("stats", "perfect_count", get_perfect_count())
	if existing_save: _save()
