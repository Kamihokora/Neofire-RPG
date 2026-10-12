@tool
class_name TaOverlay
extends Control

# AGENT: Full-screen layer base. TaModal and pause.tscn extend it; so can your overlays.
# INVARIANT: Full rect via anchors AND offsets. Hidden and click-through until open().
# open(): dimmer, focus trap, opener remembered, joins TaCancelRouter. close() undoes
# each, in reverse. Esc while open runs handle_cancel(): through the router if the
# tree has one, else here (then tree order decides who hears Esc first).
# DO NOT: Page stack or content layout. Do not autoload.

## Dimmed full-screen layer. Add your panel as a child with z_index 1 or more, then
## open(). Override handle_cancel() for what Esc does (default: close).

signal opened
signal closed

## Veil what is behind while open.
@export var dim: bool = true
## Keep Tab inside while open and hand focus back to the opener on close.
@export var trap_focus: bool = true
## False: Esc does nothing while open (a recap the player must read). Still consumed.
@export var esc_closes: bool = true
## Veil strength for this layer, 0..1. Below 0 uses look.dimmer_alpha. A light veil
## keeps the scene readable (a phone held over the room).
@export_range(-1.0, 1.0, 0.01) var dim_alpha: float = -1.0
## Backdrop blur in px for this layer. Below 0 uses look.dimmer_blur.
@export_range(-1.0, 16.0, 0.5) var dim_blur: float = -1.0
## A click outside your panel does what Esc does (handle_cancel). Off by default.
@export var close_on_outside_click: bool = false
## Play the kit's open and close sounds (TaSfx.muted silences every kit sound).
@export var sounds: bool = true

var _dimmer: TaDimmer
var _open: bool = false
var _opener: WeakRef


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dimmer = TaDimmer.on(self)
	_dimmer.z_index = 0
	_dimmer.gui_input.connect(_on_outside_input)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _open or not event.is_action_pressed("ui_cancel"):
		return
	if TaCancelRouter.find(self) != null:
		return
	get_viewport().set_input_as_handled()
	if esc_closes:
		handle_cancel()


## A click that reached the layer or its veil missed your panel (panels stop clicks).
func _gui_input(event: InputEvent) -> void:
	_on_outside_input(event)


func _on_outside_input(event: InputEvent) -> void:
	if not _open or not close_on_outside_click or Engine.is_editor_hint():
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		handle_cancel()


func is_open() -> bool:
	return _open


## True while open, so pause.tscn leaves Esc alone when there is no router.
func blocks_pause_cancel() -> bool:
	return _open


## True when a kit overlay or TaDialog other than `skip` is open in `from`'s tree
## (anything whose blocks_pause_cancel() is true). "Is a menu up?", router or not.
static func any_open(from: Node, skip: Node = null) -> bool:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return false
	return _scan_open(from.get_tree().root, skip)


static func _scan_open(node: Node, skip: Node) -> bool:
	# TaDialog is a Window, not a CanvasItem: ask it, never cast it and read visible.
	if node != skip and node.has_method("blocks_pause_cancel"):
		if bool(node.call("blocks_pause_cancel")):
			return true
	for child in node.get_children():
		if _scan_open(child, skip):
			return true
	return false


func get_dimmer() -> TaDimmer:
	return _dimmer


func open() -> void:
	if not _open and is_inside_tree():
		# A card left open outside this layer would draw over it (popovers sit at z 90),
		# so it closes first, and hands focus back to its anchor before we note the opener.
		for card in get_tree().get_nodes_in_group(TaPopover.GROUP):
			if not is_ancestor_of(card) and card.has_method("close"):
				card.close()
		var owner_now := get_viewport().gui_get_focus_owner()
		var outside := owner_now != null and not is_ancestor_of(owner_now)
		_opener = weakref(owner_now) if outside else null
		if sounds:
			TaSfx.play_on(self, TaSfx.open())
	_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if dim and is_instance_valid(_dimmer):
		_dimmer.fade_in(dim_alpha, dim_blur)
	if is_inside_tree():
		TaCancelRouter.enter(self, _on_router_cancel)
	set_process_unhandled_input(true)
	_on_opened()
	if trap_focus and is_inside_tree():
		_focus_default()
		TaFocus.trap(self)
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	if sounds and is_inside_tree():
		TaSfx.play_on(get_parent(), TaSfx.close())
	TaFocus.release(self)
	TaCancelRouter.leave(self)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_dimmer):
		_dimmer.fade_out()
	_on_closed()
	var opener := _opener.get_ref() as Control if _opener != null else null
	_opener = null
	if trap_focus and opener != null and opener.is_visible_in_tree():
		opener.grab_focus()
	closed.emit()


## What Esc does while open. Override for confirm/cancel logic. Default: close.
func handle_cancel() -> void:
	close()


## Subclass hook after the layer is shown, before focus moves in.
func _on_opened() -> void:
	pass


## Subclass hook after the layer is hidden, before focus returns.
func _on_closed() -> void:
	pass


## Where focus lands on open. Default: first focusable child.
func _focus_default() -> void:
	TaFocus.focus_first(self)


func _on_router_cancel() -> void:
	if esc_closes:
		handle_cancel()
