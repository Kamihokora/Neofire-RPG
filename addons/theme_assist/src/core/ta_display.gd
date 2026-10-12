@tool
class_name TaDisplay
extends Object

# AGENT: The display fit and the pixel framebuffer policy. Display fit: every look is
# drawn for a 1080 px tall canvas; vector_scale() and art_scale() size it for the real
# canvas (Steam Deck to 4K), never below 9 px glyphs, and watch() rebuilds the kit's
# Themes when the window crosses a step (TaLook.refit). Framebuffer: PIXEL looks with
# sync_display get a canvas / art-scale viewport, integer stretch, nearest filter.
# INVARIANT: Entering Pixel stashes the window. Leaving Pixel restores it.
# A VECTOR sync never forces 1920x1080. _fit_control only full-rects the
# scene root (nested HUD keeps anchors).
# DO NOT: Autoload. Do not persist ProjectSettings.

const PIXEL_SIZE := Vector2i(640, 360)
const HD_SIZE := Vector2i(1920, 1080)

static var pixel_active: bool = false
## Tests and capture tools: above 0, the display is this many 1080 px heights tall on a
## 1:1 canvas (0.741 a Steam Deck, 2 native 4K). 0 reads the real window.
static var factor_override: float = 0.0

static var _stashed: bool = false
static var _stash_size: Vector2i = HD_SIZE
static var _stash_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
static var _stash_aspect: Window.ContentScaleAspect = Window.CONTENT_SCALE_ASPECT_EXPAND
static var _stash_stretch: Window.ContentScaleStretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
static var _stash_filter: Viewport.DefaultCanvasItemTextureFilter = (
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
)
static var _stash_snap_t: bool = false
static var _stash_snap_v: bool = false
static var _stash_factor: float = 1.0
static var _watching: bool = false
static var _check_queued: bool = false


static func is_pixel() -> bool:
	return pixel_active


static func cell_size() -> int:
	if pixel_active:
		return TaDefaults.PIXEL_SLOT_SIZE
	return TaDefaults.SLOT_SIZE


static func sync_window(window: Window, look: TaTokens) -> void:
	if not is_instance_valid(window):
		return
	if look != null and look.is_pixel():
		_stash_if_needed(window)
		_apply_pixel(window, framebuffer_size(look))
	else:
		_apply_hd(window)


static func sync_from(control: Control, look: TaTokens) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var win := control.get_window()
	if win == null:
		var vp := control.get_viewport()
		if vp is Window:
			win = vp as Window
	sync_window(win, look)
	if is_instance_valid(control) and win != null:
		_fit_control(control, _canvas_size(win))


static func _stash_if_needed(window: Window) -> void:
	if _stashed:
		return
	_stashed = true
	_stash_size = window.content_scale_size
	_stash_mode = window.content_scale_mode
	_stash_aspect = window.content_scale_aspect
	_stash_stretch = window.content_scale_stretch
	_stash_filter = window.canvas_item_default_texture_filter
	_stash_snap_t = window.snap_2d_transforms_to_pixel
	_stash_snap_v = window.snap_2d_vertices_to_pixel
	_stash_factor = window.content_scale_factor


## The art-resolution window for a PIXEL look: the project canvas divided by the look's
## art scale on this display.
static func framebuffer_size(look: TaTokens) -> Vector2i:
	var s := art_scale(look) if look != null else 1
	var canvas := project_canvas()
	return Vector2i(canvas.x / s, canvas.y / s)


