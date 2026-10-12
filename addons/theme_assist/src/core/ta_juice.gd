class_name TaJuice
extends Object

# AGENT: Shared hover/press/open/roll/punch motion. Reads TaDefaults.
# INVARIANT: reduced_motion skips tweens. punch/shake do not shift layout position.
# DO NOT: AnimationPlayers. Do not require EditorPlugin.

const _META := "_ta_juice_bound"
const _HOVER_META := "_ta_juice_hovered"
## Per-control press sound: a TaSfx name (TaButton.press_sound sets it). "" is silent.
const PRESS_SOUND_META := &"ta_press_sound"
const _PULSE_META := "_ta_juice_pulse"
const _Sfx := preload("res://addons/theme_assist/src/core/ta_sfx.gd")

## Runtime flag. Seeded from TaDefaults.REDUCED_MOTION. Tests may toggle.
static var reduced_motion: bool = TaDefaults.REDUCED_MOTION
## 0 = none, 1 = defaults, >1 exaggerates hover/punch.
static var intensity: float = 1.0
## True inside a pixel framebuffer (TaDisplay): skip subpixel scale, flash instead. PIXEL
## looks drawn at pixel_scale on an HD canvas scale and tilt like any other.
static var pixel_grid: bool = false
## Degrees a hovered control leans (the look's motion_hover_tilt). 0 is none.
static var hover_tilt: float = 0.0
## The look's fanfare: scales punch and shake on top of intensity.
static var fanfare: float = 1.0
## Optional SFX. Null until bind_hover/bind_tree; kit ticks unless silenced.
static var hover_stream: AudioStream = null
static var press_stream: AudioStream = null
## When true, first bind installs generated kit ticks. Set false for silence.
static var use_kit_sfx: bool = true
static var hover_scale: float = TaDefaults.MOTION_HOVER_SCALE
static var press_scale: float = TaDefaults.MOTION_PRESS_SCALE
static var hover_seconds: float = TaDefaults.MOTION_HOVER_SECONDS
static var press_seconds: float = TaDefaults.MOTION_PRESS_SECONDS
static var open_seconds: float = TaDefaults.MOTION_OPEN_SECONDS
static var roll_seconds: float = TaDefaults.MOTION_ROLL_SECONDS
static var _sfx_ready: bool = false


static func apply_look(look: TaTokens) -> void:
	if look == null:
		return
	hover_scale = look.motion_hover_scale
	press_scale = look.motion_press_scale
	hover_seconds = look.motion_hover_seconds
	press_seconds = look.motion_press_seconds
	open_seconds = look.motion_open_seconds
	roll_seconds = look.motion_roll_seconds
	hover_tilt = look.motion_hover_tilt
	fanfare = maxf(0.0, look.fanfare)
	pixel_grid = TaDisplay.is_pixel()


static func is_reduced() -> bool:
	return reduced_motion or intensity <= 0.0


static func snap_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		var control := node as Control
		control.scale = Vector2.ONE
		control.modulate = Color(1, 1, 1, control.modulate.a)
	for child in node.get_children():
		snap_tree(child)


## Bind hover/press juice on every BaseButton under `node`.
static func bind_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_ensure_sfx()
	if node is BaseButton:
		bind_hover(node as Control)
	for child in node.get_children():
		bind_tree(child)


## Hover, focus, and press feel on a control: the lift, the squash, and the ticks. Focus
## that arrives from keys or a gamepad (ui_up / ui_down...) lifts and ticks like a hover;
## ui_accept presses like a click. Safe to call twice.
static func bind_hover(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_ensure_sfx()
	if control.has_meta(_META):
		return
	control.set_meta(_META, true)
	control.resized.connect(func() -> void: _on_resized(control))
	_on_resized(control)
	control.mouse_entered.connect(
		func() -> void:
			control.set_meta(_HOVER_META, true)
			_hover_on(control)
	)
	control.mouse_exited.connect(
		func() -> void:
			control.remove_meta(_HOVER_META)
			_hover_off(control)
	)
	control.focus_entered.connect(func() -> void: _focus_on(control))
	control.focus_exited.connect(
		func() -> void:
			if not control.has_meta(_HOVER_META):
				_hover_off(control)
	)
	if control is BaseButton:
		var button := control as BaseButton
		button.button_down.connect(func() -> void: _press_on(control))
		# A keyboard or gamepad press never hovered, so release returns to rest.
		button.button_up.connect(
			func() -> void:
				if button.is_hovered():
					_hover_on(control)
				else:
					_hover_off(control)
		)


static func fade_alpha(control: Control, to_alpha: float) -> Tween:
	if not is_instance_valid(control):
		return null
	if is_reduced():
		control.modulate.a = to_alpha
		return null
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate:a",
		to_alpha,
		open_seconds
	)
	return tween


