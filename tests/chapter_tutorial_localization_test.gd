extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var repo := LevelRepository.new()
	var ui_font: Font = SettingsManager.UI_FONT
	var korean_font: Font = SettingsManager.KOREAN_FONT
	var tutorial = preload("res://scripts/ui/chapter_tutorial.gd").new()
	add_child(tutorial)
	var hints := 0
	for id in ["1-1", "1-2", "1-3", "1-6", "1-10", "1-12", "1-20", "1-21", "1-22"]:
		var level := repo.load_level(id)
		var state := BoardState.new()
		state.setup(level)
		tutorial.show_state(state)
		for locale in SettingsManager.LANGUAGES:
			TranslationServer.set_locale(locale)
			await get_tree().process_frame
			var floating: Dictionary = level.tutorial.floating
			for side in floating:
				assert(floating[side].has(locale), "%s/%s missing %s" % [id, side, locale])
				var text: String = floating[side][locale]
				assert(not text.is_empty())
				var label: Label = tutorial._left if side == "left" else (tutorial._right if side == "right" else tutorial._intro)
				assert(label.text == text, "%s/%s: locale update failed" % [id, side])
				for character in text:
					if character in [" ", "\n", "\r", "\t"]:
						continue
					var code := character.unicode_at(0)
					assert(ui_font.has_char(code) or korean_font.has_char(code), "%s/%s missing glyph %s" % [id, locale, character])
		hints += level.tutorial.floating.size()
	assert(hints == 19)
	TranslationServer.set_locale("ja_JP")
	assert(tutorial._left.text == tutorial._level.tutorial.floating.left.ja)
	print("PASS: all 19 floating tutorial hints in all 8 locales, immediate language updates, regional fallback and font coverage.")
	tutorial.queue_free()
	await get_tree().process_frame
	get_tree().quit()
