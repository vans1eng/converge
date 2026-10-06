extends Node

var _recording := false
var _samples: Array[Dictionary] = []
var _previous := 0
var _draw_start := 0
var _last_draw_ms := 0.0
var _main: Node
var _phase := "selection"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	RenderingServer.frame_pre_draw.connect(func(): _draw_start = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func(): _last_draw_ms = (Time.get_ticks_usec() - _draw_start) / 1000.0)
	_run.call_deferred()


func _on_node_added(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path == "res://scripts/main.gd":
		_main = node
		# Unlock only in memory; never change the user's progress file.
		node._progress._data.set_value("completed", "1-24", true)


func _process(_delta: float) -> void:
	if not _recording:
		return
	assert(not SettingsManager._settings_fonts_warming, "Settings prewarm must not overlap level entry.")
	var now := Time.get_ticks_usec()
	var progress := -1.0
	if is_instance_valid(_main) and _main.is_node_ready():
		_phase = "entrance" if _main.board_controller.board_view._entrance_active else "playing"
		if _phase == "entrance" and _main.board_controller.board_view._entrance_tweens.is_empty():
			_phase = "preparing"
		var view: HexCellView = _main.board_controller.board_view._cell_views.values()[0]
		progress = view.scale.x
	_samples.append({"phase": _phase, "frame_ms": (now - _previous) / 1000.0, "draw_ms": _last_draw_ms, "scale": progress})
	_previous = now


func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Cold-entry test requires real rendering.")
	var home: Control = load("res://scenes/home_page.tscn").instantiate()
	get_tree().root.add_child(home)
	get_tree().current_scene = home
	var deadline := Time.get_ticks_msec() + 10000
	while home.start_button.mouse_filter != Control.MOUSE_FILTER_STOP:
		assert(Time.get_ticks_msec() < deadline, "Home startup timed out.")
		await get_tree().process_frame
	assert(SettingsManager._settings_fonts_ready)
	home._on_start_button_pressed()
	await get_tree().scene_changed
	for run in 2:
		var select: Control = get_tree().current_scene
		while select._is_transitioning:
			await get_tree().process_frame
		select._progress._data.set_value("completed", "1-24", true)
		_phase = "selection"
		_previous = Time.get_ticks_usec()
		_samples.clear()
		_recording = true
		select._open_level("1-25")
		await get_tree().scene_changed
		assert(_main.selected_level == "1-25")
		await _main.board_controller.board_view.entrance_finished
		await get_tree().create_timer(0.15).timeout
		_recording = false
		var file := FileAccess.open("/tmp/converge-cold-entry-%d.json" % run, FileAccess.WRITE)
		file.store_string(JSON.stringify(_samples, "\t"))
		for phase in ["selection", "preparing", "entrance", "playing"]:
			var times: Array[float] = []
			var worst: Dictionary = {}
			for sample in _samples:
				if sample.phase != phase:
					continue
				times.append(sample.frame_ms)
				if worst.is_empty() or sample.frame_ms > worst.frame_ms:
					worst = sample
			times.sort()
			if not times.is_empty():
				print("ENTRY run=%d phase=%s p95=%.2fms worst=%s" % [run, phase, times[int((times.size() - 1) * 0.95)], str(worst)])
		if run == 0:
			get_tree().change_scene_to_file("res://scenes/level_select.tscn")
			await get_tree().scene_changed
	print("PASS: cold launch -> home -> selection -> first level 25, then repeat, without saving progress.")
	get_tree().quit()
