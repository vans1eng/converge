extends Node

signal theme_changed(is_dark_theme: bool)

const DARK_THEME := preload("res://resources/themes/dark_theme.tres")
const LIGHT_THEME := preload("res://resources/themes/light_theme.tres")
const DARK_PALETTE := preload("res://resources/themes/dark_palette.tres")
const LIGHT_PALETTE := preload("res://resources/themes/light_palette.tres")

var is_dark := false
var _transition_layer: CanvasLayer
var _transition_rect: TextureRect
var _transition_tween: Tween
const BUTTON_HOVER_DURATION := 0.2


func _enter_tree() -> void:
	# Match SettingsManager's light default before any scene or font warmup draws.
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		is_dark = bool(settings.get_value("appearance", "theme_is_dark", false))
	_apply_game_background()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	theme_changed.connect(func(_dark): call_deferred("_refresh_button_hovers"))
	_refresh_button_hovers()


func _on_node_added(node: Node) -> void:
	if node is Button:
		_register_button_hover.call_deferred(node)


func _refresh_button_hovers() -> void:
	_register_buttons_under(get_tree().root)


func _register_buttons_under(node: Node) -> void:
	if node is Button:
		_register_button_hover(node, true)
	for child in node.get_children():
		_register_buttons_under(child)


func _register_button_hover(button: Button, refresh := false) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree():
		return
	# The gameplay guide button has its own transparent outline styles.
	if button.name == "GuideButton" or button.has_meta("custom_hover_style"):
		return
	if button.has_meta("hover_transition_ready") and not refresh:
		return
	if button.has_meta("hover_transition_ready"):
		var old_tween: Tween = button.get_meta("hover_transition_tween") if button.has_meta("hover_transition_tween") else null
		if old_tween != null and old_tween.is_running():
			old_tween.kill()
		button.remove_theme_color_override("font_color")
		button.remove_theme_color_override("font_hover_color")
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")
	var base: Color = get_palette().main_text
	var hover := Color(base.r, base.g, base.b, 0.7)
	button.set_meta("hover_transition_base", base)
	button.set_meta("hover_transition_target", hover)
	var normal_style := button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover_style := button.get_theme_stylebox("hover") as StyleBoxFlat
	if not button.flat and normal_style != null and hover_style != null:
		var animated_style := normal_style.duplicate() as StyleBoxFlat
		button.set_meta("hover_transition_style", animated_style)
		button.set_meta("hover_transition_normal_bg", normal_style.bg_color)
		button.set_meta("hover_transition_hover_bg", hover_style.bg_color)
		button.set_meta("hover_transition_normal_border", normal_style.border_color)
		button.set_meta("hover_transition_hover_border", hover_style.border_color)
		button.add_theme_stylebox_override("normal", animated_style)
		button.add_theme_stylebox_override("hover", animated_style)
	else:
		if button.has_meta("hover_transition_style"):
			button.remove_meta("hover_transition_style")
	if not button.has_meta("hover_transition_ready"):
		button.mouse_entered.connect(_animate_button_hover.bind(button, true))
		button.mouse_exited.connect(_animate_button_hover.bind(button, false))
		button.mouse_entered.connect(func():
			if not button.disabled:
				AudioManager.play_ui_hover()
		)
		button.pressed.connect(AudioManager.play_ui_click)
		button.set_meta("hover_transition_ready", true)
	_set_button_hover_mix(1.0 if button.is_hovered() else 0.0, button)


func _animate_button_hover(button: Button, hovered: bool) -> void:
	if button.has_meta("transition_input_state"):
		return
	var old_tween: Tween = button.get_meta("hover_transition_tween") if button.has_meta("hover_transition_tween") else null
	if old_tween != null and old_tween.is_running():
		old_tween.kill()
	var tween := button.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(_set_button_hover_mix.bind(button), float(button.get_meta("hover_transition_mix", 0.0)), 1.0 if hovered else 0.0, BUTTON_HOVER_DURATION)
	button.set_meta("hover_transition_tween", tween)


