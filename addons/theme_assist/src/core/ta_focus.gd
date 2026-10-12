class_name TaFocus
extends Object

# AGENT: Gamepad/keyboard neighbor chain for stock + kit Controls.
# INVARIANT: Call after nodes are in the tree. FOCUS_ALL on each. A hidden list
# never takes focus. trap() pulls focus back only while its root is visible.
# DO NOT: Require EditorPlugin. Do not re-dispatch input events.

## Which arrows a chain() wires. BOTH is the 1.x ring on all four arrows.
enum Axis {
	BOTH,
	VERTICAL,
	HORIZONTAL,
}

const _TRAP_META := "_ta_focus_trap"
const _LAST_META := "_ta_focus_last"


## Ring of neighbors. VERTICAL wires Up/Down and points Left/Right at self, so a
## menu column never hands focus sideways. HORIZONTAL is the row version.
static func chain(controls: Array, axis: Axis = Axis.BOTH) -> void:
	var list := _controls(controls)
	var count := list.size()
	if count == 0:
		return
	for i in count:
		var node := list[i]
		node.focus_mode = Control.FOCUS_ALL
		var next_path := node.get_path_to(list[(i + 1) % count])
		var prev_path := node.get_path_to(list[(i - 1 + count) % count])
		var self_path := node.get_path_to(node)
		var vertical := axis != Axis.HORIZONTAL
		var horizontal := axis != Axis.VERTICAL
		node.focus_neighbor_bottom = next_path if vertical else self_path
		node.focus_neighbor_top = prev_path if vertical else self_path
		node.focus_neighbor_right = next_path if horizontal else self_path
		node.focus_neighbor_left = prev_path if horizontal else self_path
		node.focus_next = next_path
		node.focus_previous = prev_path
	_grab_if_shown(list[0])


## Join the two ends of a row (HORIZONTAL) or column (VERTICAL) so ui_left / ui_right
## (or ui_up / ui_down) wrap around. Everything else stays Godot's geometric navigation,
## so focus can still leave the row. Never grabs focus. Kit rows and menus call this.
static func wrap(controls: Array, axis: Axis = Axis.VERTICAL) -> void:
	var list: Array[Control] = []
	for item in _controls(controls):
		if item.visible and item.focus_mode != Control.FOCUS_NONE:
			list.append(item)
	# Clear the axis links first: a row that grew must not keep its old ends joined.
	for item in list:
		if axis == Axis.HORIZONTAL:
			item.focus_neighbor_left = NodePath()
			item.focus_neighbor_right = NodePath()
		else:
			item.focus_neighbor_top = NodePath()
			item.focus_neighbor_bottom = NodePath()
	if list.size() < 2:
		return
	var first := list[0]
	var last := list[list.size() - 1]
	if axis == Axis.HORIZONTAL:
		first.focus_neighbor_left = first.get_path_to(last)
		last.focus_neighbor_right = last.get_path_to(first)
	else:
		first.focus_neighbor_top = first.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(first)


## 2D neighbor graph. columns is the row width.
static func grid(controls: Array, columns: int) -> void:
	var list := _controls(controls)
	var count := list.size()
	var cols := maxi(1, columns)
	if count == 0:
		return
	var rows_list: Array = []
	for i in count:
		if i % cols == 0:
			rows_list.append([])
		(rows_list[rows_list.size() - 1] as Array).append(list[i])
	rows(rows_list)


