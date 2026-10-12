class_name TaPopover
extends PanelContainer

# AGENT: Anchored card beside a control. In the layout tree (not a Window), so it
# can sit under HUD layers and join the focus graph. Component layer.
# INVARIANT: Hidden until open(anchor). Placed on the side with room, inside the safe
# rect (the viewport minus safe_insets); follows the anchor; scrolls when taller than
# its room. A click elsewhere closes it and still reaches what was clicked. Esc
# closes it (through a TaCancelRouter when one is placed) and focus goes back to the
# anchor. A kit overlay opening outside it closes it (it draws at z 90, above them).
# Not modal: no dimmer, no focus trap.
# DO NOT: Dim, trap focus, or eat outside clicks. Not a tooltip: no hover timer.

## A card beside a control: a plant card by its pot, an item card by its slot.
## Put your controls in get_content(), then open(anchor). Esc, close(), or a click
## elsewhere closes it. safe_insets keeps it off your HUD rows and rails.

signal opened
signal closed

## Every card is in this group; a TaOverlay opening closes the open ones outside it.
const GROUP := &"ta_popover"

enum Placement {
	AUTO,
	RIGHT,
	LEFT,
	BELOW,
	ABOVE,
}

## Where the card goes. AUTO: right, else left, else below, else above: the first
## with room for the whole card.
@export var side: Placement = Placement.AUTO
## px kept clear at the edges of the view: x left, y top, z right, w bottom.
@export var safe_insets: Vector4 = Vector4(
		TaDefaults.POPOVER_SAFE_INSET, TaDefaults.POPOVER_SAFE_INSET,
		TaDefaults.POPOVER_SAFE_INSET, TaDefaults.POPOVER_SAFE_INSET
)
## Draw a small arrow pointing at the anchor.
@export var notch: bool = true
## Move keyboard focus into the card on open (a card opened from the keyboard).
@export var focus_content: bool = false
## Play the kit's open and close sounds.
@export var sounds: bool = true

## Controls (or global Rect2s) an AUTO card should not cover: the anchor's neighbours,
## so the other pots in a row stay clickable. Among the sides with room for the whole
## card, AUTO takes the one covering least of them (ties keep right, left, below, above).
## The anchor and hidden or freed Controls are skipped, so the whole row can be passed.
var keep_clear: Array = []

var _scroll: ScrollContainer
var _content: VBoxContainer
var _anchor: WeakRef
var _open: bool = false
var _placed: Placement = Placement.RIGHT
## This open's choice: at_side if given, else side. side itself is never rewritten.
var _open_side: Placement = Placement.AUTO
var _anchor_rect: Rect2 = Rect2()


func _init() -> void:
	theme_type_variation = "TaPopover"
	add_to_group(GROUP)
	top_level = true
	visible = false
	z_index = TaDefaults.POPOVER_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The card is the surface: no second well inside it (an opaque slab on glass).
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.minimum_size_changed.connect(_queue_place)
	_scroll.add_child(_content)
	set_process(false)
	set_process_input(false)


func get_content() -> VBoxContainer:
	return _content


func get_anchor_control() -> Control:
	return _anchor.get_ref() as Control if _anchor != null else null


func is_open() -> bool:
	return _open


## Which side the card went to last (never AUTO).
func get_placed_side() -> Placement:
	return _placed


## True while open, so pause.tscn leaves Esc alone when there is no router.
func blocks_pause_cancel() -> bool:
	return _open


## Show beside `anchor`. at_side overrides `side` for this open only.
func open(anchor: Control, at_side: int = -1) -> void:
	if not is_instance_valid(anchor) or not is_inside_tree():
		return
	_anchor = weakref(anchor)
	_open_side = side if at_side < 0 else (at_side as Placement)
	if sounds and not _open:
		TaSfx.play_on(self, TaSfx.open())
	_open = true
	visible = true
	TaCancelRouter.enter(self, close)
	set_process(true)
	set_process_input(true)
	_place()
	# Placed again once the content has its final size this frame.
	_queue_place()
	if focus_content:
		TaFocus.focus_first(_content)
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	if sounds and is_inside_tree():
		TaSfx.play_on(get_parent(), TaSfx.close())
	var anchor := get_anchor_control()
	var owner_now := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_focus := owner_now != null and is_ancestor_of(owner_now)
	visible = false
	TaCancelRouter.leave(self)
	set_process(false)
	set_process_input(false)
	if had_focus and anchor != null and anchor.is_visible_in_tree():
		if anchor.focus_mode != Control.FOCUS_NONE:
			anchor.grab_focus()
	closed.emit()


func _process(_delta: float) -> void:
	var anchor := get_anchor_control()
	if anchor == null or not anchor.is_visible_in_tree():
		close()
		return
	if anchor.get_global_rect() != _anchor_rect:
		_place()


## A press outside the card and its anchor closes the card; the press is not
## consumed, so it still reaches the pot, slot, or button it landed on.
func _input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if not _open or press == null or not press.pressed:
		return
	# The press's own position (touch and injected input have no mouse position).
	var mine := make_input_local(press) as InputEventMouseButton
	if Rect2(Vector2.ZERO, size).has_point(mine.position):
		return
	var anchor := get_anchor_control()
	if anchor != null:
		var theirs := anchor.make_input_local(press) as InputEventMouseButton
		if Rect2(Vector2.ZERO, anchor.size).has_point(theirs.position):
			return
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed("ui_cancel"):
		return
	if TaCancelRouter.find(self) != null:
		return
	get_viewport().set_input_as_handled()
	close()


func _queue_place() -> void:
	if _open:
		call_deferred("_place")


