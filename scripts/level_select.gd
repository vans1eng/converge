extends Control

const HOME_SCENE := "res://scenes/home_page.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const CELL_FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const FALLBACK_PALETTE := preload("res://resources/themes/dark_palette.tres")
const ROW_LENGTHS := [4, 5, 6, 6, 5, 4]
const MAX_COLUMNS := 6
const CELL_MAX_RADIUS := 35.0
const CELL_GAP := 4.5
const BODY_TOP := 150.0
const BODY_BOTTOM := 135.0
const POP_DURATION := 0.2
const HOVER_SCALE := 1.06
const SHADOW_LAYERS := [
	{"offset": Vector2(7.0, 7.0), "opacity": 0.06},
	{"offset": Vector2(6.0, 6.0), "opacity": 0.09},
	{"offset": Vector2(5.0, 5.0), "opacity": 0.13},
	{"offset": Vector2(4.0, 4.0), "opacity": 0.18},
]

@onready var title_label: Label = $Title
@onready var back_button: Button = $FooterLayout/VBoxContainer/BackButton

var _levels: Array[Dictionary] = []
var _cell_scales: Array[float] = []
var _hover_mix: Array[float] = []
var _cell_tweens: Array[Tween] = []
var _catalog: Array[Dictionary] = []
var _progress := PlayerProgress.new()
var _chapter_id := LevelRepository.DEMO_CHAPTER_ID
var _hovered_level := -1
var _is_transitioning := false
var _game_scene_load_error := OK