## Explicit rows of different widths: a tile grid, then list rows, then Back.
## Left/Right stay in the row. Up/Down go to the matching spot in the next row.
## Edges point at self. Tab walks every control in order.
static func rows(row_list: Array) -> void:
	var clean: Array = []
	for row in row_list:
		var items := _controls(row if row is Array else [row])
		if not items.is_empty():
			clean.append(items)
	if clean.is_empty():
		return
	var flat: Array[Control] = []
	for r in clean.size():
		var row: Array = clean[r]
		for c in row.size():
			var node: Control = row[c]
			node.focus_mode = Control.FOCUS_ALL
			var left: Control = row[c - 1] if c > 0 else node
			var right: Control = row[c + 1] if c < row.size() - 1 else node
			var up: Control = _matching(clean[r - 1], c, row.size()) if r > 0 else node
			var down: Control = (
					_matching(clean[r + 1], c, row.size()) if r < clean.size() - 1 else node
			)
			node.focus_neighbor_left = node.get_path_to(left)
			node.focus_neighbor_right = node.get_path_to(right)
			node.focus_neighbor_top = node.get_path_to(up)
			node.focus_neighbor_bottom = node.get_path_to(down)
			flat.append(node)
	var count := flat.size()
	for i in count:
		flat[i].focus_next = flat[i].get_path_to(flat[(i + 1) % count])
		flat[i].focus_previous = flat[i].get_path_to(flat[(i - 1 + count) % count])
	_grab_if_shown(flat[0])


## First visible, focusable control under root in tree order, or null.
static func first_focusable(root: Node) -> Control:
	if root is Control:
		var control := root as Control
		if not control.is_visible_in_tree():
			return null
		if control.focus_mode == Control.FOCUS_ALL:
			return control
	for child in root.get_children():
		var found := first_focusable(child)
		if found != null:
			return found
	return null


## Focus the first visible, focusable control under root. Returns it or null.
static func focus_first(root: Node) -> Control:
	var target := first_focusable(root)
	if target != null:
		target.grab_focus()
	return target


## Keep keyboard focus inside root while root is visible. Tab or a stray arrow
## that lands outside is pulled back to the last control inside (or the first).
## Safe to call twice. release() or freeing root undoes it.
static func trap(root: Control) -> void:
	if not is_instance_valid(root) or root.has_meta(_TRAP_META):
		return
	if not root.is_inside_tree():
		root.tree_entered.connect(trap.bind(root), CONNECT_ONE_SHOT)
		return
	var viewport := root.get_viewport()
	var on_change := func(focused: Control) -> void: _on_focus_changed(root, focused)
	viewport.gui_focus_changed.connect(on_change)
	root.set_meta(_TRAP_META, on_change)
	var on_exit := release.bind(root)
	if not root.tree_exiting.is_connected(on_exit):
		root.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)


static func release(root: Control) -> void:
	if not is_instance_valid(root) or not root.has_meta(_TRAP_META):
		return
	var on_change: Callable = root.get_meta(_TRAP_META)
	root.remove_meta(_TRAP_META)
	if root.has_meta(_LAST_META):
		root.remove_meta(_LAST_META)
	if root.is_inside_tree():
		var viewport := root.get_viewport()
		if viewport.gui_focus_changed.is_connected(on_change):
			viewport.gui_focus_changed.disconnect(on_change)


static func is_trapped(root: Control) -> bool:
	return is_instance_valid(root) and root.has_meta(_TRAP_META)


static func _on_focus_changed(root: Control, focused: Control) -> void:
	if not is_instance_valid(root) or not root.is_visible_in_tree():
		return
	if focused != null and (focused == root or root.is_ancestor_of(focused)):
		root.set_meta(_LAST_META, weakref(focused))
		return
	var back: Control = null
	if root.has_meta(_LAST_META):
		var ref: WeakRef = root.get_meta(_LAST_META)
		var last := ref.get_ref() as Control
		if last != null and last.is_visible_in_tree() and root.is_ancestor_of(last):
			back = last
	if back == null:
		back = first_focusable(root)
	if back != null:
		back.call_deferred("grab_focus")


static func _matching(row: Array, index: int, width: int) -> Control:
	if row.size() == 1 or width <= 1:
		return row[mini(index, row.size() - 1)]
	var ratio := float(index) / float(width - 1)
	return row[clampi(roundi(ratio * float(row.size() - 1)), 0, row.size() - 1)]


static func _controls(items: Array) -> Array[Control]:
	var list: Array[Control] = []
	for item in items:
		if item is Control:
			list.append(item as Control)
	return list


static func _grab_if_shown(control: Control) -> void:
	# A hidden pause or drawer must not own focus at game start.
	if control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()
