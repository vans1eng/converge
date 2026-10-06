extends Node
class_name BoardController

signal board_changed(state: BoardState)
signal verification_requested

@export var board_view_path: NodePath
@export var level_controller_path: NodePath

var board_state: BoardState
@onready var board_view: HexBoardView = get_node_or_null(board_view_path)
@onready var level_controller: LevelController = get_node_or_null(level_controller_path)


func _ready() -> void:
	if board_view != null:
		board_view.cell_clicked.connect(_on_cell_clicked)
		board_view.cell_hovered.connect(_on_cell_hovered)
	if level_controller != null:
		level_controller.level_loaded.connect(set_board_state)
		verification_requested.connect(level_controller.verify_selected)
		level_controller.cell_verified.connect(_on_cell_verified)


func set_board_state(state: BoardState) -> void:
	board_state = state
	if board_view != null:
		board_view.show_board(board_state)
	board_changed.emit(board_state)


func select_cell(cell_id: String) -> void:
	if board_state == null:
		return
	if board_state.selected_cell_id == cell_id:
		deselect_cell()
		return

	var previously_selected := board_state.selected_cell_id
	board_state.select(cell_id)
	if previously_selected != board_state.selected_cell_id:
		AudioManager.play_cell_select()
	_refresh()


func deselect_cell() -> void:
	if board_state == null or board_state.selected_cell_id.is_empty():
		return
	board_state.clear_selection()
	_refresh()


func change_selected_value(delta: int) -> void:
	var runtime := _selected_runtime()
	if runtime == null or runtime.pending_black:
		return
	var definition := board_state.get_definition(board_state.selected_cell_id)
	if definition.mode == CellDefinition.MODE_CANDIDATE:
		_cycle_candidate(definition, runtime, delta)

	_refresh()


func pick_selected_color(type: String) -> void:
	var definition := _selected_definition()
	var runtime := _selected_runtime()
	if definition == null or runtime == null or runtime.solved or type not in definition.candidate_types:
		return
	runtime.candidate_pick = type
	runtime.wrong = false
	_refresh()


func clear_selected_input() -> void:
	var runtime := _selected_runtime()
	if runtime == null:
		return
	var definition := _selected_definition()
	if definition != null and definition.mode == CellDefinition.MODE_CANDIDATE:
		runtime.candidate_pick = ""
		runtime.wrong = false
		_refresh()
		return


func request_verification() -> void:
	if _selected_runtime() != null:
		verification_requested.emit()


func _cycle_candidate(definition: CellDefinition, runtime: CellRuntimeState, delta := 1) -> void:
	var current := definition.candidate_types.find(runtime.candidate_pick)
	var step := 1 if delta >= 0 else -1
	if current < 0:
		runtime.candidate_pick = definition.candidate_types[0 if step > 0 else definition.candidate_types.size() - 1]
	else:
		runtime.candidate_pick = definition.candidate_types[posmod(current + step, definition.candidate_types.size())]
	runtime.wrong = false


func _selected_runtime() -> CellRuntimeState:
	return board_state.get_runtime(board_state.selected_cell_id) if board_state != null and not board_state.selected_cell_id.is_empty() else null


func _selected_definition() -> CellDefinition:
	return board_state.get_definition(board_state.selected_cell_id) if board_state != null and not board_state.selected_cell_id.is_empty() else null


func _refresh() -> void:
	if board_view != null:
		board_view.refresh()
	board_changed.emit(board_state)


func refresh_view() -> void:
	_refresh()


func _on_cell_clicked(cell_id: String, button_index: int) -> void:
	if button_index == MOUSE_BUTTON_LEFT:
		select_cell(cell_id)
	elif button_index == MOUSE_BUTTON_RIGHT and board_state.selected_cell_id == cell_id:
		request_verification()


func _on_cell_hovered(_cell_id: String) -> void:
	AudioManager.play_cell_hover()


func _on_cell_verified(cell_id: String, correct: bool) -> void:
	if correct:
		AudioManager.play_cell_break()
		if board_view != null:
			board_view.play_success(cell_id)
	else:
		AudioManager.play_cell_wrong()
		if board_view != null:
			board_view.play_error(cell_id)
	_refresh()
