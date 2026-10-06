extends Control

const TILE_TYPES := ["red", "green", "purple", "yellow", "black"]
const ANSWER_TYPES := ["red", "green", "purple", "yellow"]

var columns := 6
var rows := 4
var level_id := "NEW LEVEL"
var cells: Dictionary = {}
var selected := Vector2i(-1, -1)
var updating := false
var loaded_metadata: Dictionary = {}

var canvas: HexEditorCanvas
var columns_spin: SpinBox
var rows_spin: SpinBox
var id_edit: LineEdit
var mode_select: OptionButton
var type_select: OptionButton
var value_spin: SpinBox
var scope_radius_spin: SpinBox
var candidate_a: OptionButton
var candidate_b: OptionButton
var answer_select: OptionButton
var folder_edit: LineEdit
var filename_edit: LineEdit
var status: Label
var selected_label: Label
var type_row: VBoxContainer
var candidate_row: VBoxContainer
var answer_row: VBoxContainer
var delete_button: Button
var open_dialog: FileDialog
var board_title: Label
var stats: Label
var source_label: Label
var theme_button: Button
var side_panels: Array[PanelContainer] = []
var editor_buttons: Array[Button] = []
var section_labels: Array[Label] = []
var type_chips: GridContainer
var answer_chips: GridContainer
var mode_buttons: Array[Button] = []


func _ready() -> void:
	_build_ui()
	_resize_board()
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(self)
		theme_manager.theme_changed.connect(func(_dark): _apply_editor_theme())
	_apply_editor_theme()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_QUOTELEFT:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/home_page.tscn")