func _place() -> void:
	var anchor := get_anchor_control()
	if not _open or anchor == null or not is_inside_tree():
		return
	var view := get_viewport().get_visible_rect()
	var safe := Rect2(
			view.position + Vector2(safe_insets.x, safe_insets.y),
			view.size - Vector2(safe_insets.x + safe_insets.z, safe_insets.y + safe_insets.w)
	)
	var a := anchor.get_global_rect()
	_anchor_rect = a
	var gap := _gap()
	var frame := Vector2.ZERO
	if has_theme_stylebox("panel"):
		frame = get_theme_stylebox("panel").get_minimum_size()
	var natural := _content.get_combined_minimum_size() + frame
	var rooms := {
		Placement.RIGHT: Vector2(safe.end.x - (a.end.x + gap), safe.size.y),
		Placement.LEFT: Vector2(a.position.x - gap - safe.position.x, safe.size.y),
		Placement.BELOW: Vector2(safe.size.x, safe.end.y - (a.end.y + gap)),
		Placement.ABOVE: Vector2(safe.size.x, a.position.y - gap - safe.position.y),
	}
	_placed = _pick(rooms, natural, a, safe, gap)
	var room: Vector2 = rooms[_placed]
	TaFit.fit_scroll(_scroll, maxf(room.y - frame.y, 1.0))
	size = Vector2.ZERO
	var card := get_combined_minimum_size()
	card.x = minf(maxf(card.x, natural.x), safe.size.x)
	size = card
	global_position = _rect_at(_placed, a, safe, gap, card).position
	queue_redraw()


## Where a card of size `card` lands on side `p`, clamped into the safe rect.
func _rect_at(p: Placement, a: Rect2, safe: Rect2, gap: float, card: Vector2) -> Rect2:
	var pos := Vector2.ZERO
	match p:
		Placement.RIGHT:
			pos = Vector2(a.end.x + gap, a.position.y)
		Placement.LEFT:
			pos = Vector2(a.position.x - gap - card.x, a.position.y)
		Placement.BELOW:
			pos = Vector2(a.position.x, a.end.y + gap)
		_:
			pos = Vector2(a.position.x, a.position.y - gap - card.y)
	pos.x = clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - card.x))
	pos.y = clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - card.y))
	return Rect2(pos, card)


func _pick(rooms: Dictionary, natural: Vector2, a: Rect2, safe: Rect2, gap: float) -> Placement:
	if _open_side != Placement.AUTO:
		return _open_side
	var fitting: Array = []
	for s in [Placement.RIGHT, Placement.LEFT]:
		if (rooms[s] as Vector2).x >= natural.x:
			fitting.append(s)
	for s in [Placement.BELOW, Placement.ABOVE]:
		if (rooms[s] as Vector2).y >= natural.y:
			fitting.append(s)
	if not fitting.is_empty():
		var best: Placement = fitting[0]
		if keep_clear.is_empty():
			return best
		var card := Vector2(minf(natural.x, safe.size.x), natural.y)
		var least := INF
		for s in fitting:
			var covered := _covered(_rect_at(s, a, safe, gap, card))
			if covered < least - 0.5:
				least = covered
				best = s
		return best
	# Nothing fits whole: the side with the most room; the body scrolls.
	var best := Placement.RIGHT
	var most := -INF
	for s in [Placement.RIGHT, Placement.LEFT, Placement.BELOW, Placement.ABOVE]:
		var r: Vector2 = rooms[s]
		var area := maxf(r.x, 0.0) * maxf(r.y, 0.0)
		if area > most:
			most = area
			best = s
	return best


## Area of keep_clear under `rect` (the anchor itself does not count).
func _covered(rect: Rect2) -> float:
	var anchor := get_anchor_control()
	var total := 0.0
	for item in keep_clear:
		var r := Rect2()
		if item is Rect2:
			r = item
		elif is_instance_valid(item) and item is Control:
			# is_instance_valid first: `is` on a freed pot (a rebuilt row) is an error.
			var c := item as Control
			if c == anchor or not c.is_visible_in_tree():
				continue
			r = c.get_global_rect()
		else:
			continue
		total += rect.intersection(r).get_area()
	return total


## The arrow: on the edge facing the anchor, pointing at the anchor's centre.
func _draw() -> void:
	if not notch or not _open:
		return
	var n := float(TaLook.metric(TaDefaults.POPOVER_NOTCH, TaDefaults.PIXEL_POPOVER_NOTCH))
	var tip_at := _anchor_rect.get_center() - global_position
	var color := _edge_color()
	var points := PackedVector2Array()
	match _placed:
		Placement.RIGHT, Placement.LEFT:
			var y := clampf(tip_at.y, n * 2.0, size.y - n * 2.0)
			var x := 0.0 if _placed == Placement.RIGHT else size.x
			var out := -n if _placed == Placement.RIGHT else n
			points = PackedVector2Array([Vector2(x, y - n), Vector2(x + out, y), Vector2(x, y + n)])
		_:
			var x := clampf(tip_at.x, n * 2.0, size.x - n * 2.0)
			var y := 0.0 if _placed == Placement.BELOW else size.y
			var out := -n if _placed == Placement.BELOW else n
			points = PackedVector2Array([Vector2(x - n, y), Vector2(x, y + out), Vector2(x + n, y)])
	draw_colored_polygon(points, color)


func _edge_color() -> Color:
	var box := get_theme_stylebox("panel") if has_theme_stylebox("panel") else null
	if box is StyleBoxFlat:
		return (box as StyleBoxFlat).border_color
	var look := TaLook.current()
	return look.color_border


func _gap() -> float:
	return float(TaLook.metric(TaDefaults.POPOVER_GAP, TaDefaults.PIXEL_POPOVER_GAP))
