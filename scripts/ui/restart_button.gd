extends Button


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	theme_changed.connect(queue_redraw)


func _draw() -> void:
	var color := get_theme_color("font_hover_color" if is_hovered() else "font_color")
	var icon_size := (minf(size.x, size.y) - 5.0) * 24.0 / 18.0
	var origin := (size - Vector2.ONE * icon_size) * 0.5
	var scale_factor := icon_size / 24.0
	var width := 0.8 * scale_factor
	# Follow the same counterclockwise path as the web SVG, in a 24px square.
	var points := PackedVector2Array()
	for index in 49:
		var angle := lerpf(PI, -PI * 0.5, float(index) / 48.0)
		points.append(origin + (Vector2(12, 12) + Vector2.from_angle(angle) * 9.0) * scale_factor)
	for index in range(1, 13):
		var t := float(index) / 12.0
		var point := Vector2(12, 3).bezier_interpolate(Vector2(9.5, 3), Vector2(7.3, 4), Vector2(5.7, 5.6), t)
		points.append(origin + point * scale_factor)
	points.append(origin + Vector2(3, 8) * scale_factor)
	draw_polyline(points, color, width, true)
	draw_circle(points[0], width * 0.5, color, true, -1.0, true)
	var arrow := PackedVector2Array([Vector2(3, 3), Vector2(3, 8), Vector2(8, 8)])
	for index in arrow.size():
		arrow[index] = origin + arrow[index] * scale_factor
	draw_polyline(arrow, color, width, true)
	for point in arrow:
		draw_circle(point, width * 0.5, color, true, -1.0, true)
