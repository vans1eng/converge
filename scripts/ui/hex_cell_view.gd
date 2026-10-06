extends Node2D
class_name HexCellView

const DEFAULT_PALETTE := preload("res://resources/themes/dark_palette.tres")
const CELL_FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const SHADOW_LAYERS := [
	{"offset": Vector2(7.0, 7.0), "opacity": 0.06},
	{"offset": Vector2(6.0, 6.0), "opacity": 0.09},
	{"offset": Vector2(5.0, 5.0), "opacity": 0.13},
	{"offset": Vector2(4.0, 4.0), "opacity": 0.18},
]
const HOVER_MASK_OPACITY := 0.3
const SELECTED_MASK_OPACITY := 0.4
const SOLVED_MASK_OPACITY := 0.2
const STATE_MASK_TRANSITION_DURATION := 0.2
const MASK_SCALE_SNAP_DISTANCE := 0.001
const BREAK_DURATION := 0.8
const FILL_SNAP_DISTANCE := 0.001

var scope_overlay: HexScopeOverlay
var _current_fill := Color.TRANSPARENT
var definition: CellDefinition
var runtime: CellRuntimeState
var radius := 32.0
var grid_radius := 32.0
var is_hovered := false
var is_selected := false
var intelligence_visible := true
var state_mask_opacity := 0.0
var dot_scales: Dictionary = {}
var _scale_tween: Tween
var _state_mask_tween: Tween
var _error_shake_tween: Tween
var _error_flash_tween: Tween
var _error_offset := 0.0
var error_flash_opacity := 0.0
var _break_shards: Array[Dictionary] = []
var _break_elapsed := 0.0
var _last_display_text := ""


func setup(cell_definition: CellDefinition, cell_runtime: CellRuntimeState, cell_radius: float, layout_radius: float) -> void:
	var initializing := definition != cell_definition or runtime != cell_runtime
	var geometry_changed := radius != cell_radius or grid_radius != layout_radius
	definition = cell_definition
	runtime = cell_runtime
	radius = cell_radius
	grid_radius = layout_radius
	# Initialize before the first draw; entrance animates scale, not color.
	if initializing:
		if _state_mask_tween != null:
			_state_mask_tween.kill()
		is_hovered = false
		is_selected = false
		_current_fill = _fill_color()
		state_mask_opacity = _target_state_mask_opacity()
	for type in definition.candidate_types:
		if not dot_scales.has(type):
			dot_scales[type] = 1.0
	# Scale tweens use cached draw commands; only color/dot/shard changes need processing.
	set_process(not _current_fill.is_equal_approx(_fill_color()) or _dots_animating() or not _break_shards.is_empty())
	var text := _display_text()
	if initializing or geometry_changed or text != _last_display_text:
		queue_redraw()
	_last_display_text = text


func set_intelligence_visible(visible: bool) -> void:
	if intelligence_visible != visible:
		intelligence_visible = visible
		queue_redraw()


func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	_update_state_mask_opacity()


func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_state_mask_opacity()


func _process(_delta: float) -> void:
	var redraw_needed := false
	if definition != null:
		var desired_fill := _fill_color()
		if _current_fill.a == 0.0:
			_current_fill = desired_fill
			redraw_needed = true
		if not _current_fill.is_equal_approx(desired_fill):
			_current_fill = _current_fill.lerp(desired_fill, 1.0 - exp(-_delta * 12.0))
			if maxf(maxf(absf(_current_fill.r - desired_fill.r), absf(_current_fill.g - desired_fill.g)), maxf(absf(_current_fill.b - desired_fill.b), absf(_current_fill.a - desired_fill.a))) < FILL_SNAP_DISTANCE:
				_current_fill = desired_fill
			redraw_needed = true
	if not _break_shards.is_empty():
		_break_elapsed += _delta
		if _break_elapsed >= BREAK_DURATION:
			_break_shards.clear()
			_update_overlay_z_index()
		else:
			for shard in _break_shards:
				shard["position"] += shard["velocity"] * _delta
				shard["velocity"] += Vector2(0.0, 300.0) * _delta
				shard["rotation"] += shard["spin"] * _delta
		redraw_needed = true
	if definition != null and definition.mode == CellDefinition.MODE_CANDIDATE:
		for type in definition.candidate_types:
			var target_dot_scale := 0.075 / 0.045 if type == runtime.candidate_pick else 1.0
			var dot_scale := float(dot_scales.get(type, 1.0))
			if not is_equal_approx(dot_scale, target_dot_scale):
				dot_scale = lerpf(dot_scale, target_dot_scale, _frame_rate_independent_factor(0.19, _delta))
				if absf(dot_scale - target_dot_scale) < MASK_SCALE_SNAP_DISTANCE:
					dot_scale = target_dot_scale
				dot_scales[type] = dot_scale
				redraw_needed = true
	if redraw_needed:
		_update_overlay_z_index()
		queue_redraw()
	else:
		set_process(false)


