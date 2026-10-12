extends Object

# AGENT: Playground cell wrap + gallery filter. Shared by stock/composites.
# INVARIANT: apply_filter only toggles nodes with meta ta_cell.
# DO NOT: Hide the playground root, tokens rail, or overlay hosts.

const _Cell := preload("res://addons/theme_assist/playground/playground_cell.gd")
const _Snippets := preload("res://addons/theme_assist/playground/playground_snippets.gd")


## A tool-chrome size in px on this display (the playground's own controls wear Flat).
static func ui(px: float) -> int:
	return roundi(px * TaDisplay.vector_scale(TaTokens.new()))


static func cell(key: String, body: Control, extra: String = "") -> Control:
	var box := _Cell.new()
	var snippet := _Snippets.for_key(key)
	var filter := ("%s %s" % [key, extra]).strip_edges()
	box.setup(key, snippet, filter)
	if is_instance_valid(body):
		# Widen only bodies on the default fill: tags, slots, and steppers stay compact.
		if body.size_flags_horizontal == Control.SIZE_FILL:
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_body(body)
	return box


static func apply_filter(root: Node, query: String) -> void:
	if not is_instance_valid(root):
		return
	_walk(root, query.strip_edges().to_lower())


static func count_visible_cells(root: Node) -> int:
	if not is_instance_valid(root):
		return 0
	var n := 0
	if root.has_meta("ta_cell") and root is Control and (root as Control).visible:
		n += 1
	for child in root.get_children():
		n += count_visible_cells(child)
	return n


static func _walk(node: Node, query: String) -> bool:
	if node.has_meta("ta_cell"):
		var hit := query.is_empty()
		if not hit:
			var key := String(node.get_meta("ta_filter")).to_lower()
			hit = key.contains(query)
		if node.has_method("matches"):
			hit = node.matches(query)
		if node is Control:
			(node as Control).visible = hit
		return hit
	var any := false
	for child in node.get_children():
		if _walk(child, query):
			any = true
	return any
