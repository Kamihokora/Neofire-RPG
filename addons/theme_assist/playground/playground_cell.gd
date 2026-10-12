extends PanelContainer

# AGENT: One playground gallery cell. Title, copy-snippet, body slot.
# INVARIANT: Meta ta_cell + ta_filter. Copy uses the playground group.
# DO NOT: Persist snippets. Do not rename the body widget.

var _body: VBoxContainer
var _copy: Button


func setup(title: String, snippet: String, filter_key: String) -> void:
	set_meta("ta_cell", true)
	set_meta("ta_filter", filter_key)
	set_meta("ta_snippet", snippet)
	var col := VBoxContainer.new()
	add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.theme_type_variation = "TaCaption"
	header.add_child(label)
	_copy = Button.new()
	_copy.text = "Copy"
	_copy.visible = not snippet.is_empty()
	_copy.pressed.connect(_on_copy)
	header.add_child(_copy)
	_body = VBoxContainer.new()
	col.add_child(_body)


func add_body(node: Control) -> void:
	if is_instance_valid(_body) and is_instance_valid(node):
		_body.add_child(node)


func matches(query: String) -> bool:
	if query.is_empty():
		return true
	var q := query.to_lower()
	var key := String(get_meta("ta_filter")).to_lower()
	return key.contains(q) or String(name).to_lower().contains(q)


func _on_copy() -> void:
	var text := String(get_meta("ta_snippet"))
	if text.is_empty() or not is_inside_tree():
		return
	var host := get_tree().get_first_node_in_group("ta_playground")
	if host != null and host.has_method("copy_snippet"):
		host.copy_snippet(text)
		return
	DisplayServer.clipboard_set(text)
