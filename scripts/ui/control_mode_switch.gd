extends HBoxContainer

const FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const FONT_SIZE := 16

var mode_button: Button
var mode_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.flat = true
	mode_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	mode_button.focus_mode = Control.FOCUS_NONE
	mode_button.add_theme_font_override("font", FONT)
	mode_button.add_theme_font_size_override("font_size", FONT_SIZE)
	mode_button.pressed.connect(SettingsManager.toggle_control_mode)
	add_child(mode_button)
	mode_label = Label.new()
	mode_label.name = "ModeLabel"
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_label.add_theme_font_override("font", FONT)
	mode_label.add_theme_font_size_override("font_size", FONT_SIZE)
	mode_button.add_child(mode_label)
	mode_button.resized.connect(_place_mode_label)
	SettingsManager.settings_changed.connect(_update)
	ThemeManager.theme_changed.connect(func(_dark): _update())
	_update.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update()


func _update() -> void:
	var careful := SettingsManager.control_mode == "careful"
	mode_button.text = tr("VALUE_CAREFUL" if careful else "VALUE_FAST")
	var language := TranslationServer.get_locale().get_slice("_", 0)
	mode_label.text = ("" if language in ["zh", "ja", "ko"] else " ") + tr("HUD_CONTROL_MODE")
	var palette := ThemeManager.get_palette()
	ThemeManager.set_button_hover_color(mode_button, palette.green if careful else palette.red)
	mode_label.add_theme_color_override("font_color", palette.main_text)
	# Match the home menu's text-sized hit area and stable pressed margins.
	var normal_style := mode_button.get_theme_stylebox("normal")
	mode_button.add_theme_stylebox_override("pressed", normal_style)
	mode_button.add_theme_stylebox_override("hover_pressed", normal_style)
	var text_width := FONT.get_string_size(mode_button.text + mode_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	mode_button.custom_minimum_size.x = ceilf(text_width) + normal_style.get_minimum_size().x
	_place_mode_label()


func _place_mode_label() -> void:
	if mode_label == null: return
	var normal_style := mode_button.get_theme_stylebox("normal")
	var mode_width := FONT.get_string_size(mode_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	mode_label.size = mode_label.get_minimum_size()
	mode_label.position = Vector2(normal_style.get_margin(SIDE_LEFT) + mode_width, (mode_button.size.y - mode_label.size.y) * 0.5)