## Open scale + fade. Window and toast share this.
static func open_control(control: Control) -> Tween:
	if not is_instance_valid(control):
		return null
	control.visible = true
	if is_reduced():
		control.modulate.a = 1.0
		control.scale = Vector2.ONE
		return null
	if pixel_grid:
		control.scale = Vector2.ONE
		control.modulate.a = 0.0
		return fade_alpha(control, 1.0)
	_on_resized(control)
	control.modulate.a = 0.0
	var start := TaDefaults.MOTION_OPEN_SCALE
	control.scale = Vector2(start, start)
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, open_seconds)
	tween.tween_property(control, "scale", Vector2.ONE, open_seconds)
	return tween


## Close scale + fade. Caller hides or frees after the tween.
static func close_control(control: Control) -> Tween:
	if not is_instance_valid(control):
		return null
	if is_reduced():
		control.modulate.a = 0.0
		return null
	if pixel_grid:
		return fade_alpha(control, 0.0)
	_on_resized(control)
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	var close_scale := TaDefaults.MOTION_OPEN_SCALE
	tween.tween_property(control, "modulate:a", 0.0, open_seconds)
	tween.tween_property(
		control, "scale", Vector2(close_scale, close_scale), open_seconds
	)
	return tween


## Tick label text toward to_value. Snaps when reduced-motion.
static func roll_number(
		label: Label,
		to_value: float,
		from_value: float = NAN,
		duration: float = -1.0
	) -> Tween:
	if not is_instance_valid(label):
		return null
	var start := from_value
	if is_nan(start):
		start = label.text.to_float()
	var whole := (
			is_equal_approx(start, roundf(start))
			and is_equal_approx(to_value, roundf(to_value))
	)
	if is_reduced():
		label.text = _format_roll(to_value, whole)
		return null
	var hold := duration
	if hold < 0.0:
		hold = roll_seconds
	var tween := label.create_tween()
	tween.tween_method(
		func(value: float) -> void:
			if is_instance_valid(label):
				label.text = _format_roll(value, whole),
		start,
		to_value,
		hold
	)
	tween.finished.connect(
		func() -> void:
			if is_instance_valid(label):
				label.text = _format_roll(to_value, whole)
	)
	return tween


## Intensity-scaled punch. Scale only on HD — Pixel flashes modulate (no subpixel scale).
static func punch(control: Control, intensity: float = 1.0) -> Tween:
	if not is_instance_valid(control):
		return null
	var amount := intensity * TaJuice.intensity * fanfare
	if is_reduced() or amount <= 0.0:
		return null
	if pixel_grid:
		var a := control.modulate.a
		control.modulate = Color(1.18, 1.18, 1.18, a)
		var flash := control.create_tween()
		flash.tween_property(control, "modulate", Color(1, 1, 1, a), press_seconds)
		return flash
	_on_resized(control)
	var bump := 1.0 + 0.06 * amount
	control.scale = Vector2(bump, bump)
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, press_seconds)
	return tween


## Looping "ready" glow on self_modulate until stop_pulse. tint colors the peak.
## Reduced motion returns null and leaves the control still. Calling again restarts.
static func pulse(
		control: Control,
		tint: Color = Color(1, 1, 1, 1),
		seconds: float = -1.0
	) -> Tween:
	if not is_instance_valid(control):
		return null
	stop_pulse(control)
	if is_reduced() or not control.is_inside_tree():
		return null
	var period := seconds if seconds > 0.0 else TaDefaults.PULSE_SECONDS
	var glow := TaDefaults.PULSE_BRIGHTNESS
	var peak := Color(tint.r * glow, tint.g * glow, tint.b * glow, 1.0)
	var tween := control.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "self_modulate", peak, period * 0.5)
	tween.tween_property(control, "self_modulate", Color(1, 1, 1, 1), period * 0.5)
	control.set_meta(_PULSE_META, tween)
	return tween


static func stop_pulse(control: Control) -> void:
	if not is_instance_valid(control) or not control.has_meta(_PULSE_META):
		return
	var tween := control.get_meta(_PULSE_META) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	control.remove_meta(_PULSE_META)
	control.self_modulate = Color(1, 1, 1, 1)


