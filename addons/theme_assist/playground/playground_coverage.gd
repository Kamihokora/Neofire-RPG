extends VBoxContainer

# AGENT: Phase 2 composites for the shipped playground.
# INVARIANT: Every new TaRegistry type is instanced and marked.
# DO NOT: Load res://demo.

const _ICON := "res://addons/theme_assist/icons/ta_slot.svg"
const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _InfoIcon := preload("res://addons/theme_assist/src/components/info_icon/ta_info_icon.gd")
const _Tag := preload("res://addons/theme_assist/src/components/tag/ta_tag.gd")
const _Header := preload("res://addons/theme_assist/src/components/header/ta_header_panel.gd")
const _BtnRow := preload("res://addons/theme_assist/src/components/buttons/ta_button_row.gd")
const _BtnCol := preload("res://addons/theme_assist/src/components/buttons/ta_button_col.gd")
const _Toggle := preload("res://addons/theme_assist/src/components/toggle/ta_toggle_group.gd")
const _VBar := preload("res://addons/theme_assist/src/components/bar/ta_vbar.gd")
const _Radial := preload("res://addons/theme_assist/src/components/radial/ta_radial.gd")
const _Sort := preload("res://addons/theme_assist/src/components/list/ta_sort_list.gd")
const _Reorder := preload("res://addons/theme_assist/src/components/list/ta_reorder_list.gd")
const _Icons := preload("res://addons/theme_assist/src/components/grid/ta_icon_grid.gd")
const _Field := preload("res://addons/theme_assist/src/components/field/ta_field_row.gd")
const _Registry := preload("res://addons/theme_assist/src/core/ta_registry.gd")

var _host: Control


func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	_heading("Coverage")
	_caption("First-class cells: tags, bars, lists, buttons, field row.")
	_info_and_tags()
	_header_and_buttons()
	_bars()
	_lists()
	_icon_grid()
	_heading("Focus, overlays, text")
	_caption("Ring focus keeps a selected toggle visible. Pages scroll past a height cap.")
	_review_cells()


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "TaTitle"
	add_child(label)


func _caption(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "TaCaption"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)


func _mark(type_name: String) -> void:
	if is_instance_valid(_host) and _host.has_method("mark_registry_type"):
		_host.mark_registry_type(type_name)


func _put(key: String, node: Control, extra: String = "") -> void:
	add_child(_UI.cell(key, node, extra))


func _info_and_tags() -> void:
	var row := HBoxContainer.new()
	var info := _InfoIcon.new()
	info.name = "TaInfoIcon"
	info.title = "Info"
	info.body = "Hover or click. TaInfoIcon opens TaInfoPopup."
	row.add_child(info)
	_put("TaInfoIcon", row, "info")
	_mark("TaInfoIcon")
	var tags := HBoxContainer.new()
	var tag := _Tag.new()
	tag.name = "TaTag"
	tag.text = "Quest"
	tag.dismissible = true
	tags.add_child(tag)
	_mark("TaTag")
	var static_tag := _Tag.new()
	static_tag.text = "Static"
	static_tag.dismissible = false
	static_tag.tone = 1
	tags.add_child(static_tag)
	_put("TaTag", tags, "tag")


func _header_and_buttons() -> void:
	var panel := _Header.new()
	panel.name = "TaHeaderPanel"
	panel.title = "Header panel"
	panel.get_content().add_child(_lab("Body slot. Not a window."))
	_put("TaHeaderPanel", panel, "header")
	_mark("TaHeaderPanel")
	var row := _BtnRow.new()
	row.name = "TaButtonRow"
	row.set_captions(PackedStringArray(["Save", "Load", "Quit"]))
	_put("TaButtonRow", row, "buttons")
	_mark("TaButtonRow")
	var col := _BtnCol.new()
	col.name = "TaButtonCol"
	col.set_captions(PackedStringArray(["Resume", "Options"]))
	_put("TaButtonCol", col, "buttons")
	_mark("TaButtonCol")
	var toggles := _Toggle.new()
	toggles.name = "TaToggleGroup"
	toggles.add_option("Low")
	toggles.add_option("Med")
	toggles.add_option("High")
	_put("TaToggleGroup", toggles, "toggle")
	_mark("TaToggleGroup")
	var field := _Field.new()
	field.name = "CoverageFieldRow"
	field.caption = "Seed"
	var edit := LineEdit.new()
	edit.text = "42"
	field.set_field(edit)
	_put("TaFieldRow", field, "field")
	_mark("TaFieldRow")


func _bars() -> void:
	var vbar := _VBar.new()
	vbar.name = "TaVBar"
	vbar.set_caption("MP")
	vbar.set_value(40)
	_put("TaVBar", vbar, "vertical progress")
	_mark("TaVBar")
	var radial := _Radial.new()
	radial.name = "TaRadial"
	radial.set_caption("XP")
	radial.set_value(72)
	_put("TaRadial", radial, "radial progress")
	_mark("TaRadial")


func _lists() -> void:
	var sort := _Sort.new()
	sort.name = "TaSortList"
	sort.set_items(PackedStringArray(["Oak", "Ash", "Elm"]))
	_put("TaSortList", sort, "list sort")
	_mark("TaSortList")
	var reorder := _Reorder.new()
	reorder.name = "TaReorderList"
	reorder.set_items(PackedStringArray(["First", "Second", "Third"]))
	_put("TaReorderList", reorder, "list reorder")
	_mark("TaReorderList")


func _icon_grid() -> void:
	var grid := _Icons.new()
	grid.name = "TaIconGrid"
	grid.grid_columns = 4
	grid.cell_count = 8
	var icon: Texture2D = _Registry.load_texture(_ICON)
	for i in 4:
		grid.set_item(i, icon, str(i + 1))
	_put("TaIconGrid", grid, "icons")
	_mark("TaIconGrid")