func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var left := _panel(root, "关卡配置", 250)
	id_edit = _line(left, "关卡 ID", level_id)
	var dimensions := HBoxContainer.new()
	dimensions.add_theme_constant_override("separation", 10)
	left.add_child(dimensions)
	var row_fields := VBoxContainer.new()
	row_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dimensions.add_child(row_fields)
	rows_spin = _spin(row_fields, "行数（高）", rows, 1, 30)
	var col_fields := VBoxContainer.new()
	col_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dimensions.add_child(col_fields)
	columns_spin = _spin(col_fields, "列数（宽）", columns, 1, 30)
	_hint(left, "缩小尺寸会裁掉超出范围的格子；新增格子为空，点击后创建砖块。")
	_heading(left, "统计")
	stats = _hint(left, "")
	_heading(left, "操作说明")
	_hint(left, "点击空格创建砖块。\n点击已有砖块，在右侧配置。\n候选砖保留当前候选类型规则。\n线索数值在导出时自动计算。\n作用圈数沿用当前规则。\n` 返回主菜单。")
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_button(left, "清空所有砖块", func(): cells.clear(); selected = Vector2i(-1, -1); _reset_properties(); _refresh())

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 8)
	root.add_child(middle)
	var toolbar_margin := MarginContainer.new()
	toolbar_margin.add_theme_constant_override("margin_top", 16)
	middle.add_child(toolbar_margin)
	var toolbar := HBoxContainer.new()
	toolbar.alignment = BoxContainer.ALIGNMENT_CENTER
	toolbar.add_theme_constant_override("separation", 8)
	toolbar_margin.add_child(toolbar)
	_button(toolbar, "新建", func(): cells.clear(); selected = Vector2i(-1, -1); loaded_metadata.clear(); level_id = "NEW LEVEL"; id_edit.text = level_id; source_label.text = ""; folder_edit.text = "user://levels"; filename_edit.text = "new_level.json"; _reset_properties(); _refresh(); status.text = "已新建关卡")
	_button(toolbar, "打开", _open_level_dialog)
	_button(toolbar, "导出 JSON", _export_json, true)
	theme_button = _button(toolbar, "", func(): ThemeManager.set_dark(not ThemeManager.is_dark))
	board_title = Label.new()
	board_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_title.add_theme_font_size_override("font_size", 24)
	middle.add_child(board_title)
	source_label = _hint(middle, "")
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	canvas = HexEditorCanvas.new()
	canvas.custom_minimum_size = Vector2(240, 200)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.cell_selected.connect(_select_cell)
	middle.add_child(canvas)
	var status_margin := MarginContainer.new()
	for edge in ["left", "right", "bottom"]:
		status_margin.add_theme_constant_override("margin_" + edge, 14)
	middle.add_child(status_margin)
	status = _hint(status_margin, "点击格子进行配置 · 打开可读取现有 JSON 关卡")
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var right := _panel(root, "砖块配置", 270)
	selected_label = _hint(right, "在棋盘上点击一个格子进行配置。")
	selected_label.name = "SelectedLabel"
	mode_select = _option(right, "模式", ["fixed", "candidate"])
	mode_select.hide()
	var mode_bar := HBoxContainer.new()
	mode_bar.add_theme_constant_override("separation", 4)
	mode_select.get_parent().add_child(mode_bar)
	for index in 2:
		var mode_button := _button(mode_bar, "固定" if index == 0 else "候选", func(): mode_select.select(index); _apply_properties())
		mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mode_button.toggle_mode = true
		mode_buttons.append(mode_button)
	type_row = _field(right, "砖块类型")
	type_row.name = "TypeRow"
	type_select = OptionButton.new()
	type_row.add_child(type_select)
	_fill_options(type_select, TILE_TYPES)
	type_select.hide()
	type_chips = _chips(type_row, type_select, TILE_TYPES)
	value_spin = _spin(right, "数值（导出自动计算）", 1, 0, 999)
	scope_radius_spin = _spin(right, "作用圈数", 1, 1, 30)
	candidate_row = _field(right, "候选类型")
	candidate_row.name = "CandidateRow"
	candidate_a = OptionButton.new()
	candidate_row.add_child(candidate_a)
	candidate_b = OptionButton.new()
	candidate_row.add_child(candidate_b)
	_fill_options(candidate_a, ["红绿", "红绿紫", "红绿紫黄"])
	candidate_b.hide()
	answer_row = _field(right, "确定答案")
	answer_row.name = "AnswerRow"
	answer_select = OptionButton.new()
	answer_row.add_child(answer_select)
	_fill_options(answer_select, ANSWER_TYPES)
	answer_select.hide()
	answer_chips = _chips(answer_row, answer_select, ANSWER_TYPES)
	delete_button = _button(right, "删除当前砖块", _delete_selected_cell)
	_heading(right, "导出设置")
	folder_edit = _line(right, "保存路径", "user://levels")
	filename_edit = _line(right, "文件名", "new_level.json")
	_hint(right, "导出前按现有规则计算线索，并校验关卡。")
	open_dialog = FileDialog.new()
	open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_dialog.access = FileDialog.ACCESS_RESOURCES
	open_dialog.filters = PackedStringArray(["*.json ; JSON 关卡文件"])
	open_dialog.file_selected.connect(_load_level_file)
	add_child(open_dialog)
	columns_spin.value_changed.connect(func(_v): _resize_board())
	rows_spin.value_changed.connect(func(_v): _resize_board())
	id_edit.text_changed.connect(func(text): level_id = text; _refresh())
	for control in [mode_select, type_select, candidate_a, candidate_b, answer_select]:
		control.item_selected.connect(func(_index): _apply_properties())
	value_spin.value_changed.connect(func(_v): _apply_properties())
	scope_radius_spin.value_changed.connect(func(_v): _apply_properties())
	_reset_properties()


