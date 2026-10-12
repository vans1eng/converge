extends RefCounted
class_name PuzzleSolver

# Only visible clues constrain a search. Hidden numbers become clues once
# their colors are forced; permanently hidden numbers never become clues.
var _level: LevelDefinition
var _variables: Array[CellDefinition] = []
var _domains: Dictionary = {}
var _assigned: Dictionary = {}
var _visible: Dictionary = {}
var _scopes: Dictionary = {}
var _pairs: Dictionary = {}
var _solutions := 0
var _stop_after := 2
var nodes := 0
var capped := false
var node_cap := 400000


func _prepare(level: LevelDefinition, domains_by_cell: Dictionary) -> void:
	_level = level
	_domains = domains_by_cell
	_variables.clear()
	_assigned.clear()
	_visible.clear()
	_scopes.clear()
	_pairs.clear()
	nodes = 0
	capped = false
	var grid := level.create_grid()
	for cell in level.cells:
		if cell.is_editable():
			_variables.append(cell)
		else:
			_assigned[cell.id] = cell.effective_type()
		if cell.is_number_visible(): _visible[cell.id] = true
		_scopes[cell.id] = ClueRules.scope(cell, grid)
		var pairs: Array = []
		if cell.effective_type() == CellDefinition.TYPE_YELLOW:
			for axis in 3:
				for distance in range(1, cell.scope_radius + 1):
					var first := grid.cell_at_direction_distance(cell, axis, distance)
					var second := grid.cell_at_direction_distance(cell, axis + 3, distance)
					if (first != null and first.is_black()) or (second != null and second.is_black()): break
					if first != null and second != null: pairs.append([first.id, second.id])
		_pairs[cell.id] = pairs


func count_solutions(level: LevelDefinition, domains_by_cell: Dictionary, stop_after: int = 2) -> int:
	_prepare(level, domains_by_cell)
	_solutions = 0
	_stop_after = maxi(1, stop_after)
	if _partial_consistent(): _search(0)
	return _solutions


func has_unique_solution(level: LevelDefinition, domains_by_cell: Dictionary) -> bool:
	return bool(analyze(level, domains_by_cell).unique)


func analyze(level: LevelDefinition, domains_by_cell: Dictionary = {}) -> Dictionary:
	var validator := LevelValidator.new()
	if not validator.validate(level):
		return {"unique": false, "capped": false, "nodes": 0, "unresolved": [], "issues": validator.issues.duplicate()}
	_prepare(level, domains_by_cell)
	var known := {}
	var progress := true
	while progress and not capped:
		progress = false
		for cell in _variables:
			if known.has(cell.id): continue
			if not cell.accepted_answer_types.is_empty():
				known[cell.id] = true
				continue
			var alternative := false
			for option in _options(cell):
				if option == cell.answer_type: continue
				_assigned[cell.id] = option
				_solutions = 0
				_stop_after = 1
				if _partial_consistent(): _search(0)
				_assigned.erase(cell.id)
				if _solutions > 0 or capped:
					alternative = true
					break
			if capped: break
			if not alternative:
				known[cell.id] = true
				_assigned[cell.id] = cell.answer_type
				if cell.is_number_visible(true): _visible[cell.id] = true
				progress = true
	var unresolved: Array[String] = []
	for cell in _variables:
		if not known.has(cell.id): unresolved.append(cell.id)
	return {"unique": not capped and unresolved.is_empty(), "capped": capped, "nodes": nodes, "unresolved": unresolved}


func _options(cell: CellDefinition) -> Array:
	return _domains.get(cell.id, cell.candidate_types)


func _search(index: int) -> void:
	nodes += 1
	if nodes > node_cap:
		capped = true
		return
	if capped or _solutions >= _stop_after: return
	if index == _variables.size():
		_solutions += 1
		return
	var cell := _variables[index]
	if _assigned.has(cell.id):
		_search(index + 1)
		return
	for option in _options(cell):
		_assigned[cell.id] = option
		if _partial_consistent(): _search(index + 1)
		_assigned.erase(cell.id)
		if capped or _solutions >= _stop_after: return


func _partial_consistent() -> bool:
	for cell in _level.cells:
		if not _visible.has(cell.id): continue
		var possible := false
		var types: Array = [_assigned[cell.id]] if _assigned.has(cell.id) else _options(cell)
		for type in types:
			if _clue_possible(cell, str(type)):
				possible = true
				break
		if not possible: return false
	return true


func _clue_possible(cell: CellDefinition, type: String) -> bool:
	var value := ClueRules.numeric_value(cell)
	if type == CellDefinition.TYPE_YELLOW:
		var low := 0
		var high := 0
		for pair in _pairs[cell.id]:
			var first: String = _assigned.get(pair[0], "")
			var second: String = _assigned.get(pair[1], "")
			if first in CellDefinition.ANSWER_TYPES and second in CellDefinition.ANSWER_TYPES:
				if first != second:
					low += 1
					high += 1
			elif (first.is_empty() or first in CellDefinition.ANSWER_TYPES) and (second.is_empty() or second in CellDefinition.ANSWER_TYPES):
				high += 1
		return low <= value and value <= high
	var red := 0
	var green := 0
	var unknown := 0
	for other in _scopes[cell.id]:
		match _assigned.get(other.id, ""):
			"red": red += 1
			"green": green += 1
			"": unknown += 1
	if type == CellDefinition.TYPE_RED: return red <= value and value <= red + unknown
	if type == CellDefinition.TYPE_GREEN: return green <= value and value <= green + unknown
	if type == CellDefinition.TYPE_PURPLE:
		var diff := red - green
		for target in [value, -value]:
			if absi(target - diff) <= unknown and (target - diff - unknown) % 2 == 0: return true
	return false
