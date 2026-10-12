extends CanvasLayer

# AGENT: Tiny FPS recipe consumer. Theme Assist atoms only. Not a game.
# INVARIANT: Headless prints FPS_RECIPE_OK. Preloads so class_name cache is optional.
# DO NOT: Rebuild Potato/Clover/Dungeon. Do not persist.

const _Look := preload("res://addons/theme_assist/src/core/ta_look.gd")
const _Bar := preload("res://addons/theme_assist/src/components/bar/ta_bar.gd")
const _Chip := preload("res://addons/theme_assist/src/components/chip/ta_chip.gd")
const _Interact := preload("res://addons/theme_assist/src/components/hint/ta_interact_hint.gd")
const _Feed := preload("res://addons/theme_assist/src/components/feed/ta_kill_feed.gd")
const _Reticle := preload("res://addons/theme_assist/src/components/hud/ta_reticle.gd")
const _Vignette := preload("res://addons/theme_assist/src/components/hud/ta_vignette.gd")
const _Host := preload("res://addons/theme_assist/src/components/toast/ta_toast_host.gd")
const _PAUSE := "res://addons/theme_assist/scenes/pause.tscn"


func _ready() -> void:
	var hud := Control.new()
	hud.name = "HudRoot"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	# The HUD wears your saved look (Flat until you Save one in the playground).
	_Look.apply_saved(hud)
	var vig = _Vignette.new()
	vig.name = "Vignette"
	hud.add_child(vig)
	var reticle = _Reticle.new()
	reticle.name = "Reticle"
	hud.add_child(reticle)
	var left := VBoxContainer.new()
	left.name = "LeftStack"
	hud.add_child(left)
	var hp = _Bar.new()
	hp.name = "HpBar"
	hp.set_caption("HP")
	hp.set_range(100, 100)
	left.add_child(hp)
	var armor = _Bar.new()
	armor.name = "ArmorBar"
	armor.set_caption("ARMOR")
	armor.set_range(50, 100)
	left.add_child(armor)
	var feed = _Feed.new()
	feed.name = "KillFeed"
	left.add_child(feed)
	feed.push_line("Eliminated cube")
	_pin(left, Control.PRESET_TOP_LEFT)
	var hint = _Interact.new()
	hint.name = "Interact"
	hint.set_prompt("E", "Pick up ammo")
	hud.add_child(hint)
	_pin(hint, Control.PRESET_CENTER_BOTTOM)
	var ammo = _Chip.new()
	ammo.name = "Ammo"
	ammo.set_caption("AMMO")
	ammo.set_pair(30, 90)
	hud.add_child(ammo)
	_pin(ammo, Control.PRESET_BOTTOM_RIGHT)
	var host = _Host.new()
	host.name = "Toasts"
	hud.add_child(host)
	host.set_corner(2)
	var packed := load(_PAUSE) as PackedScene
	if packed != null:
		var pause := packed.instantiate() as Control
		pause.name = "Pause"
		pause.visible = false
		hud.add_child(pause)
	if vig.has_method("hold"):
		vig.hold(0.35)
	if reticle.has_method("ping_hit"):
		reticle.ping_hit()
	if DisplayServer.get_name() == "headless":
		print("FPS_RECIPE_OK")
		var tree := get_tree()
		if tree != null and tree.current_scene == self:
			tree.quit(0)


## Keep `c` at a screen edge, corner, or centre at any resolution, 16 px in. It grows
## away from that edge when its text or the look changes size.
func _pin(c: Control, preset: Control.LayoutPreset) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 16)
	c.grow_horizontal = _grow(c.anchor_left)
	c.grow_vertical = _grow(c.anchor_top)


func _grow(at: float) -> Control.GrowDirection:
	if at >= 1.0:
		return Control.GROW_DIRECTION_BEGIN
	return Control.GROW_DIRECTION_BOTH if at > 0.0 else Control.GROW_DIRECTION_END
