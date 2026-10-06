extends Node
class_name LevelController

signal level_loaded(board_state: BoardState)
signal cell_verified(cell_id: String, correct: bool)
signal level_completed
signal load_failed(message: String)

var repository := LevelRepository.new()
var validator := LevelValidator.new()
var board_state: BoardState


func load_level(level_id: String) -> bool:
	var definition := repository.load_level(level_id)
	if definition == null:
		load_failed.emit(repository.get_last_error())
		return false
	if not validator.validate(definition):
		load_failed.emit("\n".join(validator.issues))
		return false
	board_state = BoardState.new(definition)
	level_loaded.emit(board_state)
	return true


func verify_selected() -> void:
	if board_state == null or board_state.selected_cell_id.is_empty():
		return
	var cell_id := board_state.selected_cell_id
	var result := AnswerVerifier.verify(board_state.get_definition(cell_id), board_state.get_runtime(cell_id))
	if result.reason != "":
		return

	var runtime := board_state.get_runtime(cell_id)
	runtime.wrong = not result.ok
	if result.ok:
		runtime.solved = true
		board_state.clear_selection()
		cell_verified.emit(cell_id, true)
		if board_state.is_complete():
			level_completed.emit()
		return

	board_state.mistakes += 1
	cell_verified.emit(cell_id, false)
