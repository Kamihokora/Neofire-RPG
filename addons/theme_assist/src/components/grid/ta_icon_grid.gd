class_name TaIconGrid
extends GridContainer

# AGENT: Icon + caption grid. Not inventory slots.
# INVARIANT: Children are Buttons. icon_pressed(index) on click.
# DO NOT: Own loot tables. Do not wrap TaSlot.

## Grid of icon buttons. Distinct from TaSlotGrid (no badges/tooltips).

signal icon_pressed(index: int)

@export var grid_columns: int = TaDefaults.ICON_GRID_COLUMNS:
	set(value):
		grid_columns = maxi(1, value)
		columns = grid_columns
		_rebuild()

@export var cell_count: int = TaDefaults.ICON_GRID_COUNT:
	set(value):
		cell_count = maxi(0, value)
		_rebuild()

var _building: bool = false
var _captions: PackedStringArray = PackedStringArray()
var _icons: Array = []
var _glyphs: PackedStringArray = PackedStringArray()
var _fills: Array = []


func _init() -> void:
	theme_type_variation = "TaIconGrid"
	columns = TaDefaults.ICON_GRID_COLUMNS
	refresh_metrics()
	_rebuild()


func refresh_metrics() -> void:
	var sep := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	add_theme_constant_override("h_separation", sep)
	add_theme_constant_override("v_separation", sep)
	var cell := TaLook.metric(TaDefaults.SLOT_SIZE, TaDefaults.PIXEL_SLOT_SIZE)
	var strip := TaLook.metric(TaDefaults.FONT_SIZE_CAPTION, TaDefaults.PIXEL_FONT_SIZE_CAPTION) + 6
	for i in get_child_count():
		var button := get_child(i) as Button
		if button == null:
			continue
		var extra := 0
		if i < _glyphs.size() and not _glyphs[i].is_empty() and i < _captions.size() and not _captions[i].is_empty():
			extra = strip
		button.custom_minimum_size = Vector2(cell, cell + extra)
		_apply_cell(i)


func get_button(index: int) -> Button:
	if index < 0 or index >= get_child_count():
		return null
	return get_child(index) as Button


func set_item(index: int, texture: Texture2D, caption: String = "") -> void:
	_ensure_store()
	if index < 0 or index >= cell_count:
		return
	_icons[index] = texture
	_glyphs[index] = ""
	_fills[index] = Color(0, 0, 0, 0)
	_captions[index] = caption
	_apply_cell(index)
	refresh_metrics()


## Emoji or one character, optional name under it, optional tile color.
## A transparent fill keeps the theme button. Does not bake a texture.
func set_glyph(index: int, glyph: String, caption: String = "", fill: Color = Color(0, 0, 0, 0)) -> void:
	_ensure_store()
	if index < 0 or index >= cell_count:
		return
	_icons[index] = null
	_glyphs[index] = glyph
	_captions[index] = caption
	_fills[index] = fill
	_apply_cell(index)
	refresh_metrics()


func _ensure_store() -> void:
	while _captions.size() < cell_count:
		_captions.append("")
	while _icons.size() < cell_count:
		_icons.append(null)
	while _glyphs.size() < cell_count:
		_glyphs.append("")
	while _fills.size() < cell_count:
		_fills.append(Color(0, 0, 0, 0))


func _rebuild() -> void:
	if _building:
		return
	_building = true
	columns = grid_columns
	_ensure_store()
	while get_child_count() > cell_count:
		var extra := get_child(get_child_count() - 1)
		remove_child(extra)
		extra.free()
	while get_child_count() < cell_count:
		var button := TaButton.new()
		var index := get_child_count()
		button.pressed.connect(_on_pressed.bind(index))
		add_child(button)
		TaJuice.bind_hover(button)
	for i in mini(cell_count, get_child_count()):
		_apply_cell(i)
	refresh_metrics()
	_building = false


func _apply_cell(index: int) -> void:
	var button := get_button(index)
	if button == null:
		return
	var glyph := _glyphs[index] if index < _glyphs.size() else ""
	var caption := _captions[index] if index < _captions.size() else ""
	var glyph_label := button.get_node_or_null("Glyph") as Label
	var name_label := button.get_node_or_null("Name") as Label
	if glyph.is_empty():
		button.icon = _icons[index] if index < _icons.size() else null
		button.text = caption
		if glyph_label != null:
			glyph_label.visible = false
		if name_label != null:
			name_label.visible = false
		for state in ["normal", "hover", "pressed"]:
			button.remove_theme_stylebox_override(state)
		return
	button.icon = null
	button.text = ""
	if glyph_label == null:
		glyph_label = Label.new()
		glyph_label.name = "Glyph"
		glyph_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph_label.theme_type_variation = "TaTitle"
		glyph_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(glyph_label)
		name_label = Label.new()
		name_label.name = "Name"
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.theme_type_variation = "TaCaption"
		name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		name_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		button.add_child(name_label)
	glyph_label.text = glyph
	glyph_label.visible = true
	name_label.text = caption
	name_label.visible = not caption.is_empty()
	# Keep the big glyph above the caption strip instead of centred behind it.
	var strip := name_label.get_combined_minimum_size().y if name_label.visible else 0.0
	glyph_label.offset_bottom = -strip
	var fill: Color = _fills[index] if index < _fills.size() else Color(0, 0, 0, 0)
	if fill.a <= 0.0:
		for state in ["normal", "hover", "pressed"]:
			button.remove_theme_stylebox_override(state)
		glyph_label.remove_theme_color_override("font_color")
		name_label.remove_theme_color_override("font_color")
		return
	var look := TaLook.current()
	# Your tile colour, our ink: text or page colour, whichever reads on it.
	var ink := TaThemeBuilder.ink_on(look, fill)
	glyph_label.add_theme_color_override("font_color", ink)
	name_label.add_theme_color_override("font_color", ink)
	# The tile in your colour, drawn like a chip in this look (pixel looks stay on grid).
	var box := TaChrome.box(
			TaThemeBuilder.screen(look), TaChrome.Role.CHIP, fill, fill.darkened(0.35), 2
	)
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)


func _on_pressed(index: int) -> void:
	icon_pressed.emit(index)