func set_buttons_interactive(root: Node, enabled: bool) -> void:
	if root is Button:
		var button := root as Button
		if enabled and button.has_meta("transition_input_state"):
			var state: Dictionary = button.get_meta("transition_input_state")
			button.process_mode = state["process_mode"]
			button.mouse_filter = state["mouse_filter"]
			button.focus_mode = state["focus_mode"]
			button.remove_meta("transition_input_state")
		elif not enabled and not button.has_meta("transition_input_state"):
			button.set_meta("transition_input_state", {
				"process_mode": button.process_mode,
				"mouse_filter": button.mouse_filter,
				"focus_mode": button.focus_mode,
			})
			var hover_tween: Tween = button.get_meta("hover_transition_tween") if button.has_meta("hover_transition_tween") else null
			if hover_tween != null and hover_tween.is_running():
				hover_tween.kill()
			if button.has_meta("hover_transition_ready"):
				_set_button_hover_mix(0.0, button)
			button.set_pressed_no_signal(false)
			# Stop mouse and keyboard input without switching to the disabled visual style.
			button.release_focus()
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.process_mode = Node.PROCESS_MODE_DISABLED
	for child in root.get_children():
		set_buttons_interactive(child, enabled)


func _set_button_hover_mix(mix: float, button: Button) -> void:
	if not is_instance_valid(button):
		return
	button.set_meta("hover_transition_mix", mix)
	var base: Color = button.get_meta("hover_transition_base")
	var target: Color = button.get_meta("hover_transition_target")
	var color := base.lerp(target, mix)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	if button.has_meta("hover_transition_style"):
		var style: StyleBoxFlat = button.get_meta("hover_transition_style")
		var normal_bg: Color = button.get_meta("hover_transition_normal_bg")
		var hover_bg: Color = button.get_meta("hover_transition_hover_bg")
		var normal_border: Color = button.get_meta("hover_transition_normal_border")
		var hover_border: Color = button.get_meta("hover_transition_hover_border")
		style.bg_color = normal_bg.lerp(hover_bg, mix)
		style.border_color = normal_border.lerp(hover_border, mix)


func get_palette() -> GameColorPalette:
	return DARK_PALETTE if is_dark else LIGHT_PALETTE


func set_dark(enabled: bool, animate := true) -> void:
	if enabled == is_dark:
		_apply_current_scene_theme()
		return
	if animate:
		_play_theme_transition()
	is_dark = enabled
	_apply_current_scene_theme()
	_apply_game_background()
	theme_changed.emit(is_dark)


func _apply_current_scene_theme() -> void:
	var scene := get_tree().current_scene
	if scene is Control:
		apply_to(scene)


func apply_to(root: Control, with_background := true) -> void:
	root.theme = DARK_THEME if is_dark else LIGHT_THEME
	if not with_background:
		return
	var background := root.get_node_or_null("ThemeBackground") as ColorRect
	if background == null:
		background = ColorRect.new()
		background.name = "ThemeBackground"
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.show_behind_parent = true
		root.add_child(background)
		root.move_child(background, 0)
	if background != null:
		background.color = get_palette().background


func add_toggle(root: Control, with_background := true) -> void:
	apply_to(root, with_background)
	var button := Button.new()
	button.name = "ThemeToggle"
	button.text = "☀ 浅色" if is_dark else "☾ 深色"
	button.tooltip_text = "切换浅色 / 深色主题"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.position = Vector2(-116, 18)
	button.size = Vector2(98, 38)
	button.z_index = 10
	button.pressed.connect(func():
		_play_theme_transition()
		is_dark = not is_dark
		var settings := ConfigFile.new()
		settings.set_value("appearance", "theme_is_dark", is_dark)
		settings.save("user://settings.cfg")
		button.text = "☀ 浅色" if is_dark else "☾ 深色"
		apply_to(root, with_background)
		_apply_game_background()
		theme_changed.emit(is_dark)
	)
	root.add_child(button)


func _apply_game_background() -> void:
	# The gameplay board is drawn by Node2D rather than Control widgets, so it
	# needs an explicit canvas background update in addition to Control themes.
	RenderingServer.set_default_clear_color(get_palette().background)


func _play_theme_transition() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var image := viewport.get_texture().get_image()
	if image == null:
		return
	_ensure_transition_overlay()
	_transition_rect.texture = ImageTexture.create_from_image(image)
	_transition_rect.modulate = Color.WHITE
	_transition_rect.show()
	if _transition_tween != null:
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_transition_tween.tween_property(_transition_rect, "modulate:a", 0.0, 0.2)
	_transition_tween.tween_callback(_transition_rect.hide)


func _ensure_transition_overlay() -> void:
	if _transition_layer != null:
		return
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100
	add_child(_transition_layer)
	_transition_rect = TextureRect.new()
	_transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_transition_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.hide()
	_transition_layer.add_child(_transition_rect)
