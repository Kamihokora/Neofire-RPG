class_name TaSortList
extends PanelContainer

# AGENT: ItemList with a sort header. Display + order only.
# INVARIANT: set_items replaces rows. Header toggles A–Z / Z–A.
# DO NOT: Own a database. Do not persist.

## Sortable list. item_activated(index, text) on activate.

signal item_activated(index: int, text: String)
signal sort_changed(ascending: bool)

var _col: VBoxContainer
var _header: Button
var _list: ItemList
var _items: PackedStringArray = PackedStringArray()
## Order last applied by the header. The header caption shows the next click.
var _ascending: bool = true
var _next_ascending: bool = true


func _init() -> void:
	theme_type_variation = "TaSortList"
	_col = VBoxContainer.new()
	add_child(_col)
	_header = TaButton.new()
	_header.pressed.connect(_on_header)
	_col.add_child(_header)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(_on_activated)
	_col.add_child(_list)
	_apply_header()
	refresh_metrics()


func _ready() -> void:
	TaJuice.bind_hover(_header)


func refresh_metrics() -> void:
	var h := TaLook.metric(TaDefaults.LIST_MIN_HEIGHT, TaDefaults.PIXEL_LIST_MIN_HEIGHT)
	if is_instance_valid(_list):
		_list.custom_minimum_size.y = h


func get_list() -> ItemList:
	return _list


func get_header() -> Button:
	return _header


func set_items(items: PackedStringArray) -> void:
	_items = items.duplicate()
	_refresh()


func add_row(text: String) -> void:
	_items.append(text)
	_refresh()


func get_items() -> PackedStringArray:
	return _items.duplicate()


func is_ascending() -> bool:
	return _ascending


func _on_header() -> void:
	_ascending = _next_ascending
	_sort()
	_next_ascending = not _ascending
	_apply_header()
	sort_changed.emit(_ascending)


func _sort() -> void:
	var arr: Array[String] = []
	for item in _items:
		arr.append(item)
	# Natural and case-blind, as "A-Z" promises: "ash" before "Birch", "Item 2" before
	# "Item 10". A plain sort() put every capital first and 10 before 2.
	arr.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	if not _ascending:
		arr.reverse()
	_items = PackedStringArray(arr)
	_refresh()


func _refresh() -> void:
	_apply_header()
	if not is_instance_valid(_list):
		return
	_list.clear()
	for item in _items:
		_list.add_item(item)


func _apply_header() -> void:
	if is_instance_valid(_header):
		_header.text = "A-Z" if _next_ascending else "Z-A"


func _on_activated(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	item_activated.emit(index, _items[index])
