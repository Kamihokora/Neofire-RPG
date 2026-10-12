class_name TaButton
extends Button

# AGENT: The kit button. A stock Button that wires its own feel: hover and focus lift,
# press squash, the generated ticks. Keys and gamepads reach it through ui_* actions
# (ui_up / ui_down move focus, ui_accept presses). Every kit component builds its
# buttons from this, and TaSlot and TaInfoIcon extend it.
# INVARIANT: Wiring happens in _notification(NOTIFICATION_READY), which Godot calls on
# every class in the chain, so a subclass that overrides _ready or _init keeps it.
# DO NOT: Read input here (ui_* actions do). Put colors here (the Theme does).

## A Button with feel built in. Subclass it: hover, press, focus, and sound come along.

## The TaSfx sound a press plays (press, confirm, deny, open, close, notify, celebrate,
## level_up). Empty is silent.
@export var press_sound: StringName = &"press":
	set(value):
		press_sound = value
		set_meta(TaJuice.PRESS_SOUND_META, value)


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		# Here, not _init: a subclass _init does not chain to ours (TaSlot has one).
		if not has_meta(TaJuice.PRESS_SOUND_META):
			set_meta(TaJuice.PRESS_SOUND_META, press_sound)
		TaJuice.bind_hover(self)
