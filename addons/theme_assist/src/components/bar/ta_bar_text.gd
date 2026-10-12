@tool
extends Control

# AGENT: The value text of TaBar and TaVBar ("180/480", "72%"). On a horizontal bar it
# sits wholly inside the fill or wholly inside the empty track (the larger part it fits
# in), so it never straddles the fill edge; only a bar too short for either centres it
# across the edge. Drawn twice and clipped at the fill edge: fill ink over the fill, track
# ink over the track, each 4.5:1 on what it sits on. Component layer, internal.
# INVARIANT: A full-rect child of its ProgressBar, drawn above it. The bar's own text
# is made transparent (it still sizes the bar); get_bar().show_percentage still turns
# the percentage on and off. The split follows Godot's own fill maths. Text that
# does not fit across the bar at its widest ("100%") is not drawn, never clipped.
# DO NOT: Outline the text. Outlined page-colour digits read on the fill but turned
# hollow over the empty track (the 1.11 rule).

## Air kept around the text inside its part, as a share of the text's width.
const AIR := 0.1
## A bar this many text widths wide (plus its frame) holds its widest value wholly in
## the fill or the track at any value: the larger part is at least half the bar.
const ROOM := 2.0 * (1.0 + AIR)

## Fixed text ("180/480"). Empty: the bar's percentage, when show_percentage is on.
var text: String = "":
	set(value):
		text = value
		sync()

var _bar: ProgressBar
var _clips: Array[Control] = []
var _labels: Array[Label] = []
var _queued: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# [0] over the fill, [1] over the track.
	for i in 2:
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(clip)
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(label)
		_clips.append(clip)
		_labels.append(label)
	resized.connect(sync)


## Put the text over `bar` (as its child) and hide the bar's own.
func attach(bar: ProgressBar) -> void:
	_bar = bar
	bar.add_child(self)
	var clear := Color(0, 0, 0, 0)
	bar.add_theme_color_override("font_color", clear)
	bar.add_theme_color_override("font_outline_color", clear)
	# Any change to the bar redraws it: value, show_percentage, fill_mode, a new fill.
	bar.draw.connect(_queue_sync)
	sync()


## The text shown now ("" when none).
func get_text() -> String:
	return _labels[0].text


func sync() -> void:
	_queued = false
	if not is_instance_valid(_bar) or _labels.is_empty():
		return
	var shown := text
	var widest := text
	if shown.is_empty() and _bar.show_percentage and not _bar.indeterminate:
		shown = _percent(_bar.get_as_ratio())
		widest = _percent(1.0)
	# Whole or not at all: clipped, "100%" in a slim bar read "10". The widest value
	# decides, so a percentage does not blink out as it climbs.
	if not shown.is_empty() and not _fits(widest):
		shown = ""
	var fill := _fill_rect(size)
	var parts: Array[Rect2] = [fill, _track_rect(size, fill)]
	var spot := _spot(shown, parts)
	var inks := _inks()
	for i in 2:
		var clip := _clips[i]
		clip.position = parts[i].position
		clip.size = parts[i].size
		var label := _labels[i]
		label.text = shown
		label.position = spot.position - parts[i].position
		label.size = spot.size
		if inks.is_empty():
			continue
		# Only when changed: a ticking bar syncs every frame it moves.
		if label.get_theme_color("font_color") != inks[i]:
			label.add_theme_color_override("font_color", inks[i])
		# The look's text shadow only under light ink: under dark ink it smears.
		var dark := TaContrast.luminance(inks[i]) < 0.3
		var quiet := label.has_theme_color_override("font_shadow_color")
		if dark and not quiet:
			label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		elif not dark and quiet:
			label.remove_theme_color_override("font_shadow_color")
		var font := get_theme_font("font", "ProgressBar")
		if label.get_theme_font("font") != font:
			label.add_theme_font_override("font", font)
		var font_size := get_theme_font_size("font_size", "ProgressBar")
		if label.get_theme_font_size("font_size") != font_size:
			label.add_theme_font_size_override("font_size", font_size)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		sync()


func _queue_sync() -> void:
	if not _queued:
		_queued = true
		sync.call_deferred()


