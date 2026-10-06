extends RefCounted
class_name CellRuntimeState

var player_value: Variant = null
var pending_negative := false
var pending_black := false
var player_black := false
var candidate_pick := ""
var solved := false
var wrong := false


func clear_input() -> void:
	player_value = null
	pending_negative = false
	pending_black = false
	player_black = false
	candidate_pick = ""
	wrong = false
