@tool
extends TaOverlay

# AGENT: Drop-in pause overlay PackedScene root, on TaOverlay. Addon zip, not demo/.
# INVARIANT: Starts hidden. Default card: Resume / Options / Quit + prompt; `menu` or
# set_menu() swaps in your own content and keeps the overlay behaviour (dimmer, tree
# pause, Esc, focus, Options). With a TaCancelRouter in the tree the router owns Esc
# and this overlay is its default fallback; without one it reads Esc itself in
# _unhandled_input, so tree order decides who hears Esc first. Self-paints if themeless.
# DO NOT: Autoload. Do not save settings. Do not load res://demo.

const _DropIn := preload("res://addons/theme_assist/src/core/ta_drop_in.gd")
const _OPTIONS_SCENE := "res://addons/theme_assist/scenes/options.tscn"

signal resume_pressed
signal options_pressed
signal quit_pressed

## False: the overlay never reads Esc. Your own Esc code calls toggle() instead.
## Ignored when a TaCancelRouter is in the tree (the router owns Esc).
@export var listen_cancel: bool = true
## False: show_pause() leaves SceneTree.paused alone (games that freeze their own clock).
@export var pause_tree: bool = true
## Your own menu scene in place of the Resume / Options / Quit card. Call dismiss(),
## toggle(), or open_options() from it. Null keeps the default card.
@export var menu: PackedScene

var _card: PanelContainer
var _menu: Control
var _resume: Button
var _options: Button
var _quit: Button
var _options_host: CenterContainer
var _options_panel: Control
var _held_pause: bool = false
var _tree_was_paused: bool = false


func _init() -> void:
	super()
	z_as_relative = false
	if z_index < 20:
		z_index = 20
	var center := CenterContainer.new()
	center.name = "PausePanelHost"
	center.z_index = 1
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_card = PanelContainer.new()
	_card.custom_minimum_size.x = TaDefaults.PAUSE_PANEL_MIN_WIDTH
	center.add_child(_card)
	var column := VBoxContainer.new()
	_card.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.theme_type_variation = "TaTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	_resume = _make_button("Resume", _on_resume)
	column.add_child(_resume)
	_options = _make_button("Options", _on_options)
	column.add_child(_options)
	_quit = _make_button("Quit", _on_quit)
	column.add_child(_quit)
	var hint := TaPromptHint.new()
	column.add_child(hint)
	TaJuice.bind_tree(self)


func _ready() -> void:
	add_to_group("ta_pause_overlay")
	_DropIn.ensure_theme(self)
	if menu != null and not is_instance_valid(_menu):
		set_menu(menu.instantiate() as Control)
	if visible:
		if Engine.is_editor_hint():
			if is_instance_valid(_dimmer):
				_dimmer.fade_in(dim_alpha, dim_blur)
		else:
			# Saved visible means "start paused". Run the whole show so the tree
			# pause, mouse capture, and focus agree with what is on screen.
			visible = false
			call_deferred("show_pause")
	if is_instance_valid(_resume):
		TaFocus.chain([_resume, _options, _quit], TaFocus.Axis.VERTICAL)
	set_process_unhandled_input(true)


## Editor save: keep the self-paint out of your scene file (see TaDropIn).
func _notification(what: int) -> void:
	_DropIn.strip_for_save(self, what)


func _unhandled_input(event: InputEvent) -> void:
	_handle_cancel(event)


func get_resume_button() -> Button:
	return _resume


func get_options_button() -> Button:
	return _options


func get_quit_button() -> Button:
	return _quit


func get_panel_host() -> Control:
	return get_node_or_null("PausePanelHost") as Control


func get_options_panel() -> Control:
	return _options_panel


func get_menu() -> Control:
	return _menu


## Swap the default card for your own menu. Null brings the card back.
func set_menu(control: Control) -> void:
	if is_instance_valid(_menu) and _menu != control:
		_menu.queue_free()
	_menu = control
	if is_instance_valid(_card):
		_card.visible = control == null
	var host := get_panel_host()
	if control != null and host != null and control.get_parent() == null:
		host.add_child(control)


func show_pause() -> void:
	close_options()
	open()
	_pause_tree()


func dismiss() -> void:
	close_options()
	close()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restore_tree()


## Open when hidden, resume when shown. The router's default fallback.
func toggle() -> void:
	if _open:
		_on_resume()
	else:
		show_pause()


