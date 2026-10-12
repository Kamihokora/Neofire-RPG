class_name TaToastHost
extends Control

# AGENT: Placed HUD host that queues TaToast children. Component layer.
# INVARIANT: Not an autoload. Extras queue (or drop the oldest) past max_visible.
# Esc is left alone unless esc_dismisses is true, and then open overlays go first.
# DO NOT: Create a CanvasLayer or singleton. Children are TaToast.

## Place in a HUD. Call show_message. set_corner to avoid overlapping other HUD.
## TOP_CENTER / BOTTOM_CENTER stack a compact strip in the middle of the edge.

const _Toast := preload("res://addons/theme_assist/src/components/toast/ta_toast.gd")

enum Corner {
	TOP_RIGHT,
	TOP_LEFT,
	BOTTOM_RIGHT,
	BOTTOM_LEFT,
	TOP_CENTER,
	BOTTOM_CENTER,
}

enum Overflow {
	QUEUE,
	DROP_OLDEST,
}

var corner: int = Corner.TOP_RIGHT
## Toasts on screen at once. 0 uses TaDefaults.TOAST_MAX_VISIBLE.
@export var max_visible: int = 0
## QUEUE waits for a slot. DROP_OLDEST dismisses the oldest so the new one shows now.
@export var overflow: Overflow = Overflow.QUEUE
## True: a repeat of a toast still on screen restarts its hold instead of stacking.
@export var merge_repeats: bool = false
## Toast width in px. 0 uses the look's (TaDefaults.TOAST_MAX_WIDTH, Pixel 200).
@export var max_width: int = 0:
	set(value):
		max_width = maxi(0, value)
		_apply_anchor()
		for child in get_children():
			if child is TaToast:
				(child as TaToast).set_width(_width())
		_layout_toasts()
## Extra px from the corner: x from the side edge (or right of centre), y from the top
## or bottom edge. Hang toasts under a HUD row with inset = Vector2(0, row_height).
@export var inset: Vector2 = Vector2.ZERO:
	set(value):
		inset = value
		_apply_anchor()
## True: Esc dismisses the front toast. Off by default so Esc reaches your menus.
## Open overlays still come first; with a TaCancelRouter, toasts sit under them.
@export var esc_dismisses: bool = false:
	set(value):
		esc_dismisses = value
		_sync_router()

var _pending_text: PackedStringArray = PackedStringArray()
var _pending_duration: PackedFloat32Array = PackedFloat32Array()
var _pending_tone: PackedInt32Array = PackedInt32Array()
var _pending_tone_name: PackedStringArray = PackedStringArray()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above any dim veil: a toast during a dialog drew under it.
	z_index = TaDefaults.TOAST_Z_INDEX
	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	_apply_anchor()
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_END


func _ready() -> void:
	set_process_unhandled_input(true)
	_apply_anchor()


func _unhandled_input(event: InputEvent) -> void:
	if not esc_dismisses or _toast_count() <= 0:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	# A router orders Esc itself (overlays, then these toasts, then its fallback).
	if TaCancelRouter.find(self) != null or TaOverlay.any_open(self):
		return
	_dismiss_front()
	get_viewport().set_input_as_handled()


## esc_dismisses with a router: sit under every overlay while toasts show.
func _sync_router() -> void:
	if not is_inside_tree():
		return
	if esc_dismisses and _toast_count() > 0:
		TaCancelRouter.enter(self, _on_router_cancel, true)
	else:
		TaCancelRouter.leave(self)


func _on_router_cancel() -> void:
	_dismiss_front()
	_sync_router()


func refresh_metrics() -> void:
	_apply_anchor()


func set_corner(next: int) -> void:
	corner = next
	_apply_anchor()


func _width() -> float:
	if max_width > 0:
		return float(max_width)
	return float(TaLook.metric(TaDefaults.TOAST_MAX_WIDTH, TaDefaults.PIXEL_TOAST_MAX_WIDTH))


