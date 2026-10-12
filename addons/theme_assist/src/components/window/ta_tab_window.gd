class_name TaTabWindow
extends TaWindow

# AGENT: Floating window whose body is a TabContainer. Not IDE docking.
# INVARIANT: add_page appends a tab. get_tabs() is the stock TabContainer.
# DO NOT: Dock, snap, or wrap an inner Window node.

## Draggable window with tabs in the content slot.

var _tabs: TabContainer


func _enter_tree() -> void:
	_ensure_tabs()


func get_tabs() -> TabContainer:
	_ensure_tabs()
	return _tabs


func add_page(page_title: String, page: Control) -> void:
	if not is_instance_valid(page):
		return
	page.name = page_title
	get_tabs().add_child(page)


func _ensure_tabs() -> void:
	theme_type_variation = "TaTabWindow"
	if not is_instance_valid(_tabs):
		_tabs = TabContainer.new()
		_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _tabs.get_parent() != null:
		return
	var slot := get_content()
	if is_instance_valid(slot):
		slot.add_child(_tabs)
