extends Node


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for id in ["1-13", "2-8", "1-18", "2-17", "2-20", "2-31", "2-46"]:
		assert(main.level_controller.load_level(id))
		await get_tree().create_timer(1.0).timeout
		var board: HexBoardView = main.board_controller.board_view
		var state: BoardState = main.level_controller.board_state
		for cell in state.level.cells:
			if cell.mode == "fixed" and cell.type in ["purple", "yellow"]:
				board._neighbor_masks_enabled[cell.id] = true
				board.refresh()
				break
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/converge-level-%s.png" % id)
	print("Saved fixed-clue chapter visual previews")
	get_tree().quit()