func _panel(parent: Container, title_text: String, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	parent.add_child(panel)
	side_panels.append(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	_heading(content, title_text)
	return content


func _heading(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_constant_override("outline_size", 0)
	parent.add_child(label)
	section_labels.append(label)


func _hint(parent: Container, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	parent.add_child(label)
	return label


func _field(parent: Container, label_text: String) -> VBoxContainer:
	var field := VBoxContainer.new()
	field.add_theme_constant_override("separation", 4)
	parent.add_child(field)
	_hint(field, label_text)
	return field


func _line(parent: Container, label_text: String, text_value: String) -> LineEdit:
	var field := _field(parent, label_text)
	var edit := LineEdit.new()
	edit.text = text_value
	field.add_child(edit)
	return edit


func _spin(parent: Container, label_text: String, value: float, minimum: float, maximum: float) -> SpinBox:
	var field := _field(parent, label_text)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = 1
	spin.value = value
	field.add_child(spin)
	return spin


func _option(parent: Container, label_text: String, items: Array) -> OptionButton:
	var field := _field(parent, label_text)
	var option := OptionButton.new()
	field.add_child(option)
	_fill_options(option, items)
	return option


func _button(parent: Container, text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.set_meta("custom_hover_style", true)
	button.set_meta("editor_primary", primary)
	button.pressed.connect(action)
	button.mouse_entered.connect(func(): AudioManager.play_ui_hover())
	button.pressed.connect(AudioManager.play_ui_click)
	parent.add_child(button)
	editor_buttons.append(button)
	return button


func _style(bg: Color, border: Color, radius: int, horizontal := 8, vertical := 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _apply_editor_theme() -> void:
	var dark := ThemeManager.is_dark
	var bg := Color("2B2B34" if dark else "F3F0E8")
	var side := Color("2B2B34" if dark else "EEEADF")
	var border := Color("3A3A45" if dark else "E2DCCE")
	var text := Color("EEEEEE" if dark else "2B2B34")
	var muted := Color("AAAAAA" if dark else "7A756B")
	var input := Color("34343E" if dark else "F8F6F0")
	var button_bg := Color("45454F" if dark else "E2DCCE")
	var editor_theme := Theme.new()
	editor_theme.default_font = preload("res://assets/fonts/MiSans-Light.ttf")
	editor_theme.default_font_size = 13
	editor_theme.set_color("font_color", "Label", muted)
	for control in ["LineEdit", "OptionButton", "Button"]:
		editor_theme.set_color("font_color", control, text)
		editor_theme.set_color("font_hover_color", control, text)
		editor_theme.set_color("font_pressed_color", control, text)
		editor_theme.set_color("font_focus_color", control, text)
		for state in ["normal", "hover", "pressed", "disabled"]:
			editor_theme.set_stylebox(state, control, _style(input, border, 6))
		editor_theme.set_stylebox("focus", control, _style(Color(0, 0, 0, 0), text, 6))
		editor_theme.set_font_size("font_size", control, 13)
	editor_theme.set_stylebox("panel", "PopupMenu", _style(input, border, 6))
	editor_theme.set_stylebox("hover", "PopupMenu", _style(button_bg, border, 4))
	editor_theme.set_color("font_color", "PopupMenu", text)
	editor_theme.set_color("font_hover_color", "PopupMenu", text)
	editor_theme.set_color("caret_color", "LineEdit", text)
	theme = editor_theme
	for label in section_labels + [board_title]:
		label.add_theme_color_override("font_color", text)
	for index in side_panels.size():
		var panel_style := _style(side, border, 0, 18, 20)
		panel_style.set_border_width_all(0)
		if index == 0: panel_style.border_width_right = 1
		else: panel_style.border_width_left = 1
		side_panels[index].add_theme_stylebox_override("panel", panel_style)
	for button in editor_buttons:
		var primary := bool(button.get_meta("editor_primary"))
		var fill := text if primary else button_bg
		var ink := bg if primary else text
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, _style(fill.lightened(0.06) if state == "hover" else fill, border, 20, 16, 7))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, ink)
		button.add_theme_color_override("font_disabled_color", Color(ink, 0.4))
		if button.toggle_mode:
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_stylebox_override(state, _style(button_bg, text if state == "pressed" else border, 8, 8, 6))
		if button.has_meta("chip_type"):
			var color: Color = canvas._brick_color(str(button.get_meta("chip_type")))
			for state in ["normal", "hover", "pressed"]:
				button.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", ThemeManager.get_palette().cell_text)
				button.add_theme_stylebox_override(state, _style(color.lightened(0.08) if state == "hover" else color, text if state == "pressed" else color, 8, 8, 9))
	theme_button.text = "浅色" if dark else "暗色"
	canvas.queue_redraw()


func _chips(parent: Container, option: OptionButton, items: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var names := {"red": "红色", "green": "绿色", "purple": "紫色", "yellow": "黄色", "black": "黑色"}
	for index in items.size():
		var tile_type := str(items[index])
		var button := _button(grid, names.get(tile_type, tile_type), func(): option.select(index); _apply_properties())
		button.set_meta("chip_type", tile_type)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
	return grid


func _sync_chips(grid: GridContainer, option: OptionButton) -> void:
	for index in grid.get_child_count():
		var button := grid.get_child(index) as Button
		button.visible = index < option.item_count
		button.set_pressed_no_signal(index == option.selected)


func _reset_properties() -> void:
	selected_label.text = "在棋盘上点击一个格子进行配置。"
	delete_button.disabled = true
	for control in [mode_select, value_spin, scope_radius_spin]:
		control.get_parent().hide()
	for field in [type_row, candidate_row, answer_row]:
		field.hide()


func _fill_options(option: OptionButton, items: Array) -> void:
	for item in items: option.add_item(str(item))


func _resize_board() -> void:
	columns = int(columns_spin.value)
	rows = int(rows_spin.value)
	for key in cells.keys():
		var parts := str(key).split(":")
		if int(parts[0]) >= rows or int(parts[1]) >= columns: cells.erase(key)
	if selected.y >= rows or selected.x >= columns: selected = Vector2i(-1, -1)
	_refresh()


func _select_cell(row: int, col: int) -> void:
	selected = Vector2i(col, row)
	var key := _key(row, col)
	if not cells.has(key): cells[key] = _default_cell(row, col)
	_show_properties()
	_refresh()


func _default_cell(row: int, col: int) -> Dictionary:
	return {"id": "r%dc%d" % [row, col], "row": row, "col": col, "mode": "fixed", "type": "red", "value": 0}


func _show_properties() -> void:
	mode_select.get_parent().show()
	value_spin.get_parent().show()
	updating = true
	var cell: Dictionary = cells.get(_key(selected.y, selected.x), {})
	selected_label.text = "已选：第 %d 行，第 %d 列" % [selected.y + 1, selected.x + 1]
	delete_button.disabled = cell.is_empty()
	_select_text(mode_select, str(cell.get("mode", "fixed")))
	_select_text(type_select, str(cell.get("type", "red")))
	value_spin.value = float(cell.get("value", cell.get("answer", {}).get("value", 1)))
	scope_radius_spin.value = float(cell.get("scope_radius", 1))
	var candidates: Array = cell.get("candidate_types", ["red", "green", "purple"])
	candidate_a.select(2 if "yellow" in candidates else 1 if "purple" in candidates else 0)
	var mode := str(cell.get("mode", "fixed"))
	var answer_items: Array = candidates if mode == "candidate" else []
	answer_select.clear()
	_fill_options(answer_select, answer_items)
	_select_text(answer_select, str(cell.get("answer", {}).get("type", answer_items[0] if not answer_items.is_empty() else "")))
	type_row.visible = mode == "fixed"
	scope_radius_spin.get_parent().visible = mode == "candidate" or str(cell.get("type", "red")) in CellDefinition.RADIUS_CLUE_TYPES
	candidate_row.visible = mode == "candidate"
	answer_row.visible = mode == "candidate"
	_sync_chips(type_chips, type_select)
	_sync_chips(answer_chips, answer_select)
	for index in mode_buttons.size(): mode_buttons[index].set_pressed_no_signal(index == mode_select.selected)
	updating = false


func _select_text(option: OptionButton, wanted: String) -> void:
	for index in option.item_count:
		if option.get_item_text(index) == wanted: option.select(index); return


func _apply_properties() -> void:
	if updating or selected.x < 0: return
	var row := selected.y; var col := selected.x
	var mode := mode_select.get_item_text(mode_select.selected)
	var cell := _default_cell(row, col)
	cell.mode = mode
	if mode == "fixed":
		cell.type = type_select.get_item_text(type_select.selected)
		cell.value = int(value_spin.value) if cell.type != "black" else null
		if cell.type in CellDefinition.RADIUS_CLUE_TYPES:
			cell.scope_radius = int(scope_radius_spin.value)
	else:
		cell.type = "neutral"
		cell.scope_radius = int(scope_radius_spin.value)
		cell.candidate_types = ["red", "green"]
		if candidate_a.selected >= 1: cell.candidate_types.append("purple")
		if candidate_a.selected == 2 and cell.scope_radius == 1:
			cell.candidate_types.append("yellow")
		var picked := answer_select.get_item_text(answer_select.selected) if answer_select.selected >= 0 else "red"
		cell.answer = {"type": picked if picked in cell.candidate_types else "red"}
		cell.value = int(value_spin.value)
		var original: Dictionary = cells.get(_key(row, col), {})
		if cell.candidate_types == ["red", "green"] and original.get("answer", {}).has("accepted_types"):
			cell.answer.accepted_types = original.answer.accepted_types.duplicate()
	cells[_key(row, col)] = cell
	_show_properties()
	_refresh()


func _refresh() -> void:
	if canvas != null: canvas.configure(columns, rows, cells, selected)
	if board_title != null: board_title.text = "LEVEL - " + level_id
	if stats != null:
		var candidates := 0
		for cell in cells.values():
			if cell.get("mode", "fixed") == "candidate": candidates += 1
		stats.text = "砖块 %d · 固定 %d\n候选砖 %d · 空格 %d" % [cells.size(), cells.size() - candidates, candidates, rows * columns - cells.size()]
	if selected.x < 0 and mode_select != null: _reset_properties()


func _key(row: int, col: int) -> String: return "%d:%d" % [row, col]


func _export_json() -> void:
	var filename := filename_edit.text.strip_edges()
	if filename.is_empty(): filename = "new_level.json"
	if not filename.ends_with(".json"): filename += ".json"
	var folder := folder_edit.text.strip_edges()
	if folder.is_empty(): folder = "user://levels"
	if not folder.ends_with("/"): folder += "/"
	var absolute_folder := ProjectSettings.globalize_path(folder) if folder.begins_with("res://") or folder.begins_with("user://") else folder
	var error := DirAccess.make_dir_recursive_absolute(absolute_folder)
	if error != OK: status.text = "无法创建路径：%s" % folder; return
	var data := loaded_metadata.duplicate(true)
	data.erase("name")
	data.id = level_id
	data.board = {"layout": "odd_r", "columns": columns, "rows": rows}
	data.cells = []
	for row in rows:
		for col in columns:
			var cell: Dictionary = cells.get(_key(row, col), {})
			if not cell.is_empty(): data.cells.append(cell)
	var level := LevelDefinition.from_dictionary(data)
	ClueRules.compute_values(level)
	data.infer_yellow = level.infer_yellow
	for index in level.cells.size():
		data.cells[index].value = level.cells[index].value
		if level.cells[index].mode == "candidate":
			var candidates: Array = Array(level.allowed_colors) if not level.allowed_colors.is_empty() else data.cells[index].get("candidate_types", ["red", "green", "purple"])
			if level.infer_yellow and level.cells[index].scope_radius == 1 and "yellow" not in candidates:
				candidates.append("yellow")
			data.cells[index].candidate_types = candidates
	level = LevelDefinition.from_dictionary(data)
	var validator := LevelValidator.new()
	if not validator.validate(level):
		status.text = "无法导出：" + "\n".join(validator.issues)
		return
	var path := folder + filename
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: status.text = "无法写入：%s" % path; return
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.close()
	LevelRepository.invalidate_catalog()
	status.text = "已导出：%s" % path


func _delete_selected_cell() -> void:
	if selected.x < 0:
		return
	cells.erase(_key(selected.y, selected.x))
	selected_label.text = "已删除：第 %d 行，第 %d 列" % [selected.y + 1, selected.x + 1]
	delete_button.disabled = true
	_reset_properties()
	_refresh()


func _open_level_dialog() -> void:
	open_dialog.current_dir = "res://resources/levels"
	open_dialog.popup_centered_ratio(0.72)


func _load_level_file(path: String) -> void:
	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK or not (json.data is Dictionary):
		status.text = "无法读取关卡 JSON：%s" % json.get_error_message()
		return
	var data: Dictionary = json.data
	loaded_metadata = data.duplicate(true)
	loaded_metadata.erase("cells")
	loaded_metadata.erase("board")
	var board: Dictionary = data.get("board", {})
	var new_columns := int(board.get("columns", 0))
	var new_rows := int(board.get("rows", 0))
	if new_columns < 1 or new_rows < 1:
		status.text = "关卡缺少有效的行列设置"
		return
	updating = true
	columns_spin.value = new_columns
	rows_spin.value = new_rows
	id_edit.text = str(data.get("id", ""))
	level_id = id_edit.text
	updating = false
	columns = new_columns
	rows = new_rows
	cells.clear()
	for raw_cell in data.get("cells", []):
		if not raw_cell is Dictionary:
			continue
		var cell: Dictionary = raw_cell.duplicate(true)
		var row := int(cell.get("row", -1))
		var col := int(cell.get("col", -1))
		if row >= 0 and row < rows and col >= 0 and col < columns:
			cells[_key(row, col)] = cell
	selected = Vector2i(-1, -1)
	folder_edit.text = path.get_base_dir() + "/"
	filename_edit.text = path.get_file()
	selected_label.text = "已打开：%s" % path.get_file()
	delete_button.disabled = true
	source_label.text = path.get_file()
	_refresh()
	status.text = "已打开，可直接修改后导出：%s" % path
