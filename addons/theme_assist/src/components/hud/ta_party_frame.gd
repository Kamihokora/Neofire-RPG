class_name TaPartyFrame
extends PanelContainer

# AGENT: Companion frame: portrait slot + name + health bar. Display only.
# INVARIANT: get_portrait() is a ColorRect you can fill or recolour. Until you do, it shows
# the member's initial on a look tone picked by the name. Bar is 0–100.
# DO NOT: Own party members. Do not autoload.

## Small unit frame for a companion HUD.

var _row: HBoxContainer
var _portrait: ColorRect
var _initial: Label
var _name: Label
var _bar: ProgressBar


func _init() -> void:
	theme_type_variation = "TaPartyFrame"
	_row = HBoxContainer.new()
	add_child(_row)
	_portrait = ColorRect.new()
	_row.add_child(_portrait)
	_initial = Label.new()
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.add_child(_initial)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(col)
	_name = Label.new()
	_name.theme_type_variation = "TaCardText"
	_name.text = "Ally"
	col.add_child(_name)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 100
	_bar.show_percentage = false
	col.add_child(_bar)
	refresh_metrics()
	_paint_portrait()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_paint_portrait()


func refresh_metrics() -> void:
	var s := TaLook.metric(TaDefaults.PARTY_PORTRAIT, TaDefaults.PIXEL_PARTY_PORTRAIT)
	if is_instance_valid(_portrait):
		_portrait.custom_minimum_size = Vector2(s, s)
	if is_instance_valid(_bar):
		_bar.custom_minimum_size.x = TaLook.metric(
				TaDefaults.PARTY_BAR_WIDTH, TaDefaults.PIXEL_PARTY_BAR_WIDTH
		)


func set_member_name(text: String) -> void:
	_name.text = text
	_paint_portrait()


func set_health(amount: float) -> void:
	_bar.value = clampf(amount, 0.0, 100.0)


func get_portrait() -> ColorRect:
	return _portrait


## A tone picked by the name (the same member keeps the same colour), the initial on it.
func _paint_portrait() -> void:
	if not is_instance_valid(_portrait):
		return
	var look := TaLook.current()
	var tones := [look.color_success, look.color_accent, look.color_rarity, look.color_warning]
	var who := _name.text if is_instance_valid(_name) else ""
	var tone: Color = tones[absi(who.hash()) % tones.size()]
	_portrait.color = tone
	if is_instance_valid(_initial):
		_initial.text = who.left(1).to_upper()
		_initial.add_theme_color_override("font_color", TaThemeBuilder.ink_on(look, tone))
