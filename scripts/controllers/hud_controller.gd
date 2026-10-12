extends Node
class_name HudController

@export var title_label_path: NodePath
@export var status_label_path: NodePath

@onready var title_label: Label = get_node_or_null(title_label_path)
@onready var status_label: RichTextLabel = get_node_or_null(status_label_path)


var chapter_tutorial: Control


func show_board_state(state: BoardState, update_tutorial := true) -> void:
	if state == null:
		return
	if chapter_tutorial == null:
		chapter_tutorial = preload("res://scripts/ui/chapter_tutorial.gd").new()
		chapter_tutorial.name = "ChapterTutorial"
		add_child(chapter_tutorial)
	if update_tutorial:
		chapter_tutorial.show_state(state)
	if title_label != null:
		title_label.text = state.level.id.replace("-", " - ")
	var hint := get_node_or_null("VBoxContainer/Control/TutorialHint") as Label
	if hint != null:
		hint.text = str(state.level.tutorial.get("hint_key", ""))
	if status_label != null:
		var palette: GameColorPalette = ThemeManager.get_palette()
		var colors := {"red": palette.red, "green": palette.green, "purple": palette.purple, "yellow": palette.yellow}
		var segments: PackedStringArray = []
		for type in CellDefinition.ANSWER_TYPES:
			if not state.level.allowed_colors.is_empty() and type not in state.level.allowed_colors:
				continue
			var total := 0
			var confirmed := 0
			for cell in state.level.cells:
				if cell.effective_type() == type:
					total += 1
					if cell.mode == CellDefinition.MODE_FIXED or state.get_runtime(cell.id).solved:
						confirmed += 1
			segments.append("[color=#%s]%s %d/%d[/color]" % [colors[type].to_html(false), tr("COLOR_" + type.to_upper()), confirmed, total])
		if bool(state.level.tutorial.get("practice", false)):
			segments = PackedStringArray()
		status_label.text = "[center]" + " · ".join(segments) + "[/center]"
		var mistakes_label := get_node_or_null("MistakesLabel") as Label
		if mistakes_label != null:
			mistakes_label.text = tr("HUD_MISTAKES") % state.mistakes
