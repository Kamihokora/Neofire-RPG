class_name TaWorldAttach
extends Node3D

# AGENT: Puts any kit Control into a 3D scene, wearing the active look: the in-world half
# of the HUD (the canvas half is scenes/hud.tscn). Component layer.
# INVARIANT: The content is an ordinary kit Control (TaBar, TaChip, a Label...) under a
# themed holder, so the world and the canvas show the same component. BILLBOARD draws
# it into a SubViewport on a Sprite3D that faces the camera; SCREEN pins it to the
# canvas over this node's 3D point. Follows the bound look (TaLook.bind refreshes every
# attach). Display only: no clicks in the world.
# DO NOT: Build a second widget family. Own the camera. Take input.

## Where the HUD sits over a 3D object: a nameplate, a health bar, a pickup label.
## Add it as a child of the object, move it up with position, then add_content(bar).

enum Mode {
	## A camera-facing quad in the world: scales with distance, hides behind walls.
	BILLBOARD,
	## On the HUD canvas over the 3D point: same size at any distance, always crisp.
	SCREEN,
}

## The group TaLook.bind() refreshes.
const GROUP := &"ta_world_attach"

@export var mode: Mode = Mode.BILLBOARD:
	set(value):
		mode = value
		if is_inside_tree():
			_mount()
## World units per pixel of content at the 1080 reference (BILLBOARD). 0.005 = 200 px per
## meter. On a bigger display the content has more pixels and the quad keeps its size.
@export var pixel_size: float = TaDefaults.WORLD_PIXEL_SIZE:
	set(value):
		pixel_size = value
		if is_instance_valid(_sprite):
			_sprite.pixel_size = value
## Draw over geometry (nameplates through walls) instead of hiding behind it.
@export var on_top: bool = false:
	set(value):
		on_top = value
		if is_instance_valid(_sprite):
			_sprite.no_depth_test = value
## Fade out past this distance from the camera, in meters. 0 never fades.
@export var max_distance: float = 0.0

var _holder: MarginContainer
var _viewport: SubViewport
var _sprite: Sprite3D
var _layer: CanvasLayer
var _look: TaTokens
static var _themes: Dictionary = {}


func _init() -> void:
	add_to_group(GROUP)
	_holder = MarginContainer.new()
	_holder.name = "Content"
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.minimum_size_changed.connect(_fit)


func _ready() -> void:
	refresh_look()
	_mount()


func _notification(what: int) -> void:
	# An attach freed before it ever mounted still owns its holder.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_holder):
		if _holder.get_parent() == null:
			_holder.free()


## Put `control` in the world over this node. Several stack in a column.
func add_content(control: Control) -> void:
	if not is_instance_valid(control):
		return
	if _holder.get_child_count() == 0:
		_holder.add_child(control)
	else:
		_column().add_child(control)
	_fit()


## The themed holder your content sits in (a MarginContainer sized to it).
func get_content_root() -> Control:
	return _holder


## Wear `look` instead of the bound look. Null follows the bound look again.
func set_look(look: TaTokens) -> void:
	_look = look
	refresh_look()


## Rebuild the holder's Theme from the look (TaLook.bind calls this on every attach).
func refresh_look() -> void:
	var look := _look if _look != null else TaLook.current()
	_holder.theme = _theme_for(look)
	TaLook.refresh_tree(_holder)
	if is_instance_valid(_sprite):
		_sprite.texture_filter = (
				BaseMaterial3D.TEXTURE_FILTER_NEAREST if look.is_pixel()
				else BaseMaterial3D.TEXTURE_FILTER_LINEAR
		)
	_fit()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var point := global_position
	var fade := 1.0
	if max_distance > 0.0:
		var far := camera.global_position.distance_to(point)
		fade = clampf((max_distance - far) / (max_distance * 0.15), 0.0, 1.0)
	if mode == Mode.BILLBOARD:
		if is_instance_valid(_sprite):
			_sprite.modulate.a = fade
			_sprite.pixel_size = _readable_size(camera)
		return
	if not is_instance_valid(_layer):
		return
	if camera.is_position_behind(point) or fade <= 0.0:
		_holder.visible = false
		return
	_holder.visible = true
	_holder.modulate.a = fade
	var at := camera.unproject_position(point)
	# Bottom centre sits on the point, like a label hung over a head.
	_holder.position = (at - Vector2(_holder.size.x * 0.5, _holder.size.y)).round()


