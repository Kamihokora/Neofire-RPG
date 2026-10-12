class_name TaTransition
extends ColorRect

# AGENT: Screen fade/slide cover. Juice layer, not a page stack.
# INVARIANT: mouse_filter IGNORE when idle. fade_through runs callback at cover.
# Not a registry type — spawn with on(host), same rule as TaDimmer.
# DO NOT: push/pop routes. Do not autoload.

const NODE_NAME := "_TaTransition"


func _init() -> void:
	name = NODE_NAME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	color = Color(0, 0, 0, 0)
	z_index = 128


static func on(host: Control) -> TaTransition:
	if not is_instance_valid(host):
		return null
	var existing := host.get_node_or_null(NODE_NAME)
	if existing is TaTransition:
		return existing as TaTransition
	var overlay := TaTransition.new()
	host.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay


## Fade to cover, run `mid`, fade out. Used when switching looks.
func fade_through(mid: Callable = Callable()) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if TaJuice.is_reduced():
		if mid.is_valid():
			mid.call()
		modulate.a = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	color = Color(0, 0, 0, 1)
	scale = Vector2.ONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	var tween := create_tween()
	var hold := cover_seconds()
	tween.tween_property(self, "modulate:a", 1.0, hold)
	tween.tween_callback(
		func() -> void:
			if mid.is_valid():
				mid.call()
	)
	tween.tween_property(self, "modulate:a", 0.0, hold)
	tween.finished.connect(
		func() -> void:
			mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


## Horizontal wipe cover, then `mid`, then uncover. Not a router.
func wipe_through(mid: Callable = Callable()) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	if TaJuice.is_reduced():
		if mid.is_valid():
			mid.call()
		modulate.a = 0.0
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	color = Color(0, 0, 0, 1)
	modulate.a = 1.0
	pivot_offset = Vector2.ZERO
	scale = Vector2(0, 1)
	var tween := create_tween()
	var hold := cover_seconds()
	tween.tween_property(self, "scale", Vector2.ONE, hold)
	tween.tween_callback(
		func() -> void:
			if mid.is_valid():
				mid.call()
	)
	tween.tween_property(self, "scale:x", 0.0, hold)
	tween.finished.connect(
		func() -> void:
			modulate.a = 0.0
			scale = Vector2.ONE
			mouse_filter = Control.MOUSE_FILTER_IGNORE
	)


func slide_in(control: Control) -> Tween:
	if not is_instance_valid(control):
		return null
	if TaJuice.is_reduced():
		# Show it where the layout put it. Setting position here moved it to x = 0.
		control.modulate.a = 1.0
		return null
	var origin := control.position
	control.position = origin + Vector2(0, TaDefaults.MOTION_SLIDE_PIXELS)
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	var hold := cover_seconds()
	tween.tween_property(control, "position", origin, hold)
	tween.tween_property(control, "modulate:a", 1.0, hold)
	return tween


## Pixel uses the wipe; HD fades. Duration follows the active look.
func through(mid: Callable = Callable()) -> void:
	if TaJuice.pixel_grid:
		wipe_through(mid)
	else:
		fade_through(mid)


func cover_seconds() -> float:
	return TaJuice.open_seconds
