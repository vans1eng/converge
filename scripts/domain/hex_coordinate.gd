extends RefCounted
class_name HexCoordinate

# Axial directions used by the odd-r offset grid.
const DIRECTIONS := [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]


static func key(row: int, col: int) -> String:
	return "%d,%d" % [row, col]


static func offset_to_axial(row: int, col: int) -> Vector2i:
	return Vector2i(col - ((row - (row & 1)) >> 1), row)


static func axial_to_offset(axial: Vector2i) -> Vector2i:
	return Vector2i(axial.y, axial.x + ((axial.y - (axial.y & 1)) >> 1))


static func neighbor_position(row: int, col: int, direction_index: int) -> Vector2i:
	var axial: Vector2i = offset_to_axial(row, col) + DIRECTIONS[direction_index]
	return axial_to_offset(axial)
