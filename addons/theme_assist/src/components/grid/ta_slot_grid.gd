class_name TaSlotGrid
extends GridContainer

# AGENT: Visual slot grid. Display only. Component layer.
# INVARIANT: Children are TaSlot. No item database or stacks.
# DO NOT: Own loot tables. Do not drag-drop rules.

## Grid of TaSlot cells. slot_pressed(index) when a cell is clicked.

signal slot_pressed(index: int)

const _Slot := preload("res://addons/theme_assist/src/components/slot/ta_slot.gd")

@export var grid_columns: int = TaDefaults.SLOT_GRID_COLUMNS:
	set(value):
		grid_columns = maxi(1, value)
		columns = grid_columns
		_rebuild()

@export var slot_count: int = TaDefaults.SLOT_GRID_COUNT:
	set(value):
		slot_count = maxi(0, value)
		_rebuild()

var _building: bool = false


func _init() -> void:
	theme_type_variation = "TaSlotGrid"
	columns = TaDefaults.SLOT_GRID_COLUMNS
	refresh_metrics()
	_rebuild()


func refresh_metrics() -> void:
	_sync_gaps()
	for child in get_children():
		if child.has_method("refresh_metrics"):
			child.refresh_metrics()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		_sync_gaps()


## Rows keep room for a count rising over a slot's top edge (TaSlot.count_room), so it
## never lands on the slot above. Writes only on change: an override emits THEME_CHANGED.
func _sync_gaps() -> void:
	var sep := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	var rows := maxi(sep, TaSlot.count_room(self))
	for spec in [[&"h_separation", sep], [&"v_separation", rows]]:
		var key: StringName = spec[0]
		if not has_theme_constant_override(key) or get_theme_constant(key) != int(spec[1]):
			add_theme_constant_override(key, spec[1])


func get_slot(index: int) -> TaSlot:
	if index < 0 or index >= get_child_count():
		return null
	var child := get_child(index)
	return child as TaSlot


func _rebuild() -> void:
	if _building:
		return
	_building = true
	columns = grid_columns
	while get_child_count() > slot_count:
		var extra := get_child(get_child_count() - 1)
		remove_child(extra)
		extra.free()
	while get_child_count() < slot_count:
		var slot: Button = _Slot.new()
		var index := get_child_count()
		slot.pressed.connect(_on_slot_pressed.bind(index))
		add_child(slot)
	_building = false


func _on_slot_pressed(index: int) -> void:
	slot_pressed.emit(index)
