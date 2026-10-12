extends VBoxContainer

# AGENT: Above-the-fold kit tab. Stranger 10-second comprehension.
# INVARIANT: Button, ProgressBar, Dialog, Tag, Radial, dropdown, FieldRow visible.
# DO NOT: Load res://demo.

const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _Field := preload("res://addons/theme_assist/src/components/field/ta_field_row.gd")
const _Tag := preload("res://addons/theme_assist/src/components/tag/ta_tag.gd")
const _Radial := preload("res://addons/theme_assist/src/components/radial/ta_radial.gd")
const _Sort := preload("res://addons/theme_assist/src/components/list/ta_sort_list.gd")

var _host: Control


func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	name = "Kit"
	var blurb := Label.new()
	blurb.text = (
			"Every Ta* component, wearing the live look. Presets are starting points: tune "
			+ "the tokens on the right and Save, and your whole project wears it."
	)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)
	var button := TaButton.new()
	button.name = "TaButton"
	button.text = "TaButton: hover, focus, press, sound"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_put("TaButton", button, "button press focus sound juice")
	if is_instance_valid(_host) and _host.has_method("mark_registry_type"):
		_host.mark_registry_type("TaButton")
	var bar := ProgressBar.new()
	bar.name = "KitProgressBar"
	bar.value = 62
	bar.show_percentage = true
	_put("ProgressBar", bar, "bar")
	var options := OptionButton.new()
	options.name = "KitDropdown"
	options.add_item("Alpha")
	options.add_item("Beta")
	options.add_item("Gamma")
	options.select(1)
	_put("OptionButton", options, "dropdown")
	var tag := _Tag.new()
	tag.name = "KitTag"
	tag.text = "Quest"
	tag.dismissible = true
	_put("TaTag", tag, "tag")
	var radial := _Radial.new()
	radial.name = "KitRadial"
	radial.set_caption("XP")
	radial.set_value(72)
	_put("TaRadial", radial, "radial")
	var field := _Field.new()
	field.name = "TaFieldRow"
	field.caption = "Name"
	var edit := LineEdit.new()
	edit.text = "Joker"
	field.set_field(edit)
	_put("TaFieldRow", field, "field inspector")
	if is_instance_valid(_host) and _host.has_method("mark_registry_type"):
		_host.mark_registry_type("TaFieldRow")
	var sort := _Sort.new()
	sort.name = "KitSortList"
	sort.set_items(PackedStringArray(["Oak", "Ash", "Elm"]))
	_put("TaSortList", sort, "list")
	var row := HBoxContainer.new()
	row.add_child(_btn("Dialog", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_dialog"):
			_host.show_dialog()
	))
	row.add_child(_btn("Pause", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_pause_overlay"):
			_host.show_pause_overlay()
	))
	_put("TaDialog", row, "pause dialog")


func _put(key: String, node: Control, extra: String = "") -> void:
	add_child(_UI.cell(key, node, extra))


func _btn(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	return button
