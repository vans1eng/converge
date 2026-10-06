extends Node2D
class_name HexScopeOverlay

# Match the SVG union: cancel shared edges, inset only the exterior/hole
# boundaries, and share the resulting vertices between touching hexagons.
const VERTICES := [Vector2i(1, -1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(0, -2)]
var polygons: Array[PackedVector2Array] = []
var color := Color.TRANSPARENT
var target_color := Color.TRANSPARENT
var amount := 0.0
var target_amount := 0.0


func _ready() -> void:
	hide()
	set_process(false)


func configure(source: CellDefinition, cells: Array[CellDefinition], grid_radius: float, gap: float) -> void:
	polygons.clear()
	var origin := HexCoordinate.offset_to_axial(source.row, source.col)
	var edges := {}
	var tiles: Array[Array] = []
	for cell in cells:
		if cell.is_black():
			continue
		var axial := HexCoordinate.offset_to_axial(cell.row, cell.col) - origin
		var center := Vector2i(2 * axial.x + axial.y, 3 * axial.y)
		var vertices: Array[Vector2i] = []
		for vertex in VERTICES:
			vertices.append(center + vertex)
		tiles.append(vertices)
		for index in 6:
			var a := vertices[index]
			var b := vertices[(index + 1) % 6]
			if edges.has([b, a]):
				edges.erase([b, a])
			else:
				edges[[a, b]] = true
	var adjusted := {}
	while not edges.is_empty():
		var edge: Array = edges.keys()[0]
		var start: Vector2i = edge[0]
		var loop: Array[Vector2i] = []
		while true:
			loop.append(edge[0])
			edges.erase(edge)
			if edge[1] == start:
				break
			var next: Array = []
			for candidate in edges:
				if candidate[0] == edge[1]:
					next = candidate
					break
			if next.is_empty():
				break
			edge = next
		for index in loop.size():
			var p := _pixel(loop[index], grid_radius)
			var before := _pixel(loop[posmod(index - 1, loop.size())], grid_radius)
			var after := _pixel(loop[(index + 1) % loop.size()], grid_radius)
			var incoming := (p - before).normalized()
			var outgoing := (after - p).normalized()
			var n1 := Vector2(-incoming.y, incoming.x)
			var n2 := Vector2(-outgoing.y, outgoing.x)
			adjusted[loop[index]] = p + (n1 + n2) * (gap * sqrt(3.0) / 2.0) / (1.0 + n1.dot(n2))
	for tile in tiles:
		var polygon := PackedVector2Array()
		for vertex in tile:
			polygon.append(adjusted.get(vertex, _pixel(vertex, grid_radius)))
		polygons.append(polygon)
	queue_redraw()


func set_active(active: bool, fill: Color) -> void:
	target_amount = 1.0 if active else 0.0
	if active:
		target_color = Color(fill.r, fill.g, fill.b, 0.3)
		if color.a == 0.0:
			color = target_color
	set_process(amount != target_amount or (active and not color.is_equal_approx(target_color)))


func _pixel(vertex: Vector2i, grid_radius: float) -> Vector2:
	return Vector2(vertex.x * sqrt(3.0) * grid_radius / 2.0, vertex.y * grid_radius / 2.0)


func _process(delta: float) -> void:
	amount = lerpf(amount, target_amount, 1.0 - pow(0.81, delta * 60.0))
	if absf(amount - target_amount) < 0.005:
		amount = target_amount
	color = color.lerp(target_color, 1.0 - pow(0.9, delta * 60.0))
	if maxf(maxf(absf(color.r - target_color.r), absf(color.g - target_color.g)), maxf(absf(color.b - target_color.b), absf(color.a - target_color.a))) < 0.001:
		color = target_color
	scale = Vector2.ONE * maxf(amount, 0.00001)
	visible = amount > 0.0
	queue_redraw()
	if amount == target_amount and (amount == 0.0 or color == target_color):
		set_process(false)


func _draw() -> void:
	for polygon in polygons:
		draw_colored_polygon(polygon, color)
