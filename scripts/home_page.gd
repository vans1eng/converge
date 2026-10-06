extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const PAGE_FADE_DURATION := 0.2
const START_FADE_DURATION := 0.2
const START_FADE_DELAY := 0.1
const EXIT_DELAY := 0.3

var _is_transitioning := false
var _page_tween: Tween

@onready var start_button: Button = $MarginContainer/VBoxContainer/btn_start
@onready var options_button: Button = $MarginContainer/VBoxContainer/btn_options
@onready var about_button: Button = $MarginContainer/VBoxContainer/btn_about
@onready var exit_button: Button = $MarginContainer/VBoxContainer/btn_exit


func _ready() -> void:
	modulate.a = 0.0
	start_button.pressed.connect(_on_start_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	about_button.pressed.connect(_on_about_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	_set_menu_mouse_enabled(false)
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self)
		theme_manager.theme_changed.connect(func(_is_dark): _apply_button_state_colors())
	_fit_menu_button_hit_areas()
	_apply_button_state_colors()
	_fade_in_after_first_frame()


func _fade_in_after_first_frame() -> void:
	# Prepare settings glyphs before any visible animation. The pause menu is
	# instantiated with gameplay, so doing this there stalls the first entrance.
	await SettingsManager.warm_settings_fonts()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(START_FADE_DELAY).timeout
	if not is_inside_tree() or _is_transitioning:
		return
	_page_tween = create_tween()
	_page_tween.tween_property(self, "modulate:a", 1.0, START_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _page_tween.finished
	if is_inside_tree() and not _is_transitioning:
		_set_menu_mouse_enabled(true)


func _set_menu_mouse_enabled(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	for button in [start_button, options_button, about_button, exit_button]:
		button.mouse_filter = filter


func _apply_button_state_colors() -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	var base: Color = theme_manager.get_palette().main_text if theme_manager != null else Color.WHITE
	for button in [start_button, options_button, about_button, exit_button]:
		button.add_theme_color_override("font_hover_color", Color(base.r, base.g, base.b, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(base.r, base.g, base.b, 0.5))


func _fit_menu_button_hit_areas() -> void:
	for button in [start_button, options_button, about_button, exit_button]:
		# Keep the same content margins while pressed so the VBox never relayouts.
		var normal_style: StyleBox = button.get_theme_stylebox("normal")
		button.add_theme_stylebox_override("pressed", normal_style)
		button.add_theme_stylebox_override("hover_pressed", normal_style)
		button.focus_mode = Control.FOCUS_NONE
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		# Keep the target text-sized, with a minimal reserve for the pressed state.
		button.custom_minimum_size.x = ceilf(text_width) + 8.0




func _on_start_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out_page()
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_options_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out_page()
	get_tree().change_scene_to_file("res://scenes/options_page.tscn")


func _on_about_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out_page()
	get_tree().change_scene_to_file("res://scenes/about_page.tscn")


func _on_exit_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	await _fade_out_page()
	await get_tree().create_timer(EXIT_DELAY).timeout
	get_tree().quit()


func _fade_out_page() -> void:
	ThemeManager.set_buttons_interactive(self, false)
	if _page_tween != null and _page_tween.is_running():
		_page_tween.kill()
	_page_tween = create_tween()
	_page_tween.tween_property(self, "modulate:a", 0.0, PAGE_FADE_DURATION)
	await _page_tween.finished


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return
	if OS.has_feature("editor") and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/level_editor.tscn")
