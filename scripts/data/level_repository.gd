extends RefCounted
class_name LevelRepository

const LEVEL_DIRECTORY := "res://resources/levels"
const DEMO_CHAPTER_ID := 1
static var _catalog_cache: Array[Dictionary] = []
static var _catalog_loaded := false
static var _guide_features_cache: Dictionary = {}
var loader := LevelLoader.new()


static func get_catalog() -> Array[Dictionary]:
	if _catalog_loaded:
		return _catalog_cache.duplicate(true)
	var catalog: Array[Dictionary] = []
	var directory := DirAccess.open(LEVEL_DIRECTORY)
	if directory == null:
		return catalog
	for filename in directory.get_files():
		if not filename.ends_with(".json"):
			continue
		var level := LevelLoader.new().load_file(LEVEL_DIRECTORY.path_join(filename))
		if level != null:
			catalog.append({"id": level.id, "chapter_id": level.chapter_id, "number": int(level.id.get_slice("-", 1)), "file": filename.get_basename()})
	catalog.sort_custom(func(a, b): return a.chapter_id < b.chapter_id if a.chapter_id != b.chapter_id else a.number < b.number)
	_catalog_cache = catalog.duplicate(true)
	_catalog_loaded = true
	return catalog


static func invalidate_catalog() -> void:
	_catalog_cache.clear()
	_catalog_loaded = false
	_guide_features_cache.clear()


static func get_introduced_features(level: LevelDefinition) -> Dictionary:
	if _guide_features_cache.has(level.id):
		return _guide_features_cache[level.id].duplicate()
	var features := {}
	var number := int(level.id.get_slice("-", 1))
	for entry in get_catalog():
		if entry.chapter_id > level.chapter_id or (entry.chapter_id == level.chapter_id and entry.number > number):
			break
		var previous := LevelLoader.new().load_file(LEVEL_DIRECTORY.path_join(entry.file + ".json"))
		if previous != null:
			_collect_guide_features(previous, features)
	_collect_guide_features(level, features)
	_guide_features_cache[level.id] = features.duplicate()
	return features


static func _collect_guide_features(level: LevelDefinition, features: Dictionary) -> void:
	for cell in level.cells:
		features[cell.effective_type()] = true
		for color in cell.candidate_types:
			features[color] = true
		if cell.scope_radius >= 2:
			features["r2"] = true
		if cell.scope_radius >= 3:
			features["r3"] = true


static func get_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in get_catalog():
		ids.append(entry.id)
	return ids


static func get_playable_catalog() -> Array[Dictionary]:
	return get_catalog().filter(func(entry): return entry.chapter_id == DEMO_CHAPTER_ID)


static func get_playable_level_ids() -> Array[String]:
	var ids: Array[String] = []
	for entry in get_playable_catalog():
		ids.append(entry.id)
	return ids


func load_level(level_id: String) -> LevelDefinition:
	for entry in get_catalog():
		if entry.id == level_id or entry.file == level_id:
			return loader.load_file("%s/%s.json" % [LEVEL_DIRECTORY, entry.file])
	return loader.load_file("%s/%s.json" % [LEVEL_DIRECTORY, level_id])


func get_last_error() -> String:
	return loader.last_error
