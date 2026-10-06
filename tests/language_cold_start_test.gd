extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# Run in an isolated project/user directory, with a real renderer.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await get_tree().process_frame
	SettingsManager.language = "ko"
	TranslationServer.set_locale("ko")
	var page: Node = load("res://scenes/options_page.tscn").instantiate()
	get_tree().root.add_child(page)
	get_tree().current_scene = page
	# Wait for real draw completion rather than assuming a fixed frame rate.
	var deadline := Time.get_ticks_msec() + 10000
	while not SettingsManager._settings_fonts_ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert(SettingsManager._settings_fonts_ready)
	assert(not SettingsManager._settings_fonts_warming)
	await RenderingServer.frame_post_draw
	for index in 15:
		var prior: String = SettingsManager.language
		var start := Time.get_ticks_usec()
		page.language_button.pressed.emit()
		await RenderingServer.frame_post_draw
		assert(page.language_button.text == SettingsManager.language_label_key())
		assert(TranslationServer.get_locale() == SettingsManager.language)
		print("%s -> %s: %.3f ms" % [prior, SettingsManager.language, (Time.get_ticks_usec() - start) / 1000.0])
	page.queue_free()
	await get_tree().create_timer(AudioManager.ui_click.stream.get_length() + 0.1).timeout
	print("PASS: cold font warmup and 15 rendered language switches")
	get_tree().quit()
