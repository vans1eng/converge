extends Control

const FADE_DURATION := 0.2
const DEMO_VERSION := "0.1.0"

var _is_transitioning := true
var _showing_licenses := false

@onready var title_label: Label = $Title
@onready var scroll: ScrollContainer = $Body
@onready var credits: VBoxContainer = $Body/Content/Credits
@onready var version_label: Label = $Body/Content/Credits/Version
@onready var license_text: RichTextLabel = $Body/Content/LicenseText
@onready var license_button: Button = $Body/Content/Credits/Licenses
@onready var back_button: Button = $Footer/BackButton


func _ready() -> void:
	modulate.a = 0.0
	back_button.pressed.connect(_return_back)
	license_button.pressed.connect(_show_licenses)
	resized.connect(_fit_body)
	ThemeManager.apply_to(self)
	ThemeManager.theme_changed.connect(func(_dark): _apply_palette())
	_refresh_text()
	_fit_body()
	_apply_palette()
	ThemeManager.set_buttons_interactive(self, false)
	await create_tween().tween_property(self, "modulate:a", 1.0, FADE_DURATION).finished
	_is_transitioning = false
	ThemeManager.set_buttons_interactive(self, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	title_label.text = tr("ABOUT_LICENSES") if _showing_licenses else tr("HOME_ABOUT")
	version_label.text = tr("ABOUT_VERSION") % str(ProjectSettings.get_setting("application/config/version", DEMO_VERSION))
	_fit_text_buttons()


func _fit_text_buttons() -> void:
	for button in [license_button, back_button]:
		# Match the main menu: pressing must retain the normal content margins.
		var normal_style: StyleBox = button.get_theme_stylebox("normal")
		button.add_theme_stylebox_override("pressed", normal_style)
		button.add_theme_stylebox_override("hover_pressed", normal_style)
		button.focus_mode = Control.FOCUS_NONE
		var font: Font = button.get_theme_font("font")
		var font_size: int = button.get_theme_font_size("font_size")
		button.custom_minimum_size.x = ceilf(font.get_string_size(tr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x) + 8.0


func _fit_body() -> void:
	var width := minf(640.0, maxf(1.0, size.x - 64.0))
	scroll.offset_left = -width * 0.5
	scroll.offset_right = width * 0.5


func _apply_palette() -> void:
	var color := ThemeManager.get_palette().main_text
	for label in find_children("*", "Label", true, false):
		label.add_theme_color_override("font_color", color)
	license_text.add_theme_color_override("default_color", color)
	for button in [license_button, back_button]:
		button.add_theme_color_override("font_hover_color", Color(color.r, color.g, color.b, 0.7))
		button.add_theme_color_override("font_pressed_color", Color(color.r, color.g, color.b, 0.5))
	_fit_text_buttons()


func _show_licenses() -> void:
	if _is_transitioning:
		return
	_showing_licenses = true
	credits.hide()
	license_text.text = "Noto Sans KR\n\n" + FileAccess.get_file_as_string("res://assets/fonts/NotoSansKR-OFL.txt") + "\n\nGodot Engine\n\n" + Engine.get_license_text()
	license_text.show()
	scroll.scroll_vertical = 0
	_refresh_text()


func _return_back() -> void:
	if _is_transitioning:
		return
	if _showing_licenses:
		_showing_licenses = false
		license_text.hide()
		credits.show()
		scroll.scroll_vertical = 0
		_refresh_text()
		return
	_is_transitioning = true
	ThemeManager.set_buttons_interactive(self, false)
	await create_tween().tween_property(self, "modulate:a", 0.0, FADE_DURATION).finished
	get_tree().change_scene_to_file("res://scenes/home_page.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_return_back()
		get_viewport().set_input_as_handled()
