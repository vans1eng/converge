extends Node


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for no in [6, 20, 26, 30]:
		main.current_level_index = main.LEVEL_IDS.find("1-%d" % no)
		main._load_current_level()
		await get_tree().create_timer(1.0).timeout
		var board: HexBoardView = main.board_controller.board_view
		var state: BoardState = main.level_controller.board_state
		for cell in state.level.cells:
			if (no < 26 and cell.mode == "fixed" and (cell.type == "yellow" or cell.scope_radius > 1)) or (no >= 26 and cell.mode == "candidate" and cell.answer_type == "yellow"):
				if cell.mode == "fixed":
					board._neighbor_masks_enabled[cell.id] = true
					board.refresh()
				else:
					main.board_controller.select_cell(cell.id)
					main.board_controller.pick_selected_color("yellow")
				break
		if no == 6:
			for cell in state.level.cells:
				if cell.scope_radius > 1:
					main.board_controller.select_cell(cell.id)
					main.board_controller.pick_selected_color("purple")
					break
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/converge-level-%d.png" % no)
	print("Saved visual previews for levels 6, 20, 26, 30")
	get_tree().quit()
