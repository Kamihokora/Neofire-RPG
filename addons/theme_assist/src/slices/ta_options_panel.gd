@tool
extends PanelContainer

# AGENT: Drop-in options PackedScene. Presentation only — no save file.
# INVARIANT: Volume, fullscreen, vsync, reduce-motion, UI sounds, one TaRebindRow.
# DO NOT: Autoload. Do not persist InputMap. Do not load res://demo.

const _DropIn := preload("res://addons/theme_assist/src/core/ta_drop_in.gd")

signal back_pressed

var _inspector: TaInspector
var _rebind: TaRebindRow
var _volume: HSlider
var _fullscreen: CheckBox
var _vsync: CheckBox
var _motion: CheckBox
var _sfx: CheckBox
var _back: Button


func _ready() -> void:
	if get_child_count() > 0:
		return
	var column := VBoxContainer.new()
	add_child(column)
	var heading := Label.new()
	heading.text = "Options"
	heading.theme_type_variation = "TaTitle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_inspector = TaInspector.new()
	column.add_child(_inspector)
	_volume = HSlider.new()
	_volume.min_value = 0
	_volume.max_value = 100
	_volume.step = 1
	_volume.set_value_no_signal(_volume_from_bus())
	_volume.value_changed.connect(_on_volume)
	_inspector.add_row("Volume", _volume, "Master bus volume")
	_fullscreen = CheckBox.new()
	_fullscreen.button_pressed = (
			DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	_fullscreen.toggled.connect(_on_fullscreen)
	_inspector.add_row("Fullscreen", _fullscreen)
	_vsync = CheckBox.new()
	_vsync.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_vsync.toggled.connect(_on_vsync)
	_inspector.add_row("Vsync", _vsync)
	_motion = CheckBox.new()
	_motion.button_pressed = TaJuice.reduced_motion
	_motion.toggled.connect(_on_motion)
	_inspector.add_row("Reduce motion", _motion)
	_sfx = CheckBox.new()
	_sfx.button_pressed = not TaSfx.muted
	_sfx.toggled.connect(_on_sfx)
	_inspector.add_row("UI sounds", _sfx)
	for box in [_fullscreen, _vsync, _motion, _sfx]:
		_say_state(box)
		box.toggled.connect(func(_on: bool) -> void: _say_state(box))
	_rebind = TaRebindRow.new()
	_rebind.action = &"ui_accept"
	_inspector.add_row("Confirm key", _rebind)
	_back = TaButton.new()
	_back.text = "Back"
	_back.custom_minimum_size.y = TaLook.button_height()
	_back.pressed.connect(_on_back)
	column.add_child(_back)
	custom_minimum_size.x = TaDefaults.PAUSE_PANEL_MIN_WIDTH
	TaJuice.bind_tree(self)
	_DropIn.ensure_theme(self)
	TaFocus.chain(
			[_volume, _fullscreen, _vsync, _motion, _sfx, _rebind, _back],
			TaFocus.Axis.VERTICAL
	)


## Editor save: keep the self-paint out of your scene file (see TaDropIn).
func _notification(what: int) -> void:
	_DropIn.strip_for_save(self, what)


func focus_first() -> void:
	if is_instance_valid(_volume) and _volume.is_inside_tree():
		_volume.grab_focus()


func get_rebind() -> TaRebindRow:
	return _rebind


func get_inspector() -> TaInspector:
	return _inspector


func get_back_button() -> Button:
	return _back


## "On" or "Off" to match the box (every box said "On", ticked or not).
func _say_state(box: CheckBox) -> void:
	box.text = TaDefaults.TOGGLE_ON if box.button_pressed else TaDefaults.TOGGLE_OFF


func _on_back() -> void:
	back_pressed.emit()


func _volume_from_bus() -> float:
	var db := AudioServer.get_bus_volume_db(0)
	if db <= -79.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _on_volume(value: float) -> void:
	if value <= 0.0:
		AudioServer.set_bus_volume_db(0, -80.0)
		return
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(value / 100.0, 0.0, 1.0)))


func _on_fullscreen(pressed: bool) -> void:
	DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if pressed else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _on_vsync(pressed: bool) -> void:
	DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if pressed else DisplayServer.VSYNC_DISABLED
	)


func _on_motion(pressed: bool) -> void:
	TaJuice.reduced_motion = pressed
	TaJuice.snap_tree(self)


func _on_sfx(pressed: bool) -> void:
	TaSfx.muted = not pressed
