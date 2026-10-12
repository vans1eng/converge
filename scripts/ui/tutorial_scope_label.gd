extends RichTextLabel

# Keep the plain copy separate from the inline image used for rendering.
var copy_text := ""
var scope_icon_enabled := false
var _icon: ImageTexture
var _icon_size := 0
var _ink := Color.TRANSPARENT
var _highlights: Dictionary = {}


func set_highlights(highlights: Dictionary) -> void:
    if _highlights == highlights: return
    _highlights = highlights.duplicate()
    _rebuild()


func _init() -> void:
    fit_content = true
    scroll_active = false
    selection_enabled = false
    autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_theme_stylebox_override("normal", StyleBoxEmpty.new())


func set_copy_text(value: String) -> void:
    if copy_text == value: return
    copy_text = value
    _rebuild()


func configure_scope_icon(enabled: bool, font_size: int, ink: Color) -> void:
    if scope_icon_enabled == enabled and _icon_size == (font_size + 3) * 2 and _ink == ink: return
    scope_icon_enabled = enabled
    _ink = ink
    add_theme_font_size_override("normal_font_size", font_size)
    add_theme_color_override("default_color", ink)
    var icon_size := (font_size + 3) * 2
    if _icon_size != icon_size:
        _icon_size = icon_size
        var center := Vector2.ONE * (icon_size + 2.0) * 0.5
        var paths := ""
        for inset in [0.0, icon_size * 0.1]:
            var points := PackedStringArray()
            for index in 6:
                var point: Vector2 = center + Vector2.from_angle(deg_to_rad(60.0 * index - 30.0)) * (icon_size * 0.5 - inset)
                points.append("%f,%f" % [point.x, point.y])
            paths += '<polygon points="%s"/>' % " ".join(points)
        var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><g fill="none" stroke="white" stroke-width="0.8">%s</g></svg>' % [icon_size + 2, icon_size + 2, paths]
        var image := Image.new()
        image.load_svg_from_string(svg)
        _icon = ImageTexture.create_from_image(image)
    _rebuild()


func _rebuild() -> void:
    clear()
    if scope_icon_enabled and _icon != null:
        # Inline images inherit text opacity; apply the theme's RGB only here.
        add_image(_icon, _icon_size + 2, _icon_size + 2, Color(_ink, 1.0), INLINE_ALIGNMENT_CENTER)
        add_text(" ")
    var cursor := 0
    while cursor < copy_text.length():
        var next := copy_text.length()
        var matched := ""
        for term: String in _highlights:
            var position := copy_text.find(term, cursor)
            if position >= cursor and position < next:
                next = position
                matched = term
        add_text(copy_text.substr(cursor, next - cursor))
        if matched.is_empty(): break
        push_color(_highlights[matched])
        add_text(matched)
        pop()
        cursor = next + matched.length()
