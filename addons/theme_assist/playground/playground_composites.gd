extends VBoxContainer

# AGENT: TaRegistry composite gallery plus pause/HUD/options launchers.
# INVARIANT: Every registry type is instanced and marked on the playground.
# DO NOT: Load res://demo. Pause starts hidden so the lab stays usable.

const _HUD := "res://addons/theme_assist/scenes/hud.tscn"
const _OPTIONS := "res://addons/theme_assist/scenes/options.tscn"
const _ICON := "res://addons/theme_assist/icons/ta_slot.svg"
const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _Registry := preload("res://addons/theme_assist/src/core/ta_registry.gd")

var _host: Control


func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	_heading("Composites")
	_caption("Every Ta* widget. Pause / HUD / Options are drop-in slices.")
	_badges()
	_chip_bar()
	_slots()
	_inspector_windows()
	_hint_rebind()
	_sample_toast()
	_launchers()
	_hud_slice()
	_options_slice()


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


func _badges() -> void:
	var row := HBoxContainer.new()
	for spec in [
		["Default", TaBadge.Tone.DEFAULT],
		["Accent", TaBadge.Tone.ACCENT],
		["Muted", TaBadge.Tone.MUTED],
	]:
		var badge := TaBadge.new()
		badge.name = "TaBadge"
		badge.text = String(spec[0])
		badge.tone = spec[1] as TaBadge.Tone
		row.add_child(badge)
	_put("TaBadge", row, "badge")
	_mark("TaBadge")
	var hover := Label.new()
	hover.text = "Hover for TaItemTooltip"
	var tip := TaItemTooltip.new()
	tip.name = "TaItemTooltip"
	tip.title = "Tooltip"
	tip.body = "Kit hover card. Not a native tooltip."
	tip.attach(hover)
	_put("TaItemTooltip", hover, "tooltip")
	_mark("TaItemTooltip")


func _chip_bar() -> void:
	var chip := TaChip.new()
	chip.name = "TaChip"
	chip.set_caption("Gold")
	chip.set_badge("NEW")
	chip.set_value(120)
	_put("TaChip", chip, "chip hud")
	_mark("TaChip")
	var bar := TaBar.new()
	bar.name = "TaBar"
	bar.set_caption("HP")
	bar.set_value(62)
	_put("TaBar", bar, "progress")
	_mark("TaBar")


func _slots() -> void:
	var slot := TaSlot.new()
	slot.name = "TaSlot"
	slot.tooltip_title = "Slot"
	slot.tooltip_body = "Display cell. No inventory backend."
	slot.badge_text = "1"
	slot.selected = true
	slot.icon = _Registry.load_texture(_ICON)
	_put("TaSlot", slot)
	_mark("TaSlot")
	var grid := TaSlotGrid.new()
	grid.name = "TaSlotGrid"
	grid.grid_columns = 4
	grid.slot_count = 8
	var icon: Texture2D = _Registry.load_texture(_ICON)
	for i in 8:
		var cell := grid.get_slot(i)
		if cell == null:
			continue
		cell.tooltip_title = "Chip %d" % (i + 1)
		cell.tooltip_body = "Display cell."
		if i < 3 and icon != null:
			cell.icon = icon
			cell.badge_text = str(i + 1)
	_put("TaSlotGrid", grid, "grid inventory")
	_mark("TaSlotGrid")


func _inspector_windows() -> void:
	var inspect := TaInspector.new()
	inspect.name = "TaInspector"
	inspect.add_row("Name", _readonly("Joker"))
	inspect.add_row("Value", _readonly("+12"))
	_put("TaInspector", inspect)
	_mark("TaInspector")
	var win := TaWindow.new()
	win.name = "TaWindow"
	win.title = "TaWindow"
	win.get_content().add_child(_readonly("Content slot."))
	_put("TaWindow", win)
	_mark("TaWindow")
	var tabs := TaTabWindow.new()
	tabs.name = "TaTabWindow"
	tabs.title = "TaTabWindow"
	_put("TaTabWindow", tabs, "tabs")
	tabs.add_page("Stats", _readonly("ATK 12   DEF 4"))
	tabs.add_page("Notes", _readonly("Tabbed window. Not docking."))
	_mark("TaTabWindow")


func _hint_rebind() -> void:
	var hint := TaPromptHint.new()
	hint.name = "TaPromptHint"
	_put("TaPromptHint", hint)
	_mark("TaPromptHint")
	var rebind := TaRebindRow.new()
	rebind.name = "TaRebindRow"
	rebind.action = &"ui_focus_next"
	_put("TaRebindRow", rebind, "rebind input")
	_mark("TaRebindRow")


func _sample_toast() -> void:
	var toast := TaToast.new()
	toast.name = "TaToast"
	toast.text = "Toast sample"
	_put("TaToast", toast)
	_mark("TaToast")
	_put("TaToastHost", _readonly("Host is top-right on the playground root."))
	_put("TaTransition", _readonly("Fade / wipe live on the Fanfare page."))
	_put("TaDialog", _readonly("Use Dialog in Drop-in slices."))
	_put("TaInfoPopup", _readonly("Use Info popup in Drop-in slices."))


func _launchers() -> void:
	_heading("Drop-in slices")
	var row := HBoxContainer.new()
	row.add_child(_btn("Pause overlay", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_pause_overlay"):
			_host.show_pause_overlay()
	))
	row.add_child(_btn("Options overlay", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_options_overlay"):
			_host.show_options_overlay()
	))
	row.add_child(_btn("Dialog", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_dialog"):
			_host.show_dialog()
	))
	row.add_child(_btn("Info popup", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_info"):
			_host.show_info(row)
	))
	_put("PauseOverlay", row, "pause options dialog popup")


func _hud_slice() -> void:
	var wrap := Control.new()
	wrap.name = "HudStripWrap"
	wrap.custom_minimum_size.y = _UI.ui(56)
	wrap.clip_contents = true
	var packed := load(_HUD) as PackedScene
	if packed == null:
		return
	var hud := packed.instantiate() as Control
	hud.name = "HudStrip"
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	wrap.add_child(hud)
	hud.ready.connect(func() -> void: _fit_hud_wrap(wrap, hud))
	_put("HudStrip", wrap, "hud")


## The strip is a full-screen overlay; the cell shows its top row at its real height
## (a fixed 56 px clipped the chip and bar borders).
func _fit_hud_wrap(wrap: Control, hud: Control) -> void:
	var strip := hud.get_child(0) as Control if hud.get_child_count() > 0 else null
	if strip == null:
		return
	var fit := func() -> void: wrap.custom_minimum_size.y = strip.get_combined_minimum_size().y
	fit.call()
	strip.minimum_size_changed.connect(fit)


func _options_slice() -> void:
	var packed := load(_OPTIONS) as PackedScene
	if packed == null:
		return
	var options := packed.instantiate() as Control
	options.name = "OptionsPanel"
	_put("OptionsPanel", options, "options")


func _readonly(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _btn(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	return button
