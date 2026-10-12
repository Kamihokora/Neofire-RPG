extends VBoxContainer

# AGENT: Stock Control gallery for the shipped playground.
# INVARIANT: One live instance of every Control class the Theme paints.
# DO NOT: Invent kit widgets here. Composites live in playground_composites.gd.

const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")

const STOCK_CLASSES := [
	"Button",
	"OptionButton",
	"MenuButton",
	"LinkButton",
	"CheckBox",
	"CheckButton",
	"LineEdit",
	"TextEdit",
	"SpinBox",
	"HSlider",
	"VSlider",
	"ProgressBar",
	"ItemList",
	"Tree",
	"TabBar",
	"TabContainer",
	"ScrollContainer",
	"HSeparator",
	"VSeparator",
	"HSplitContainer",
	"ColorPickerButton",
	"Panel",
	"Window",
]


func _ready() -> void:
	if get_child_count() > 0:
		return
	_heading("Stock controls")
	_caption("Every Control the Theme paints. Twist tokens on the right.")
	_semantics()
	var button := Button.new()
	button.name = "Button"
	button.text = "Button"
	_put("Button", button)
	var disabled := Button.new()
	disabled.name = "ButtonDisabled"
	disabled.text = "Disabled"
	disabled.disabled = true
	_put("Button", disabled, "disabled")
	var options := OptionButton.new()
	options.name = "OptionButton"
	options.add_item("Alpha")
	options.add_item("Beta")
	options.add_item("Gamma")
	options.select(1)
	_put("OptionButton", options, "dropdown")
	var menu := MenuButton.new()
	menu.name = "MenuButton"
	menu.text = "MenuButton"
	menu.get_popup().add_item("One")
	menu.get_popup().add_item("Two")
	_put("MenuButton", menu)
	var link := LinkButton.new()
	link.name = "LinkButton"
	link.text = "LinkButton"
	_put("LinkButton", link)
	var check := CheckBox.new()
	check.name = "CheckBox"
	check.text = "CheckBox"
	_put("CheckBox", check)
	var check_btn := CheckButton.new()
	check_btn.name = "CheckButton"
	check_btn.text = "CheckButton"
	_put("CheckButton", check_btn)
	var edit := LineEdit.new()
	edit.name = "LineEdit"
	edit.placeholder_text = "LineEdit"
	_put("LineEdit", edit, "text field")
	var area := TextEdit.new()
	area.name = "TextEdit"
	area.placeholder_text = "TextEdit"
	area.custom_minimum_size.y = _UI.ui(64)
	_put("TextEdit", area, "text field")
	var spin := SpinBox.new()
	spin.name = "SpinBox"
	spin.value = 3
	_put("SpinBox", spin)
	var slider := HSlider.new()
	slider.name = "HSlider"
	slider.min_value = 0
	slider.max_value = 100
	slider.value = 40
	slider.custom_minimum_size = Vector2(_UI.ui(160), _UI.ui(24))
	_put("HSlider", slider, "slider")
	var vslide := VSlider.new()
	vslide.name = "VSlider"
	vslide.min_value = 0
	vslide.max_value = 100
	vslide.value = 40
	vslide.custom_minimum_size = Vector2(_UI.ui(24), _UI.ui(72))
	_put("VSlider", vslide, "slider")
	var bar := ProgressBar.new()
	bar.name = "ProgressBar"
	bar.value = 55
	bar.show_percentage = true
	bar.custom_minimum_size.y = _UI.ui(24)
	_put("ProgressBar", bar, "bar")
	var vbar := ProgressBar.new()
	vbar.name = "ProgressBarVertical"
	vbar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	vbar.value = 55
	vbar.show_percentage = false
	vbar.custom_minimum_size = Vector2(_UI.ui(24), _UI.ui(72))
	vbar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_put("ProgressBar", vbar, "vertical bar")
	_lists()
	_tabs_and_split()
	var color_btn := ColorPickerButton.new()
	color_btn.name = "ColorPickerButton"
	color_btn.custom_minimum_size = Vector2(_UI.ui(48), _UI.ui(24))
	color_btn.color = Color(0.22, 0.76, 0.48)
	_put("ColorPickerButton", color_btn)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(_UI.ui(120), _UI.ui(36))
	_put("Panel", panel)
	_window_row()
	var tip := Label.new()
	tip.text = "Hover me (TooltipPanel)"
	tip.tooltip_text = "Native tooltip, themed."
	_put("TooltipPanel", tip, "tooltip")


func shown_classes() -> PackedStringArray:
	return PackedStringArray(STOCK_CLASSES)


