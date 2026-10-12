class_name TaToast
extends PanelContainer

# AGENT: One toast row. Created by TaToastHost. Component layer.
# INVARIANT: Lifetime is host-owned. Fade uses MOTION_OPEN_SECONDS.
# DO NOT: Autoload. Do not invent durations.

## Short message panel. Prefer TaToastHost.show_message over placing this.

signal dismissed

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

@export var tone: TaBadge.Tone = TaBadge.Tone.DEFAULT:
	set(value):
		tone = value
		_apply_tone()

## Play the kit's notify sound when the toast shows.
@export var notify_sound: bool = true

## A tone from look.tones. Wins over tone while not empty.
@export var tone_name: String = "":
	set(value):
		tone_name = value
		_apply_tone()

var _label: Label
var _width: float = 0.0
var _painting: bool = false
var _hold_seconds: float = TaDefaults.TOAST_DURATION_SECONDS
var _played: bool = false
var _skip: bool = false
var _finished: bool = false
var _hold: Timer


func _init() -> void:
	theme_type_variation = "TaToast"
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh_metrics()
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_label)
	_fit_label()
	_hold = Timer.new()
	_hold.one_shot = true
	_hold.timeout.connect(_on_hold_elapsed)
	add_child(_hold)
	gui_input.connect(_on_gui_input)
	_apply_text()
	_apply_tone()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_PARENTED:
		_paint_ink()
		_fit_label()


func _ready() -> void:
	_paint_ink()


func present(duration: float = -1.0) -> void:
	if duration < 0.0:
		_hold_seconds = TaLook.current().toast_seconds
	else:
		_hold_seconds = duration
	if is_inside_tree():
		_play()
	elif not tree_entered.is_connected(_play):
		tree_entered.connect(_play, CONNECT_ONE_SHOT)


## Restart the hold without a second open animation. No-op once closing.
func extend(duration: float = -1.0) -> void:
	if _skip:
		return
	var had_hold := _hold_seconds
	present(duration)
	if _played and is_instance_valid(_hold) and _hold.is_inside_tree():
		_hold.start(_hold_seconds if _hold_seconds > 0.0 else had_hold)


func is_closing() -> bool:
	return _skip


func refresh_metrics() -> void:
	custom_minimum_size.x = _max_width()
	_fit_label()


func get_hold_seconds() -> float:
	return _hold_seconds


func dismiss() -> void:
	if _skip:
		return
	_skip = true
	_hold.stop()
	_finish_close()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismiss()
		accept_event()


func _apply_text() -> void:
	if is_instance_valid(_label):
		_label.text = text


func _apply_tone() -> void:
	if not tone_name.is_empty():
		theme_type_variation = TaThemeBuilder.tone_type("TaToast", tone_name)
		_paint_ink()
		return
	match tone:
		TaBadge.Tone.ACCENT:
			theme_type_variation = "TaToastAccent"
		TaBadge.Tone.MUTED:
			theme_type_variation = "TaToastMuted"
		TaBadge.Tone.DANGER:
			theme_type_variation = "TaToastDanger"
		TaBadge.Tone.SUCCESS:
			theme_type_variation = "TaToastSuccess"
		TaBadge.Tone.WARNING:
			theme_type_variation = "TaToastWarning"
		_:
			theme_type_variation = "TaToast"
	_paint_ink()


## The tone's ink from the nearest Theme that has it (see TaBadge._paint_ink).
func _paint_ink() -> void:
	if _painting or not is_instance_valid(_label):
		return
	var type_name := StringName(theme_type_variation)
	var source := TaThemeBuilder.theme_with_color(self, "font_color", type_name)
	if source == null or type_name.is_empty():
		return
	_painting = true
	TaThemeBuilder.paint_label(_label, source, type_name)
	_painting = false


func _play() -> void:
	if _played:
		return
	_played = true
	if notify_sound:
		TaSfx.play_on(self, TaSfx.notify())
	_life()


func _life() -> void:
	var open := TaJuice.open_control(self)
	if open:
		await open.finished
	if not is_inside_tree() or _skip:
		if not _finished:
			_on_play_finished()
		return
	# Reduced motion skips the open tween, so this can run from tree_entered
	# before the hold Timer child is in the tree. Starting it then is a no-op.
	if not _hold.is_inside_tree():
		await _hold.ready
	_hold.start(_hold_seconds)


func _on_hold_elapsed() -> void:
	if _skip:
		return
	_skip = true
	_finish_close()


func _finish_close() -> void:
	if not is_inside_tree():
		_on_play_finished()
		return
	var close := TaJuice.close_control(self)
	if close:
		await close.finished
	_on_play_finished()


## An autowrap Label measures its height at its current width, which is 0 before
## layout: one word per line, and each toast came out ~400 px tall. Give it the
## real width (toast width minus the panel's content margins) up front.
func _fit_label() -> void:
	if not is_instance_valid(_label):
		return
	var inset := 0.0
	if is_inside_tree():
		var box := get_theme_stylebox("panel")
		if box != null:
			inset = box.get_minimum_size().x
	_label.custom_minimum_size.x = maxf(0.0, _max_width() - inset)


## Width for this toast in px (a TaToastHost with max_width sets it). 0 is the look's.
func set_width(px: float) -> void:
	_width = maxf(0.0, px)
	refresh_metrics()


func _max_width() -> float:
	if _width > 0.0:
		return _width
	return float(TaLook.metric(TaDefaults.TOAST_MAX_WIDTH, TaDefaults.PIXEL_TOAST_MAX_WIDTH))


func _on_play_finished() -> void:
	if _finished:
		return
	_finished = true
	dismissed.emit()
	queue_free()
