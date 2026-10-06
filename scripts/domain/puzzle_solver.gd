extends RefCounted
class_name PuzzleSolver

# This solver is for editor/generator validation. Runtime verification uses AnswerVerifier.
var _level: LevelDefinition
var _variables: Array[CellDefinition] = []
var _domains: Dictionary = {}
var _source_totals: Dictionary = {}
var _solutions := 0
var _stop_after := 2


func count_solutions(level: LevelDefinition, domains_by_cell: Dictionary, stop_after: int = 2) -> int:
	_source_totals.clear()
	for cell in level.cells:
		var type := cell.effective_type()
		_source_totals[type] = int(_source_totals.get(type, 0)) + 1
	_level = _copy_level(level)
	_domains = domains_by_cell
	_stop_after = max(1, stop_after)
	_solutions = 0
	_variables.clear()
	for cell in _level.cells:
		if cell.is_editable():
			_variables.append(cell)
	_search(0)
	return _solutions


func has_unique_solution(level: LevelDefinition, domains_by_cell: Dictionary) -> bool:
	return count_solutions(level, domains_by_cell, 2) == 1


func _search(index: int) -> void:
	if _solutions >= _stop_after:
		return
	if index == _variables.size():
		if _all_clues_consistent():
			_solutions += 1
		return

	var cell := _variables[index]
	for option in _domains.get(cell.id, []):
		_apply_option(cell, option)
		_search(index + 1)
		if _solutions >= _stop_after:
			return


func _apply_option(cell: CellDefinition, option: Variant) -> void:
	if cell.mode == CellDefinition.MODE_CANDIDATE:
		cell.answer_type = str(option)
		return
	if option is Dictionary:
		cell.answer_type = str(option.get("type", ""))
		cell.answer_value = option.get("value", null)


func _all_clues_consistent() -> bool:
	var grid := _level.create_grid()
	for cell in _level.cells:
		if cell.is_clue() and not ClueRules.is_consistent(cell, grid):
			return false
	for type in CellDefinition.COLOR_TYPES:
		var expected := _level.cells.filter(func(cell): return cell.effective_type() == type).size()
		var authored := _source_totals.get(type, 0)
		if expected != authored:
			return false
	return true


func _copy_level(source: LevelDefinition) -> LevelDefinition:
	var copy := LevelDefinition.new()
	copy.id = source.id
	copy.layout = source.layout
	copy.infer_yellow = source.infer_yellow
	copy.rows = source.rows
	copy.columns = source.columns
	for source_cell in source.cells:
		var cell := CellDefinition.new()
		cell.id = source_cell.id
		cell.row = source_cell.row
		cell.col = source_cell.col
		cell.mode = source_cell.mode
		cell.type = source_cell.type
		cell.value = source_cell.value
		cell.scope_radius = source_cell.scope_radius
		cell.candidate_types = source_cell.candidate_types.duplicate()
		cell.answer_type = source_cell.answer_type
		cell.answer_value = source_cell.answer_value
		copy.cells.append(cell)
	return copy