func _review_cells() -> void:
	var dial := _Radial.new()
	dial.set_caption_visible(false)
	dial.set_ring_width(6)
	dial.set_center_text("72%")
	dial.set_value(72)
	_put("TaRadial ring", dial, "radial dial ring center")
	var row := HBoxContainer.new()
	row.add_theme_constant_override(
			"separation", TaLook.metric(TaDefaults.SEPARATION * 2, TaDefaults.PIXEL_SEPARATION * 2)
	)
	var phone := Button.new()
	phone.text = "Phone"
	row.add_child(phone)
	TaBadge.attach(phone, "3")
	var ready_button := Button.new()
	ready_button.text = "Ready"
	row.add_child(ready_button)
	ready_button.ready.connect(func() -> void: TaJuice.pulse(ready_button), CONNECT_ONE_SHOT)
	_put("TaBadge.attach", row, "badge unread attach pulse ready")
	var danger := HBoxContainer.new()
	for pair in [["Continue", ""], ["New game", "TaDangerQuiet"], ["Wipe save", "TaDanger"]]:
		var b := Button.new()
		b.text = pair[0]
		b.theme_type_variation = pair[1]
		danger.add_child(b)
	_put("TaDangerQuiet", danger, "danger quiet muted destructive")
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.text = "Regular, [b]bold[/b], [i]italic (face_italic)[/i], [s]done[/s] 🌱"
	_put("Text styles", rich, "rich text bold italic strike emoji")
	var launch := HBoxContainer.new()
	var page_button := Button.new()
	page_button.text = "Open page"
	page_button.pressed.connect(_open_page)
	launch.add_child(page_button)
	var ask_button := Button.new()
	ask_button.text = "Rename"
	ask_button.pressed.connect(_open_prompt)
	launch.add_child(ask_button)
	var card_button := Button.new()
	card_button.text = "Water"
	card_button.pressed.connect(_open_confirm_card)
	launch.add_child(card_button)
	var layer_button := Button.new()
	layer_button.text = "Bare overlay"
	layer_button.pressed.connect(_open_overlay)
	launch.add_child(layer_button)
	_put("TaModal page", launch, "modal page drawer prompt rename scroll close")
	call_deferred("_overlay_layer")
	_mark("TaOverlay")
	_popover_cell()


## TaPopover: a card beside whichever slot you press; a press elsewhere closes it and
## still lands where it was aimed (press another slot: its card opens).
func _popover_cell() -> void:
	var row := HBoxContainer.new()
	var card := TaPopover.new()
	card.name = "TaPopover"
	var title := Label.new()
	title.theme_type_variation = "TaTitle"
	card.get_content().add_child(title)
	var cost := TaBadge.cost_row([["⏱", "15 min"], ["⚡", "-2"]])
	card.get_content().add_child(cost)
	var water := Button.new()
	water.text = "Water"
	water.pressed.connect(card.close)
	card.get_content().add_child(water)
	for plant in ["Basil", "Mint", "Sage"]:
		var slot := Button.new()
		slot.text = plant
		slot.pressed.connect(
			func() -> void:
				title.text = plant
				card.open(slot)
		)
		row.add_child(slot)
	row.add_child(card)
	_put("TaPopover", row, "popover card anchored beside click outside")
	_mark("TaPopover")


func _open_page() -> void:
	var page := _sheet("PlaygroundPage")
	page.title = "Journal"
	page.confirm_text = ""
	page.closable = true
	if page.get_content().get_child_count() == 0:
		for i in 40:
			page.get_content().add_child(_lab("Day %d: the grove grew." % (i + 1)))
	page.show_modal()


func _open_prompt() -> void:
	var ask := _sheet("PlaygroundPrompt")
	ask.title = "Nickname"
	ask.cancel_text = "Cancel"
	ask.add_text_field("Sprout", 16)
	ask.show_modal()


## Confirm card: costs, one choice, notes, Back | Water. Rebuilt each open.
func _open_confirm_card() -> void:
	var card := _sheet("PlaygroundConfirm")
	card.title = "Water"
	card.body = "Water the flowering pots."
	card.cancel_text = "Back"
	card.confirm_text = "Water"
	card.clear_content()
	card.add_costs([["⏱", "15 min"], ["⚡", "-2"]])
	card.add_options("Amount", PackedStringArray(["Light", "Soak"]))
	card.add_bullets(PackedStringArray(["Soak doubles runoff."]))
	card.show_modal()


## TaOverlay with your own panel: dimmer, focus trap, Esc, router, no layout.
func _open_overlay() -> void:
	_overlay_layer().open()


func _overlay_layer() -> TaOverlay:
	var parent: Node = _host if is_instance_valid(_host) else self
	var layer := parent.get_node_or_null("TaOverlay") as TaOverlay
	if layer == null:
		layer = TaOverlay.new()
		layer.name = "TaOverlay"
		layer.z_index = 40
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.z_index = 1
		layer.add_child(center)
		var panel := PanelContainer.new()
		center.add_child(panel)
		var close := Button.new()
		close.text = "Your content here. Esc or click to close."
		close.pressed.connect(layer.close)
		panel.add_child(close)
		parent.add_child(layer)
	return layer


func _sheet(node_name: String) -> TaModal:
	var parent: Node = _host if is_instance_valid(_host) else self
	var existing := parent.get_node_or_null(node_name) as TaModal
	if existing != null:
		return existing
	var sheet := TaModal.new()
	sheet.name = node_name
	parent.add_child(sheet)
	return sheet


func _lab(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