func _dots_animating() -> bool:
	if definition.mode != CellDefinition.MODE_CANDIDATE or runtime.solved:
		return false
	for type in definition.candidate_types:
		var target := 0.075 / 0.045 if type == runtime.candidate_pick else 1.0
		if not is_equal_approx(float(dot_scales.get(type, 1.0)), target):
			return true
	return false


func play_success() -> void:
	_create_break_shards()
	if _scale_tween != null:
		_scale_tween.kill()
	scale = Vector2.ONE
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * 1.12, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func play_error() -> void:
	if _error_shake_tween != null:
		_error_shake_tween.kill()
	if _error_flash_tween != null:
		_error_flash_tween.kill()
	_set_error_offset(0.0)
	error_flash_opacity = 0.0
	_error_shake_tween = create_tween()
	var previous_offset := 0.0
	for offset in [7.0, -7.0, 5.0, -5.0, 2.0, 0.0]:
		_error_shake_tween.tween_method(_set_error_offset, previous_offset, offset, 0.055).set_trans(Tween.TRANS_SINE)
		previous_offset = offset
	_error_flash_tween = create_tween()
	_error_flash_tween.tween_method(_set_error_flash_opacity, 0.0, 0.65, 0.09)
	_error_flash_tween.tween_method(_set_error_flash_opacity, 0.65, 0.0, 0.28)


func _set_error_offset(offset: float) -> void:
	position.x += offset - _error_offset
	_error_offset = offset
	queue_redraw()


func _set_error_flash_opacity(opacity: float) -> void:
	error_flash_opacity = opacity
	queue_redraw()


func contains_global_point(screen_point: Vector2) -> bool:
	var point: Vector2 = to_local(screen_point)
	return _point_in_polygon(point, _hex_points())


func _draw() -> void:
	if definition == null or runtime == null:
		return
	var points := _hex_points()
	_draw_shadow(points)
	if not intelligence_visible:
		draw_colored_polygon(points, _palette().gray)
		return
	if definition.mode == CellDefinition.MODE_CANDIDATE and not runtime.solved:
		_draw_candidate(points)
	else:
		draw_colored_polygon(points, _current_fill)
	if state_mask_opacity > 0.0:
		var hover_mask := _palette().hover_mask
		draw_colored_polygon(points, Color(hover_mask.r, hover_mask.g, hover_mask.b, state_mask_opacity))
	var text := _display_text()
	if not text.is_empty():
		var text_center_y := -grid_radius * 0.24 if definition.scope_radius > 1 else (-grid_radius * 0.1 if definition.is_editable() and not runtime.solved else 0.0)
		var font_size := int(grid_radius * 0.66)
		var baseline := text_center_y + (CELL_FONT.get_ascent(font_size) - CELL_FONT.get_descent(font_size)) * 0.5
		draw_string(CELL_FONT, Vector2(-radius, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, _palette().cell_text)
	if definition.scope_radius > 1 and intelligence_visible and not definition.is_black():
		var font_size := int(grid_radius * 0.26)
		var baseline := grid_radius * 0.24 + (CELL_FONT.get_ascent(font_size) - CELL_FONT.get_descent(font_size)) * 0.5
		draw_string(CELL_FONT, Vector2(-radius, baseline), "r%d" % definition.scope_radius, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, _palette().cell_text)
	if error_flash_opacity > 0.0:
		var flash_color := _palette().red
		flash_color.a = error_flash_opacity
		draw_colored_polygon(points, flash_color)
	_draw_break_shards()


func _create_break_shards() -> void:
	set_process(true)
	_break_shards.clear()
	_break_elapsed = 0.0
	var old_color := _palette().gray
	if definition.mode == CellDefinition.MODE_CANDIDATE:
		old_color = _brick_color(runtime.candidate_pick) if not runtime.candidate_pick.is_empty() else old_color
	elif definition.mode == CellDefinition.MODE_RED_INPUT:
		old_color = _palette().red
	elif definition.is_wildcard():
		old_color = _palette().red
	elif runtime.player_black:
		old_color = _palette().black
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in 32:
		var center := Vector2.from_angle(rng.randf_range(0.0, TAU)) * sqrt(rng.randf()) * radius * 0.68
		var shard_radius := radius * rng.randf_range(0.055, 0.14)
		var sides := rng.randi_range(3, 5)
		var points := PackedVector2Array()
		for vertex in sides:
			var angle := TAU * float(vertex) / float(sides)
			points.append(center + Vector2.from_angle(angle) * shard_radius * rng.randf_range(0.65, 1.25))
		_add_break_shard(points, old_color, rng)
	_update_overlay_z_index()
	queue_redraw()


func _add_break_shard(points: PackedVector2Array, color: Color, rng: RandomNumberGenerator) -> void:
	var center := Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var local_points := PackedVector2Array()
	for point in points:
		local_points.append(point - center)
	var direction := center.normalized()
	_break_shards.append({
		"points": local_points,
		"position": center,
		"velocity": direction * rng.randf_range(28.0, 105.0) + Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-105.0, -25.0)),
		"rotation": 0.0,
		"spin": rng.randf_range(-5.0, 5.0),
		"color": color,
	})


