extends Node
class_name GameSession

var current_level_id := ""


func start_level(level_id: String) -> void:
	current_level_id = level_id
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func return_home() -> void:
	current_level_id = ""
	get_tree().change_scene_to_file("res://scenes/home_page.tscn")
