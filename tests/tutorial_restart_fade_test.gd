extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	get_tree().set_meta("selected_level", "1-1")
	var main = preload("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var board = main.board_controller.board_view
	await board.entrance_finished
	await get_tree().create_timer(2.0).timeout
	var tutorial = main.hud_controller.chapter_tutorial
	for from_pause in [false, true]:
		if from_pause:
			main.pause_menu.open()
			await get_tree().create_timer(0.3).timeout
		var old_level = tutorial._level
		main._restart_level(from_pause)
		assert(tutorial._restarting)
		assert(tutorial.modulate.a == (0.0 if from_pause else 1.0))
		assert(tutorial._level == old_level and tutorial._mode_hint.modulate.a == 1.0)
		await get_tree().create_timer(0.1).timeout
		if from_pause:
			assert(tutorial.modulate.a == 0.0 and not board.visible)
		else:
			assert(tutorial.modulate.a > 0.0 and tutorial.modulate.a < 1.0)
		assert(tutorial._level == old_level)
		await board.entrance_finished
		await get_tree().create_timer(2.0).timeout
		assert(not tutorial._restarting and tutorial.modulate.a == 1.0)
		assert(tutorial._level != old_level)
		assert(tutorial._mode_hint.modulate.a == 1.0)
	print("PASS: HUD restart fades tutorial; pause restart hides tutorial immediately; both replay entrance.")
	main.queue_free()
	await get_tree().process_frame
	get_tree().quit()
