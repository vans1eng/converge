extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var original_dark := ThemeManager.is_dark
	var original_mode := SettingsManager.control_mode
	var repo := LevelRepository.new()
	for dark in [false, true]:
		ThemeManager.is_dark = dark
		SettingsManager.control_mode = "careful"
		var tutorial = preload("res://scripts/ui/chapter_tutorial.gd").new()
		add_child(tutorial)
		tutorial.show_state(BoardState.new(repo.load_level("1-1")))
		var ink := Color(ThemeManager.get_palette().main_text, tutorial.TEXT_OPACITY)
		# Switch during entrance, then repeat after completing each crossfade.
		for mode in ["fast", "careful", "fast"]:
			SettingsManager.control_mode = mode
			SettingsManager.settings_changed.emit()
			for index in 3:
				var key := "default_color" if index < 2 else "font_color"
				assert(tutorial._labels[index].get_theme_color(key) == ink, "Incoming tutorial color missing: %s/%s" % [dark, index])
				assert(tutorial._alternate_labels[index].get_theme_color(key) == ink, "Outgoing tutorial color missing")
			tutorial._mode_tween.pause()
			tutorial._mode_tween.custom_step(1.0)
		# Theme changes must update both buffers before the next mode switch.
		ThemeManager.is_dark = not dark
		ThemeManager.theme_changed.emit(not dark)
		ink = Color(ThemeManager.get_palette().main_text, tutorial.TEXT_OPACITY)
		for index in 3:
			var key := "default_color" if index < 2 else "font_color"
			assert(tutorial._labels[index].get_theme_color(key) == ink)
			assert(tutorial._alternate_labels[index].get_theme_color(key) == ink)
		tutorial._stop_tweens()
		tutorial.queue_free()
		await get_tree().process_frame
	ThemeManager.is_dark = original_dark
	SettingsManager.control_mode = original_mode
	print("PASS: tutorial colors survive first and repeated mode switches and theme changes in light/dark.")
	get_tree().quit()
