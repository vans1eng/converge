extends Control

const HOME_SCENE := "res://scenes/home_page.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const CELL_FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const FALLBACK_PALETTE := preload("res://resources/themes/dark_palette.tres")
const GAME_CONFIG := preload("res://scripts/data/game_config.gd")
const ROW_LENGTHS := [4, 5, 6, 6, 5, 4]
const MAX_COLUMNS := 6
const CELL_MAX_RADIUS := 35.0
const CELL_GAP := 4.5
const CHAPTER_COUNT := 3
const PAGE_SIDE_MARGIN := 40.0
const BODY_TOP := 150.0
const BODY_BOTTOM := 135.0
const POP_DURATION := 0.2
const INFO_FADE_DURATION := 0.2
const HOVER_SCALE := 1.06
const SHADOW_LAYERS := [
	{"offset": Vector2(7.0, 7.0), "opacity": 0.06},
	{"offset": Vector2(6.0, 6.0), "opacity": 0.09},
	{"offset": Vector2(5.0, 5.0), "opacity": 0.13},
	{"offset": Vector2(4.0, 4.0), "opacity": 0.18},
]

@onready var back_button: Button = $FooterLayout/VBoxContainer/BackButton
@onready var title_label: Label = $FooterLayout/VBoxContainer/Title

var _levels: Array[Dictionary] = []
var _cell_scales: Array[float] = []
var _hover_mix: Array[float] = []
var _cell_tweens: Array[Tween] = []
var _catalog: Array[Dictionary] = []
var _progress := PlayerProgress.new()
var _perfect_count := 0
var _chapter_level_counts: Array[int] = [0, 0, 0]
var _hovered_level := -1
var _is_transitioning := false
var _game_scene_load_error := OK
var _info_alpha := 0.0


