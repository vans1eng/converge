extends Node2D

var selected_level := "1-1"
var LEVEL_IDS: Array[String] = LevelRepository.get_playable_level_ids()
var _progress := PlayerProgress.new()

@onready var level_controller: LevelController = $LevelController
@onready var board_controller: BoardController = $BoardController
@onready var input_controller: InputController = $InputController
@onready var hud_controller: HudController = $CanvasLayer/HUD
@onready var pause_menu: PauseMenu = $CanvasLayer/PauseMenu
@onready var level_complete: LevelComplete = $CanvasLayer/LevelComplete
@onready var guide_button: Button = $CanvasLayer/HUD/GuideButton
@onready var legend_panel: PanelContainer = $CanvasLayer/HUD/LegendPanel

var current_level_index := 0
var waiting_for_next_level := false
var _timer_running := false
var _hud_entrance_duration := 0.2


func _ready() -> void:
	legend_panel.hide()
	guide_button.pressed.connect(_toggle_legend)
	guide_button.mouse_entered.connect(AudioManager.play_ui_hover)
	guide_button.pressed.connect(AudioManager.play_ui_click)
	level_complete.continue_requested.connect(_advance_after_completion)
	level_complete.back_requested.connect(_return_home_after_completion)
	SettingsManager.settings_changed.connect(_queue_legend_size_update)
	# HUD is above the board; only theme its controls, so its background stays transparent.
	# Keep level loading independent from the optional theme autoload.
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(hud_controller, false)
		theme_manager.apply_to(pause_menu, false)
		theme_manager.theme_changed.connect(_apply_palette)
		_apply_palette(theme_manager.is_dark)
	selected_level = str(get_tree().get_meta("selected_level", "1-1"))
	if not _progress.is_unlocked(selected_level):
		selected_level = LEVEL_IDS[0]
	current_level_index = maxi(0, LEVEL_IDS.find(selected_level))

	level_controller.level_loaded.connect(hud_controller.show_board_state)
	level_controller.level_loaded.connect(_update_legend_features)
	board_controller.board_changed.connect(hud_controller.show_board_state)
	level_controller.load_failed.connect(_on_level_load_failed)
	level_controller.level_completed.connect(_on_level_completed)
	board_controller.board_view.entrance_finished.connect(_on_board_entrance_finished)
	board_controller.board_view.entrance_started.connect(_on_board_entrance_started)
	_load_current_level()
	_queue_legend_size_update()


func _toggle_legend() -> void:
	legend_panel.visible = not legend_panel.visible
	if legend_panel.visible:
		_queue_legend_size_update()


func _update_legend_features(state: BoardState) -> void:
	var features := LevelRepository.get_introduced_features(state.level)
	var legend := $CanvasLayer/HUD/LegendPanel/Legend
	var rows := {"Red": "red", "Green": "green", "Purple": "purple", "Yellow": "yellow", "Black": "black", "Radius2": "r2", "Radius3": "r3"}
	for entry in rows:
		legend.get_node(entry).visible = features.has(rows[entry])
	legend.get_node("Black/Label").text = "LEGEND_BLACK_RAYS" if features.has("yellow") else "LEGEND_BLACK"
	_queue_legend_size_update()


func _queue_legend_size_update() -> void:
	call_deferred("_fit_legend_panel")


func _fit_legend_panel() -> void:
	legend_panel.reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_ESCAPE:
		pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if OS.has_feature("editor") and event is InputEventKey and event.is_pressed() and not event.is_echo() and event.keycode == KEY_QUOTELEFT:
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file("res://scenes/level_editor.tscn")


func _advance_after_completion() -> void:
	if not waiting_for_next_level:
		return
	waiting_for_next_level = false
	if current_level_index + 1 >= LEVEL_IDS.size():
		ThemeManager.set_buttons_interactive(self, false)
	await level_complete.fade_out()
	if current_level_index + 1 < LEVEL_IDS.size():
		current_level_index += 1
		_load_current_level(true)
	else:
		get_tree().change_scene_to_file("res://scenes/home_page.tscn")


func _return_home_after_completion() -> void:
	if not waiting_for_next_level:
		return
	waiting_for_next_level = false
	ThemeManager.set_buttons_interactive(self, false)
	await level_complete.fade_out()
	get_tree().change_scene_to_file("res://scenes/home_page.tscn")


func _load_current_level(fade_hud := false) -> void:
	if current_level_index < 0 or current_level_index >= LEVEL_IDS.size():
		push_error("Level index %d is outside the %d available levels." % [current_level_index, LEVEL_IDS.size()])
		return
	waiting_for_next_level = false
	get_tree().set_meta("selected_chapter", int(LEVEL_IDS[current_level_index].get_slice("-", 0)))
	_timer_running = false
	level_complete.hide()
	hud_controller.show()
	hud_controller.modulate.a = 0.0
	_hud_entrance_duration = 0.32 if fade_hud else 0.2
	input_controller.set_gameplay_input_enabled(false)
	_timer_running = level_controller.load_level(LEVEL_IDS[current_level_index])


