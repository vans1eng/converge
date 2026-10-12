extends RefCounted
class_name LevelValidator

var issues: Array[String] = []


func validate(level: LevelDefinition) -> bool:
	issues.clear()
	if level == null:
		issues.append("Level is missing.")
		return false
	if level.id.is_empty() or level.layout != "odd_r" or level.rows <= 0 or level.columns <= 0 or level.cells.is_empty():
		issues.append("Invalid level identity or board dimensions.")
	if level.allowed_colors != ["red", "green"] or level.infer_yellow:
		issues.append("Only red and green may be inferred; purple/yellow are fixed clues.")
	var ids := {}
	var positions := {}
	for cell in level.cells:
		if cell.id.is_empty() or ids.has(cell.id) or positions.has(cell.position_key()):
			issues.append("Duplicate cell identity or position: %s" % cell.id)
		ids[cell.id] = true
		positions[cell.position_key()] = true
		if cell.row < 0 or cell.row >= level.rows or cell.col < 0 or cell.col >= level.columns:
			issues.append("Cell outside board: %s" % cell.id)
		if cell.mode not in [CellDefinition.MODE_FIXED, CellDefinition.MODE_CANDIDATE] or not CellDefinition.is_valid_type(cell.effective_type()):
			issues.append("Invalid cell mode or color: %s" % cell.id)
		if cell.scope_radius < 1 or cell.scope_radius > 30 or (cell.scope_radius > 1 and cell.effective_type() not in CellDefinition.RADIUS_CLUE_TYPES):
			issues.append("Invalid radius: %s" % cell.id)
		if not cell.direction.is_empty() and (cell.direction not in CellDefinition.DIRECTIONS or cell.effective_type() not in CellDefinition.ANSWER_TYPES or cell.scope_radius != 1):
			issues.append("Invalid arrow: %s" % cell.id)
		if cell.hidden and not (cell.mode == CellDefinition.MODE_CANDIDATE or (cell.mode == CellDefinition.MODE_FIXED and cell.type in CellDefinition.ANSWER_TYPES)):
			issues.append("Only candidates and fixed red/green bricks may hide numbers: %s" % cell.id)
		if cell.keep_hidden and (not cell.hidden or cell.mode != CellDefinition.MODE_CANDIDATE):
			issues.append("Permanent hiding requires a hidden candidate: %s" % cell.id)
		if cell.is_black():
			if cell.mode != CellDefinition.MODE_FIXED or cell.value != null:
				issues.append("Walls must be fixed and have no value: %s" % cell.id)
		else:
			if cell.value == null or not (cell.value is int or cell.value is float) or float(cell.value) < 0 or float(cell.value) != floorf(float(cell.value)):
				issues.append("Color cells need public nonnegative integers: %s" % cell.id)
		if cell.mode == CellDefinition.MODE_CANDIDATE:
			if cell.candidate_types != CellDefinition.ANSWER_TYPES or cell.answer_type not in CellDefinition.ANSWER_TYPES:
				issues.append("Candidates must be red/green: %s" % cell.id)
		if cell.effective_type() in [CellDefinition.TYPE_PURPLE, CellDefinition.TYPE_YELLOW] and cell.mode != CellDefinition.MODE_FIXED:
			issues.append("Purple/yellow must be fixed clues: %s" % cell.id)
		if not cell.accepted_answer_types.is_empty():
			if not bool(level.tutorial.get("practice", false)) or level.cells.size() != 1 or cell.mode != CellDefinition.MODE_CANDIDATE or cell.value != 0 or cell.scope_radius != 1 or cell.candidate_types != ["red", "green"] or cell.accepted_answer_types != ["red", "green"]:
				issues.append("Multiple accepted colors are only valid for the single-brick input tutorial.")
	if issues.is_empty():
		var grid := level.create_grid()
		for cell in level.cells:
			if not ClueRules.is_consistent(cell, grid):
				issues.append("Rule value is inconsistent: %s" % cell.id)
	return issues.is_empty()
