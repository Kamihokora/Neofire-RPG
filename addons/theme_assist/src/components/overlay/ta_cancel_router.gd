class_name TaCancelRouter
extends Node

# AGENT: Placed Esc router. One per scene, like TaToastHost. Not an autoload (D10, D37).
# INVARIANT: Esc goes to the most recently pushed entry that is still visible in the
# tree; hidden or freed entries drop out on their own. Entries pushed `under` sit
# below every overlay (esc_dismisses toasts). With nothing on the stack, fallback
# runs (default: the scene's pause.tscn toggles). Listens in _unhandled_input, so a
# focused popup or LineEdit still gets Esc first.
# DO NOT: Route pages or scenes (UIFlow's job). Do not hold strong refs to entries.

## Place one in your UI. TaOverlay, TaModal, TaDialog, and pause.tscn join it on open;
## a TaToastHost with esc_dismisses joins under them while toasts show.
## Your own panels: router.push(panel, panel.close) when they open.
## Without a router, overlays read Esc themselves and tree order decides who goes first.

signal fallback_ran

const GROUP := "ta_cancel_router"

## Runs when Esc arrives and nothing is open. Empty: toggles the scene's pause.tscn.
var fallback: Callable = Callable()

var _stack: Array[Dictionary] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)


## The router for this tree, or null.
static func find(from: Node) -> TaCancelRouter:
	if not is_instance_valid(from) or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group(GROUP) as TaCancelRouter


## Push `entry` onto the router in its tree, if there is one. True when routed.
static func enter(entry: Node, on_cancel: Callable, under: bool = false) -> bool:
	var router := find(entry)
	if router == null:
		return false
	router.push(entry, on_cancel, under)
	return true


static func leave(entry: Node) -> void:
	var router := find(entry)
	if router != null:
		router.pop(entry)


## Put `entry` on top. `on_cancel` runs when Esc arrives while it is on top.
## under: below every other entry instead, for HUD state Esc clears before the
## fallback runs but never ahead of an open overlay (toasts, a unit selection).
func push(entry: Node, on_cancel: Callable, under: bool = false) -> void:
	pop(entry)
	var item := {"node": weakref(entry), "cancel": on_cancel}
	if under:
		_stack.insert(0, item)
	else:
		_stack.append(item)


func pop(entry: Node) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if (_stack[i]["node"] as WeakRef).get_ref() == entry:
			_stack.remove_at(i)


## The entry Esc goes to next, or null. Under entries count, so with esc_dismisses
## toasts on screen this can be the TaToastHost.
func top() -> Node:
	_prune()
	return (_stack[-1]["node"] as WeakRef).get_ref() if not _stack.is_empty() else null


## Entries on the stack, under entries included.
func depth() -> int:
	_prune()
	return _stack.size()


## What Esc does. Call it from a gamepad Back button or an on-screen back arrow too.
## True when something handled it.
func cancel() -> bool:
	_prune()
	if not _stack.is_empty():
		var callback: Callable = _stack[-1]["cancel"]
		if callback.is_valid():
			callback.call()
		return true
	if fallback.is_valid():
		fallback.call()
		fallback_ran.emit()
		return true
	var pause := get_tree().get_first_node_in_group("ta_pause_overlay") if is_inside_tree() else null
	if pause != null and pause.has_method("toggle"):
		pause.toggle()
		fallback_ran.emit()
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if cancel():
		get_viewport().set_input_as_handled()


func _prune() -> void:
	for i in range(_stack.size() - 1, -1, -1):
		var node := (_stack[i]["node"] as WeakRef).get_ref() as Node
		var gone := node == null or not node.is_inside_tree()
		if not gone and node is CanvasItem:
			gone = not (node as CanvasItem).is_visible_in_tree()
		elif not gone and node is Window:
			gone = not (node as Window).visible
		if gone:
			_stack.remove_at(i)
