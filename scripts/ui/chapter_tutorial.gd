extends Control

# These labels float in the board's existing empty margins. They never reserve
# layout space, capture input, or move/scale the board.
const FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const REVEAL_DELAY := 0.5
const REVEAL_DURATION := 0.65
const RISE_DISTANCE := 10.0
const TEXT_OPACITY := 0.55

var _state: BoardState
var _level: LevelDefinition
var _left: Label
var _right: Label
var _intro: Label
var _labels: Array[Label] = []
var _revealed := [false, false, false]
var _completed := false
var _motions := [0.0, 0.0, 0.0]
var _tweens: Array[Tween] = []
var _bases := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _layout_signature := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index in 3:
		var label := Label.new()
		label.name = ["SwitchHint", "ConfirmHint", "SelectHint"][index]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", FONT)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_constant_override("line_spacing", 5)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate.a = 0.0
		add_child(label)
		_labels.append(label)
		if index == 0: _left = label
		elif index == 1: _right = label
		else: _intro = label
	ThemeManager.theme_changed.connect(func(_dark): _update_text())
	get_viewport().size_changed.connect(_place_labels)


func show_state(state: BoardState) -> void:
	var changed := _level != state.level
	_state = state
	_level = state.level
	visible = not _level.tutorial.is_empty()
	if changed:
		_stop_tweens()
		_revealed = [false, false, false]
		_completed = false
		_motions = [0.0, 0.0, 0.0]
		_layout_signature = ""
		for label in _labels: label.modulate.a = 0.0
		_update_text()
		if visible:
			if _level.id == "1-1":
				_reveal(2)
			elif not _level.tutorial.has("reveal_on_selection"):
				_reveal(0)
				_reveal(1)
	if visible:
		_check_progress()
		_place_labels.call_deferred()


func _process(_delta: float) -> void:
	if not visible or _state == null: return
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
	if _level.id != "1-1": return
	var definition := _state.get_definition(_state.selected_cell_id)
	var runtime := _state.get_runtime(_state.selected_cell_id)
	if definition == null or runtime == null or runtime.solved: return
	_reveal(0)
	if not runtime.candidate_pick.is_empty(): _reveal(1)


func _reveal(index: int) -> void:
	if _revealed[index]: return
	_revealed[index] = true
	_motions[index] = RISE_DISTANCE
	var label := _labels[index]
	label.modulate.a = 0.0
	_place_labels()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, REVEAL_DURATION).set_delay(REVEAL_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_motion.bind(index), RISE_DISTANCE, 0.0, REVEAL_DURATION).set_delay(REVEAL_DELAY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tweens.append(tween)


func _set_motion(offset: float, index: int) -> void:
	_motions[index] = offset
	var label := _labels[index]
	label.position = _bases[index] + Vector2(0, offset)


func _stop_tweens() -> void:
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
	var copy: Dictionary = _level.tutorial.get("floating", {})
	_left.text = _localized(copy.get("left", ""))
	_right.text = _localized(copy.get("right", ""))
	_intro.text = _localized(copy.get("intro", "")) if _level.id == "1-1" else ""
	var ink := Color(ThemeManager.get_palette().main_text, TEXT_OPACITY)
	for label in _labels: label.add_theme_color_override("font_color", ink)


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
	var confirm_gap := 112.0 if _level != null and _level.id == "1-1" else 48.0
	var gaps := [48.0, confirm_gap, 80.0]
	for index in 3:
		var label := _labels[index]
		var gap: float = gaps[index]
		var available := bounds.position.x - gap - margin if index == 0 else viewport_size.x - bounds.end.x - gap - margin
		var width := minf(280, available)
		# Never let teaching copy overlap a brick, even in very small windows.
		label.visible = width >= 100 and not label.text.is_empty()
		if not label.visible: continue
		label.add_theme_font_size_override("font_size", 16 if width >= 220 else 14)
		label.custom_minimum_size = Vector2(width, 0)
		label.size = Vector2(width, 0)
		var x := bounds.position.x - gap - width if index == 0 else bounds.end.x + gap
		var y := bounds.get_center().y - 88 if index == 0 else bounds.get_center().y + (96 if confirm_gap > 48 else 48)
		if index == 2: y = bounds.get_center().y - 180
		_bases[index] = Vector2(x, clampf(y, 128, viewport_size.y - label.get_minimum_size().y - 80))
		_set_motion(_motions[index], index)
