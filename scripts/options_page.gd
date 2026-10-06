extends Control

const HOME_SCENE := "res://scenes/home_page.tscn"
const PAGE_FADE_DURATION := 0.2

var _is_transitioning := false

@onready var back_button: Button = $MarginContainer/VBoxContainer/btn_back
@onready var language_button: Button = $MarginContainer/VBoxContainer/language_container/language_value
@onready var display_button: Button = $MarginContainer/VBoxContainer/display_container/display_value
@onready var resolution_button: Button = $MarginContainer/VBoxContainer/resolution_container/resolution_value
@onready var theme_button: Button = $MarginContainer/VBoxContainer/theme_container/theme_value
@onready var music_button: Button = $MarginContainer/VBoxContainer/music_container/music_value
@onready var sound_button: Button = $MarginContainer/VBoxContainer/sound_container/sound_value


func _ready() -> void:
	SettingsManager.warm_settings_fonts()
	modulate.a = 0.0
	back_button.pressed.connect(_return_home)
	language_button.pressed.connect(SettingsManager.cycle_language)
	display_button.pressed.connect(SettingsManager.cycle_display_mode)
	resolution_button.pressed.connect(SettingsManager.cycle_resolution)
	theme_button.pressed.connect(SettingsManager.toggle_theme)
	music_button.pressed.connect(SettingsManager.toggle_music)
	sound_button.pressed.connect(SettingsManager.toggle_sound)
	SettingsManager.settings_changed.connect(_refresh_values)
	_fit_back_button_hit_area()
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self)
		theme_manager.theme_changed.connect(func(_is_dark): _apply_button_state_colors())
	_apply_button_state_colors()
	_refresh_values()
	create_tween().tween_property(self, "modulate:a", 1.0, PAGE_FADE_DURATION)


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
	_fit_back_button_hit_area()


func _apply_button_state_colors() -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	var base: Color = theme_manager.get_palette().main_text if theme_manager != null else Color.WHITE
	for button in [back_button, language_button, display_button, resolution_button, theme_button, music_button, sound_button]:
		button.add_theme_color_override("font_hover_color", Color(base.r, base.g, base.b, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(base.r, base.g, base.b, 0.5))


func _fit_back_button_hit_area() -> void:
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var font: Font = back_button.get_theme_font("font")
	var font_size: int = back_button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(tr(back_button.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	back_button.custom_minimum_size.x = ceilf(text_width) + 8.0




func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_home()
		get_viewport().set_input_as_handled()


func _return_home() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, PAGE_FADE_DURATION)
	await tween.finished
	get_tree().change_scene_to_file(HOME_SCENE)
