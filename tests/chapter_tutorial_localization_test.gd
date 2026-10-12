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
	for id in ["1-1", "1-2", "1-3", "1-4", "1-7", "2-1", "2-4", "1-13", "1-14", "2-5", "2-6", "2-7"]:
		var level := repo.load_level(id)
		var state := BoardState.new()
		state.setup(level)
		tutorial.show_state(state)
		for locale in SettingsManager.LANGUAGES:
			TranslationServer.set_locale(locale)
			await get_tree().process_frame
			if id == "1-1":
				var mode_copy := tr("TUTORIAL_CONTROL_MODE").replace("[careful]", "").replace("[/careful]", "").replace("[fast]", "").replace("[/fast]", "")
				assert(tutorial._mode_hint.get_parsed_text() == mode_copy)
				assert(mode_copy != "TUTORIAL_CONTROL_MODE")
				var palette := ThemeManager.get_palette()
				assert(tutorial._mode_hint.text.contains("[color=#%s]" % palette.green.to_html(false)))
				assert(tutorial._mode_hint.text.contains("[color=#%s]" % palette.red.to_html(false)))
				for character in mode_copy:
					if character in [" ", "\n"]: continue
					assert(ui_font.has_char(character.unicode_at(0)) or korean_font.has_char(character.unicode_at(0)), "%s mode hint missing glyph %s" % [locale, character])
			var floating: Dictionary = level.tutorial.floating
			for side in floating:
				assert(floating[side].has(locale), "%s/%s missing %s" % [id, side, locale])
				var text: String = floating[side][locale]
				if id == "1-1":
					var careful := SettingsManager.control_mode == "careful"
					if side == "left": text = tr("TUTORIAL_CAREFUL_LEFT" if careful else "TUTORIAL_MOUSE_RED")
					elif side == "right": text = tr("TUTORIAL_CAREFUL_RIGHT" if careful else "TUTORIAL_MOUSE_GREEN")
					else: text = tr("TUTORIAL_CAREFUL_INTRO" if careful else "TUTORIAL_MOUSE_HYPOTHESIS")
				assert(not text.is_empty())
				var label = tutorial._left if side == "left" else (tutorial._right if side == "right" else tutorial._intro)
				assert((label.copy_text if side == "left" else label.text) == text, "%s/%s: locale update failed" % [id, side])
				for character in text:
					if character in [" ", "\n", "\r", "\t"]:
						continue
					var code := character.unicode_at(0)
					assert(ui_font.has_char(code) or korean_font.has_char(code), "%s/%s missing glyph %s" % [id, locale, character])
		hints += level.tutorial.floating.size()
	assert(hints == 24)
	TranslationServer.set_locale("ja_JP")
	assert(tutorial._left.copy_text == tutorial._level.tutorial.floating.left.ja)
	print("PASS: all 24 floating tutorial hints in all 8 locales, immediate language updates, regional fallback and font coverage.")
	tutorial.queue_free()
	await get_tree().process_frame
	get_tree().quit()
