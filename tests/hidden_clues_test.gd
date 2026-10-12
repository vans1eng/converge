extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	AudioManager.bgm.stop()
	AudioManager.set_sound_enabled(false)
	_test_visibility_and_solver()
	await _test_editor()
	var repo := LevelRepository.new()
	var validator := LevelValidator.new()
	for number in range(1, 21):
		var level := repo.load_level("1-%d" % number)
		assert(validator.validate(level), str(validator.issues))
		var result := PuzzleSolver.new().analyze(level)
		assert(not result.capped, "%s: %s" % [level.id, result])
		assert(bool(result.unique) == (number not in [8, 19, 20]), "%s: %s" % [level.id, result])
	assert(LevelRepository.get_playable_level_ids().size() == 20)
	assert(LevelRepository.get_playable_level_ids()[-1] == "1-20")
	await _test_scope_privacy()
	print("PASS: hidden/fixed/permanent clues; progressive uniqueness without color totals; 20 demo levels (one authored puzzle needs color totals; two templates are included); editor H/round-trip/edge geometry/confirmation; scope privacy before and after verification.")
	get_tree().quit()


func _chain() -> LevelDefinition:
	return LevelDefinition.from_dictionary({"id": "test", "board": {"layout": "odd_r", "rows": 1, "columns": 3}, "cells": [
		{"id": "a", "row": 0, "col": 0, "type": "red", "value": 1},
		{"id": "b", "row": 0, "col": 1, "mode": "candidate", "type": "neutral", "candidate_types": ["red", "green"], "answer": {"type": "red"}, "value": 1, "hidden": true},
		{"id": "c", "row": 0, "col": 2, "mode": "candidate", "type": "neutral", "candidate_types": ["red", "green"], "answer": {"type": "green"}, "value": 0, "hidden": true, "keep_hidden": true},
	]})


func _test_visibility_and_solver() -> void:
	var level := _chain()
	var solver := PuzzleSolver.new()
	assert(solver.count_solutions(level, {}) == 2)
	assert(solver.has_unique_solution(level, {}), "Forced hidden clues must reveal during deduction")
	level.cells[1].keep_hidden = true
	assert(not solver.has_unique_solution(level, {}), "Permanent hidden numbers must never constrain deduction")
	level.cells[0].hidden = true
	assert(not solver.has_unique_solution(level, {}), "Color totals and hidden fixed numbers cannot supply clues")
	var validator := LevelValidator.new()
	assert(validator.validate(level), str(validator.issues))
	level.cells[0].keep_hidden = true
	assert(not validator.validate(level))
	level.cells[0].keep_hidden = false
	level.cells[1].hidden = false
	assert(not validator.validate(level))
	for cell in _chain().cells:
		var runtime := CellRuntimeState.new()
		var view := HexCellView.new()
		add_child(view)
		view.setup(cell, runtime, 32, 33.5)
		assert(view._display_text() == ("1" if cell.mode == "fixed" else ""))
		runtime.solved = true
		assert(view._display_text() == ("" if cell.keep_hidden else "1"))
		if cell.mode == "fixed":
			cell.hidden = true
			assert(view._display_text().is_empty())
		view.free()


