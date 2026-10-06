extends Node
class_name InputController

@export var board_controller_path: NodePath

@onready var board_controller: BoardController = get_node_or_null(board_controller_path)

var gameplay_input_enabled := true


func set_gameplay_input_enabled(enabled: bool) -> void:
	gameplay_input_enabled = enabled


func _input(event: InputEvent) -> void:
	if not gameplay_input_enabled or board_controller == null or board_controller.board_state == null or not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("confirm") or (event is InputEventKey and (event.keycode == KEY_KP_ENTER or event.physical_keycode == KEY_KP_ENTER)):
		if not board_controller.board_state.selected_cell_id.is_empty():
			board_controller.request_verification()
		get_viewport().set_input_as_handled()
		return

	if board_controller.board_state.selected_cell_id.is_empty():
		return

	var handled_gameplay_input := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		board_controller.change_selected_value(1)
		handled_gameplay_input = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		board_controller.change_selected_value(-1)
		handled_gameplay_input = true
	elif event.is_action_pressed("move_up"):
		board_controller.change_selected_value(1)
		handled_gameplay_input = true
	elif event.is_action_pressed("move_down"):
		board_controller.change_selected_value(-1)
		handled_gameplay_input = true
	elif event.is_action_pressed("move_right"):
		board_controller.change_selected_value(1)
		handled_gameplay_input = true
	elif event.is_action_pressed("move_left"):
		board_controller.change_selected_value(-1)
		handled_gameplay_input = true
	elif event.is_action_pressed("clear_input"):
		board_controller.clear_selected_input()
		handled_gameplay_input = true
	if handled_gameplay_input:
		get_viewport().set_input_as_handled()
