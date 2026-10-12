@tool
extends Control

# AGENT: Drop-in HUD strip PackedScene. Chip + TaBar + toast-host hook.
# INVARIANT: get_toast_host returns the placed host. Display only.
# DO NOT: Autoload. Do not own gold/HP backends. Do not load res://demo.

const _Bar := preload("res://addons/theme_assist/src/components/bar/ta_bar.gd")
const _DropIn := preload("res://addons/theme_assist/src/core/ta_drop_in.gd")

var _chip: TaChip
var _bar: PanelContainer
var _host: TaToastHost
var _margin: MarginContainer


func _ready() -> void:
	if get_child_count() > 0:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	refresh_metrics()
	_chip = TaChip.new()
	_chip.set_caption("Gold")
	_chip.set_value(120)
	row.add_child(_chip)
	_bar = _Bar.new()
	_bar.set_caption("HP")
	_bar.set_value(62)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bar)
	_host = TaToastHost.new()
	add_child(_host)
	TaJuice.bind_tree(self)
	_DropIn.ensure_theme(self)


## Edge margin and gap on the look's grid (Pixel had the HD 8 px, twice its spacing).
func refresh_metrics() -> void:
	var gap := TaLook.metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)
	if is_instance_valid(_margin):
		for side in ["margin_left", "margin_top", "margin_right"]:
			_margin.add_theme_constant_override(side, gap)
		var row := _margin.get_child(0) as HBoxContainer if _margin.get_child_count() > 0 else null
		if row != null:
			row.add_theme_constant_override("separation", gap)


## Editor save: keep the self-paint out of your scene file (see TaDropIn).
func _notification(what: int) -> void:
	_DropIn.strip_for_save(self, what)


func get_toast_host() -> TaToastHost:
	return _host


func get_bar() -> PanelContainer:
	return _bar


func get_chip() -> TaChip:
	return _chip
