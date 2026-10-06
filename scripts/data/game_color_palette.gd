extends Resource
class_name GameColorPalette

@export_category("Base")
@export var background := Color("2b2b34")
@export var main_text := Color("e8e7ec")
@export var cell_text := Color("2b2b34")

@export_category("Brick colors")
@export var red := Color("ff9297")
@export var orange := Color("ffc28f")
@export var yellow := Color("f6ef86")
@export var green := Color("8fefa8")
@export var cyan := Color("84d9e8")
@export var blue := Color("89b6ea")
@export var purple := Color("aa96ec")
@export var gray := Color("b9bac2")
@export var black := Color("07080a")

@export_category("Brick effects")
@export var cell_shadow := Color("1d1d23")
@export var axis_guide := Color(1.0, 1.0, 1.0, 0.3)
@export var hover_mask := Color(0.0, 0.0, 0.0, 0.18)
