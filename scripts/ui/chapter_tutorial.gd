extends Control

# These labels float in the board's existing empty margins. They never reserve
# layout space, capture input, or move/scale the board.
const FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const SCOPE_LABEL := preload("res://scripts/ui/tutorial_scope_label.gd")
const REVEAL_DELAY := 0.5
const REVEAL_INTERVAL := 0.3
const REVEAL_DURATION := 0.65
const MODE_SWITCH_DURATION := 0.3
const RESTART_FADE_DURATION := 0.25
const RISE_DISTANCE := 10.0
const TEXT_OPACITY := 0.55

var _state: BoardState
var _level: LevelDefinition
var _left: RichTextLabel
var _right: RichTextLabel
var _intro: Label
var _mode_hint: RichTextLabel
var _labels: Array[Control] = []
var _revealed := [false, false, false, false]
var _completed := false
var _motions := [0.0, 0.0, 0.0, 0.0]
var _tweens: Array[Tween] = []
var _bases := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _layout_signature := ""
var _text_ink := Color.TRANSPARENT
var _alternate_labels: Array[Control] = []
var _reveal_tweens: Array[Tween] = [null, null, null, null]
var _mode_tween: Tween
var _displayed_mode := ""
var _restarting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in 4:
		var label = SCOPE_LABEL.new() if index in [0, 1] else (RichTextLabel.new() if index == 3 else Label.new())
		if index == 3:
			label.bbcode_enabled = true
			label.fit_content = true
			label.scroll_active = false
			label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		label.name = ["RedCheckHint", "GreenCheckHint", "HypothesisHint", "ControlModeHint"][index]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("normal_font" if index in [0, 1, 3] else "font", FONT)
		label.add_theme_font_size_override("normal_font_size" if index in [0, 1, 3] else "font_size", 16)
		label.add_theme_constant_override("line_separation" if index in [0, 1, 3] else "line_spacing", 5)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate.a = 0.0
		add_child(label)
		_labels.append(label)
		if index == 0: _left = label
		elif index == 1: _right = label
		elif index == 2: _intro = label
		else: _mode_hint = label
	for index in 3:
		var alternate := _labels[index].duplicate() as Control
		alternate.name = _labels[index].name + "Alternate"
		alternate.modulate.a = 0.0
		add_child(alternate)
		_alternate_labels.append(alternate)
	SettingsManager.settings_changed.connect(_update_text)
	ThemeManager.theme_changed.connect(func(_dark): _update_text())
	get_viewport().size_changed.connect(_place_labels)


func show_state(state: BoardState) -> void:
	var changed := _level != state.level
	_state = state
	_level = state.level
	visible = not _level.tutorial.is_empty()
	if changed:
		_restarting = false
		modulate.a = 1.0
		_stop_tweens()
		_displayed_mode = SettingsManager.control_mode
		_revealed = [false, false, false, false]
		_completed = false
		_motions = [0.0, 0.0, 0.0, 0.0]
		_layout_signature = ""
		for label in _labels: label.modulate.a = 0.0
		_update_text()
		if visible:
			if _level.id == "1-1":
				# Upper-left, upper-right, lower-left, lower-right.
				_reveal(3)
				_reveal(2, REVEAL_INTERVAL)
				_reveal(0, REVEAL_INTERVAL * 2)
				_reveal(1, REVEAL_INTERVAL * 3)
			elif _level.id in ["1-2", "1-4", "1-10"]:
				_reveal(0)
				_reveal(1, REVEAL_INTERVAL)
				if _level.id == "1-2": _reveal(2, REVEAL_INTERVAL * 2)
			elif not _level.tutorial.has("reveal_on_selection"):
				_reveal(0)
				_reveal(1)
	if visible:
		_check_progress()
		_place_labels.call_deferred()


func _process(_delta: float) -> void:
	if not visible or _state == null or _restarting: return
	_check_progress()
	# The board positions settle after the HUD's container layout, and may change
	# again on window resize. Read their real bounds without changing that layout.
	var bounds := _board_bounds()
	var signature := str(bounds) + str(get_viewport_rect().size)
	if signature != _layout_signature:
		_layout_signature = signature
		_place_labels()