func _put(key: String, node: Control, extra: String = "") -> void:
	add_child(_UI.cell(key, node, extra))


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


func _semantics() -> void:
	_heading("Type ramp / semantic")
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "TaTitle"
	title.theme_type_variation = "TaTitle"
	box.add_child(title)
	var caption := Label.new()
	caption.text = "TaCaption"
	caption.theme_type_variation = "TaCaption"
	box.add_child(caption)
	var row := HBoxContainer.new()
	box.add_child(row)
	for spec in [
		["Danger", "TaDanger"],
		["Success", "TaSuccess"],
		["Warning", "TaWarning"],
	]:
		var button := Button.new()
		button.text = String(spec[0])
		button.theme_type_variation = String(spec[1])
		row.add_child(button)
	var tones := HBoxContainer.new()
	box.add_child(tones)
	for spec in [
		["Danger", "TaDangerLabel"],
		["Success", "TaSuccessLabel"],
		["Warning", "TaWarningLabel"],
	]:
		var label := Label.new()
		label.text = String(spec[0])
		label.theme_type_variation = String(spec[1])
		tones.add_child(label)
	_put("TaTitle", box, "caption danger success warning")


func _lists() -> void:
	var list := ItemList.new()
	list.name = "ItemList"
	list.custom_minimum_size.y = _UI.ui(88)
	list.add_item("ItemList A")
	list.add_item("ItemList B")
	list.add_item("ItemList C")
	_put("ItemList", list)
	var tree := Tree.new()
	tree.name = "Tree"
	tree.custom_minimum_size.y = _UI.ui(120)
	tree.columns = 2
	tree.column_titles_visible = true
	tree.set_column_title(0, "Name")
	tree.set_column_title(1, "Kind")
	tree.hide_root = false
	var root := tree.create_item()
	root.set_text(0, "Tree")
	root.set_text(1, "root")
	var child := tree.create_item(root)
	child.set_text(0, "Node")
	child.set_text(1, "leaf")
	var sibling := tree.create_item(root)
	sibling.set_text(0, "Other")
	sibling.set_text(1, "leaf")
	_put("Tree", tree, "worktree")
	var sep_row := HBoxContainer.new()
	sep_row.custom_minimum_size.y = _UI.ui(48)
	var left := Label.new()
	left.text = "H"
	sep_row.add_child(left)
	var vsep := VSeparator.new()
	vsep.name = "VSeparator"
	sep_row.add_child(vsep)
	var right := Label.new()
	right.text = "VSeparator"
	sep_row.add_child(right)
	_put("VSeparator", sep_row, "separator")
	var hsep := HSeparator.new()
	hsep.name = "HSeparator"
	_put("HSeparator", hsep, "separator")


func _tabs_and_split() -> void:
	var bar := TabBar.new()
	bar.name = "TabBar"
	bar.add_tab("One")
	bar.add_tab("Two")
	_put("TabBar", bar, "tabs")
	var tabs := TabContainer.new()
	tabs.name = "TabContainer"
	tabs.custom_minimum_size.y = _UI.ui(72)
	var page_a := Label.new()
	page_a.name = "Alpha"
	page_a.text = "TabContainer A"
	tabs.add_child(page_a)
	var page_b := Label.new()
	page_b.name = "Beta"
	page_b.text = "TabContainer B"
	tabs.add_child(page_b)
	_put("TabContainer", tabs, "tabs")
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.custom_minimum_size.y = _UI.ui(56)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var copy := Label.new()
	copy.text = "ScrollContainer\nline 2\nline 3\nline 4"
	scroll.add_child(copy)
	_put("ScrollContainer", scroll, "scrollbar")
	var split := HSplitContainer.new()
	split.name = "HSplitContainer"
	split.custom_minimum_size.y = _UI.ui(48)
	var a := Label.new()
	a.text = "Split L"
	var b := Label.new()
	b.text = "Split R"
	split.add_child(a)
	split.add_child(b)
	_put("HSplitContainer", split, "split")


func _window_row() -> void:
	var win := Window.new()
	win.name = "Window"
	win.title = "Native Window"
	win.size = Vector2i(320, 180)
	win.visible = false
	win.unresizable = true
	win.close_requested.connect(func() -> void: win.hide())
	var body := Label.new()
	body.text = "Themed Window chrome."
	win.add_child(body)
	var box := VBoxContainer.new()
	box.add_child(win)
	var open := Button.new()
	open.text = "Open native Window"
	open.pressed.connect(func() -> void: win.popup_centered())
	box.add_child(open)
	_put("Window", box)