func open_options() -> void:
	_ensure_options()
	var host := get_panel_host()
	if is_instance_valid(host):
		host.visible = false
	if is_instance_valid(_options_host):
		_options_host.visible = true
	if is_instance_valid(_dimmer) and dim:
		_dimmer.fade_in(dim_alpha, dim_blur)
	if is_instance_valid(_options_panel) and _options_panel.has_method("focus_first"):
		_options_panel.focus_first()


func close_options() -> void:
	var listening := _find_listening_rebind(self)
	if listening != null:
		listening.cancel_listen()
	if is_instance_valid(_options_host):
		_options_host.visible = false
	var host := get_panel_host()
	if is_instance_valid(host):
		host.visible = true
	if _open:
		_focus_default()


## Esc while open: cancel a key listen, then close Options, then resume.
func handle_cancel() -> void:
	var listening := _find_listening_rebind(self)
	if listening != null:
		listening.cancel_listen()
	elif _options_open():
		close_options()
	else:
		_on_resume()


func refresh_metrics() -> void:
	var h := TaLook.button_height()
	for button in [_resume, _options, _quit]:
		if is_instance_valid(button):
			button.custom_minimum_size.y = h
	if is_instance_valid(_card):
		_card.custom_minimum_size.x = TaDefaults.PAUSE_PANEL_MIN_WIDTH


func _focus_default() -> void:
	if is_instance_valid(_menu):
		TaFocus.focus_first(_menu)
	elif is_instance_valid(_resume) and _resume.is_inside_tree():
		_resume.grab_focus()


## No router: this overlay reads Esc itself. With a router it stands down and runs
## as the router's fallback (closed) or top entry (open).
func _handle_cancel(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not event.is_action_pressed("ui_cancel"):
		return
	if not is_inside_tree() or TaCancelRouter.find(self) != null or not listen_cancel:
		return
	var listening := _find_listening_rebind(get_tree().root)
	if listening != null:
		listening.cancel_listen()
		get_viewport().set_input_as_handled()
		return
	if _dialog_open():
		return
	if _open and is_visible_in_tree():
		if esc_closes:
			handle_cancel()
		get_viewport().set_input_as_handled()
		return
	if _parent_is_on_screen():
		show_pause()
		get_viewport().set_input_as_handled()


func _ensure_options() -> void:
	if is_instance_valid(_options_panel):
		return
	var packed := load(_OPTIONS_SCENE) as PackedScene
	if packed == null:
		return
	_options_host = CenterContainer.new()
	_options_host.name = "OptionsHost"
	_options_host.z_index = 2
	_options_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_options_host)
	_options_panel = packed.instantiate() as Control
	if _options_panel == null:
		return
	_options_panel.custom_minimum_size.x = TaDefaults.PAUSE_PANEL_MIN_WIDTH
	_options_host.add_child(_options_panel)
	if _options_panel.has_signal("back_pressed"):
		_options_panel.back_pressed.connect(close_options)


func _options_open() -> bool:
	return is_instance_valid(_options_host) and _options_host.visible


func _parent_is_on_screen() -> bool:
	if not is_inside_tree():
		return false
	var parent := get_parent()
	if parent is CanvasItem:
		return (parent as CanvasItem).is_visible_in_tree()
	return parent != null


func _dialog_open() -> bool:
	return TaOverlay.any_open(self, self)


func _find_listening_rebind(node: Node) -> TaRebindRow:
	if node == null:
		return null
	if node is TaRebindRow and (node as TaRebindRow).is_listening():
		return node as TaRebindRow
	for child in node.get_children():
		var found := _find_listening_rebind(child)
		if found != null:
			return found
	return null


func _pause_tree() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if not pause_tree:
		return
	if not _held_pause:
		_tree_was_paused = get_tree().paused
		_held_pause = true
	get_tree().paused = true


func _restore_tree() -> void:
	if not _held_pause:
		return
	if is_inside_tree() and not Engine.is_editor_hint():
		get_tree().paused = _tree_was_paused
	_held_pause = false


func _make_button(caption: String, callback: Callable) -> Button:
	var button := TaButton.new()
	button.text = caption
	button.custom_minimum_size.y = TaLook.button_height()
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _on_resume() -> void:
	dismiss()
	resume_pressed.emit()


func _on_options() -> void:
	open_options()
	options_pressed.emit()


func _on_quit() -> void:
	quit_pressed.emit()
