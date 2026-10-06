extends Button


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	theme_changed.connect(queue_redraw)


func _draw() -> void:
	var color := get_theme_color("font_hover_color" if is_hovered() else "font_color")
	var center := size * 0.5
	var radius := 9.0
	var start := deg_to_rad(-55.0)
	draw_arc(center, radius, start, deg_to_rad(245.0), 40, color, 1.8, true)
	var tip := center + Vector2.from_angle(start) * radius
	draw_polyline(PackedVector2Array([tip + Vector2(-5, -1), tip, tip + Vector2(0, 5)]), color, 1.8, true)