## Where the text centres: the larger of fill and track that holds it with a little air
## (horizontal bars), else the whole bar. Off-tree, or a vertical bar: the whole bar.
func _spot(value: String, parts: Array[Rect2]) -> Rect2:
	var whole := Rect2(Vector2.ZERO, size)
	var vertical := _bar.fill_mode == ProgressBar.FILL_TOP_TO_BOTTOM
	vertical = vertical or _bar.fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP
	if value.is_empty() or vertical or not is_inside_tree():
		return whole
	var font := get_theme_font("font", "ProgressBar")
	if font == null:
		return whole
	var wide := font.get_string_size(
			value, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size", "ProgressBar")
	).x
	var air := wide * AIR
	var order: Array[Rect2] = parts.duplicate()
	if order[1].size.x > order[0].size.x:
		order.reverse()
	for part in order:
		if part.size.x >= wide + air:
			return Rect2(part.position.x, 0.0, part.size.x, size.y)
	return whole


## Across the bar inside its frame (the track box's own margins). Off-tree: true.
func _fits(value: String) -> bool:
	if not is_inside_tree():
		return true
	var font := get_theme_font("font", "ProgressBar")
	var font_size := get_theme_font_size("font_size", "ProgressBar")
	if font == null:
		return true
	var track := _bar.get_theme_stylebox("background")
	var frame := track.get_minimum_size().x if track != null else 0.0
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= size.x - frame


## Godot's text: whole percent, cut not rounded, localized when the bar is.
func _percent(ratio: float) -> String:
	var n := str(int(ratio * 100.0))
	if not _bar.localize_numeral_system:
		return n + "%"
	var ts := TextServerManager.get_primary_interface()
	var lang := TranslationServer.get_locale()
	return ts.format_number(n, lang) + ts.percent_sign(lang)


## Where ProgressBar draws its fill (NOTIFICATION_DRAW, 4.4 to 4.7): nothing below
## one pixel of progress, else the progress plus the fill box's own minimum size.
func _fill_rect(area: Vector2) -> Rect2:
	var r := _bar.get_as_ratio()
	var box := _bar.get_theme_stylebox("fill")
	var edge := box.get_minimum_size() if box != null else Vector2.ZERO
	match _bar.fill_mode:
		ProgressBar.FILL_TOP_TO_BOTTOM, ProgressBar.FILL_BOTTOM_TO_TOP:
			var mp := int(edge.y)
			var p := roundi(r * (area.y - mp))
			if p <= 0:
				return Rect2()
			var y := 0.0
			if _bar.fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP:
				y = roundi((1.0 - r) * (area.y - mp))
			return Rect2(0.0, y, area.x, p + mp)
		_:
			var mp := int(edge.x)
			var p := roundi(r * (area.x - mp))
			if p <= 0:
				return Rect2()
			var from_end := ProgressBar.FILL_END_TO_BEGIN
			if _bar.is_layout_rtl():
				from_end = ProgressBar.FILL_BEGIN_TO_END
			var x := 0.0
			if _bar.fill_mode == from_end:
				x = roundi((1.0 - r) * (area.x - mp))
			return Rect2(x, 0.0, p + mp, area.y)


## The rest of the bar: the fill sits at one end, so the track is one rect.
func _track_rect(area: Vector2, fill: Rect2) -> Rect2:
	var whole := Rect2(Vector2.ZERO, area)
	if fill.size.x <= 0.0 or fill.size.y <= 0.0:
		return whole
	if is_equal_approx(fill.size.y, area.y):
		if fill.position.x > 0.0:
			return Rect2(0.0, 0.0, fill.position.x, area.y)
		return Rect2(fill.end.x, 0.0, maxf(area.x - fill.end.x, 0.0), area.y)
	if fill.position.y > 0.0:
		return Rect2(0.0, 0.0, area.x, fill.position.y)
	return Rect2(0.0, fill.end.y, area.x, maxf(area.y - fill.end.y, 0.0))


## [ink over the fill, ink over the track]: the Theme's two bar inks (page colour and
## text colour), whichever reads, pushed to 4.5:1 if neither does. Empty off-tree.
func _inks() -> Array[Color]:
	var out: Array[Color] = []
	if not is_inside_tree():
		return out
	var page := get_theme_color("font_color", "ProgressBar")
	var text_ink := get_theme_color("font_outline_color", "ProgressBar")
	var track := TaContrast.box_fill(_bar.get_theme_stylebox("background"), page)
	var fill := TaContrast.box_fill(_bar.get_theme_stylebox("fill"), track)
	out.append(TaContrast.ink_between(text_ink, page, fill))
	out.append(TaContrast.ink_between(text_ink, page, track))
	return out