func _draw_break_shards() -> void:
	if _break_shards.is_empty():
		return
	var opacity := clampf((BREAK_DURATION - _break_elapsed) / 0.25, 0.0, 1.0)
	for shard in _break_shards:
		var points := PackedVector2Array()
		for point in shard["points"]:
			points.append(point.rotated(shard["rotation"]) + shard["position"])
		var color: Color = shard["color"]
		color.a *= opacity
		draw_colored_polygon(points, color)


func _draw_shadow(points: PackedVector2Array) -> void:
	var shadow_color := _palette().cell_shadow
	for layer in SHADOW_LAYERS:
		var shadow_points := PackedVector2Array()
		for point in points:
			shadow_points.append(point + layer["offset"])
		var layer_color := Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_color.a * layer["opacity"])
		draw_colored_polygon(shadow_points, layer_color)


func _frame_rate_independent_factor(reference_factor: float, delta: float) -> float:
	# Produces the same exponential convergence as reference_factor per frame at 60 FPS.
	return 1.0 - pow(1.0 - reference_factor, delta * 60.0)


func _hex_points_for_radius(point_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 6:
		points.append(Vector2.from_angle(deg_to_rad(60.0 * index - 30.0)) * point_radius)
	return points


func _update_overlay_z_index() -> void:
	z_index = 20 if not _break_shards.is_empty() else 0


func _draw_candidate(points: PackedVector2Array) -> void:
	draw_colored_polygon(points, _current_fill)
	for index in definition.candidate_types.size():
		var type := definition.candidate_types[index]
		var mix := clampf((float(dot_scales.get(type, 1.0)) - 1.0) / (0.075 / 0.045 - 1.0), 0.0, 1.0)
		var dot_color := _palette().cell_text
		dot_color.a = lerpf(0.3, 0.9, mix)
		var x := (index - (definition.candidate_types.size() - 1) / 2.0) * grid_radius * 0.17
		draw_circle(Vector2(x, grid_radius * 0.52), grid_radius * 0.045 * float(dot_scales.get(type, 1.0)), dot_color)


func _fill_color() -> Color:
	var palette := _palette()
	if definition.mode == CellDefinition.MODE_CANDIDATE and not runtime.solved:
		return _brick_color(runtime.candidate_pick) if not runtime.candidate_pick.is_empty() else palette.gray
	if definition.mode == CellDefinition.MODE_RED_INPUT and not runtime.solved:
		return palette.red
	if definition.mode == CellDefinition.MODE_HIDDEN and not runtime.solved:
		if definition.is_wildcard():
			return palette.red
		return palette.black if runtime.player_black else palette.gray
	if runtime.solved and not definition.accepted_answer_types.is_empty():
		return _brick_color(runtime.candidate_pick)
	return _brick_color(definition.effective_type())


func _target_state_mask_opacity() -> float:
	if runtime.solved:
		return SOLVED_MASK_OPACITY
	elif is_selected:
		return SELECTED_MASK_OPACITY
	elif is_hovered and definition.is_editable() and not runtime.solved:
		return HOVER_MASK_OPACITY
	return 0.0


func _update_state_mask_opacity() -> void:
	var target_opacity := _target_state_mask_opacity()
	if is_equal_approx(target_opacity, state_mask_opacity):
		return
	if _state_mask_tween != null:
		_state_mask_tween.kill()
	_state_mask_tween = create_tween()
	_state_mask_tween.tween_method(_set_state_mask_opacity, state_mask_opacity, target_opacity, STATE_MASK_TRANSITION_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_state_mask_opacity(opacity: float) -> void:
	state_mask_opacity = opacity
	queue_redraw()


func _palette() -> GameColorPalette:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	return theme_manager.get_palette() if theme_manager != null else DEFAULT_PALETTE


func _brick_color(type: String) -> Color:
	var palette := _palette()
	match type:
		"red": return palette.red
		"yellow": return palette.yellow
		"green": return palette.green
		"purple": return palette.purple
		_: return palette.black


func _display_text() -> String:
	if not intelligence_visible:
		return ""
	if definition.is_wildcard() and runtime.solved:
		return _format_value(runtime.player_value)
	if definition.mode in [CellDefinition.MODE_HIDDEN, CellDefinition.MODE_RED_INPUT] and not runtime.solved:
		if runtime.player_black:
			return ""
		if runtime.pending_black:
			return "b"
		if runtime.player_value == null:
			if runtime.pending_negative:
				return "-"
			return "?"
		return _format_value(runtime.player_value)
	if definition.effective_type() == CellDefinition.TYPE_BLACK:
		return ""
	return _format_value(definition.effective_value())


func _format_value(value: Variant) -> String:
	# JSON numbers are parsed as floats; puzzle values are always displayed as integers.
	return str(int(value))


func _hex_points(inset := 0.0) -> PackedVector2Array:
	return _hex_points_for_radius(radius - inset)


func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside := false
	var previous := polygon.size() - 1
	for current in polygon.size():
		var a := polygon[current]
		var b := polygon[previous]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		previous = current
	return inside
