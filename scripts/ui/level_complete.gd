extends Control
class_name LevelComplete

signal continue_requested
signal back_requested

const FADE_DURATION := 0.32

var _fade_tween: Tween

@onready var title_label: Label = $MarginContainer/VBoxContainer/Title
@onready var level_label: Label = $MarginContainer/VBoxContainer/Center/Content/Level
@onready var time_label: Label = $MarginContainer/VBoxContainer/Center/Content/Time
@onready var mistakes_label: Label = $MarginContainer/VBoxContainer/Center/Content/Mistakes
@onready var back_button: Button = $MarginContainer/VBoxContainer/Footer/BackButton
@onready var continue_button: Button = $MarginContainer/VBoxContainer/Footer/ContinueButton


func _ready() -> void:
	continue_button.pressed.connect(func(): continue_requested.emit())
	back_button.pressed.connect(func(): back_requested.emit())
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self, false)
		theme_manager.theme_changed.connect(func(_dark): _apply_palette())
	_apply_palette()


func show_result(level_number: String, elapsed_seconds: float, mistakes: int, has_next_level: bool) -> void:
	ThemeManager.set_buttons_interactive(self, true)
	title_label.text = tr("RESULT_TITLE")
	level_label.text = tr("RESULT_LEVEL") % level_number
	time_label.text = tr("RESULT_TIME") % HudController.format_time(elapsed_seconds)
	mistakes_label.text = tr("RESULT_MISTAKES") % mistakes
	back_button.text = tr("RESULT_HOME")
	continue_button.text = tr("RESULT_NEXT")
	continue_button.visible = has_next_level
	_fit_footer_button_hit_areas()
	visible = true
	modulate.a = 0.0
	AudioManager.play_level_complete()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)


func fade_out() -> void:
	ThemeManager.set_buttons_interactive(self, false)
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	await _fade_tween.finished
	hide()


func _apply_palette() -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	var palette: GameColorPalette = theme_manager.get_palette() if theme_manager != null else preload("res://resources/themes/dark_palette.tres")
	title_label.add_theme_color_override("font_color", palette.main_text)
	level_label.add_theme_color_override("font_color", palette.main_text)
	time_label.add_theme_color_override("font_color", palette.main_text)
	mistakes_label.add_theme_color_override("font_color", palette.main_text)
	back_button.add_theme_color_override("font_color", palette.main_text)
	continue_button.add_theme_color_override("font_color", palette.main_text)
	for button in [back_button, continue_button]:
		button.add_theme_color_override("font_hover_color", Color(palette.main_text.r, palette.main_text.g, palette.main_text.b, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(palette.main_text.r, palette.main_text.g, palette.main_text.b, 0.5))


func _fit_footer_button_hit_areas() -> void:
	for button in [back_button, continue_button]:
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		button.custom_minimum_size.x = ceilf(text_width) + 8.0
