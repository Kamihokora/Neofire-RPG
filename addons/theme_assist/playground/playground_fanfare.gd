extends PanelContainer

# AGENT: Fanfare page for the shipped playground. Previews presets, SFX, transitions.
# INVARIANT: Every TaFanfare preset and TaSfx name has a button.
# DO NOT: Persist. Do not quit the tree.

const _Fanfare := preload("res://addons/theme_assist/src/core/ta_fanfare.gd")

var _host: Control
var _score: Label
var _stage_panel: Control
var _preview_idx: int = 0
var _preview_names: PackedStringArray = PackedStringArray()


func setup(host: Control, score: Label) -> void:
	_host = host
	_score = score


func _ready() -> void:
	if get_child_count() > 0:
		return
	var col := VBoxContainer.new()
	add_child(col)
	var title_row := HBoxContainer.new()
	col.add_child(title_row)
	var title := Label.new()
	title.text = "Fanfare"
	title.theme_type_variation = "TaTitle"
	title_row.add_child(title)
	if is_instance_valid(_score):
		title_row.add_child(_score)
	var hint := Label.new()
	hint.text = "Kit fanfare. Reduce motion (top bar) skips juice and SFX. Silent boxes still toast SFX names."
	hint.theme_type_variation = "TaCaption"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(hint)
	col.add_child(_btn("Preview all", preview_all))
	_stage_panel = _make_target()
	col.add_child(_stage_panel)
	col.add_child(_row("Presets", _Fanfare.preset_names(), _on_preset))
	col.add_child(_row("SFX", TaSfx.names(), _on_sfx))
	col.add_child(_primitives())


func _make_target() -> Control:
	var panel := PanelContainer.new()
	panel.name = "FanfareTarget"
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.name = "FanfareTargetLabel"
	label.text = "Fanfare target"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return panel


func _row(caption: String, names: PackedStringArray, on_press: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := Label.new()
	head.text = caption
	head.theme_type_variation = "TaCaption"
	box.add_child(head)
	var flow := HFlowContainer.new()
	box.add_child(flow)
	for item in names:
		var name := String(item)
		flow.add_child(_btn(name, on_press.bind(name)))
	return box


func _primitives() -> VBoxContainer:
	var box := VBoxContainer.new()
	var head := Label.new()
	head.text = "Primitives"
	head.theme_type_variation = "TaCaption"
	box.add_child(head)
	var flow := HFlowContainer.new()
	box.add_child(flow)
	flow.add_child(_btn("Toast", _on_toast))
	flow.add_child(_btn("Punch", func() -> void: TaJuice.punch(_motion_target(), 1.0)))
	flow.add_child(_btn("Shake", func() -> void: TaJuice.shake(_motion_target(), 1.0)))
	flow.add_child(_btn("Roll", _on_roll))
	flow.add_child(_btn("Combo", _on_combo))
	flow.add_child(_btn("Fade", func() -> void: TaTransition.on(_root()).fade_through()))
	flow.add_child(_btn("Wipe", func() -> void: TaTransition.on(_root()).wipe_through()))
	flow.add_child(_btn("Through", func() -> void: TaTransition.on(_root()).through()))
	flow.add_child(_btn("Dialog", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_dialog"):
			_host.show_dialog()
	))
	flow.add_child(_btn("Info", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_info"):
			_host.show_info(self)
	))
	flow.add_child(_btn("Pause", func() -> void:
		if is_instance_valid(_host) and _host.has_method("show_pause_overlay"):
			_host.show_pause_overlay()
	))
	return box


func _btn(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	TaJuice.bind_hover(button)
	return button


func _root() -> Control:
	if is_instance_valid(_host):
		return _host
	return self


func _motion_target() -> Control:
	if is_instance_valid(_score):
		return _score
	if is_instance_valid(_stage_panel):
		return _stage_panel
	return self


func _stage() -> Control:
	if is_instance_valid(_stage_panel):
		return _stage_panel
	return _motion_target()


func _on_preset(preset: String) -> void:
	if preset == "panel_in":
		var stage := _stage()
		stage.visible = false
		_Fanfare.panel_in(stage)
		return
	if preset == "level_up" and is_instance_valid(_score):
		_Fanfare.level_up(_score)
		return
	_Fanfare.play_named(_stage(), preset)


func preview_all() -> void:
	_preview_names = _Fanfare.preset_names()
	_preview_idx = 0
	_preview_step()


func _preview_step() -> void:
	if _preview_idx < 0 or _preview_idx >= _preview_names.size():
		return
	var preset := String(_preview_names[_preview_idx])
	_on_preset(preset)
	_announce(preset)
	_preview_idx += 1
	if _preview_idx < _preview_names.size() and is_inside_tree():
		get_tree().create_timer(0.55).timeout.connect(_preview_step)


func _announce(label: String) -> void:
	if is_instance_valid(_host) and _host.has_method("show_sfx_toast"):
		_host.show_sfx_toast(label)


func _on_sfx(sfx_name: String) -> void:
	TaSfx.play_on(_stage(), TaSfx.stream(sfx_name))
	_announce(sfx_name)


func _toast_host() -> TaToastHost:
	if is_instance_valid(_host) and _host.has_method("get_toast_host"):
		return _host.get_toast_host()
	return null


func _on_toast() -> void:
	var host := _toast_host()
	if host != null:
		host.show_message("Saved", -1.0, TaBadge.Tone.ACCENT)
		_Fanfare.notify(_stage())


func _on_roll() -> void:
	if is_instance_valid(_score):
		TaJuice.roll_number(_score, 250.0, 0.0)


func _on_combo() -> void:
	_on_roll()
	_Fanfare.celebrate(_motion_target())
	_on_toast()