func _mount() -> void:
	if _holder.get_parent() != null:
		_holder.get_parent().remove_child(_holder)
	for node in [_sprite, _viewport, _layer]:
		if is_instance_valid(node):
			node.queue_free()
	_sprite = null
	_viewport = null
	_layer = null
	if mode == Mode.SCREEN:
		_layer = CanvasLayer.new()
		_layer.name = "Screen"
		add_child(_layer, false, Node.INTERNAL_MODE_FRONT)
		_layer.add_child(_holder)
	else:
		_viewport = SubViewport.new()
		_viewport.name = "Board"
		_viewport.transparent_bg = true
		_viewport.disable_3d = true
		_viewport.gui_disable_input = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport, false, Node.INTERNAL_MODE_FRONT)
		_viewport.add_child(_holder)
		_sprite = Sprite3D.new()
		_sprite.name = "Billboard"
		_sprite.texture = _viewport.get_texture()
		_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_sprite.shaded = false
		_sprite.double_sided = true
		_sprite.transparent = true
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_sprite.pixel_size = pixel_size
		_sprite.no_depth_test = on_top
		_sprite.offset = Vector2(0, 0)
		_sprite.centered = true
		add_child(_sprite, false, Node.INTERNAL_MODE_FRONT)
	refresh_look()


## World units per content pixel: pixel_size over the display scale (the content was
## built bigger for a bigger display), raised when the camera is so far that a content
## pixel would shrink below WORLD_MIN_TEXT_SCALE screen pixels (1 on pixel looks).
func _readable_size(camera: Camera3D) -> float:
	var look := _look if _look != null else TaLook.current()
	var k := TaDisplay.vector_scale(look)
	if look.is_pixel():
		k = float(TaDisplay.art_scale(look)) / float(maxi(1, look.pixel_scale))
	var base := pixel_size / maxf(k, 0.01)
	# Screen pixels, not canvas units: a 1080 canvas stretched onto an 800-line window
	# shows its content at two thirds the size (Flat plates fell to 7 px text there).
	var vp := get_viewport()
	var view := vp.get_visible_rect().size.y * absf(vp.get_screen_transform().get_scale().y)
	var span := 0.0
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		span = camera.size
	else:
		var far := camera.global_position.distance_to(global_position)
		span = 2.0 * far * tan(deg_to_rad(camera.fov) * 0.5)
	if span <= 0.0 or view <= 0.0:
		return base
	var on_screen := base * view / span
	return base if on_screen >= least_scale(look) else base * least_scale(look) / on_screen


## Fewest screen pixels per content pixel a BILLBOARD draws at: whole pixels on pixel
## looks (their faces break up when shrunk); on vector looks, caption capitals stay at
## TaDefaults.MIN_GLYPH_PX, the floor every kit text keeps.
static func least_scale(look: TaTokens) -> float:
	if look.is_pixel():
		return 1.0
	var cap := look.font_size_caption * TaDisplay.vector_scale(look) * TaDefaults.CAP_HEIGHT
	return maxf(TaDefaults.WORLD_MIN_TEXT_SCALE, TaDefaults.MIN_GLYPH_PX / maxf(cap, 1.0))


func _fit() -> void:
	if not is_instance_valid(_holder):
		return
	var want := _holder.get_combined_minimum_size().ceil()
	_holder.size = want
	if is_instance_valid(_viewport):
		_viewport.size = Vector2i(maxi(1, int(want.x)), maxi(1, int(want.y)))
		if is_instance_valid(_sprite):
			# The quad's bottom sits on this node, like the SCREEN mode.
			_sprite.offset = Vector2(0, want.y * 0.5)


func _column() -> VBoxContainer:
	var first := _holder.get_child(0)
	if first is VBoxContainer and first.has_meta("ta_world_column"):
		return first as VBoxContainer
	var col := VBoxContainer.new()
	col.set_meta("ta_world_column", true)
	col.add_theme_constant_override("separation", TaLook.gap() / 2)
	_holder.remove_child(first)
	_holder.add_child(col)
	col.add_child(first)
	return col


## One Theme per look object, shared by every attach that wears it.
static func _theme_for(look: TaTokens) -> Theme:
	var key := look.get_instance_id()
	var cached: Array = _themes.get(key, [])
	var stamp := _stamp(look)
	if cached.size() == 2 and cached[0] == stamp:
		return cached[1]
	var theme := TaThemeBuilder.make(look)
	_themes[key] = [stamp, theme]
	return theme


## A cheap fingerprint of the look and the display fit, so a live edit or a window
## change rebuilds the shared Theme.
static func _stamp(look: TaTokens) -> int:
	var parts := [TaDisplay.fit_key(look)]
	for prop in look.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_STORAGE:
			var value: Variant = look.get(String(prop["name"]))
			parts.append(value.get_instance_id() if value is Object else value)
	return hash(parts)