func _on_board_entrance_started() -> void:
	create_tween().tween_property(hud_controller, "modulate:a", 1.0, _hud_entrance_duration).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if not _timer_running or get_tree().paused or level_controller.board_state == null:
		return
	level_controller.board_state.elapsed_seconds += delta
	hud_controller.show_elapsed_time(level_controller.board_state.elapsed_seconds)


func _on_board_entrance_finished() -> void:
	input_controller.set_gameplay_input_enabled(true)


func _on_level_completed() -> void:
	_timer_running = false
	var state := level_controller.board_state
	_progress.complete_level(LEVEL_IDS[current_level_index], state.elapsed_seconds, state.mistakes)
	input_controller.set_gameplay_input_enabled(false)
	_show_completion_sequence()


func _show_completion_sequence() -> void:
	# Let the final brick finish its success pop before the board recedes.
	await get_tree().create_timer(0.32).timeout
	board_controller.board_view.play_exit_wave()
	await board_controller.board_view.exit_finished
	var hud_fade := create_tween()
	hud_fade.tween_property(hud_controller, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	await hud_fade.finished
	hud_controller.hide()
	var state := level_controller.board_state
	level_complete.show_result(LEVEL_IDS[current_level_index], state.elapsed_seconds, state.mistakes, current_level_index + 1 < LEVEL_IDS.size())
	waiting_for_next_level = true


func _on_level_load_failed(message: String) -> void:
	push_error(message)


func _apply_palette(_is_dark_theme: bool) -> void:
	var theme_manager := get_node_or_null("/root/ThemeManager")
	if theme_manager != null:
		theme_manager.apply_to(hud_controller, false)
	var palette: GameColorPalette = theme_manager.get_palette() if theme_manager != null else preload("res://resources/themes/dark_palette.tres")
	var legend_colors := {
		"Red": palette.red,
		"Yellow": palette.yellow,
		"Green": palette.green,
		"Purple": palette.purple,
	}
	var panel_style := StyleBoxFlat.new()
	var panel_color := palette.background.lerp(palette.black, 0.35 if theme_manager != null and theme_manager.is_dark else 0.05)
	panel_color.a = 0.94
	panel_style.bg_color = panel_color
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 12.0
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	legend_panel.add_theme_stylebox_override("panel", panel_style)
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = palette.black
	swatch_style.border_color = palette.main_text
	swatch_style.border_width_left = 1
	swatch_style.border_width_top = 1
	swatch_style.border_width_right = 1
	swatch_style.border_width_bottom = 1
	$CanvasLayer/HUD/LegendPanel/Legend/Black/Swatch.add_theme_stylebox_override("panel", swatch_style)
	$CanvasLayer/HUD/TimerLabel.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/VBoxContainer/LevelTitle.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/VBoxContainer/Control/TutorialHint.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/VBoxContainer/StatusMessage.add_theme_color_override("default_color", palette.main_text)
	var guide_style := StyleBoxFlat.new()
	guide_style.bg_color = Color.TRANSPARENT
	guide_style.border_color = Color(palette.main_text.r, palette.main_text.g, palette.main_text.b, 0.55)
	guide_style.border_width_left = 2
	guide_style.border_width_top = 2
	guide_style.border_width_right = 2
	guide_style.border_width_bottom = 2
	guide_style.corner_radius_top_left = 17
	guide_style.corner_radius_top_right = 17
	guide_style.corner_radius_bottom_right = 17
	guide_style.corner_radius_bottom_left = 17
	var guide_hover_style := guide_style.duplicate() as StyleBoxFlat
	guide_hover_style.border_color = palette.main_text
	guide_button.add_theme_stylebox_override("normal", guide_style)
	guide_button.add_theme_stylebox_override("hover", guide_hover_style)
	guide_button.add_theme_stylebox_override("pressed", guide_style)
	guide_button.add_theme_color_override("font_color", palette.main_text)
	guide_button.add_theme_color_override("font_hover_color", palette.main_text)
	guide_button.add_theme_color_override("font_pressed_color", palette.main_text)
	guide_button.add_theme_color_override("font_hover_pressed_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/Title.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/Scope.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/Radius2.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/Radius3.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/InputHelp.add_theme_color_override("font_color", palette.main_text)
	$CanvasLayer/HUD/LegendPanel/Legend/Black/Label.add_theme_color_override("font_color", palette.main_text)
	for name in legend_colors:
		$CanvasLayer/HUD/LegendPanel/Legend.get_node(name).add_theme_color_override("font_color", legend_colors[name])
	_queue_legend_size_update()
