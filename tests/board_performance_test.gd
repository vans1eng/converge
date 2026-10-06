extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var board := HexBoardView.new()
	add_child(board)
	for level_id in ["1-25", "2-25"]:
		var level := LevelRepository.new().load_level(level_id)
		assert(level != null)
		var state := BoardState.new(level)
		var start := Time.get_ticks_usec()
		board.show_board(state)
		var build_ms := (Time.get_ticks_usec() - start) / 1000.0
		for view in board._cell_views.values():
			assert(view.scope_overlay.polygons.is_empty(), "Entrance must not build hidden assist geometry.")
			assert(not view.scope_overlay.is_processing())
			assert(not view.is_processing(), "Scale-only entrance needs no per-cell processing.")
		start = Time.get_ticks_usec()
		board._reposition_in_body()
		var layout_ms := (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		for iteration in 10:
			board.refresh()
		var refresh_ms := (Time.get_ticks_usec() - start) / 10000.0
		var frame_times: Array[float] = []
		var previous := Time.get_ticks_usec()
		while board._entrance_active:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			frame_times.append((now - previous) / 1000.0)
			previous = now
		frame_times.sort()
		print("BENCH %s cells=%d build=%.2fms layout=%.2fms refresh=%.2fms entrance_p95=%.2fms max=%.2fms" % [level_id, level.cells.size(), build_ms, layout_ms, refresh_ms, frame_times[int((frame_times.size() - 1) * 0.95)], frame_times.back()])
		_check_assists(board, state)
		board.play_exit_wave()
		await board.exit_finished
		assert(not board.visible)
	# A level replaced while the first render is pending must never start its old entrance.
	var started_ids: Array[String] = []
	board.entrance_started.connect(func(): started_ids.append(board.board_state.level.id))
	board.show_board(BoardState.new(LevelRepository.new().load_level("1-25")))
	await get_tree().process_frame
	board.show_board(BoardState.new(LevelRepository.new().load_level("1-1")))
	await board.entrance_finished
	assert(started_ids == ["1-1"])
	assert(board.get_child_count() == board.board_state.level.cells.size() * 2)
	board.queue_free()
	await get_tree().process_frame
	print("PASS: large-board entrance/exit, idle processing, assist colors, geometry caching, resize, theme refresh and cancelled entrance preparation.")
	get_tree().quit()


func _check_assists(board: HexBoardView, state: BoardState) -> void:
	var candidate: CellDefinition
	for cell in state.level.cells:
		if cell.is_editable():
			candidate = cell
			break
	assert(candidate != null)
	state.select(candidate.id)
	var runtime := state.get_runtime(candidate.id)
	var view: HexCellView = board._cell_views[candidate.id]
	var overlay := view.scope_overlay
	for type in candidate.candidate_types:
		runtime.candidate_pick = type
		board.refresh()
		assert(view.is_processing())
		assert(overlay.is_processing() and overlay.target_amount == 1.0)
		_check_geometry(board, candidate, type)
		view._process(2.0)
		view._process(2.0)
		overlay._process(2.0)
		assert(not view.is_processing() and not overlay.is_processing())
		assert(view._current_fill == view._fill_color())
		assert(overlay.visible and overlay.amount == 1.0)
		var geometry := overlay.polygons.duplicate()
		board.refresh()
		assert(overlay.polygons == geometry and not overlay.is_processing())
	var old_radius := board.radius
	board.board_margin = 550.0
	board._reposition_in_body()
	assert(board.radius != old_radius)
	_check_geometry(board, candidate, runtime.candidate_pick)
	board.board_margin = 72.0
	board._reposition_in_body()
	var was_dark := ThemeManager.is_dark
	ThemeManager.set_dark(not was_dark, false)
	board.refresh()
	view._process(2.0)
	overlay._process(2.0)
	assert(view._current_fill == view._fill_color())
	assert(overlay.color == overlay.target_color)
	ThemeManager.set_dark(was_dark, false)
	state.clear_selection()
	board.refresh()
	assert(overlay.target_amount == 0.0)
	overlay._process(2.0)
	assert(not overlay.visible and not overlay.is_processing())
	# Solved cells can still toggle their assist; breaking shards wake an idle cell.
	runtime.solved = true
	board._neighbor_masks_enabled[candidate.id] = true
	board.refresh()
	assert(overlay.target_amount == 1.0)
	board.play_success(candidate.id)
	assert(view.is_processing())
	view._process(2.0)
	view._process(2.0)
	assert(view._break_shards.is_empty() and not view.is_processing())


func _check_geometry(board: HexBoardView, source: CellDefinition, type: String) -> void:
	var reference := HexScopeOverlay.new()
	var scope := ClueRules.scope(source, board.board_state.level.create_grid(), type)
	scope.push_front(source)
	reference.configure(source, scope, board.radius, 1.5)
	assert(board._cell_views[source.id].scope_overlay.polygons == reference.polygons)
	reference.free()