func _ready() -> void:
	# Prepare gameplay resources while the selection page is visible instead of
	# parsing the scene and its scripts at the first entrance.
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_game_scene_load_error = ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	resized.connect(queue_redraw)
	back_button.pressed.connect(_return_home)
	back_button.mouse_entered.connect(func(): _set_hovered_level(-1))
	mouse_exited.connect(func(): _set_hovered_level(-1))
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self)
		theme_manager.theme_changed.connect(func(_is_dark): _apply_theme())
	_catalog = LevelRepository.get_playable_catalog()
	get_tree().set_meta("selected_chapter", _chapter_id)
	_apply_theme()
	_load_levels()
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	_animate_cells(true)
	await _wait_for_cell_animations()
	_is_transitioning = false
	ThemeManager.set_buttons_interactive(self, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_chapter_title()


func _refresh_chapter_title() -> void:
	title_label.text = tr("CHAPTER_%d" % _chapter_id)
	_fit_back_button_hit_area()


func _fit_back_button_hit_area() -> void:
	var font := back_button.get_theme_font("font")
	var font_size := back_button.get_theme_font_size("font_size")
	back_button.custom_minimum_size.x = ceilf(font.get_string_size(tr(back_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) + 8.0


func _apply_theme() -> void:
	var base := _palette().main_text
	back_button.add_theme_color_override("font_hover_color", Color(base.r, base.g, base.b, 0.7))
	back_button.add_theme_color_override("font_pressed_color", Color(base.r, base.g, base.b, 0.5))
	queue_redraw()


func _load_levels() -> void:
	_levels.clear()
	_cell_scales.clear()
	_hover_mix.clear()
	for entry in _catalog:
		if entry.chapter_id != _chapter_id:
			continue
		_levels.append({
			"number": entry.number,
			"id": entry.id,
			"completed": _progress.is_completed(entry.id),
			"unlocked": _progress.is_unlocked(entry.id),
		})
		_cell_scales.append(0.0)
		_hover_mix.append(0.0)
	_refresh_chapter_title()
	queue_redraw()


func _animate_cells(appearing: bool) -> float:
	for active_tween in _cell_tweens:
		active_tween.kill()
	_cell_tweens.clear()
	var last_finish := 0.0
	for index in _levels.size():
		var position := _cell_grid_position(index)
		var row := position.x
		var column := position.y
		var delay := row * 0.075 + column * 0.03
		var tween := create_tween()
		_cell_tweens.append(tween)
		tween.tween_interval(delay)
		tween.tween_method(_set_cell_scale.bind(index), _cell_scales[index], 1.0 if appearing else 0.0, POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
		last_finish = maxf(last_finish, delay + POP_DURATION)
	return last_finish


func _wait_for_cell_animations() -> void:
	# Wait for the actual tweens, including their staggered delays.
	for tween in _cell_tweens:
		if tween.is_running():
			await tween.finished


func _set_cell_scale(value: float, index: int) -> void:
	_cell_scales[index] = value
	queue_redraw()


func _process(delta: float) -> void:
	var smoothing := 1.0 - pow(0.8, delta * 60.0)
	var changed := false
	for index in _hover_mix.size():
		var target := 1.0 if index == _hovered_level and not _is_transitioning else 0.0
		if is_equal_approx(_hover_mix[index], target):
			continue
		_hover_mix[index] = lerpf(_hover_mix[index], target, smoothing)
		if absf(_hover_mix[index] - target) < 0.005:
			_hover_mix[index] = target
		changed = true
	if changed:
		queue_redraw()


func _draw() -> void:
	var palette := _palette()
	for index in _levels.size():
		var scale_value := _cell_scales[index]
		if scale_value <= 0.02:
			continue
		var center := _cell_center(index)
		var radius := _draw_radius() * scale_value * lerpf(1.0, HOVER_SCALE, _hover_mix[index])
		var points := _hex_points(center, radius)
		for layer in SHADOW_LAYERS:
			var shadow := _hex_points(center + layer["offset"], radius)
			var shadow_color := palette.cell_shadow
			shadow_color.a *= layer["opacity"]
			draw_colored_polygon(shadow, shadow_color)
		draw_colored_polygon(points, palette.red if _levels[index]["completed"] else palette.gray)
		if _hover_mix[index] > 0.0:
			var hover := palette.hover_mask
			hover.a = 0.22 * _hover_mix[index]
			draw_colored_polygon(points, hover)
		var font_size := maxi(12, roundi(_draw_radius() * scale_value * 0.72))
		var baseline := center + Vector2(0.0, CELL_FONT.get_ascent(font_size) * 0.34)
		draw_string(CELL_FONT, baseline - Vector2(50.0, 0.0), str(_levels[index]["number"]), HORIZONTAL_ALIGNMENT_CENTER, 100.0, font_size, palette.cell_text)
		if not _levels[index]["unlocked"]:
			draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.55))


func _cell_radius() -> float:
	var rows := _cell_grid_position(maxi(0, _levels.size() - 1)).x + 1
	var width_limit := (size.x - 120.0) / (MAX_COLUMNS * sqrt(3.0))
	var height_limit := (size.y - BODY_TOP - BODY_BOTTOM) / (1.5 * (rows - 1) + 2.0)
	return maxf(12.0, minf(CELL_MAX_RADIUS, minf(width_limit, height_limit)))


func _draw_radius() -> float:
	return maxf(8.0, _cell_radius() - CELL_GAP)


func _cell_center(index: int) -> Vector2:
	var rows := _cell_grid_position(maxi(0, _levels.size() - 1)).x + 1
	var position := _cell_grid_position(index)
	var row := position.x
	var column := position.y
	var radius := _cell_radius()
	var step_x := sqrt(3.0) * radius
	var step_y := 1.5 * radius
	var body_center_y := (BODY_TOP + size.y - BODY_BOTTOM) * 0.5
	var min_x := INF
	var max_x := -INF
	for cell_index in _levels.size():
		var grid_position := _cell_grid_position(cell_index)
		var grid_x := grid_position.y + 0.5 * (grid_position.x & 1)
		min_x = minf(min_x, grid_x)
		max_x = maxf(max_x, grid_x)
	var grid_center_x := (min_x + max_x) * 0.5 if not _levels.is_empty() else 0.0
	return Vector2(
		size.x * 0.5 + (column + 0.5 * (row & 1) - grid_center_x) * step_x,
		body_center_y + (row - (rows - 1) * 0.5) * step_y
	)


func _cell_grid_position(index: int) -> Vector2i:
	var remaining := index
	var consumed := 0
	for row in ROW_LENGTHS.size():
		if remaining < ROW_LENGTHS[row]:
			var visible_count := mini(ROW_LENGTHS[row], maxi(0, _levels.size() - consumed))
			return Vector2i(row, remaining + int((MAX_COLUMNS - visible_count) / 2))
		remaining -= ROW_LENGTHS[row]
		consumed += ROW_LENGTHS[row]
	var extra_row := ROW_LENGTHS.size() + int(remaining / 5)
	return Vector2i(extra_row, remaining % 5 + (1 if extra_row % 2 == 0 else 0))


func _hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for vertex in 6:
		points.append(center + Vector2.from_angle(deg_to_rad(60.0 * vertex - 30.0)) * radius)
	return points


func _gui_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if event is InputEventMouseMotion:
		_set_hovered_level(_level_at(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var selected := _level_at(event.position)
		if selected >= 0:
			AudioManager.play_cell_select()
			_open_level(_levels[selected]["id"])


func _set_hovered_level(index: int) -> void:
	if index >= 0 and not _levels[index]["unlocked"]:
		index = -1
	if index == _hovered_level:
		return
	_hovered_level = index
	if index >= 0:
		AudioManager.play_cell_hover()


func _level_at(point: Vector2) -> int:
	for index in _levels.size():
		if not _levels[index]["unlocked"] or _cell_scales[index] < 0.8:
			continue
		if Geometry2D.is_point_in_polygon(point, _hex_points(_cell_center(index), _draw_radius())):
			return index
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_home()
		get_viewport().set_input_as_handled()


func _return_home() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	_hovered_level = -1
	var duration := _animate_cells(false)
	await get_tree().create_timer(duration).timeout
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	get_tree().change_scene_to_file(HOME_SCENE)


func _open_level(level_id: String) -> void:
	if _is_transitioning or not _progress.is_unlocked(level_id):
		return
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	_hovered_level = -1
	var ui_tween := create_tween()
	ui_tween.set_parallel(true)
	ui_tween.tween_property(title_label, "modulate:a", 0.0, 0.2)
	ui_tween.tween_property(back_button, "modulate:a", 0.0, 0.2)
	await ui_tween.finished
	var duration := _animate_cells(false)
	await get_tree().create_timer(duration).timeout
	get_tree().set_meta("selected_level", level_id)
	if _game_scene_load_error == OK:
		while ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
			var game_scene := ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
			get_tree().change_scene_to_packed(game_scene)
			return
	get_tree().change_scene_to_file(GAME_SCENE)


func _palette() -> GameColorPalette:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	return theme_manager.get_palette() if theme_manager != null else FALLBACK_PALETTE
