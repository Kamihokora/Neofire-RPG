class_name TaRadial
extends PanelContainer

# AGENT: Radial progress. TextureProgressBar clockwise from 12 o'clock.
# INVARIANT: set_value writes 0–100. Textures come from the active look. The empty
# track meets 3:1 against the fill and is visible on its panel. HD edges are smooth.
# DO NOT: Autoload. Do not own stats.

## Caption plus a radial TextureProgressBar (0–100). set_ring_width makes it a ring;
## set_center_text puts a label in the middle. Color by value: get_bar().tint_progress.

var _col: VBoxContainer
var _caption: Label
var _bar: TextureProgressBar
var _show_caption: bool = true
var _show_chrome: bool = true
var _diameter: int = 0
## Stroke width in px; -1 is the look's ring (a ring, never a pie chart by default).
var _ring: int = -1
var _center: Label


func _init() -> void:
	theme_type_variation = "TaRadial"
	_col = VBoxContainer.new()
	add_child(_col)
	_caption = Label.new()
	_caption.theme_type_variation = "TaCardText"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_caption)
	_bar = TextureProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	_bar.radial_initial_angle = TaDefaults.RADIAL_INITIAL_ANGLE
	_bar.radial_fill_degrees = 360.0
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(_bar)
	_center = Label.new()
	_center.theme_type_variation = "TaCardText"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.visible = false
	_bar.add_child(_center)
	refresh_metrics()


func refresh_metrics() -> void:
	if not is_instance_valid(_bar):
		return
	var look := TaLook.current()
	var size := _diameter
	if size <= 0:
		size = TaLook.metric(TaDefaults.RADIAL_SIZE, TaDefaults.PIXEL_RADIAL_SIZE)
	_bar.custom_minimum_size = Vector2(size, size)
	var smooth := not look.is_pixel()
	var ring := _ring
	if ring < 0:
		ring = TaLook.metric(TaDefaults.RADIAL_RING, TaDefaults.PIXEL_RADIAL_RING)
	_bar.texture_under = _disk(size, _track_color(look), ring, smooth)
	_bar.texture_progress = _disk(size, look.color_accent, ring, smooth)
	if is_instance_valid(_caption):
		_caption.visible = _show_caption
	if _show_chrome:
		remove_theme_stylebox_override("panel")
	else:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())


func get_bar() -> TextureProgressBar:
	return _bar


func set_caption(text: String) -> void:
	_caption.text = text


func set_caption_visible(on: bool) -> void:
	_show_caption = on
	if is_instance_valid(_caption):
		_caption.visible = on


## Pixel size of the ring. 0 uses the look default (64, or 40 in pixel).
func set_diameter(px: int) -> void:
	_diameter = maxi(0, px)
	refresh_metrics()


## False drops the panel fill and border so a small ring can sit on the HUD.
func set_chrome_visible(on: bool) -> void:
	_show_chrome = on
	refresh_metrics()


## Stroke width in px. -1 (the default) is the look's ring; 0 is a filled disk.
func set_ring_width(px: int) -> void:
	_ring = maxi(-1, px)
	refresh_metrics()


## Text in the middle of the ring ("72%", "3:05"). Empty hides it.
func set_center_text(text: String) -> void:
	if is_instance_valid(_center):
		_center.text = text
		_center.visible = not text.is_empty()


func get_center_label() -> Label:
	return _center


func set_value(amount: float) -> void:
	if is_instance_valid(_bar):
		_bar.value = clampf(amount, _bar.min_value, _bar.max_value)


## The empty part of the dial. It must meet 3:1 against the fill (WCAG non-text), so the
## value reads, and then stand out as far as it can from what the dial sits on (the
## panel, or the page when chromeless). 1.10 used the page colour: 1:1 on the panel in
## the 1.x looks, so an empty track was invisible.
func _track_color(look: TaTokens) -> Color:
	var base := TaThemeBuilder.panel_fill(look) if _show_chrome else look.color_bg
	var best := look.color_bg
	var best_seen := -1.0
	var candidates: Array[Color] = [look.color_bg, look.color_disabled_bg, look.color_border]
	for lift in TaDefaults.RADIAL_TRACK_LIFTS:
		candidates.append(base.lerp(look.color_text, lift))
	for c in candidates:
		if TaThemeBuilder.contrast(c, look.color_accent) < TaDefaults.RADIAL_TRACK_MIN_CONTRAST:
			continue
		var seen := TaThemeBuilder.contrast(c, base)
		if seen > best_seen:
			best = c
			best_seen = seen
	return best


## Disk or ring. smooth: coverage-blended edges (HD); Pixel keeps hard integer edges.
func _disk(size: int, fill: Color, ring: int = 0, smooth: bool = false) -> ImageTexture:
	var img := Image.create(maxi(8, size), maxi(8, size), false, Image.FORMAT_RGBA8)
	img.fill(TaDefaults.COLOR_TRANSPARENT)
	var dim := img.get_width()
	var cx := (dim - 1) * 0.5
	var r := cx - 1.0
	var inner := maxf(0.0, r - float(ring)) if ring > 0 else 0.0
	for y in dim:
		for x in dim:
			var d := Vector2(float(x) - cx, float(y) - cx).length()
			var cover := 0.0
			if smooth:
				cover = clampf(r + 0.5 - d, 0.0, 1.0)
				if ring > 0:
					cover = minf(cover, clampf(d - inner + 0.5, 0.0, 1.0))
			elif d <= r and d >= inner:
				cover = 1.0
			if cover > 0.0:
				img.set_pixel(x, y, Color(fill.r, fill.g, fill.b, fill.a * cover))
	return ImageTexture.create_from_image(img)
