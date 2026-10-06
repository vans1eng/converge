extends Control
class_name HeartIcon

const ICON_SIZE := 22.0
const CURVE_STEPS := 12

var heart_color := Color(1.0, 0.42, 0.42)
var heart_opacity := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var points := PackedVector2Array()
	# The same rounded silhouette as the former SVG, sampled as a path at draw time.
	points = _append_curve(points, Vector2(11.0, 19.5), Vector2(9.3, 18.1), Vector2(2.0, 13.2), Vector2(2.0, 8.7))
	points = _append_curve(points, Vector2(2.0, 8.7), Vector2(2.0, 3.1), Vector2(8.8, 2.1), Vector2(11.0, 6.3))
	points = _append_curve(points, Vector2(11.0, 6.3), Vector2(13.2, 2.1), Vector2(20.0, 3.1), Vector2(20.0, 8.7))
	points = _append_curve(points, Vector2(20.0, 8.7), Vector2(20.0, 13.2), Vector2(12.7, 18.1), Vector2(11.0, 19.5))
	var offset := (size - Vector2(ICON_SIZE, ICON_SIZE)) * 0.5
	for index in points.size():
		points[index] += offset
	var color := heart_color
	color.a *= heart_opacity
	draw_colored_polygon(points, color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, color, 1.0, true)


func _append_curve(points: PackedVector2Array, start: Vector2, control_1: Vector2, control_2: Vector2, end: Vector2) -> PackedVector2Array:
	for step in CURVE_STEPS:
		var t := float(step) / float(CURVE_STEPS)
		var inverse := 1.0 - t
		points.append(start * pow(inverse, 3) + control_1 * 3.0 * pow(inverse, 2) * t + control_2 * 3.0 * inverse * t * t + end * pow(t, 3))
	return points
