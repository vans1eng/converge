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
	if not cell.direction.is_empty():
		result = grid.direction_cells(cell, CellDefinition.DIRECTIONS.find(cell.direction))
	elif tile_type == CellDefinition.TYPE_YELLOW:
		for axis in 3:
			result.append_array(grid.axis_cells(cell, axis, cell.scope_radius))
	else:
		result = grid.cells_within_radius(cell, cell.scope_radius)
	return result.filter(func(other): return not other.is_black())


static func evaluate(cell: CellDefinition, grid: HexGrid) -> Variant:
	var tile_type := cell.effective_type()
	if cell.is_black():
		return null
	if tile_type == CellDefinition.TYPE_YELLOW:
		var pairs := 0
		for axis in 3:
			for distance in range(1, cell.scope_radius + 1):
				var first := grid.cell_at_direction_distance(cell, axis, distance)
				var second := grid.cell_at_direction_distance(cell, axis + 3, distance)
				# Either wall makes this and all farther pairs on this axis invalid.
				if (first != null and first.is_black()) or (second != null and second.is_black()):
					break
				if first == null or second == null:
					continue
				if first.effective_type() in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN] and second.effective_type() in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN] and first.effective_type() != second.effective_type():
					pairs += 1
		return pairs
	var total := 0
	for other in scope(cell, grid):
		if tile_type in [CellDefinition.TYPE_RED, CellDefinition.TYPE_GREEN]:
			if other.effective_type() == tile_type:
				total += 1
		elif tile_type == CellDefinition.TYPE_PURPLE:
			if other.effective_type() == CellDefinition.TYPE_RED:
				total += 1
			elif other.effective_type() == CellDefinition.TYPE_GREEN:
				total -= 1
	return absi(total)


static func is_consistent(cell: CellDefinition, grid: HexGrid) -> bool:
	return cell.effective_value() == evaluate(cell, grid)


static func compute_values(level: LevelDefinition) -> void:
	var grid := level.create_grid()
	# All clues now depend only on colors and geometry, never other clue numbers.
	for cell in level.cells:
		cell.value = evaluate(cell, grid)