## The project's base canvas (Project Settings → Display → Window → Viewport size).
static func project_canvas() -> Vector2i:
	return Vector2i(
			int(ProjectSettings.get_setting("display/window/size/viewport_width", HD_SIZE.x)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", HD_SIZE.y))
	)


## How big a VECTOR look draws on this display: canvas height over 1080, times
## look.ui_scale, never below the size where its caption keeps 9 px glyphs on screen.
## Steps of 1/8. A canvas_items stretch already scales the canvas, so a 1080 project
## shown on 4K stays at 1; a native 4K canvas draws at 2.
static func vector_scale(look: TaTokens) -> float:
	var c := _canvas()
	var raw := c.x / TaDefaults.REFERENCE_HEIGHT * maxf(look.ui_scale, 0.1)
	var cap := maxf(1.0, float(look.font_size_caption) * TaDefaults.CAP_HEIGHT)
	var legible := TaDefaults.MIN_GLYPH_PX / cap / c.y
	var steps := maxf(raw, legible) / TaDefaults.SCALE_STEP
	return ceilf(steps - 0.001) * TaDefaults.SCALE_STEP


## Screen px per art px for a PIXEL look on this display: pixel_scale (drawn for 1080 px)
## times the canvas factor and look.ui_scale, a whole number, never below the scale where
## its caption face keeps 9 px glyphs. Pixel 3 is 2 on a Steam Deck and 6 at 4K. 1 inside
## a pixel framebuffer, where the window scales.
static func art_scale(look: TaTokens) -> int:
	if pixel_active:
		return 1
	var c := _canvas()
	var raw := c.x / TaDefaults.REFERENCE_HEIGHT * maxf(look.ui_scale, 0.1)
	var cap := float(TaPixelFont.cap_height(_caption_face(look)))
	if cap <= 0.0:
		cap = maxf(1.0, float(look.font_size_caption) * TaDefaults.CAP_HEIGHT)
	var legible := ceili(TaDefaults.MIN_GLYPH_PX / cap / c.y - 0.001)
	var fitted := roundi(float(maxi(1, look.pixel_scale)) * raw)
	return clampi(maxi(legible, fitted), 1, TaDefaults.ART_SCALE_MAX)


## The fit a look gets on this display, as text: the Theme meta TaLook.refit compares.
static func fit_key(look: TaTokens) -> String:
	if look.is_pixel():
		return "art %d" % art_scale(look)
	return "px %.3f" % vector_scale(look)


## Follow the main window. When a resize moves the bound look across a scale step, every
## kit Theme is rebuilt for it (TaLook.refit). Also refits once now, for a saved theme made
## in the editor at the reference size. Idempotent; a no-op in the editor and headless.
static func watch() -> void:
	if _watching or not _live():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_watching = true
	tree.root.size_changed.connect(_queue_check)
	_queue_check()


static func _queue_check() -> void:
	if _check_queued:
		return
	_check_queued = true
	_check.call_deferred()


static func _check() -> void:
	_check_queued = false
	TaLook.refit()


## True in a running game with a real window (not the editor, not headless).
static func _live() -> bool:
	return not Engine.is_editor_hint() and DisplayServer.get_name() != "headless"


## (canvas height, screen px per canvas unit) of the main window.
static func _canvas() -> Vector2:
	if factor_override > 0.0:
		return Vector2(TaDefaults.REFERENCE_HEIGHT * factor_override, 1.0)
	if not _live():
		return Vector2(TaDefaults.REFERENCE_HEIGHT, 1.0)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return Vector2(TaDefaults.REFERENCE_HEIGHT, 1.0)
	var canvas_h := tree.root.get_visible_rect().size.y
	var window_h := float(tree.root.size.y)
	if canvas_h < 1.0 or window_h < 1.0:
		return Vector2(TaDefaults.REFERENCE_HEIGHT, 1.0)
	return Vector2(canvas_h, window_h / canvas_h)


static func _caption_face(look: TaTokens) -> Font:
	return look.face_caption if look.face_caption != null else look.face


static func _apply_pixel(window: Window, size: Vector2i) -> void:
	pixel_active = true
	TaJuice.pixel_grid = true
	window.content_scale_factor = 1.0
	window.content_scale_size = size
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	window.canvas_item_default_texture_filter = (
			Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	)
	window.snap_2d_transforms_to_pixel = true
	window.snap_2d_vertices_to_pixel = true


static func _apply_hd(window: Window) -> void:
	pixel_active = false
	TaJuice.pixel_grid = false
	if not _stashed:
		return
	window.content_scale_size = _stash_size
	window.content_scale_mode = _stash_mode
	window.content_scale_aspect = _stash_aspect
	window.content_scale_stretch = _stash_stretch
	window.canvas_item_default_texture_filter = _stash_filter
	window.snap_2d_transforms_to_pixel = _stash_snap_t
	window.snap_2d_vertices_to_pixel = _stash_snap_v
	window.content_scale_factor = _stash_factor
	_stashed = false


static func _canvas_size(window: Window) -> Vector2:
	var base := Vector2(window.content_scale_size)
	if base.x < 1.0 or base.y < 1.0:
		base = Vector2(PIXEL_SIZE) if pixel_active else Vector2(project_canvas())
	if not pixel_active:
		var vis_hd := window.get_visible_rect().size
		if vis_hd.x >= 1.0 and vis_hd.y >= 1.0:
			return vis_hd
		return base
	var vis := window.get_visible_rect().size
	# Viewport stretch uses canvas coords. If we got window pixels, ignore them.
	if vis.x > base.x * 2.0 and vis.y > base.y * 2.0:
		return base
	if vis.x >= base.x and vis.y >= base.y:
		return vis
	return base


static func _fit_control(control: Control, sz: Vector2) -> void:
	if not is_instance_valid(control) or sz.x < 1.0 or sz.y < 1.0:
		return
	if not _is_scene_root(control):
		return
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BOTH


static func _is_scene_root(control: Control) -> bool:
	if not control.is_inside_tree():
		return false
	var tree := control.get_tree()
	return tree != null and control == tree.current_scene
