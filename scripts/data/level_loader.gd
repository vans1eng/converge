extends RefCounted
class_name LevelLoader

var last_error := ""


func load_file(path: String) -> LevelDefinition:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "Level file does not exist: %s" % path
		return null

	var json := JSON.new()
	var parse_result := json.parse(FileAccess.get_file_as_string(path))
	if parse_result != OK or not (json.data is Dictionary):
		last_error = "Invalid JSON in %s: %s" % [path, json.get_error_message()]
		return null
	return LevelDefinition.from_dictionary(json.data)
