class_name TaVignette
extends Control

# AGENT: Edge hit flash. Not a full-screen wash.
# INVARIANT: mouse_filter IGNORE. flash() pulses four edge bands that fade inward (a smooth
# ramp on vector looks, three whole steps on pixel looks). Bands run the full edge, so
# the corners, where two fades meet, are the darkest part, as in a lens vignette. A band
# is never deeper than half the short side (a bright stripe through the middle).
# DO NOT: Autoload. Do not own player HP.

## Full-rect overlay. Edges only; center stays clear.

## Where each band's ramp starts and ends (outer edge to inner), in texture space.
const _FILLS := [
	[Vector2(0.5, 0.0), Vector2(0.5, 1.0)],
	[Vector2(0.5, 1.0), Vector2(0.5, 0.0)],
	[Vector2(0.0, 0.5), Vector2(1.0, 0.5)],
	[Vector2(1.0, 0.5), Vector2(0.0, 0.5)],
]

var _edges: Array[TextureRect] = []
var _paint_id: int = 0
var _stepped: bool = false


func _init() -> void:
	theme_type_variation = "TaVignette"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	for i in 4:
		var edge := TextureRect.new()
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(edge)
		_edges.append(edge)
	_ramp(TaLook.uses_pixel())
	_layout_edges()
	_paint(0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_edges()
	elif what == NOTIFICATION_THEME_CHANGED:
		if TaLook.uses_pixel() != _stepped:
			_ramp(not _stepped)
		_layout_edges()


func hold(amount: float = TaDefaults.VIGNETTE_HOLD) -> void:
	_paint_id += 1
	_layout_edges()
	_paint(clampf(amount, 0.0, 1.0))


func flash(amount: float = 1.0) -> void:
	_paint_id += 1
	var id := _paint_id
	var peak := clampf(amount, 0.0, 1.0)
	_paint(peak)
	if TaJuice.is_reduced():
		# No fade, but the hit still shows for the open time.
		if is_inside_tree():
			get_tree().create_timer(TaJuice.open_seconds).timeout.connect(
				func() -> void:
					if is_instance_valid(self) and _paint_id == id:
						_paint(0.0)
			)
		else:
			_paint(0.0)
		return
	var tween := create_tween()
	tween.tween_method(_paint, peak, 0.0, TaJuice.open_seconds)


## The inward fade each band carries: white, tinted by _paint through self_modulate.
func _ramp(stepped: bool) -> void:
	_stepped = stepped
	var stops: Array = TaDefaults.PIXEL_VIGNETTE_RAMP if stepped else TaDefaults.VIGNETTE_RAMP
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(stops.map(func(s: Array) -> float: return s[0]))
	gradient.colors = PackedColorArray(
			stops.map(func(s: Array) -> Color: return Color(1, 1, 1, s[1]))
	)
	if stepped:
		gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	for i in _edges.size():
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.width = TaDefaults.VIGNETTE_RAMP_TEXELS
		tex.height = TaDefaults.VIGNETTE_RAMP_TEXELS
		tex.fill_from = _FILLS[i][0]
		tex.fill_to = _FILLS[i][1]
		_edges[i].texture = tex
		_edges[i].texture_filter = (
				CanvasItem.TEXTURE_FILTER_NEAREST if stepped else CanvasItem.TEXTURE_FILTER_LINEAR
		)


func _layout_edges() -> void:
	var w := size.x
	var h := size.y
	var t := float(TaLook.metric(TaDefaults.VIGNETTE_EDGE, TaDefaults.PIXEL_VIGNETTE_EDGE))
	# No deeper than half the short side: overlapping bands doubled up into a bright
	# stripe through the middle, the opposite of a vignette.
	t = minf(t, minf(w, h) * 0.5)
	if _edges.size() < 4:
		return
	_edges[0].position = Vector2.ZERO
	_edges[0].size = Vector2(w, t)
	_edges[1].position = Vector2(0, h - t)
	_edges[1].size = Vector2(w, t)
	_edges[2].position = Vector2.ZERO
	_edges[2].size = Vector2(t, h)
	_edges[3].position = Vector2(w - t, 0)
	_edges[3].size = Vector2(t, h)


func _paint(amount: float) -> void:
	var look := TaLook.current()
	var base: Color = look.color_danger
	base.a = TaDefaults.VIGNETTE_ALPHA * clampf(amount, 0.0, 1.0)
	for edge in _edges:
		edge.self_modulate = base
