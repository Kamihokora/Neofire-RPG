class_name TaDropIn
extends Object

# AGENT: Paint-only Theme on drop-in scenes when the tree has none.
# INVARIANT: A project theme (the saved look) or a parent Control.theme wins, including
# one a parent sets in its own _ready:
# the check waits for the end of the frame, because Godot readies children first.
# apply_to() above a self-paint removes it. Never sets sync_display. A self-paint is
# never saved: drop-ins pass editor save notifications to strip_for_save.
# DO NOT: Autoload. Do not resize the Window. Do not mark with metadata (it saves).

## Self-painted drop-ins. A non-persistent group, so it is never written to a scene.
const PAINTED := &"ta_drop_in_painted"


## Paint `control` at the end of this frame if nothing above it has a Theme by then.
## (1.11 checked at once: a game root that applied its look in _ready came second, and
## every drop-in kept the default look.)
static func ensure_theme(control: Control) -> void:
	if is_instance_valid(control):
		# By id: a drop-in freed before the end of the frame is skipped, not an error.
		_paint_id.call_deferred(control.get_instance_id())


## True while `control` wears its own self-paint.
static func is_painted(control: Control) -> bool:
	return is_instance_valid(control) and control.is_in_group(PAINTED)


## `root` just got a Theme: drop the self-paints under it, or they would outrank it.
static func unpaint_below(root: Node) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return
	for node in root.get_tree().get_nodes_in_group(PAINTED):
		if node is Control and root.is_ancestor_of(node):
			(node as Control).remove_from_group(PAINTED)
			(node as Control).theme = null


## Drop the self-paint before the editor saves and put it back after. Otherwise
## the generated Theme is written into your scene and outranks your root's look.
static func strip_for_save(control: Control, what: int) -> void:
	if not is_painted(control):
		return
	if what == Node.NOTIFICATION_EDITOR_PRE_SAVE:
		control.theme = null
	elif what == Node.NOTIFICATION_EDITOR_POST_SAVE:
		control.theme = TaThemeBuilder.make(TaLook.current())


static func _paint_id(id: int) -> void:
	var control := instance_from_id(id) as Control
	if control != null:
		_paint_if_bare(control)


static func _paint_if_bare(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	if control.theme != null or is_painted(control):
		return
	# The saved look is the project theme: every Control already wears it.
	if ThemeDB.get_project_theme() != null:
		return
	var node: Node = control.get_parent()
	while node != null:
		if node is Control and (node as Control).theme != null:
			return
		node = node.get_parent()
	TaThemeBuilder.apply_to(control, TaLook.current(), false)
	control.add_to_group(PAINTED)
