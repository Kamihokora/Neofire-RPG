class_name TaPlateButton
extends TextureButton

# AGENT: One baked texture, click, disabled. No theme caption on the art.
# INVARIANT: set_plate writes the TextureButton states. No Label child.
# DO NOT: Theme it as Button. Do not own bets, felt, or a chip rail.

## Plaque or chip art that already has its own words. pressed fires on click.


var _dim_when_disabled: bool = true
var _was_disabled: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	ignore_texture_size = false
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED


func _notification(what: int) -> void:
	# Feel like TaButton: hover, focus, press, and the ticks (here so subclasses keep it).
	if what == NOTIFICATION_READY:
		TaJuice.bind_hover(self)


func _ready() -> void:
	_was_disabled = disabled
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	set_process(true)
	_apply_disabled_look()


## normal is required. Omitted states reuse it. A missing disabled texture dims instead.
func set_plate(
		plate: Texture2D,
		hover: Texture2D = null,
		pressed_plate: Texture2D = null,
		disabled_plate: Texture2D = null
	) -> void:
	texture_normal = plate
	texture_hover = hover if hover != null else plate
	texture_pressed = pressed_plate if pressed_plate != null else plate
	_dim_when_disabled = disabled_plate == null
	texture_disabled = disabled_plate if disabled_plate != null else plate
	_apply_disabled_look()


## Baked art has no focus state, so draw the look's ring or keyboard players are lost.
func _draw() -> void:
	if has_focus():
		var ring := get_theme_stylebox("focus", "Button")
		if ring != null:
			draw_style_box(ring, Rect2(Vector2.ZERO, size))


func _process(_delta: float) -> void:
	if disabled == _was_disabled:
		return
	_was_disabled = disabled
	_apply_disabled_look()


func _apply_disabled_look() -> void:
	modulate.a = TaDefaults.PLATE_DISABLED_ALPHA if disabled and _dim_when_disabled else 1.0
