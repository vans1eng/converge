extends Node2D
class_name HexBoardView

signal cell_clicked(cell_id: String, button_index: int)
signal cell_hovered(cell_id: String)
signal entrance_finished
signal entrance_started
signal exit_finished

@export var max_radius := 36.0
@export var min_radius := 16.0
@export var board_margin := 72.0

var radius := 32.0

var board_state: BoardState
var _cell_views: Dictionary = {}
var _hovered_cell_id := ""
var _neighbor_masks_enabled: Dictionary = {}
var _entrance_tweens: Array[Tween] = []
var _entrance_active := false
var _exit_tweens: Array[Tween] = []
var _exit_active := false
var _grid: HexGrid
var _overlay_geometry_keys: Dictionary = {}
var _entrance_generation := 0


func show_board(state: BoardState) -> void:
	_entrance_generation += 1
	visible = true
	for active_tween in _exit_tweens:
		active_tween.kill()
	_exit_tweens.clear()
	_exit_active = false
	for active_tween in _entrance_tweens:
		active_tween.kill()
	_entrance_tweens.clear()
	_entrance_active = false
	board_state = state
	_grid = state.level.create_grid() if state != null else null
	_overlay_geometry_keys.clear()
	for child in get_children():
		child.queue_free()
	_cell_views.clear()
	_hovered_cell_id = ""
	_neighbor_masks_enabled.clear()
	if board_state == null:
		return

	radius = _calculate_radius(board_state.level)
	var width := sqrt(3.0) * radius
	var height := 1.5 * radius
	var origin := _board_origin(board_state.level)

	for definition in board_state.level.cells:
		var view := HexCellView.new()
		view.name = definition.id
		view.scale = Vector2.ZERO
		view.position = origin + Vector2(width * (definition.col + 0.5 * (definition.row & 1)), height * definition.row)
		add_child(view)
		var overlay := HexScopeOverlay.new()
		view.scope_overlay = overlay
		add_child(overlay)
		overlay.position = view.position
		overlay.z_index = 10
		_cell_views[definition.id] = view
	refresh()
	_entrance_active = true
	# Control containers resolve their final rectangles at the end of the frame.
	# Reflow then, otherwise the footer still reports y=0 on the first load.
	_prepare_entrance.call_deferred(_entrance_generation)


func _prepare_entrance(generation: int) -> void:
	if generation != _entrance_generation:
		return
	_reposition_in_body()
	# Finish first-use draw commands, glyph uploads and layout before motion.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		await get_tree().process_frame
	else:
		await RenderingServer.frame_post_draw
		# One settled frame also keeps the first tween step from inheriting the
		# scene-loading frame's large delta.
		await RenderingServer.frame_post_draw
	if generation != _entrance_generation or _exit_active:
		return
	_play_entrance()


