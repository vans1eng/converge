extends Node2D
class_name SettingsFontWarmup

var texts: PackedStringArray = []


func _draw() -> void:
	# Use the root window's canvas/DPI, matching the visible settings controls.
	# An opaque background covers this canvas while the glyphs are prepared.
	for font_size in SettingsManager.SETTINGS_FONT_SIZES:
		for text in texts:
			for offset in [0.0, 0.25, 0.5, 0.75]:
				draw_string(SettingsManager.UI_FONT, Vector2(8.0 + offset, 64.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
