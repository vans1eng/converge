extends Button

const HIT_PADDING := Vector2(4.0, 4.0)


func _has_point(point: Vector2) -> bool:
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var text_size := font.get_string_size(tr(text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var style := get_theme_stylebox("normal")
	var content_left := style.get_margin(SIDE_LEFT)
	var content_right := size.x - style.get_margin(SIDE_RIGHT)
	var content_top := style.get_margin(SIDE_TOP)
	var content_bottom := size.y - style.get_margin(SIDE_BOTTOM)
	var text_left := (content_left + content_right - text_size.x) * 0.5
	match alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			text_left = content_left
		HORIZONTAL_ALIGNMENT_RIGHT:
			text_left = content_right - text_size.x
	var text_top := (content_top + content_bottom - text_size.y) * 0.5
	var hit_rect := Rect2(Vector2(text_left, text_top) - HIT_PADDING, text_size + HIT_PADDING * 2.0)
	return Rect2(Vector2.ZERO, size).intersection(hit_rect).has_point(point)