func _test_editor() -> void:
	var editor = load("res://scenes/level_editor.tscn").instantiate()
	add_child(editor)
	editor._select_cell(0, 0)
	assert(editor.hidden_check.visible and not editor.keep_hidden_check.visible)
	var h := InputEventKey.new()
	h.keycode = KEY_H
	h.pressed = true
	editor._input(h)
	assert(editor.cells["0:0"].hidden)
	editor.mode_select.select(1)
	editor.hidden_check.set_pressed_no_signal(false)
	editor._apply_properties()
	for state in [1, 2, 0]:
		editor._input(h)
		assert(bool(editor.cells["0:0"].get("hidden", false)) == (state > 0))
		assert(bool(editor.cells["0:0"].get("keep_hidden", false)) == (state == 2))
	editor._load_level_file("res://resources/levels/1-9.json")
	editor.folder_edit.text = "user://hidden_clues_test"
	editor.filename_edit.text = "roundtrip.json"
	editor._export_json()
	assert(editor.status.text.begins_with("已导出"), editor.status.text)
	var restored := LevelLoader.new().load_file("user://hidden_clues_test/roundtrip.json")
	var source := LevelRepository.new().load_level("1-9")
	assert(restored.cells.size() == source.cells.size())
	for i in source.cells.size():
		assert(restored.cells[i].hidden == source.cells[i].hidden)
		assert(restored.cells[i].keep_hidden == source.cells[i].keep_hidden)
	DirAccess.remove_absolute("user://hidden_clues_test/roundtrip.json")
	DirAccess.remove_absolute("user://hidden_clues_test")
	# Shifting the top edge preserves axial distances and selected identity.
	editor.cells.clear()
	editor.rows = 3
	editor.columns = 3
	for pos in [Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 2)]:
		editor.cells[editor._key(pos.y, pos.x)] = editor._default_cell(pos.y, pos.x)
	editor.selected = Vector2i(1, 1)
	var original: Dictionary = editor.cells.duplicate(true)
	editor._resize_edge("top", 1)
	assert(editor.rows == 4 and editor.cells.size() == 3)
	_assert_shape(original, editor.cells)
	assert(editor.cells[editor._key(editor.selected.y, editor.selected.x)].id == original["1:1"].id)
	editor._resize_edge("top", -1)
	_assert_shape(original, editor.cells)
	for edge in ["left", "right", "bottom"]:
		editor._resize_edge(edge, 1)
		assert(editor.cells.size() == 3)
		_assert_shape(original, editor.cells)
		editor._resize_edge(edge, -1)
		assert(editor.cells.size() == 3)
		_assert_shape(original, editor.cells)
	editor._request_resize_edge("top", -1)
	assert(editor.edge_dialog.visible and editor.cells.size() == 3)
	editor.edge_dialog.hide()
	assert(editor.cells.size() == 3) # cancelling does not delete bricks
	editor._request_resize_edge("top", -1)
	editor.edge_dialog.confirmed.emit()
	editor.edge_dialog.hide()
	assert(editor.cells.size() == 2 and editor.rows == 2)
	editor.queue_free()
	await get_tree().process_frame


func _assert_shape(before: Dictionary, after: Dictionary) -> void:
	var first := {}
	var second := {}
	for cell in before.values(): first[cell.id] = HexCoordinate.offset_to_axial(int(cell.row), int(cell.col))
	for cell in after.values(): second[cell.id] = HexCoordinate.offset_to_axial(int(cell.row), int(cell.col))
	for a in first:
		for b in first:
			assert(first[a] - first[b] == second[a] - second[b], "Edge resize changed hex geometry")


func _test_scope_privacy() -> void:
	var board := HexBoardView.new()
	add_child(board)
	var level := _chain()
	level.cells[1].direction = "right"
	level.cells[0].hidden = true
	var state := BoardState.new(level)
	board.show_board(state)
	await board.entrance_finished
	state.select("b")
	state.get_runtime("b").candidate_pick = "red"
	board.refresh()
	assert(board._cell_views.b.scope_overlay.target_amount == 0.0)
	assert(board._cell_views.b.scope_overlay.polygons.is_empty())
	state.get_runtime("b").solved = true
	state.clear_selection()
	for id in ["a", "b", "c"]:
		state.get_runtime(id).solved = true
		board._neighbor_masks_enabled = {id: true}
		board.refresh()
		assert((board._cell_views[id].scope_overlay.target_amount > 0.0) == (id == "b"))
		var click := InputEventMouseButton.new()
		click.position = board._cell_views[id].global_position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		board._neighbor_masks_enabled.clear()
		board._unhandled_input(click)
		assert(board._neighbor_masks_enabled.has(id) == (id == "b"))
	board.queue_free()
	await get_tree().process_frame