func _ready() -> void:
	back_button.modulate.a = 0.0
	title_label.modulate.a = 0.0
	# Prepare gameplay resources while the selection page is visible instead of
	# parsing the scene and its scripts at the first entrance.
	if ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_game_scene_load_error = ResourceLoader.load_threaded_request(GAME_SCENE, "PackedScene")
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	resized.connect(queue_redraw)
	back_button.resized.connect(queue_redraw)
	back_button.item_rect_changed.connect(queue_redraw)
	back_button.pressed.connect(_return_home)
	back_button.mouse_entered.connect(func(): _set_hovered_level(-1))
	mouse_exited.connect(func(): _set_hovered_level(-1))
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self)
		theme_manager.theme_changed.connect(func(_is_dark): _apply_theme())
	_catalog = LevelRepository.get_catalog()
	_apply_theme()
	_load_levels()
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	# Let initial layout and text rendering finish before starting the fade.
	await get_tree().process_frame
	await get_tree().process_frame
	var info_tween := _animate_info(true)
	_animate_cells(true)
	await _wait_for_cell_animations()
	if info_tween.is_running():
		await info_tween.finished
	_is_transitioning = false
	ThemeManager.set_buttons_interactive(self, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_fit_back_button_hit_area()
		queue_redraw()


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
	_perfect_count = 0
	_chapter_level_counts = [0, 0, 0]
	var second_chapter_count := 0
	var has_third_chapter := false
	for entry in _catalog:
		if entry.chapter_id == 2:
			second_chapter_count += 1
		elif entry.chapter_id == 3:
			has_third_chapter = true
	var second_chapter_preview_size := ceili(second_chapter_count / 2.0)
	var second_chapter_index := 0
	for entry in _catalog:
		if GAME_CONFIG.DEMO_MODE and entry.chapter_id != LevelRepository.DEMO_CHAPTER_ID:
			continue
		var chapter_slot: int = entry.chapter_id - 1
		# Until chapter three has its own data, split chapter two for layout
		# preview only. Keep the real IDs and progression rules unchanged.
		if entry.chapter_id == 2 and not has_third_chapter:
			chapter_slot = 1 if second_chapter_index < second_chapter_preview_size else 2
			second_chapter_index += 1
		if chapter_slot < 0 or chapter_slot >= CHAPTER_COUNT:
			continue
		var local_index := _chapter_level_counts[chapter_slot]
		_levels.append({
			"number": _levels.size() + 1,
			"id": entry.id,
			"chapter_slot": chapter_slot,
			"local_index": local_index,
			"completed": _progress.is_completed(entry.id),
			"perfect": _progress.is_perfect(entry.id),
			"unlocked": _progress.is_unlocked(entry.id),
		})
		_chapter_level_counts[chapter_slot] += 1
		if _levels.back()["perfect"]:
			_perfect_count += 1
		_cell_scales.append(0.0)
		_hover_mix.append(0.0)
	_fit_back_button_hit_area()
	queue_redraw()


func _animate_cells(appearing: bool) -> float:
	for active_tween in _cell_tweens:
		active_tween.kill()
	_cell_tweens.clear()
	var last_finish := 0.0
	# Sweep across all chapters as one board.
	var origin := Vector2(INF, INF)
	for index in _levels.size():
		var center := _cell_center(index)
		origin.x = minf(origin.x, center.x)
		origin.y = minf(origin.y, center.y)
	for index in _levels.size():
		var offset := _cell_center(index) - origin
		var radius := _cell_radius(index)
		var delay := offset.y / (1.5 * radius) * 0.075 + offset.x / (sqrt(3.0) * radius) * 0.03
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


func _animate_info(appearing: bool) -> Tween:
	var tween := create_tween().set_parallel(true)
	var target := 1.0 if appearing else 0.0
	tween.tween_method(_set_info_alpha, _info_alpha, target, INFO_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
	tween.tween_property(back_button, "modulate:a", target, INFO_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
	tween.tween_property(title_label, "modulate:a", target, INFO_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if appearing else Tween.EASE_IN)
	return tween


func _set_info_alpha(value: float) -> void:
	_info_alpha = value
	queue_redraw()


func _info_color(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * _info_alpha)


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
	_draw_perfect_count(palette)
	for index in _levels.size():
		var scale_value := _cell_scales[index]
		if scale_value <= 0.02:
			continue
		var center := _cell_center(index)
		var radius := _draw_radius(index) * scale_value * lerpf(1.0, HOVER_SCALE, _hover_mix[index])
		var points := _hex_points(center, radius)
		for layer in SHADOW_LAYERS:
			var shadow := _hex_points(center + layer["offset"], radius)
			var shadow_color := palette.cell_shadow
			shadow_color.a *= layer["opacity"]
			draw_colored_polygon(shadow, shadow_color)
		draw_colored_polygon(points, _level_color(index))
		if _hover_mix[index] > 0.0:
			var hover := palette.hover_mask
			hover.a = 0.22 * _hover_mix[index]
			draw_colored_polygon(points, hover)
		var font_size := maxi(12, roundi(_draw_radius(index) * scale_value * 0.72))
		var baseline := center + Vector2(0.0, CELL_FONT.get_ascent(font_size) * 0.34)
		draw_string(CELL_FONT, baseline - Vector2(50.0, 0.0), str(_levels[index]["number"]), HORIZONTAL_ALIGNMENT_CENTER, 100.0, font_size, palette.cell_text)
		if not _levels[index]["unlocked"]:
			draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.55))


func _draw_perfect_count(palette: GameColorPalette) -> void:
	var radius := _draw_radius(0) if not _levels.is_empty() else CELL_MAX_RADIUS - CELL_GAP
	var font_size := maxi(12, roundi(radius * 0.72))
	# Size the summary brick independently of the count's font size.
	var brick_radius := font_size * 0.55
	var gap := radius * 0.3
	var count_text := "×  %d" % _perfect_count
	var count_size := CELL_FONT.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var brick_width := sqrt(3.0) * brick_radius
	var total_width := brick_width + gap + count_size.x
	var left := (size.x - total_width) * 0.5
	var center_y := _perfect_summary_center_y()
	var brick_left := left
	# Font line metrics include whitespace; lower the icon to match the visible glyphs.
	var brick_center := Vector2(brick_left + brick_width * 0.5, center_y + font_size * 0.05)
	draw_colored_polygon(_hex_points(brick_center, brick_radius), _info_color(palette.blue))
	var baseline := center_y + (CELL_FONT.get_ascent(font_size) - CELL_FONT.get_descent(font_size)) * 0.5
	draw_string(CELL_FONT, Vector2(brick_left + brick_width + gap, baseline), count_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _info_color(palette.main_text))


func _back_text_center_y() -> float:
	var center := get_global_transform().affine_inverse() * (back_button.get_global_transform() * (back_button.size * 0.5))
	return center.y


func _back_text_height() -> float:
	return back_button.get_theme_font("font").get_height(back_button.get_theme_font_size("font_size"))


func _perfect_summary_center_y() -> float:
	# Place the summary halfway between the visible board and the footer text.
	var board_bottom := _board_center_y() + (_board_rows() - 1) * 0.75 * _board_radius()
	board_bottom += maxf(8.0, _board_radius() - CELL_GAP)
	for layer in SHADOW_LAYERS:
		board_bottom = maxf(board_bottom, _board_center_y() + (_board_rows() - 1) * 0.75 * _board_radius() + maxf(8.0, _board_radius() - CELL_GAP) + layer["offset"].y)
	var back_text_top := _back_text_center_y() - _back_text_height() * 0.5
	return (board_bottom + back_text_top) * 0.5


func _board_center_y() -> float:
	var radius := _draw_radius(0) if not _levels.is_empty() else CELL_MAX_RADIUS - CELL_GAP
	var summary_font_size := maxi(12, roundi(radius * 0.72))
	# Preserve the board's current position after moving the summary below it.
	var top_margin := maxf(0.0, size.y - _back_text_center_y() - _back_text_height() * 0.5)
	var summary_bottom := top_margin + CELL_FONT.get_height(summary_font_size)
	var back_text_top := _back_text_center_y() - _back_text_height() * 0.5
	# Center the entire visible board, including the shadows below the cells.
	var shadow_bottom := 0.0
	for layer in SHADOW_LAYERS:
		shadow_bottom = maxf(shadow_bottom, layer["offset"].y)
	return (summary_bottom + back_text_top - shadow_bottom) * 0.5


func _chapter_grid_bounds(chapter_slot: int) -> Vector2:
	var count := _chapter_level_counts[chapter_slot]
	var bounds := Vector2(INF, -INF)
	for index in count:
		var position := _cell_grid_position(index, count)
		var x := position.y + 0.5 * (position.x & 1)
		bounds.x = minf(bounds.x, x)
		bounds.y = maxf(bounds.y, x)
	return bounds if count > 0 else Vector2.ZERO


func _board_grid_width() -> float:
	var width := 0.0
	var sections := 0
	for slot in CHAPTER_COUNT:
		if _chapter_level_counts[slot] == 0:
			continue
		var bounds := _chapter_grid_bounds(slot)
		width += bounds.y - bounds.x + 1.0
		sections += 1
	# One empty brick column between neighboring sections.
	return width + maxi(0, sections - 1)


func _board_rows() -> int:
	var rows := 1
	for count in _chapter_level_counts:
		if count > 0:
			rows = maxi(rows, _cell_grid_position(count - 1, count).x + 1)
	return rows


func _board_radius() -> float:
	var width_limit := (size.x - PAGE_SIDE_MARGIN * 2.0) / (maxf(1.0, _board_grid_width()) * sqrt(3.0))
	var height_limit := (size.y - BODY_TOP - BODY_BOTTOM) / (1.5 * (_board_rows() - 1) + 2.0)
	return maxf(12.0, minf(CELL_MAX_RADIUS, minf(width_limit, height_limit)))


func _cell_radius(_index: int) -> float:
	return _board_radius()


func _draw_radius(index: int) -> float:
	return maxf(8.0, _cell_radius(index) - CELL_GAP)


func _cell_center(index: int) -> Vector2:
	var chapter_slot: int = _levels[index]["chapter_slot"]
	var count := _chapter_level_counts[chapter_slot]
	var position := _cell_grid_position(_levels[index]["local_index"], count)
	var radius := _board_radius()
	var step_x := sqrt(3.0) * radius
	var step_y := 1.5 * radius
	var section_offset := 0.0
	for slot in chapter_slot:
		if _chapter_level_counts[slot] > 0:
			var bounds := _chapter_grid_bounds(slot)
			section_offset += bounds.y - bounds.x + 2.0
	var section_bounds := _chapter_grid_bounds(chapter_slot)
	var grid_x := section_offset + position.y + 0.5 * (position.x & 1) - section_bounds.x
	# All sections share one grid origin and the same first-row height.
	return Vector2(
		size.x * 0.5 + (grid_x - (_board_grid_width() - 1.0) * 0.5) * step_x,
		_board_center_y() + (position.x - (_board_rows() - 1) * 0.5) * step_y
	)


func _cell_grid_position(index: int, level_count: int) -> Vector2i:
	var remaining := index
	var consumed := 0
	for row in ROW_LENGTHS.size():
		if remaining < ROW_LENGTHS[row]:
			var visible_count := mini(ROW_LENGTHS[row], maxi(0, level_count - consumed))
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
		if Geometry2D.is_point_in_polygon(point, _hex_points(_cell_center(index), _draw_radius(index))):
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
	var info_tween := _animate_info(false)
	await info_tween.finished
	get_tree().change_scene_to_file(HOME_SCENE)


func _open_level(level_id: String) -> void:
	if _is_transitioning or not _progress.is_unlocked(level_id):
		return
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	_hovered_level = -1
	var ui_tween := _animate_info(false)
	await ui_tween.finished
	var duration := _animate_cells(false)
	await get_tree().create_timer(duration).timeout
	get_tree().set_meta("selected_level", level_id)
	get_tree().set_meta("selected_chapter", int(level_id.get_slice("-", 0)))
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


func _level_color(index: int) -> Color:
	var palette := _palette()
	if _levels[index]["perfect"]: return palette.blue
	return palette.red if _levels[index]["completed"] else palette.gray
