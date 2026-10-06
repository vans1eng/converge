extends Control
class_name PauseMenu

signal closed

const FADE_DURATION := 0.2

var _fade_tween: Tween
var _is_closing := false

@onready var background: ColorRect = $Background
@onready var content: MarginContainer = $MarginContainer
@onready var resume_button: Button = $MarginContainer/VBoxContainer/Footer/ResumeButton
@onready var back_to_main_button: Button = $MarginContainer/VBoxContainer/Footer/BackToMainButton
@onready var language_button: Button = $MarginContainer/VBoxContainer/Language/Value
@onready var display_button: Button = $MarginContainer/VBoxContainer/Display/Value
@onready var resolution_button: Button = $MarginContainer/VBoxContainer/Resolution/Value
@onready var theme_button: Button = $MarginContainer/VBoxContainer/Theme/Value
@onready var music_button: Button = $MarginContainer/VBoxContainer/Music/Value
@onready var sound_button: Button = $MarginContainer/VBoxContainer/Sound/Value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	resume_button.pressed.connect(close)
	back_to_main_button.pressed.connect(_back_to_main)
	language_button.pressed.connect(SettingsManager.cycle_language)
	display_button.pressed.connect(SettingsManager.cycle_display_mode)
	resolution_button.pressed.connect(SettingsManager.cycle_resolution)
	theme_button.pressed.connect(SettingsManager.toggle_theme)
	music_button.pressed.connect(SettingsManager.toggle_music)
	sound_button.pressed.connect(SettingsManager.toggle_sound)
	SettingsManager.settings_changed.connect(_refresh_values)
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.theme_changed.connect(func(_is_dark): _apply_theme())
	_apply_theme()
	_refresh_values()
	visible = false


func _apply_theme() -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager == null:
		return
	theme_manager.apply_to(self, false)
	var palette: GameColorPalette = theme_manager.get_palette()
	background.color = palette.background
	for button in [resume_button, back_to_main_button, language_button, display_button, resolution_button, theme_button, music_button, sound_button]:
		button.add_theme_color_override("font_hover_color", Color(palette.main_text.r, palette.main_text.g, palette.main_text.b, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(palette.main_text.r, palette.main_text.g, palette.main_text.b, 0.5))


func _refresh_values() -> void:
	language_button.text = SettingsManager.language_label_key()
	match SettingsManager.display_mode:
		"fullscreen": display_button.text = "VALUE_FULLSCREEN"
		"borderless": display_button.text = "VALUE_BORDERLESS"
		_: display_button.text = "VALUE_WINDOWED"
	resolution_button.text = SettingsManager.resolution_text()
	theme_button.text = "VALUE_DARK" if SettingsManager.dark_theme else "VALUE_LIGHT"
	music_button.text = "VALUE_ON" if SettingsManager.music_enabled else "VALUE_OFF"
	sound_button.text = "VALUE_ON" if SettingsManager.sound_enabled else "VALUE_OFF"
	_fit_footer_button_hit_areas()


func _fit_footer_button_hit_areas() -> void:
	for button in [resume_button, back_to_main_button]:
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		button.custom_minimum_size.x = ceilf(text_width) + 8.0


func open() -> void:
	if visible:
		return
	_is_closing = false
	content.modulate.a = 1.0
	modulate.a = 0.0
	visible = true
	get_tree().paused = true
	_fade_tween = _fade_to(1.0)


func close() -> void:
	if not visible or _is_closing:
		return
	_is_closing = true
	_fade_tween = _fade_to(0.0)
	await _fade_tween.finished
	visible = false
	get_tree().paused = false
	closed.emit()


func _back_to_main() -> void:
	if _is_closing:
		return
	_is_closing = true
	ThemeManager.set_buttons_interactive(get_tree().current_scene, false)
	_fade_tween = create_tween()
	_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade_tween.tween_property(content, "modulate:a", 0.0, FADE_DURATION)
	await _fade_tween.finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/home_page.tscn")


func _fade_to(target_alpha: float) -> Tween:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", target_alpha, FADE_DURATION)
	return tween


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
