extends RefCounted
class_name HexGrid

var _cells_by_position: Dictionary = {}
var _rows := 0
var _columns := 0


func _init(cells: Array = [], rows: int = 0, columns: int = 0) -> void:
	_rows = rows
	_columns = columns
	for cell in cells:
		_cells_by_position[cell.position_key()] = cell
		_rows = max(_rows, cell.row + 1)
		_columns = max(_columns, cell.col + 1)


func get_cell(row: int, col: int) -> CellDefinition:
	# Missing coordinates are empty space, not a black cell.
	return _cells_by_position.get(HexCoordinate.key(row, col), null) as CellDefinition


func neighbors(cell: CellDefinition) -> Array[CellDefinition]:
	var result: Array[CellDefinition] = []
	for direction_index in HexCoordinate.DIRECTIONS.size():
		var neighbor: CellDefinition = neighbor_at_direction(cell, direction_index)
		if neighbor != null:
			result.append(neighbor)
	return result


func cells_within_radius(cell: CellDefinition, radius: int) -> Array[CellDefinition]:
	var result: Array[CellDefinition] = []
	var origin := HexCoordinate.offset_to_axial(cell.row, cell.col)
	for other in _cells_by_position.values():
		if other == cell:
			continue
		var position := HexCoordinate.offset_to_axial(other.row, other.col)
		var delta := position - origin
		var distance := maxi(maxi(abs(delta.x), abs(delta.y)), abs(delta.x + delta.y))
		if distance <= radius:
			result.append(other)
	return result


func neighbor_at_direction(cell: CellDefinition, direction_index: int) -> CellDefinition:
	var position: Vector2i = HexCoordinate.neighbor_position(cell.row, cell.col, direction_index)
	return get_cell(position.x, position.y)


func cell_at_direction_distance(cell: CellDefinition, direction_index: int, distance: int) -> CellDefinition:
	var axial: Vector2i = HexCoordinate.offset_to_axial(cell.row, cell.col) + HexCoordinate.DIRECTIONS[direction_index] * distance
	var position := HexCoordinate.axial_to_offset(axial)
	return get_cell(position.x, position.y)


func axis_cells(cell: CellDefinition, direction_index: int) -> Array[CellDefinition]:
	var result: Array[CellDefinition] = []
	var origin: Vector2i = HexCoordinate.offset_to_axial(cell.row, cell.col)
	var direction: Vector2i = HexCoordinate.DIRECTIONS[direction_index]

	for direction_sign in [1, -1]:
		var current: Vector2i = origin
		while true:
			current += direction * direction_sign
			var offset: Vector2i = HexCoordinate.axial_to_offset(current)
			if offset.x < 0 or offset.x >= _rows or offset.y < 0 or offset.y >= _columns:
				break
			var axis_cell: CellDefinition = get_cell(offset.x, offset.y)
			if axis_cell != null:
				if axis_cell.is_black():
					break
				result.append(axis_cell)
	return result
