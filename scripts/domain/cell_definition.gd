extends RefCounted
class_name CellDefinition

const MODE_FIXED := "fixed"
const MODE_HIDDEN := "hidden"
const MODE_RED_INPUT := "red_input"
const MODE_CANDIDATE := "candidate"

const TYPE_RED := "red"
const TYPE_BLACK := "black"
const TYPE_WILDCARD := "wildcard"
const TYPE_GREEN := "green"
const TYPE_PURPLE := "purple"
const TYPE_YELLOW := "yellow"
const COLOR_TYPES := [TYPE_RED, TYPE_GREEN, TYPE_PURPLE, TYPE_YELLOW]
const CLUE_TYPES := COLOR_TYPES
const RADIUS_CLUE_TYPES := [TYPE_RED, TYPE_GREEN, TYPE_PURPLE]

var id := ""
var row := 0
var col := 0
var mode := MODE_FIXED
var type := TYPE_RED
var value: Variant = null
var scope_radius := 1
var initially_revealed := false
var candidate_types: Array[String] = []
var accepted_answer_types: Array[String] = []
var answer_type := ""
var answer_value: Variant = null


static func from_dictionary(data: Dictionary) -> CellDefinition:
	var cell := CellDefinition.new()
	cell.id = str(data.get("id", ""))
	cell.row = int(data.get("row", 0))
	cell.col = int(data.get("col", 0))
	cell.mode = str(data.get("mode", MODE_FIXED))
	cell.type = str(data.get("type", TYPE_RED))
	cell.value = data.get("value", null)
	cell.scope_radius = int(data.get("scope_radius", 1))
	cell.initially_revealed = bool(data.get("revealed", false))

	for candidate_type in data.get("candidate_types", []):
		cell.candidate_types.append(str(candidate_type))

	var answer: Dictionary = data.get("answer", {})
	cell.answer_type = str(answer.get("type", ""))
	for accepted in answer.get("accepted_types", []):
		cell.accepted_answer_types.append(str(accepted))
	cell.answer_value = answer.get("value", null)
	return cell


func position_key() -> String:
	return HexCoordinate.key(row, col)


func effective_type() -> String:
	return type if mode == MODE_FIXED else answer_type


func effective_value() -> Variant:
	return answer_value if mode in [MODE_HIDDEN, MODE_RED_INPUT] else value


func is_clue() -> bool:
	return effective_type() in COLOR_TYPES


func is_black() -> bool:
	return effective_type() == TYPE_BLACK


func is_wildcard() -> bool:
	return mode == MODE_HIDDEN and type == TYPE_WILDCARD


func is_editable() -> bool:
	return mode in [MODE_HIDDEN, MODE_RED_INPUT, MODE_CANDIDATE]


static func is_valid_type(tile_type: String) -> bool:
	return tile_type == TYPE_RED or tile_type == TYPE_BLACK or tile_type in CLUE_TYPES
