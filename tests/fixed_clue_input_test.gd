extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var validator := LevelValidator.new()
	var level := LevelLoader.new().load_file("res://resources/levels/2-5.json")
	assert(validator.validate(level), str(validator.issues))
	var state := BoardState.new(level)
	for cell in level.cells:
		if cell.effective_type() in ["purple", "yellow"]:
			state.select(cell.id)
			assert(state.selected_cell_id.is_empty())
			assert(not AnswerVerifier.verify(cell, state.get_runtime(cell.id)).ok)
	var fixed: CellDefinition
	for cell in level.cells:
		if cell.effective_type() == "yellow": fixed = cell; break
	fixed.mode = CellDefinition.MODE_CANDIDATE
	fixed.answer_type = "yellow"
	fixed.candidate_types = ["red", "green", "yellow"]
	assert(not validator.validate(level))
	level = LevelLoader.new().load_file("res://resources/levels/2-5.json")
	level.infer_yellow = true
	assert(not validator.validate(level))
	var editor = load("res://scenes/level_editor.tscn").instantiate()
	add_child(editor)
	assert(editor.candidate_a.item_count == 1 and editor.candidate_a.disabled)
	editor._select_cell(0, 0)
	editor.mode_select.select(1)
	editor._apply_properties()
	assert(editor.cells["0:0"].candidate_types == ["red", "green"])
	assert(editor.answer_select.item_count == 2)
	assert(editor.answer_chips.get_child_count() == 2)
	editor.mode_select.select(0)
	editor.type_select.select(3) # Fixed yellow remains authorable, including r2.
	editor.scope_radius_spin.value = 2
	editor._apply_properties()
	assert(editor.cells["0:0"].type == "yellow" and editor.cells["0:0"].scope_radius == 2)
	editor.queue_free()
	await get_tree().process_frame
	print("PASS: fixed purple/yellow cannot be answered; invalid inference rejected; editor exposes only red/green answers and supports fixed yellow r2.")
	get_tree().quit()
