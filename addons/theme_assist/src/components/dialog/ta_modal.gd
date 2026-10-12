class_name TaModal
extends TaOverlay

# AGENT: Layout-tree sheet on TaOverlay. Sibling of TaDialog. One sheet, four uses:
# confirm sheet, menu page (X + scroll body), one-line prompt (add_text_field), and
# confirm card (add_costs / add_options / add_bullets).
# INVARIANT: Hidden until show_modal. The whole panel stays within max_height_ratio of
# the viewport; only the body scrolls. Esc: Cancel if shown, else X if shown, else
# confirm. esc_closes false ignores Esc. Dimmer, trap, and router come from TaOverlay.
# DO NOT: Become a page stack. Do not replace TaDialog's popup.

## Full-rect modal that stays in the layout tree, so z_index works.
## Use TaDialog when you want a small Window popup over a 3D view.
## Put page content in get_content(). It scrolls once the panel reaches the height cap.

signal confirmed
signal canceled

@export var title: String = "":
	set(value):
		title = value
		_apply_title()

@export var body: String = "":
	set(value):
		body = value
		_apply_body()

@export var confirm_text: String = "OK":
	set(value):
		confirm_text = value
		_apply_buttons()

## Empty hides Cancel. Esc then confirms (or closes, when closable).
@export var cancel_text: String = "":
	set(value):
		cancel_text = value
		_apply_buttons()

## Show an X in the header. It emits canceled. Empty confirm and cancel text plus
## closable makes a menu page with no footer.
@export var closable: bool = false:
	set(value):
		closable = value
		_apply_buttons()

## Panel width in px. 0 uses TaDefaults.DIALOG_MIN_WIDTH (pixel: PIXEL_DIALOG_MIN_WIDTH).
@export var panel_width: int = 0:
	set(value):
		panel_width = maxi(0, value)
		refresh_metrics()

## The whole panel (title, body, content, buttons) stays within this share of the
## viewport height; the content scrolls inside it. 0 (with max_height_px 0) never scrolls.
@export_range(0.0, 1.0, 0.01) var max_height_ratio: float = TaDefaults.MODAL_MAX_HEIGHT_RATIO:
	set(value):
		max_height_ratio = clampf(value, 0.0, 1.0)
		_fit_height()

## The panel also stays within this many px (a 4K screen makes 80 % very tall).
## 0 is no pixel cap. The smaller cap wins.
@export var max_height_px: int = 0:
	set(value):
		max_height_px = maxi(0, value)
		_fit_height()

var _panel: PanelContainer
var _head: PanelContainer
var _title: Label
var _close: Button
var _body: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _footer: HBoxContainer
var _confirm: Button
var _cancel: Button
var _field: LineEdit
var _latched: bool = false


func _init() -> void:
	super()
	theme_type_variation = "TaModal"
	z_index = 40
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.z_index = 1
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = "TaModal"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)
	var column := VBoxContainer.new()
	_panel.add_child(column)
	# The title row wears the header rule (Modern: the accent rule under panel headers).
	_head = PanelContainer.new()
	_head.theme_type_variation = "TaDialogHeader"
	column.add_child(_head)
	var header := HBoxContainer.new()
	_head.add_child(header)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.theme_type_variation = "TaTitle"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close = TaButton.new()
	_close.press_sound = &"close"
	_close.text = TaDefaults.MODAL_CLOSE
	_close.pressed.connect(_on_cancel)
	header.add_child(_close)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible = false
	column.add_child(_body)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.minimum_size_changed.connect(_fit_height)
	_scroll.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(_footer)
	_cancel = TaButton.new()
	_cancel.press_sound = &"close"
	_cancel.pressed.connect(_on_cancel)
	_footer.add_child(_cancel)
	_confirm = TaButton.new()
	_confirm.press_sound = &"confirm"
	_confirm.pressed.connect(_on_confirm)
	_footer.add_child(_confirm)
	_apply_title()
	_apply_body()
	_apply_buttons()
	refresh_metrics()


func _ready() -> void:
	TaJuice.bind_hover(_confirm)
	TaJuice.bind_hover(_cancel)
	TaJuice.bind_hover(_close)
	get_viewport().size_changed.connect(_fit_height)


func get_content() -> Control:
	return _content


func get_panel() -> PanelContainer:
	return _panel


func get_confirm_button() -> Button:
	return _confirm


func get_cancel_button() -> Button:
	return _cancel


func get_close_button() -> Button:
	return _close


## One-line text entry above the buttons. Enter confirms. Read get_text_field().text
## in your confirmed handler. max_length 0 is unlimited. Calling again reuses the field.
func add_text_field(text: String = "", max_length: int = 0, placeholder: String = "") -> LineEdit:
	if not is_instance_valid(_field):
		_field = LineEdit.new()
		_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_field.text_submitted.connect(func(_submitted: String) -> void: _on_confirm())
		_content.add_child(_field)
	_field.text = text
	_field.max_length = maxi(0, max_length)
	_field.placeholder_text = placeholder
	return _field


