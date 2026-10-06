extends RefCounted
class_name ClueRules


static func numeric_value(cell: CellDefinition) -> int:
	if cell == null or cell.is_black():
		return 0
	return int(cell.effective_value()) if cell.effective_value() != null else 0


static func scope(cell: CellDefinition, grid: HexGrid, tile_type: String = "") -> Array[CellDefinition]:
	if tile_type.is_empty():
		tile_type = cell.effective_type()
	var result: Array[CellDefinition] = []
	if tile_type == CellDefinition.TYPE_YELLOW:
		for axis in 3:
			result.append_array(grid.axis_cells(cell, axis))
	else:
		result = grid.cells_within_radius(cell, cell.scope_radius)
	return result.filter(func(other): return not other.is_black())


static func evaluate(cell: CellDefinition, grid: HexGrid) -> Variant:
	var tile_type := cell.effective_type()
	if cell.is_black():
		return null
	var total := 0
	for other in scope(cell, grid):
		if tile_type in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN]:
			if other.effective_type() == tile_type:
				total += 1
		elif other.effective_type() in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN]:
			total += numeric_value(other)
	return total


static func is_consistent(cell: CellDefinition, grid: HexGrid) -> bool:
	return cell.effective_value() == evaluate(cell, grid)


static func compute_values(level: LevelDefinition) -> void:
	var grid := level.create_grid()
	# Counts first; purple/yellow only reference those counts, never each other.
	for cell in level.cells:
		if cell.effective_type() in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN, CellDefinition.TYPE_BLACK]:
			cell.value = evaluate(cell, grid)
	for cell in level.cells:
		if cell.effective_type() in [CellDefinition.TYPE_PURPLE, CellDefinition.TYPE_YELLOW]:
			cell.value = evaluate(cell, grid)
