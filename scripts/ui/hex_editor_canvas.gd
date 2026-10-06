extends Control
class_name HexEditorCanvas

signal cell_selected(row: int, col: int)

const DEFAULT_PALETTE := preload("res://resources/themes/dark_palette.tres")
const CELL_FONT := preload("res://assets/fonts/MiSans-Light.ttf")

var columns := 6
var rows := 4
var cells: Dictionary = {}
var selected := Vector2i(-1, -1)
var _radius := 30.0
var _origin := Vector2.ZERO


func _ready() -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.theme_changed.connect(func(_is_dark_theme): queue_redraw())
	resized.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func configure(new_columns: int, new_rows: int, new_cells: Dictionary, new_selected: Vector2i) -> void:
	columns = new_columns
	rows = new_rows
	cells = new_cells
	selected = new_selected
	queue_redraw()


func _draw() -> void:
	if columns <= 0 or rows <= 0:
		return
	var palette := _palette()
	var width := sqrt(3.0) * _radius
	var height := 1.5 * _radius
	var board_width := (columns + 0.5) * width
	var board_height := (rows - 1) * height + _radius * 2.0
	_radius = clampf(minf((size.x - 36.0) / (sqrt(3.0) * (columns + 0.5)), (size.y - 36.0) / (1.5 * (rows - 1) + 2.0)), 2.0, 34.0)
	width = sqrt(3.0) * _radius
	height = 1.5 * _radius
	board_width = (columns + 0.5) * width
	board_height = (rows - 1) * height + _radius * 2.0
	_origin = size * 0.5 - Vector2(board_width, board_height) * 0.5 + Vector2(width * 0.5, _radius)

	for row in rows:
		for col in columns:
			var position := _cell_position(row, col)
			var cell: Dictionary = cells.get(_key(row, col), {})
			var points := _hex_points(position)
			var tile_type := _tile_type(cell)
			if cell.is_empty():
				_outline(points, Color(palette.main_text, 0.3), 1.0, true)
			else:
				draw_colored_polygon(points, _brick_color(tile_type))
				if str(cell.get("mode", "fixed")) == "candidate":
					var inner := PackedVector2Array()
					for point in points: inner.append(position + (point - position) * 0.78)
					_outline(inner, Color(palette.cell_text, 0.55), 1.0, true)
			if selected == Vector2i(col, row):
				_outline(points, palette.main_text, 2.5)
			var label := _label_for(cell)
			if not label.is_empty():
				var scope_radius := int(cell.get("scope_radius", 1))
				var text_y := _radius * (0.12 if scope_radius > 1 else 0.22)
				draw_string(CELL_FONT, Vector2(position.x - _radius, position.y + text_y), label, HORIZONTAL_ALIGNMENT_CENTER, _radius * 2.0, _radius * 0.63, palette.cell_text)
				if scope_radius > 1:
					draw_string(CELL_FONT, Vector2(position.x - _radius, position.y + _radius * 0.66), "r%d" % scope_radius, HORIZONTAL_ALIGNMENT_CENTER, _radius * 2.0, maxf(10.0, _radius * 0.30), palette.cell_text)


func _outline(points: PackedVector2Array, color: Color, width: float, dashed := false) -> void:
	for index in points.size():
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		if dashed:
			draw_dashed_line(start, end, color, width, 3.0, true, true)
		else:
			draw_line(start, end, color, width, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for row in rows:
			for col in columns:
				if Geometry2D.is_point_in_polygon(event.position, _hex_points(_cell_position(row, col))):
					cell_selected.emit(row, col)
					accept_event()
					return


func _cell_position(row: int, col: int) -> Vector2:
	return _origin + Vector2(sqrt(3.0) * _radius * (col + 0.5 * (row & 1)), 1.5 * _radius * row)


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 6:
		points.append(center + Vector2.from_angle(deg_to_rad(60.0 * index - 30.0)) * (_radius - 1.5))
	return points


func _key(row: int, col: int) -> String:
	return "%d:%d" % [row, col]


func _tile_type(cell: Dictionary) -> String:
	if cell.is_empty():
		return "black"
	var mode := str(cell.get("mode", "fixed"))
	if mode == "hidden":
		return "black"
	if mode == "candidate":
		return str(cell.get("answer", {}).get("type", "red"))
	return str(cell.get("type", "red"))


func _palette() -> GameColorPalette:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	return theme_manager.get_palette() if theme_manager != null else DEFAULT_PALETTE


func _brick_color(type: String) -> Color:
	var palette := _palette()
	match type:
		"red": return palette.red
		"black_neighbor_count": return palette.orange
		"yellow": return palette.yellow
		"green": return palette.green
		"opposite_pair_sum": return palette.cyan
		"same_neighbor_value": return palette.blue
		"purple": return palette.purple
		_: return palette.black


func _label_for(cell: Dictionary) -> String:
	if cell.is_empty():
		return ""
	var mode := str(cell.get("mode", "fixed"))
	if mode == "hidden":
		return "?"
	if mode == "red_input":
		return "?"
	if mode == "candidate":
		return str(int(cell.get("value", 0)))
	var tile_type := str(cell.get("type", "red"))
	return "" if tile_type == "black" else str(int(cell.get("value", 0)))