func _play_entrance() -> void:
	_entrance_active = true
	entrance_started.emit()
	var last_finish := 0.0
	for definition in board_state.level.cells:
		var view: HexCellView = _cell_views.get(definition.id, null)
		if view == null:
			continue
		view.scale = Vector2.ZERO
		var delay := definition.row * 0.055 + definition.col * 0.025
		var tween := create_tween()
		_entrance_tweens.append(tween)
		tween.tween_interval(delay)
		tween.tween_property(view, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		last_finish = maxf(last_finish, delay + 0.2)
	var finish_tween := create_tween()
	_entrance_tweens.append(finish_tween)
	finish_tween.tween_interval(last_finish)
	finish_tween.tween_callback(func():
		_entrance_active = false
		entrance_finished.emit()
	)


func play_exit_wave() -> void:
	if board_state == null or _exit_active:
		return
	_exit_active = true
	for view in _cell_views.values():
		view.scope_overlay.set_active(false, Color.TRANSPARENT)
	_hovered_cell_id = ""
	var last_finish := 0.0
	for definition in board_state.level.cells:
		var view: HexCellView = _cell_views.get(definition.id, null)
		if view == null:
			continue
		var delay := (definition.row + definition.col) * 0.045
		var tween := create_tween()
		_exit_tweens.append(tween)
		tween.tween_interval(delay)
		tween.tween_property(view, "scale", Vector2.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		last_finish = maxf(last_finish, delay + 0.24)
	var finish_tween := create_tween()
	_exit_tweens.append(finish_tween)
	finish_tween.tween_interval(last_finish)
	finish_tween.tween_callback(func():
		_exit_active = false
		visible = false
		exit_finished.emit()
	)


func _reposition_in_body() -> void:
	if board_state == null:
		return
	var new_radius := _calculate_radius(board_state.level)
	var radius_changed := not is_equal_approx(radius, new_radius)
	radius = new_radius
	if radius_changed:
		_overlay_geometry_keys.clear()
	var width := sqrt(3.0) * radius
	var height := 1.5 * radius
	var origin := _board_origin(board_state.level)
	for definition in board_state.level.cells:
		var view: HexCellView = _cell_views.get(definition.id, null)
		if view == null:
			continue
		view.position = origin + Vector2(width * (definition.col + 0.5 * (definition.row & 1)), height * definition.row)
		view.scope_overlay.position = view.position
	if radius_changed:
		refresh()


func _board_origin(level: LevelDefinition) -> Vector2:
	var width := sqrt(3.0) * radius
	var origin := _body_rect().get_center()
	# Center the occupied hex bounds horizontally, including odd-row offsets.
	# Every hex has the same width, so the extreme cell centers suffice.
	if not level.cells.is_empty():
		var left := INF
		var right := -INF
		for cell in level.cells:
			var x := width * (cell.col + 0.5 * (cell.row & 1))
			left = minf(left, x)
			right = maxf(right, x)
		origin.x -= (left + right) * 0.5
	origin.y -= (level.rows - 1) * 1.5 * radius * 0.5
	return origin


func _ready() -> void:
	get_viewport().size_changed.connect(_reposition_in_body)
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.theme_changed.connect(func(_is_dark_theme): refresh())


func _calculate_radius(level: LevelDefinition) -> float:
	# Keep sizing based on declared bounds; horizontal placement uses occupied cells.
	var body_rect := _body_rect()
	var available_width: float = maxf(1.0, body_rect.size.x - board_margin * 2.0)
	var available_height: float = maxf(1.0, body_rect.size.y - board_margin * 2.0)
	var width_factor: float = sqrt(3.0) * (level.columns + 0.5)
	var height_factor: float = 1.5 * (level.rows - 1) + 2.0
	return clamp(min(available_width / width_factor, available_height / height_factor), min_radius, max_radius)


func _body_rect() -> Rect2:
	var viewport_rect := get_viewport_rect()
	var scene := get_tree().current_scene
	if scene == null:
		return viewport_rect
	var title := scene.get_node_or_null("CanvasLayer/HUD/VBoxContainer/LevelTitle") as Control
	var status := scene.get_node_or_null("CanvasLayer/HUD/VBoxContainer/StatusMessage") as Control
	if title == null or status == null:
		return viewport_rect
	var header_bottom := title.get_global_rect().end.y + 48.0
	var footer_top := status.get_global_rect().position.y
	return Rect2(0.0, header_bottom, viewport_rect.size.x, maxf(1.0, footer_top - header_bottom))


func refresh() -> void:
	if board_state == null:
		return
	if not _is_hoverable_cell(_hovered_cell_id):
		_hovered_cell_id = ""
	for definition in board_state.level.cells:
		var view: HexCellView = _cell_views.get(definition.id, null)
		if view == null:
			continue
		view.setup(definition, board_state.get_runtime(definition.id), radius - 1.5, radius)
		view.set_intelligence_visible(board_state.is_intelligence_visible(definition))
		view.set_selected(definition.id == board_state.selected_cell_id)
		view.set_hovered(definition.is_editable() and definition.id == _hovered_cell_id)
		var assist_type := _active_assist_type(definition)
		var preview := definition.is_editable() and not view.runtime.solved and definition.id == board_state.selected_cell_id and not view.runtime.candidate_pick.is_empty()
		var known := not definition.is_editable() or view.runtime.solved
		var enabled := not definition.is_black() and (preview or (known and _neighbor_masks_enabled.has(definition.id)))
		# Hidden assists need no geometry. Reuse it until the color or radius changes.
		if enabled and assist_type in CellDefinition.COLOR_TYPES:
			if _overlay_geometry_keys.get(definition.id, "") != assist_type:
				var scope := ClueRules.scope(definition, _grid, assist_type)
				scope.push_front(definition)
				view.scope_overlay.configure(definition, scope, radius, 1.5)
				_overlay_geometry_keys[definition.id] = assist_type
		view.scope_overlay.set_active(enabled, view._brick_color(assist_type))


func play_success(cell_id: String) -> void:
	var view: HexCellView = _cell_views.get(cell_id, null)
	if view != null:
		view.play_success()


func play_error(cell_id: String) -> void:
	var view: HexCellView = _cell_views.get(cell_id, null)
	if view != null:
		view.play_error()


func _unhandled_input(event: InputEvent) -> void:
	if board_state == null or _entrance_active or _exit_active or not visible:
		return
	if event is InputEventMouseMotion:
		var cell_id := _cell_at(event.position)
		if not _is_hoverable_cell(cell_id):
			cell_id = ""
		if cell_id != _hovered_cell_id:
			_hovered_cell_id = cell_id
			if not cell_id.is_empty():
				board_state.focused_cell_id = cell_id
				cell_hovered.emit(cell_id)
			refresh()
	elif event is InputEventMouseButton and event.pressed:
		var cell_id := _cell_at(event.position)
		if cell_id.is_empty() and event.button_index == MOUSE_BUTTON_LEFT:
			board_state.clear_selection()
			refresh()
			get_viewport().set_input_as_handled()
			return
		if not cell_id.is_empty():
			var clicked_definition := board_state.get_definition(cell_id)
			if clicked_definition.is_editable() and not board_state.get_runtime(cell_id).solved:
				cell_clicked.emit(cell_id, event.button_index)
				get_viewport().set_input_as_handled()
				return
			if event.button_index == MOUSE_BUTTON_LEFT and not clicked_definition.is_black():
				if _neighbor_masks_enabled.has(cell_id):
					_neighbor_masks_enabled.erase(cell_id)
				else:
					_neighbor_masks_enabled[cell_id] = true
				board_state.clear_selection()
				refresh()
				get_viewport().set_input_as_handled()
				return
			cell_clicked.emit(cell_id, event.button_index)
			get_viewport().set_input_as_handled()


func _cell_at(global_position: Vector2) -> String:
	for cell_id in _cell_views:
		if _cell_views[cell_id].contains_global_point(global_position):
			return cell_id
	return ""


func _active_assist_type(definition: CellDefinition) -> String:
	if definition.mode == CellDefinition.MODE_CANDIDATE and not board_state.get_runtime(definition.id).solved:
		return board_state.get_runtime(definition.id).candidate_pick
	if board_state.get_runtime(definition.id).solved and not definition.accepted_answer_types.is_empty():
		return board_state.get_runtime(definition.id).candidate_pick
	return definition.effective_type()


func _is_hoverable_cell(cell_id: String) -> bool:
	if board_state == null or cell_id.is_empty() or cell_id == board_state.selected_cell_id:
		return false
	var definition := board_state.get_definition(cell_id)
	var runtime := board_state.get_runtime(cell_id)
	return definition != null and runtime != null and definition.is_editable() and not runtime.solved