func _apply_anchor() -> void:
	var width := _width()
	var m := TaDefaults.TOAST_MARGIN
	var mx := m + inset.x
	var my := m + inset.y
	var left := corner == Corner.TOP_LEFT or corner == Corner.BOTTOM_LEFT
	var center := corner == Corner.TOP_CENTER or corner == Corner.BOTTOM_CENTER
	var top := (
			corner == Corner.TOP_LEFT or corner == Corner.TOP_RIGHT or corner == Corner.TOP_CENTER
	)
	var h_anchor := 0.5 if center else (0.0 if left else 1.0)
	anchor_left = h_anchor
	anchor_right = h_anchor
	anchor_top = 0.0 if top else 1.0
	anchor_bottom = 0.0 if top else 1.0
	if center:
		grow_horizontal = Control.GROW_DIRECTION_BOTH
	else:
		grow_horizontal = (
				Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
		)
	grow_vertical = (
			Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
	)
	if center:
		offset_left = -width * 0.5 + inset.x
		offset_right = width * 0.5 + inset.x
	elif left:
		offset_left = mx
		offset_right = mx + width
	else:
		offset_left = -(width + mx)
		offset_right = -mx
	if top:
		offset_top = my
		offset_bottom = my
	else:
		offset_top = -my
		offset_bottom = -my


func _dismiss_front() -> void:
	for child in get_children():
		var toast := child as TaToast
		if toast != null and not toast.is_closing():
			toast.dismiss()
			return


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_toasts()


## Show a toast. duration < 0 uses the active look's toast_seconds (else TaDefaults).
## tone_name picks a look.tones entry and wins over tone.
func show_message(
		text: String,
		duration: float = -1.0,
		tone: TaBadge.Tone = TaBadge.Tone.DEFAULT,
		tone_name: String = ""
	) -> void:
	if merge_repeats:
		var twin := _visible_with_text(text)
		if twin != null:
			twin.extend(duration)
			return
		if _pending_text.has(text):
			return
	if _toast_count() >= get_max_visible():
		if overflow == Overflow.DROP_OLDEST:
			_drop_oldest()
			_spawn(text, duration, tone, tone_name)
			return
		_pending_text.append(text)
		_pending_duration.append(duration)
		_pending_tone.append(int(tone))
		_pending_tone_name.append(tone_name)
		return
	_spawn(text, duration, tone, tone_name)


func _spawn(
		text: String,
		duration: float,
		tone: TaBadge.Tone = TaBadge.Tone.DEFAULT,
		tone_name: String = ""
	) -> void:
	var toast = _Toast.new()
	toast.text = text
	toast.tone = tone
	toast.tone_name = tone_name
	toast.set_width(_width())
	toast.dismissed.connect(_on_toast_dismissed, CONNECT_ONE_SHOT)
	toast.resized.connect(_layout_toasts)
	add_child(toast)
	toast.present(duration)
	_layout_toasts()
	_sync_router()


func get_max_visible() -> int:
	return max_visible if max_visible > 0 else TaDefaults.TOAST_MAX_VISIBLE


func _visible_with_text(text: String) -> TaToast:
	for child in get_children():
		var toast := child as TaToast
		if toast != null and not toast.is_closing() and toast.text == text:
			return toast
	return null


## Oldest leaves the tree now so the count frees a slot this frame.
func _drop_oldest() -> void:
	for child in get_children():
		var toast := child as TaToast
		if toast != null and not toast.is_closing():
			if toast.dismissed.is_connected(_on_toast_dismissed):
				toast.dismissed.disconnect(_on_toast_dismissed)
			remove_child(toast)
			toast.queue_free()
			_layout_toasts()
			_sync_router()
			return


func _toast_count() -> int:
	var count := 0
	for child in get_children():
		if child is TaToast and not (child as TaToast).is_closing():
			count += 1
	return count


func _layout_toasts() -> void:
	var y := 0.0
	var width := size.x
	if width <= 0.0:
		width = _width()
	for child in get_children():
		if not child is TaToast:
			continue
		var toast := child as TaToast
		var min_size := toast.get_combined_minimum_size()
		toast.size = Vector2(width, min_size.y)
		toast.position = Vector2(0.0, y)
		y += toast.size.y + TaDefaults.TOAST_SEPARATION
	custom_minimum_size = Vector2(_width(), y)


func _on_toast_dismissed() -> void:
	call_deferred("_drain_queue")


func _drain_queue() -> void:
	while (
			not _pending_text.is_empty()
			and _toast_count() < get_max_visible()
	):
		var text := _pending_text[0]
		var hold := _pending_duration[0]
		var tone := TaBadge.Tone.DEFAULT
		if not _pending_tone.is_empty():
			tone = _pending_tone[0] as TaBadge.Tone
			_pending_tone.remove_at(0)
		var named := ""
		if not _pending_tone_name.is_empty():
			named = _pending_tone_name[0]
			_pending_tone_name.remove_at(0)
		_pending_text.remove_at(0)
		_pending_duration.remove_at(0)
		_spawn(text, hold, tone, named)
	_sync_router()
