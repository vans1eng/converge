extends Node

signal settings_changed
signal startup_window_ready

const SETTINGS_PATH := "user://settings.cfg"
const SAVE_DELAY := 0.25
const DEFAULT_RESOLUTION := Vector2i(1280, 720)
const UI_FONT := preload("res://assets/fonts/MiSans-Light.ttf")
const KOREAN_FONT := preload("res://assets/fonts/NotoSansKR-UI.ttf")
const SETTINGS_FONT_SIZES := [18, 24, 48]
const SETTINGS_TEXT_KEYS := [
	"OPTIONS_TITLE", "ACTION_BACK", "PAUSE_TITLE", "PAUSE_RESUME", "PAUSE_BACK_TO_MAIN",
	"SETTING_LANGUAGE", "SETTING_DISPLAY", "SETTING_RESOLUTION", "SETTING_THEME",
	"SETTING_MUSIC", "SETTING_SOUND", "VALUE_ENGLISH", "VALUE_CHINESE",
	"VALUE_TRADITIONAL_CHINESE", "VALUE_JAPANESE", "VALUE_KOREAN",
	"VALUE_RUSSIAN", "VALUE_FRENCH", "VALUE_GERMAN",
	"VALUE_FULLSCREEN", "VALUE_WINDOWED", "VALUE_BORDERLESS", "VALUE_DARK",
	"VALUE_LIGHT", "VALUE_ON", "VALUE_OFF",
]
const LANGUAGES := ["en", "zh_CN", "zh_TW", "ja", "ko", "ru", "fr", "de"]
const LANGUAGE_LABELS := {
	"en": "VALUE_ENGLISH",
	"zh_CN": "VALUE_CHINESE",
	"zh_TW": "VALUE_TRADITIONAL_CHINESE",
	"ja": "VALUE_JAPANESE",
	"ko": "VALUE_KOREAN",
	"ru": "VALUE_RUSSIAN",
	"fr": "VALUE_FRENCH",
	"de": "VALUE_GERMAN",
}
const DISPLAY_MODES := ["fullscreen", "windowed", "borderless"]
const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var language := "en"
var display_mode := "windowed"
var resolution := DEFAULT_RESOLUTION
var dark_theme := false
var music_enabled := true
var sound_enabled := true
var _save_timer: Timer
var _save_pending := false
var _language_update_queued := false
var _settings_fonts_warming := false
var _settings_fonts_ready := false
var _startup_window_pending := false


func _enter_tree() -> void:
	_startup_window_pending = DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor() and Engine.get_write_movie_path().is_empty()
	if _startup_window_pending:
		# Keep the configured 1080p size for MovieWriter; shrink only normal play.
		# The native window is already transparent and borderless at creation.
		get_window().size = Vector2i.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.timeout.connect(_save_settings)
	add_child(_save_timer)
	var ui_font: FontFile = UI_FONT
	ui_font.fallbacks = [KOREAN_FONT]
	# All shipped translations are covered by bundled fonts. Avoid platform
	# font searches and retain shaped strings across repeated language cycles.
	ui_font.allow_system_fallback = false
	var korean_font: FontFile = KOREAN_FONT
	korean_font.allow_system_fallback = false
	ui_font.set_cache_capacity(1024, 256)
	_load_settings()
	if _save_pending:
		_save_settings()
	TranslationServer.set_locale(language)
	if Engine.get_write_movie_path().is_empty():
		call_deferred("_apply_startup_settings")
	else:
		# MovieWriter fixes its output size before the first frame is recorded.
		_apply_startup_settings()


func _apply_startup_settings() -> void:
	if not _startup_window_pending:
		get_viewport().transparent_bg = false
		if DisplayServer.get_name() != "headless":
			get_window().transparent = false
			get_window().borderless = false
			get_window().unfocusable = false
		apply_all()
		return
	apply_all()
	# Keep the native window tiny and transparent until the scene has drawn.
	await RenderingServer.frame_post_draw
	get_viewport().transparent_bg = false
	# Draw an opaque pixel in the saved theme before enlarging the window.
	await RenderingServer.frame_post_draw
	_startup_window_pending = false
	var window := get_window()
	window.transparent = false
	window.unfocusable = false
	window.borderless = false
	_apply_display_mode()
	_apply_resolution()
	window.grab_focus()
	startup_window_ready.emit()


func warm_settings_fonts() -> void:
	if _settings_fonts_ready or _settings_fonts_warming:
		return
	if DisplayServer.get_name() == "headless":
		return
	_settings_fonts_warming = true
	# Warm glyphs at the final window size, without exposing the startup window.
	if _startup_window_pending:
		await startup_window_ready
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var canvas := SettingsFontWarmup.new()
	layer.add_child(canvas)
	var cover := ColorRect.new()
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.color = ThemeManager.get_palette().background
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	# Real root-window draws prepare the correct DPI/subpixel glyph textures.
	# A separate SubViewport uses different font scaling and misses this cache.
	# Render one locale per frame during the page's existing fade-in.
	for locale in LANGUAGES:
		var translation := TranslationServer.get_translation_object(locale)
		canvas.texts.clear()
		canvas.texts.append("0123456789 X")
		for key in SETTINGS_TEXT_KEYS:
			canvas.texts.append(str(translation.get_message(key)))
		cover.color = ThemeManager.get_palette().background
		canvas.queue_redraw()
		await RenderingServer.frame_post_draw
	layer.queue_free()
	_settings_fonts_warming = false
	_settings_fonts_ready = true


func cycle_language() -> void:
	language = LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()]
	_save_pending = true
	_save_timer.start()
	# Count every click, but retranslate/reflow only once for an input frame.
	if _language_update_queued:
		return
	_language_update_queued = true
	call_deferred("_apply_pending_language")


func _apply_pending_language() -> void:
	_language_update_queued = false
	if TranslationServer.get_locale() != language:
		TranslationServer.set_locale(language)
	_save_and_emit()


func language_label_key() -> String:
	return LANGUAGE_LABELS.get(language, "VALUE_ENGLISH")


func cycle_display_mode() -> void:
	display_mode = DISPLAY_MODES[(DISPLAY_MODES.find(display_mode) + 1) % DISPLAY_MODES.size()]
	_apply_display_mode()
	_apply_resolution()
	_save_and_emit()


func cycle_resolution() -> void:
	resolution = RESOLUTIONS[(RESOLUTIONS.find(resolution) + 1) % RESOLUTIONS.size()]
	_apply_resolution()
	_save_and_emit()


func toggle_theme() -> void:
	dark_theme = not dark_theme
	ThemeManager.set_dark(dark_theme)
	_save_and_emit()
	# Persist the next startup's theme even on an immediate exit.
	_save_settings()


func toggle_music() -> void:
	music_enabled = not music_enabled
	AudioManager.set_music_enabled(music_enabled)
	_save_and_emit()


func toggle_sound() -> void:
	sound_enabled = not sound_enabled
	AudioManager.set_sound_enabled(sound_enabled)
	_save_and_emit()


func apply_all() -> void:
	if TranslationServer.get_locale() != language:
		TranslationServer.set_locale(language)
	ThemeManager.set_dark(dark_theme, false)
	AudioManager.set_music_enabled(music_enabled)
	AudioManager.set_sound_enabled(sound_enabled)
	if not _startup_window_pending:
		_apply_display_mode()
		_apply_resolution()
	settings_changed.emit()


func resolution_text() -> String:
	return "%dX%d" % [resolution.x, resolution.y]


static func language_for_locale(locale: String) -> String:
	var normalized := locale.strip_edges().replace("-", "_").get_slice(".", 0).get_slice("@", 0).to_lower()
	var parts := normalized.split("_")
	var base := normalized.get_slice("_", 0)
	if base == "zh":
		# Explicit script preferences take priority over the region.
		if "hant" in parts:
			return "zh_TW"
		if "hans" in parts:
			return "zh_CN"
		for region in ["tw", "hk", "mo"]:
			if region in parts:
				return "zh_TW"
		return "zh_CN"
	return base if base in LANGUAGES else "en"


static func initial_language(config: ConfigFile, system_locale: String) -> String:
	var saved := str(config.get_value("localization", "language", ""))
	return saved if saved in LANGUAGES else language_for_locale(system_locale)


func _load_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	language = initial_language(config, OS.get_locale())
	if str(config.get_value("localization", "language", "")) not in LANGUAGES:
		_save_pending = true
	display_mode = str(config.get_value("display", "mode", display_mode))
	if display_mode not in DISPLAY_MODES:
		display_mode = "windowed"
	var width := int(config.get_value("display", "width", resolution.x))
	var height := int(config.get_value("display", "height", resolution.y))
	resolution = Vector2i(width, height)
	if resolution not in RESOLUTIONS:
		resolution = DEFAULT_RESOLUTION
	dark_theme = bool(config.get_value("appearance", "theme_is_dark", dark_theme))
	music_enabled = bool(config.get_value("audio", "music_enabled", music_enabled))
	sound_enabled = bool(config.get_value("audio", "sound_enabled", sound_enabled))


func _save_and_emit() -> void:
	# Refresh immediately; coalesce disk writes while settings are clicked rapidly.
	_save_pending = true
	_save_timer.start()
	settings_changed.emit()


func _exit_tree() -> void:
	if _save_pending:
		_save_settings()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("localization", "language", language)
	config.set_value("display", "mode", display_mode)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("appearance", "theme_is_dark", dark_theme)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "sound_enabled", sound_enabled)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save settings: %s" % error_string(error))
		return
	_save_pending = false


func _apply_display_mode() -> void:
	match display_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func _apply_resolution() -> void:
	if display_mode != "windowed":
		return
	DisplayServer.window_set_size(resolution)
	var screen := DisplayServer.window_get_current_screen()
	var screen_position := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_position + (screen_size - resolution) / 2)