func get_text_field() -> LineEdit:
	return _field if is_instance_valid(_field) else null


## Cost chips for a confirm card: [["⏱", "15 min"], ["⚡", "-2"]]. Each entry is
## [glyph, text] with an optional tone, or a plain String. Toned TaBadges, so they
## follow the look and look.tones; colour emoji belong on untoned chips (TaBadge.cost_row).
## Returns the row.
func add_costs(costs: Array) -> HBoxContainer:
	var row := TaBadge.cost_row(costs)
	_content.add_child(row)
	return row


## A labelled one-of-N choice (mode, amount, target). Returns the TaToggleGroup;
## read get_selected() in your confirmed handler.
func add_options(caption: String, options: PackedStringArray, selected: int = 0) -> TaToggleGroup:
	if not caption.is_empty():
		var label := Label.new()
		label.text = caption
		label.theme_type_variation = "TaCaption"
		_content.add_child(label)
	var group := TaToggleGroup.new()
	for option in options:
		group.add_option(option)
	group.set_selected(PackedInt32Array([clampi(selected, 0, maxi(0, options.size() - 1))]))
	_content.add_child(group)
	return group


## Bullet notes under the choices ("Soak doubles runoff"). Returns their column.
func add_bullets(lines: PackedStringArray) -> VBoxContainer:
	var column := VBoxContainer.new()
	for line in lines:
		var label := Label.new()
		label.text = "• " + line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = _body.custom_minimum_size.x
		column.add_child(label)
	_content.add_child(column)
	return column


## Empty the content slot (text field included) so one sheet can be rebuilt per action.
func clear_content() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_field = null


func refresh_metrics() -> void:
	if not is_instance_valid(_panel):
		return
	var width := panel_width
	if width <= 0:
		width = TaLook.metric(TaDefaults.DIALOG_MIN_WIDTH, TaDefaults.PIXEL_DIALOG_MIN_WIDTH)
	_panel.custom_minimum_size.x = width
	if is_instance_valid(_body):
		var margin := TaLook.metric(TaDefaults.PANEL_MARGIN, TaDefaults.PIXEL_PANEL_MARGIN)
		_body.custom_minimum_size.x = maxi(0, width - margin * 2)
	_fit_height()


func show_modal() -> void:
	_latched = false
	_apply_title()
	_apply_body()
	_apply_buttons()
	open()


func hide_modal() -> void:
	close()


func handle_cancel() -> void:
	if (is_instance_valid(_cancel) and _cancel.visible) or closable:
		_on_cancel()
	else:
		_on_confirm()


func _on_opened() -> void:
	_fit_height()


func _focus_default() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_field) and _field.is_visible_in_tree():
		_field.grab_focus()
		_field.caret_column = _field.text.length()
	elif is_instance_valid(_confirm) and _confirm.is_visible_in_tree():
		_confirm.grab_focus()
	elif TaFocus.focus_first(_content) == null and is_instance_valid(_close) and _close.visible:
		_close.grab_focus()


## The cap is for the whole panel, so the body gets what the title, text, buttons,
## and panel margins leave over. (1.10 capped only the body: 986 px on a 1080 screen.)
func _fit_height() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_content):
		return
	var cap := INF
	if is_inside_tree():
		if max_height_ratio > 0.0:
			cap = get_viewport_rect().size.y * max_height_ratio
		if max_height_px > 0:
			cap = minf(cap, float(max_height_px))
	if is_inf(cap) or not is_instance_valid(_panel):
		TaFit.fit_scroll(_scroll, 0.0)
		return
	var chrome := _panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	TaFit.fit_scroll(_scroll, maxf(cap - chrome, 1.0))


func _apply_title() -> void:
	if is_instance_valid(_title):
		_title.text = title
		_title.visible = not title.is_empty()
	_sync_head()


## No title and no close: no header row (its rule would sit alone over the body).
func _sync_head() -> void:
	if is_instance_valid(_head):
		_head.visible = not title.is_empty() or closable


func _apply_body() -> void:
	if is_instance_valid(_body):
		_body.text = body
		_body.visible = not body.is_empty()


func _apply_buttons() -> void:
	if is_instance_valid(_confirm):
		_confirm.text = confirm_text
		_confirm.visible = not confirm_text.is_empty()
	if is_instance_valid(_cancel):
		_cancel.text = cancel_text
		_cancel.visible = not cancel_text.is_empty()
	if is_instance_valid(_close):
		_close.visible = closable
	_sync_head()
	if is_instance_valid(_footer):
		_footer.visible = not confirm_text.is_empty() or not cancel_text.is_empty()


func _on_confirm() -> void:
	if _latched:
		return
	_latched = true
	confirmed.emit()
	hide_modal()


func _on_cancel() -> void:
	if _latched:
		return
	_latched = true
	canceled.emit()
	hide_modal()
