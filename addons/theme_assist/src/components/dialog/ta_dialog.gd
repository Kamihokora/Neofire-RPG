class_name TaDialog
extends PopupPanel

# AGENT: Modal chrome + content slot. Component layer.
# INVARIANT: get_content() is the user slot. Confirm/cancel only emit once. Joins a
# TaCancelRouter while showing, so router.top() and router.cancel() see it.
# DO NOT: Add a page stack. Do not call EditorPlugin.

## Small Window confirm. Put custom widgets in get_content().
## For a panel that lives in the HUD and uses z_index, use TaModal.

signal confirmed
signal canceled

@export var confirm_text: String = "OK":
	set(value):
		confirm_text = value
		_apply_buttons()

@export var cancel_text: String = "Cancel":
	set(value):
		cancel_text = value
		_apply_buttons()

@export var body: String = "":
	set(value):
		body = value
		if is_instance_valid(_body):
			_body.text = body
			_body.visible = not body.is_empty()

var _root: VBoxContainer
var _head: PanelContainer
var _title: Label
var _content: VBoxContainer
var _confirm: Button
var _cancel: Button
var _body: Label
var _latched: bool = false


func _init() -> void:
	theme_type_variation = "TaDialog"
	exclusive = true
	unresizable = true
	wrap_controls = true
	_root = VBoxContainer.new()
	add_child(_root)
	# The title wears the header rule (Modern: the accent rule under panel headers).
	_head = PanelContainer.new()
	_head.theme_type_variation = "TaDialogHeader"
	_root.add_child(_head)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = "TaTitle"
	_head.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = TaDefaults.PIXEL_DIALOG_MIN_WIDTH - TaDefaults.PIXEL_PANEL_MARGIN * 2
	_body.visible = false
	_root.add_child(_body)
	_content = VBoxContainer.new()
	_root.add_child(_content)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(row)
	_cancel = TaButton.new()
	_cancel.press_sound = &"close"
	_cancel.pressed.connect(_on_cancel_pressed)
	row.add_child(_cancel)
	_confirm = TaButton.new()
	_confirm.press_sound = &"confirm"
	_confirm.pressed.connect(_on_confirm_pressed)
	row.add_child(_confirm)
	_apply_title()
	_apply_buttons()
	refresh_metrics()


func _ready() -> void:
	_apply_title()
	if not about_to_popup.is_connected(_apply_title):
		about_to_popup.connect(_apply_title)
	close_requested.connect(_on_cancel_pressed)
	visibility_changed.connect(_on_visibility_changed)
	TaJuice.bind_hover(_confirm)
	TaJuice.bind_hover(_cancel)
	set_process_unhandled_input(true)


## Inner slot. Add your body controls as children of this node.
func get_content() -> Control:
	return _content


func refresh_metrics() -> void:
	var min_w := TaLook.metric(TaDefaults.DIALOG_MIN_WIDTH, TaDefaults.PIXEL_DIALOG_MIN_WIDTH)
	min_size = Vector2i(min_w, 0)
	if is_instance_valid(_body):
		var margin := TaLook.metric(TaDefaults.PANEL_MARGIN, TaDefaults.PIXEL_PANEL_MARGIN)
		_body.custom_minimum_size.x = min_w - margin * 2
	var h := TaLook.button_height()
	if is_instance_valid(_cancel):
		_cancel.custom_minimum_size.y = h
	if is_instance_valid(_confirm):
		_confirm.custom_minimum_size.y = h


func get_confirm_button() -> Button:
	return _confirm


func get_cancel_button() -> Button:
	return _cancel


## True while the popup is showing. Pause leaves Esc to this dialog.
func blocks_pause_cancel() -> bool:
	return visible


## Show centered, sized to title / body / actions (not a viewport-ratio sheet).
## No-op until the dialog is in the tree. popup_centered cannot run before that.
func show_dialog() -> void:
	if not is_inside_tree():
		return
	_latched = false
	_apply_title()
	if is_instance_valid(_body):
		_body.text = body
		_body.visible = not body.is_empty()
	wrap_controls = true
	reset_size()
	popup_centered()
	TaSfx.play_on(self, TaSfx.open())
	if is_instance_valid(_confirm):
		_confirm.grab_focus()
	_show_dim()


func _apply_title() -> void:
	if is_instance_valid(_title):
		_title.text = title
		_head.visible = not title.is_empty()


func _apply_buttons() -> void:
	if is_instance_valid(_confirm):
		_confirm.text = confirm_text
	if is_instance_valid(_cancel):
		_cancel.text = cancel_text


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func _on_confirm_pressed() -> void:
	if _latched:
		return
	_latched = true
	confirmed.emit()
	_hide_dim()
	hide()


func _on_cancel_pressed() -> void:
	if _latched:
		return
	_latched = true
	canceled.emit()
	_hide_dim()
	hide()


func _on_visibility_changed() -> void:
	if visible:
		_apply_title()
		TaCancelRouter.enter(self, _on_cancel_pressed)
		return
	TaCancelRouter.leave(self)
	_hide_dim()
	if not _latched:
		_latched = true
		canceled.emit()


func _show_dim() -> void:
	var parent := get_parent()
	if parent is Control:
		TaDimmer.on(parent as Control).fade_in()


func _hide_dim() -> void:
	var parent := get_parent()
	if parent is Control:
		var dim := parent.get_node_or_null(TaDimmer.NODE_NAME)
		if dim is TaDimmer:
			(dim as TaDimmer).fade_out()