static func is_pulsing(control: Control) -> bool:
	return is_instance_valid(control) and control.has_meta(_PULSE_META)


## Intensity-scaled shake. Rotation only — layout `position` is unchanged.
static func shake(control: Control, intensity: float = 1.0) -> Tween:
	if not is_instance_valid(control):
		return null
	var amount := intensity * TaJuice.intensity * fanfare
	if is_reduced() or amount <= 0.0:
		return null
	_on_resized(control)
	var deg := 5.0 * amount
	control.rotation_degrees = deg
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var half := TaDefaults.MOTION_SHAKE_SECONDS * 0.5
	tween.tween_property(control, "rotation_degrees", -deg, half)
	tween.tween_property(control, "rotation_degrees", 0.0, half)
	return tween


## Keyboard or gamepad focus: the same lift and tick as a hover. A click focuses too, but
## the pointer already hovered, so it does not tick twice.
static func _focus_on(control: Control) -> void:
	if control.has_meta(_HOVER_META):
		return
	_hover_on(control, true)


static func _hover_on(control: Control, from_keys: bool = false) -> void:
	if _is_disabled(control):
		return
	# Sound is not motion: reduced motion keeps the ticks (TaSfx.muted silences them).
	_sfx(control, hover_stream)
	if is_reduced():
		return
	if pixel_grid:
		control.modulate = Color(1.12, 1.12, 1.12, control.modulate.a)
		return
	_on_resized(control)
	var hover := 1.0 + (hover_scale - 1.0) * intensity
	_tween_scale(control, hover, hover_seconds)
	if not is_zero_approx(hover_tilt):
		# Lean away from the side the pointer came in on, like a card in the hand; keys lean right.
		var lean := hover_tilt * intensity
		if not from_keys and control.get_local_mouse_position().x > control.size.x * 0.5:
			lean = -lean
		_tween_tilt(control, lean, hover_seconds)


static func _hover_off(control: Control) -> void:
	if pixel_grid:
		control.modulate = Color(1, 1, 1, control.modulate.a)
		return
	if is_reduced():
		control.scale = Vector2.ONE
		control.rotation_degrees = 0.0
		return
	_tween_scale(control, 1.0, hover_seconds)
	if not is_zero_approx(control.rotation_degrees):
		_tween_tilt(control, 0.0, hover_seconds)


static func _press_on(control: Control) -> void:
	if _is_disabled(control):
		return
	_sfx(control, _press_stream_for(control))
	if is_reduced():
		return
	if pixel_grid:
		punch(control, 1.0)
		return
	var press := 1.0 + (press_scale - 1.0) * intensity
	_tween_scale(control, press, press_seconds)


## Press feel for something that is not a BaseButton (a selectable card): the press
## sound and a small punch. Buttons get this from bind_hover.
static func tap(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_ensure_sfx()
	_sfx(control, _press_stream_for(control))
	punch(control, 0.5)


## A disabled button must not lift or tick: that reads as "you can press me".
static func _is_disabled(control: Control) -> bool:
	return control is BaseButton and (control as BaseButton).disabled


static func _on_resized(control: Control) -> void:
	if not is_instance_valid(control):
		return
	# Bottom-center pivot so hover scale reads as a lift.
	var next := Vector2(control.size.x * 0.5, control.size.y)
	if control.pivot_offset != next:
		control.pivot_offset = next


static func _tween_tilt(control: Control, degrees: float, seconds: float) -> void:
	if not is_instance_valid(control):
		return
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC if degrees != 0.0 else Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation_degrees", degrees, seconds * 2.5)


static func _tween_scale(control: Control, to: float, seconds: float) -> void:
	if not is_instance_valid(control):
		return
	var tween := control.create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2(to, to), seconds)


static func _ensure_sfx() -> void:
	if _sfx_ready or not use_kit_sfx:
		return
	_sfx_ready = true
	if hover_stream == null:
		hover_stream = _Sfx.hover()
	if press_stream == null:
		press_stream = _Sfx.press()


static func _press_stream_for(control: Control) -> AudioStream:
	if not control.has_meta(PRESS_SOUND_META):
		return press_stream
	var sound := String(control.get_meta(PRESS_SOUND_META))
	return null if sound.is_empty() else TaSfx.stream(sound)


static func _sfx(control: Control, stream: AudioStream) -> void:
	TaSfx.play_on(control, stream)


static func _format_roll(value: float, whole: bool) -> String:
	if whole:
		return "%d" % int(round(value))
	return "%.2f" % value