func _check_progress() -> void:
	if _state.is_complete():
		if not _completed:
			_completed = true
			_stop_tweens()
			for label in _labels:
				var tween := create_tween()
				tween.tween_property(label, "modulate:a", 0.0, 0.25)
				_tweens.append(tween)
		return
	var selection_triggers: Dictionary = _level.tutorial.get("reveal_on_selection", {})
	if not selection_triggers.is_empty():
		for index in 2:
			var side := "left" if index == 0 else "right"
			if not _state.selected_cell_id.is_empty() and _state.selected_cell_id == str(selection_triggers.get(side, "")):
				_reveal(index)
		return


func _reveal(index: int, extra_delay: float = 0.0) -> void:
	if _revealed[index]: return
	_revealed[index] = true
	_motions[index] = RISE_DISTANCE
	var label = _labels[index]
	label.modulate.a = 0.0
	_place_labels()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, REVEAL_DURATION).set_delay(REVEAL_DELAY + extra_delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_motion.bind(index), RISE_DISTANCE, 0.0, REVEAL_DURATION).set_delay(REVEAL_DELAY + extra_delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)
	_reveal_tweens[index] = tween


func _set_motion(offset: float, index: int) -> void:
	_motions[index] = offset
	var label = _labels[index]
	label.position = _bases[index] + Vector2(0, offset)


func _stop_tweens(hide_alternates := true) -> void:
	if _mode_tween != null: _mode_tween.kill()
	if hide_alternates:
		for label in _alternate_labels: label.modulate.a = 0.0
	for tween in _tweens:
		if tween != null and tween.is_running(): tween.kill()
	_tweens.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_text()
		_place_labels.call_deferred()


func _localized(data: Variant) -> String:
	if data is Dictionary:
		var locale := TranslationServer.get_locale()
		var language := locale.get_slice("_", 0)
		return str(data.get(locale, data.get(language, data.get("zh_CN" if locale.begins_with("zh") else "en", ""))))
	return str(data)


