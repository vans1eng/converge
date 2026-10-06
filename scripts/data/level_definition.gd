extends RefCounted
class_name LevelDefinition

var id := ""
var chapter_id := 1
var layout := "odd_r"
var columns := 0
var rows := 0
var infer_yellow := false
var fog_of_war := false
var cells: Array[CellDefinition] = []
var allowed_colors: Array[String] = []
var tutorial: Dictionary = {}


static func from_dictionary(data: Dictionary) -> LevelDefinition:
	var level := LevelDefinition.new()
	level.id = str(data.get("id", ""))
	level.chapter_id = int(data.get("chapter_id", 1))
	level.tutorial = data.get("tutorial", {}).duplicate(true)
	for color in data.get("allowed_colors", []):
		level.allowed_colors.append(str(color))
	var board: Dictionary = data.get("board", {})
	level.layout = str(board.get("layout", "odd_r"))
	level.columns = int(board.get("columns", 0))
	level.rows = int(board.get("rows", 0))
	level.fog_of_war = false
	level.infer_yellow = bool(data.get("infer_yellow", false))

	for cell_data in data.get("cells", []):
		if cell_data is Dictionary:
			level.cells.append(CellDefinition.from_dictionary(cell_data))
	if not data.has("infer_yellow"):
		level.infer_yellow = level.cells.any(func(cell): return cell.mode == CellDefinition.MODE_CANDIDATE and cell.answer_type == CellDefinition.TYPE_YELLOW)
	return level


func create_grid() -> HexGrid:
	# The grid is sparse: positions omitted from JSON remain empty.
	return HexGrid.new(cells, rows, columns)
