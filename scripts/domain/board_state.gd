extends RefCounted
class_name BoardState

var level: LevelDefinition
var cells: Dictionary = {}
var mistakes := 0
var elapsed_seconds := 0.0
var selected_cell_id := ""
var focused_cell_id := ""


func _init(level_definition: LevelDefinition = null) -> void:
	if level_definition != null:
		setup(level_definition)


func setup(level_definition: LevelDefinition) -> void:
	level = level_definition
	cells.clear()
	for cell in level.cells:
		cells[cell.id] = CellRuntimeState.new()
	mistakes = 0
	elapsed_seconds = 0.0
	selected_cell_id = ""
	focused_cell_id = ""


func get_runtime(cell_id: String) -> CellRuntimeState:
	return cells.get(cell_id, null)


func get_definition(cell_id: String) -> CellDefinition:
	if level == null:
		return null
	for cell in level.cells:
		if cell.id == cell_id:
			return cell
	return null


func select(cell_id: String) -> void:
	var definition := get_definition(cell_id)
	var runtime := get_runtime(cell_id)
	if definition != null and runtime != null and definition.is_editable() and not runtime.solved:
		selected_cell_id = cell_id
		focused_cell_id = cell_id


func clear_selection() -> void:
	selected_cell_id = ""


func is_complete() -> bool:
	for cell in level.cells:
		if cell.is_editable() and not get_runtime(cell.id).solved:
			return false
	return true


func is_intelligence_visible(cell: CellDefinition) -> bool:
	if not level.fog_of_war:
		return true
	var grid := level.create_grid()
	var visible := {}
	var frontier: Array[CellDefinition] = []
	for source in level.cells:
		if source.initially_revealed or get_runtime(source.id).solved:
			visible[source.id] = true
			frontier.append(source)
	while not frontier.is_empty():
		var source: CellDefinition = frontier.pop_back()
		for neighbor in grid.neighbors(source):
			if visible.has(neighbor.id):
				continue
			visible[neighbor.id] = true
			# A fixed clue is already known once it becomes visible.
			# Unconfirmed editable bricks reveal their own ring only after solving.
			if neighbor.mode == CellDefinition.MODE_FIXED or get_runtime(neighbor.id).solved:
				frontier.append(neighbor)
	return visible.has(cell.id)