func _update_text() -> void:
	if _left == null or _level == null: return
	var mode_changed := _level.id == "1-1" and not _completed and not _displayed_mode.is_empty() and _displayed_mode != SettingsManager.control_mode
	if mode_changed:
		if _mode_tween != null: _mode_tween.kill()
		for index in 3:
			if _reveal_tweens[index] != null: _reveal_tweens[index].kill()
			var outgoing := _labels[index]
			_labels[index] = _alternate_labels[index]
			_alternate_labels[index] = outgoing
			_labels[index].modulate.a = 0.0
			_motions[index] = RISE_DISTANCE
		_left = _labels[0] as RichTextLabel
		_right = _labels[1] as RichTextLabel
		_intro = _labels[2] as Label
	_displayed_mode = SettingsManager.control_mode
	var left_text: String
	var right_text: String
	var intro_text := ""
	var mode_text := ""
	if _level.id == "1-1":
		var careful := SettingsManager.control_mode == "careful"
		left_text = tr("TUTORIAL_CAREFUL_LEFT" if careful else "TUTORIAL_MOUSE_RED")
		right_text = tr("TUTORIAL_CAREFUL_RIGHT" if careful else "TUTORIAL_MOUSE_GREEN")
		intro_text = tr("TUTORIAL_CAREFUL_INTRO" if careful else "TUTORIAL_MOUSE_HYPOTHESIS")
		mode_text = tr("TUTORIAL_CONTROL_MODE")
		var palette := ThemeManager.get_palette()
		mode_text = mode_text.replace("[careful]", "[color=#%s]" % palette.green.to_html(false)).replace("[/careful]", "[/color]")
		mode_text = mode_text.replace("[fast]", "[color=#%s]" % palette.red.to_html(false)).replace("[/fast]", "[/color]")
	else:
		var copy: Dictionary = _level.tutorial.get("floating", {})
		left_text = _localized(copy.get("left", ""))
		right_text = _localized(copy.get("right", ""))
		intro_text = _localized(copy.get("bottom", ""))
	var text_changed: bool = _left.copy_text != left_text or _right.copy_text != right_text or _intro.text != intro_text or _mode_hint.text != mode_text
	if _left.copy_text != left_text: _left.set_copy_text(left_text)
	if _right.copy_text != right_text: _right.set_copy_text(right_text)
	if _intro.text != intro_text: _intro.text = intro_text
	if _mode_hint.text != mode_text: _mode_hint.text = mode_text
	var highlights := {}
	if _level.id == "1-2":
		var palette := ThemeManager.get_palette()
		for term in ["红色", "红砖", "紅色", "紅磚"]:
			highlights[term] = palette.red
	_left.set_highlights(highlights)
	highlights = {}
	if _level.id == "1-2":
		var palette := ThemeManager.get_palette()
		for term in ["绿色", "绿砖", "綠色", "綠磚"]:
			highlights[term] = palette.green
	_right.set_highlights(highlights)
	var ink := Color(ThemeManager.get_palette().main_text, TEXT_OPACITY)
	if ink != _text_ink:
		_text_ink = ink
		# Both crossfade buffers need theme ink before their first appearance.
		for index in _labels.size():
			var color_key := "default_color" if index in [0, 1, 3] else "font_color"
			_labels[index].add_theme_color_override(color_key, ink)
			if index < _alternate_labels.size():
				_alternate_labels[index].add_theme_color_override(color_key, ink)
		_place_labels.call_deferred()
	if text_changed:
		_place_labels.call_deferred()
	if mode_changed:
		# Crossfade both copies using matching easing for opacity and motion.
		_place_labels()
		_mode_tween = create_tween().set_parallel(true)
		for index in 3:
			var outgoing := _alternate_labels[index]
			outgoing.add_theme_color_override("default_color" if index in [0, 1] else "font_color", ink)
			_mode_tween.tween_property(outgoing, "modulate:a", 0.0, MODE_SWITCH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_mode_tween.tween_property(outgoing, "position:y", _bases[index].y + RISE_DISTANCE, MODE_SWITCH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if _revealed[index]:
				_mode_tween.tween_property(_labels[index], "modulate:a", 1.0, MODE_SWITCH_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				_mode_tween.tween_method(_set_motion.bind(index), RISE_DISTANCE, 0.0, MODE_SWITCH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _board_bounds() -> Rect2:
	var scene := get_tree().current_scene
	var board := scene.get_node_or_null("HexBoard") if scene != null else null
	var viewport_size := get_viewport_rect().size
	if board == null or board._cell_views.is_empty():
		return Rect2(viewport_size * 0.5 - Vector2(36, 36), Vector2(72, 72))
	var first := true
	var bounds := Rect2()
	for view in board._cell_views.values():
		# Full settled extents, independent of entrance/hover animation scale.
		var cell_rect := Rect2(view.position - Vector2.ONE * board.radius, Vector2.ONE * board.radius * 2)
		bounds = cell_rect if first else bounds.merge(cell_rect)
		first = false
	return bounds


func _place_labels() -> void:
	if _left == null: return
	var bounds := _board_bounds()
	var viewport_size := get_viewport_rect().size
	var margin := 32.0
	if _level != null and _level.id == "1-1":
		_place_first_level_labels(bounds, viewport_size)
		return
	var confirm_gap := 48.0
	var gaps := [48.0, confirm_gap, 80.0]
	for index in 4:
		var label = _labels[index]
		if index == 2 and _level != null and _level.id == "1-2":
			var width := minf(520.0, viewport_size.x - margin * 2.0)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 16)
			label.custom_minimum_size = Vector2(width, 0)
			label.size = Vector2(width, 0)
			var footer_top := viewport_size.y - 52.0
			var scene := get_tree().current_scene
			var status := scene.get_node_or_null("CanvasLayer/HUD/StatusMessage") as Control if scene != null else null
			if status != null: footer_top = status.get_global_rect().position.y
			var y := (bounds.end.y + footer_top - label.get_minimum_size().y) * 0.5
			label.visible = not label.text.is_empty() and y >= bounds.end.y + 16.0 and y + label.get_minimum_size().y + RISE_DISTANCE <= footer_top - 16.0
			_bases[index] = Vector2(clampf(bounds.get_center().x - width * 0.5, margin, viewport_size.x - width - margin), y)
			_set_motion(_motions[index], index)
			continue
		if index == 2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var slot := index
		if index == 3: slot = 0
		var gap: float = gaps[slot]
		var available := bounds.position.x - gap - margin if slot == 0 else viewport_size.x - bounds.end.x - gap - margin
		var width := minf(280, available)
		# Never let teaching copy overlap a brick, even in very small windows.
		var copy_text: String = label.copy_text if index in [0, 1] else label.text
		label.visible = width >= 100 and not copy_text.is_empty()
		if not label.visible: continue
		label.add_theme_font_size_override("normal_font_size" if index in [0, 1, 3] else "font_size", 16 if width >= 220 else 14)
		if index == 0:
			label.configure_scope_icon(_level != null and _level.id == "1-10", 16 if width >= 220 else 14, _text_ink)
		label.custom_minimum_size = Vector2(width, 0)
		label.size = Vector2(width, 0)
		var x := bounds.position.x - gap - width if slot == 0 else bounds.end.x + gap
		var y := bounds.get_center().y - 88 if slot == 0 else bounds.get_center().y + (96 if confirm_gap > 48 else 48)
		if slot == 2: y = bounds.get_center().y - 180
		if index == 0 and _level != null and _level.id == "1-2":
			# Mirror the green hint's gap and vertical offset beside the red row.
			var copy_width := 0.0
			for line in _left.copy_text.split("\n"):
				copy_width = maxf(copy_width, FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16 if width >= 220 else 14).x)
			width = minf(width, ceilf(copy_width) + 2.0)
			label.custom_minimum_size.x = width
			label.size.x = width
			x = bounds.position.x - gap - width
			y = bounds.position.y + bounds.size.y * 0.2 - 6.0
		_bases[index] = Vector2(x, clampf(y, 128, viewport_size.y - label.get_minimum_size().y - 80))
		_set_motion(_motions[index], index)


func _place_first_level_labels(bounds: Rect2, viewport_size: Vector2) -> void:
	# Reflect the upper-left label bounds around the brick's center.
	var gap := 48.0
	var margin := 32.0
	var width := minf(280.0, minf(bounds.position.x - gap - margin, viewport_size.x - bounds.end.x - gap - margin))
	var center := bounds.get_center()
	for index in 4:
		var label = _labels[index]
		var copy_text: String = label.copy_text if index in [0, 1] else label.text
		label.visible = width >= 100.0 and not copy_text.is_empty()
		if not label.visible: continue
		var font_size := 16 if width >= 220.0 else 14
		label.add_theme_font_size_override("font_size" if index == 2 else "normal_font_size", font_size)
		if index == 0: label.configure_scope_icon(false, font_size, _text_ink)
		if index == 2: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(width, 0)
		label.size = Vector2(width, 0)
		var left_side := index in [0, 3]
		var upper_side := index in [2, 3]
		var x := bounds.position.x - gap - width if left_side else bounds.end.x + gap
		var upper_y := maxf(128.0, center.y - 180.0)
		var y := upper_y if upper_side else center.y * 2.0 - upper_y - label.get_minimum_size().y
		y = minf(y, viewport_size.y - label.get_minimum_size().y - 80.0)
		_bases[index] = Vector2(x, y)
		_set_motion(_motions[index], index)


func fade_out_for_restart(immediate := false) -> Tween:
	if not visible or _level == null or _level.tutorial.is_empty(): return null
	_restarting = true
	_stop_tweens(false)
	if immediate:
		modulate.a = 0.0
		return null
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, RESTART_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween
