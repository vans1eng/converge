extends Node

# Run in an isolated project/user directory: this exercises settings persistence.
var _save_count := 0
var _refresh_count := 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var settings := get_tree().root.get_node("SettingsManager")
	settings._save_timer.timeout.connect(func(): _save_count += 1)
	settings.settings_changed.connect(func(): _refresh_count += 1)
	var font: FontFile = settings.UI_FONT
	assert(not font.allow_system_fallback)
	assert(not settings.KOREAN_FONT.allow_system_fallback)
	var csv := FileAccess.open("res://localization/translations.csv", FileAccess.READ)
	csv.get_csv_line()
	var keys: Array[String] = []
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if not row[0].is_empty():
			keys.append(row[0])
	for translation in TranslationServer.get_loaded_locales():
		var resource := TranslationServer.get_translation_object(translation)
		for key in keys:
			for character in str(resource.get_message(key)):
				if character not in [" ", "\n", "\r", "\t"]:
					assert(font.has_char(character.unicode_at(0)), "%s: %s" % [translation, character])
	var page = load("res://scenes/options_page.tscn").instantiate()
	get_tree().root.add_child(page)
	get_tree().current_scene = page
	settings.language = "ko"
	TranslationServer.set_locale("ko")
	settings.settings_changed.emit()
	_refresh_count = 0
	for index in range(settings.LANGUAGES.size() * 5 - settings.LANGUAGES.find("ko")):
		settings.cycle_language()
	assert(settings.language == "en")
	await get_tree().process_frame
	assert(TranslationServer.get_locale() == settings.language)
	assert(page.language_button.text == settings.language_label_key())
	assert(_refresh_count == 1)
	assert(_save_count == 0)
	assert(settings._save_pending)
	await get_tree().create_timer(settings.SAVE_DELAY + 0.1).timeout
	assert(_save_count == 1)
	assert(not settings._save_pending)
	_assert_saved_language(settings, "en")
	for index in range(settings.LANGUAGES.size() * 2):
		settings.cycle_language()
		await get_tree().process_frame
		assert(TranslationServer.get_locale() == settings.language)
		assert(page.language_button.text == settings.language_label_key())
	await get_tree().create_timer(settings.SAVE_DELAY + 0.1).timeout
	assert(_save_count == 2)
	page.queue_free()
	await get_tree().process_frame
	var game = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().process_frame
	var pause_menu = game.get_node("CanvasLayer/PauseMenu")
	pause_menu.open()
	for index in range(settings.LANGUAGES.size()):
		settings.cycle_language()
	await get_tree().process_frame
	assert(pause_menu.language_button.text == settings.language_label_key())
	await get_tree().create_timer(settings.SAVE_DELAY + 0.1).timeout
	assert(_save_count == 3)
	assert(not settings._save_pending)
	get_tree().paused = false
	settings.cycle_language()
	# The exit hook must flush even before the debounce timer expires.
	settings._exit_tree()
	_assert_saved_language(settings, "zh_CN")
	assert(not settings._save_pending)
	print("PASS: font coverage, rapid language switching, paused saving, exit flush")
	get_tree().quit()


func _assert_saved_language(settings: Node, expected: String) -> void:
	var config := ConfigFile.new()
	assert(config.load(settings.SETTINGS_PATH) == OK)
	assert(config.get_value("localization", "language") == expected)
