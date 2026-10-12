class_name TaFanfare
extends Object

# AGENT: Named juice+SFX presets. Kit feature, not a sprinkle of punch/shake.
# INVARIANT: play_named matches preset_names(). Reduced-motion is a no-op.
# DO NOT: AnimationPlayers. Do not autoload. Do not register as a Control.

## Named motion + SFX. celebrate / deny / level_up / panel_in / confirm / notify.

const PRESETS := [
	"celebrate",
	"deny",
	"level_up",
	"panel_in",
	"confirm",
	"notify",
]


static func preset_names() -> PackedStringArray:
	return PackedStringArray(PRESETS)


static func play_named(control: Control, preset: String) -> void:
	match preset:
		"celebrate":
			celebrate(control)
		"deny":
			deny(control)
		"level_up":
			level_up(control)
		"panel_in":
			panel_in(control)
		"confirm":
			confirm(control)
		"notify":
			notify(control)


static func celebrate(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.celebrate())
	TaJuice.punch(control, TaDefaults.FANFARE_CELEBRATE_PUNCH)


static func deny(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.deny())
	TaJuice.shake(control, TaDefaults.FANFARE_DENY_SHAKE)


static func level_up(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.level_up())
	# Punch only. It used to roll a Label to its value + 100, which changed the
	# number the game shows. Call TaJuice.roll_number with your real value.
	TaJuice.punch(control, TaDefaults.FANFARE_LEVEL_PUNCH)


static func panel_in(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.open())
	control.modulate.a = 0.0
	TaJuice.open_control(control)


static func confirm(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.confirm())
	TaJuice.punch(control, TaDefaults.FANFARE_CONFIRM_PUNCH)


static func notify(control: Control) -> void:
	if not is_instance_valid(control):
		return
	TaSfx.play_on(control, TaSfx.notify())
	TaJuice.punch(control, TaDefaults.FANFARE_NOTIFY_PUNCH)
