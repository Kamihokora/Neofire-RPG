extends Object

# AGENT: Full GDScript shells for Recipes Copy recipe. Paste onto a CanvasLayer.
# INVARIANT: FPS shell matches examples/fps_hud. No DIY reticle/feed/vignette/[E]. Every
# shell wears the saved look (TaLook.apply_saved), never a fixed preset. Every shell
# compiles, and pins its widgets to edges (_pin) so they sit apart on any canvas
# (test_playground runs each one at 1920x1080).
# DO NOT: Mini-games. Do not persist.


static func fps() -> String:
	return """extends CanvasLayer
# Theme Assist FPS HUD recipe. Attach to a CanvasLayer.

func _ready() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	TaLook.apply_saved(hud)  # your saved look (Flat until you Save one)
	var vig := TaVignette.new()
	hud.add_child(vig)
	var reticle := TaReticle.new()
	hud.add_child(reticle)
	var left := VBoxContainer.new()
	hud.add_child(left)
	var hp := TaBar.new()
	hp.set_caption("HP")
	hp.set_range(100, 100)
	left.add_child(hp)
	var armor := TaBar.new()
	armor.set_caption("ARMOR")
	armor.set_range(50, 100)
	left.add_child(armor)
	var feed := TaKillFeed.new()
	left.add_child(feed)
	_pin(left, Control.PRESET_TOP_LEFT)
	var hint := TaInteractHint.new()
	hint.set_prompt("E", "Pick up ammo")
	hud.add_child(hint)
	_pin(hint, Control.PRESET_CENTER_BOTTOM)
	var ammo := TaChip.new()
	ammo.set_caption("AMMO")
	ammo.set_pair(30, 90)
	hud.add_child(ammo)
	_pin(ammo, Control.PRESET_BOTTOM_RIGHT)
	var host := TaToastHost.new()
	hud.add_child(host)
	host.set_corner(2)
	var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
	hud.add_child(pause)
	pause.visible = false
	feed.push_line("Eliminated cube")
	vig.hold(0.35)

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
"""


static func dungeon() -> String:
	return """extends CanvasLayer
# Theme Assist dungeon HUD recipe. Attach to a CanvasLayer.

func _ready() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	TaLook.apply_saved(hud)  # your saved look (Flat until you Save one)
	var hp := TaBar.new()
	hp.set_caption("HP")
	hp.set_range(72, 100)
	hud.add_child(hp)
	_pin(hp, Control.PRESET_BOTTOM_LEFT)
	var hot := TaHotbar.new()
	hot.slot_count = 8
	hot.paint_demo_icons()
	hud.add_child(hot)
	_pin(hot, Control.PRESET_CENTER_BOTTOM)
	var mini := TaMinimap.new()
	hud.add_child(mini)
	_pin(mini, Control.PRESET_TOP_RIGHT)
	var party := TaPartyFrame.new()
	party.set_member_name("Companion")
	party.set_health(70)
	hud.add_child(party)
	_pin(party, Control.PRESET_CENTER_LEFT)
	var quest := TaQuestTracker.new()
	quest.set_title("Quest")
	quest.set_objectives(PackedStringArray(["Clear the crypt", "Loot the chest"]))
	quest.set_progress(40)
	hud.add_child(quest)
	_pin(quest, Control.PRESET_TOP_LEFT)
	var hint := TaInteractHint.new()
	hint.set_prompt("E", "Open chest")
	hud.add_child(hint)
	_pin(hint, Control.PRESET_CENTER)
	var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
	hud.add_child(pause)
	pause.visible = false

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
"""


static func shop() -> String:
	return """extends CanvasLayer
# Theme Assist shop / wave recipe. Attach to a CanvasLayer.

func _ready() -> void:
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	TaLook.apply_saved(hud)  # your saved look (Flat until you Save one)
	var banner := TaBanner.new()
	banner.set_title("WAVE 3")
	banner.set_sub("Shop")
	hud.add_child(banner)
	_pin(banner, Control.PRESET_CENTER_TOP)
	var card := TaShopCard.new()
	card.set_title("Spud SMG")
	card.set_price("$22")
	var stat := TaStatRow.new()
	stat.set_stat("Damage", 8)
	card.get_stats().add_child(stat)
	hud.add_child(card)
	_pin(card, Control.PRESET_BOTTOM_RIGHT)
	var pick := TaChoicePicker.new()
	pick.set_heading("Level up")
	pick.set_choice(0, "Berserk", "+8 Damage")
	pick.set_choice(1, "Shield", "+20 Max HP")
	pick.set_choice(2, "Haste", "+10% Speed")
	hud.add_child(pick)
	_pin(pick, Control.PRESET_CENTER)
	var buffs := TaBuffStrip.new()
	buffs.set_buff(0, "Haste")
	hud.add_child(buffs)
	_pin(buffs, Control.PRESET_TOP_LEFT)
	var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
	hud.add_child(pause)
	pause.visible = false

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
"""


static func casino() -> String:
	return """extends Control
# Theme Assist felt-table shell. Wears your saved look; add your felt and plaques.
# The playground row still shows stepper / splash / speech. This paste does not.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TaLook.apply_saved(self)  # your saved look (Flat until you Save one)
	var vault := TaChip.new()
	vault.set_caption("Vault")
	vault.set_pair(24, 55)
	add_child(vault)
	_pin(vault, Control.PRESET_TOP_LEFT)
	var table := Control.new()
	table.name = "Table"
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table)
	# Game adds the felt TextureRect and TaPlateButton row as children of Table.
	var spin := TaPlateButton.new()
	spin.set_plate(preload("res://addons/theme_assist/icons/ta_buttons.svg"))
	table.add_child(spin)
	_pin(spin, Control.PRESET_CENTER_BOTTOM)
	var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
	add_child(pause)
	pause.visible = false

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
"""
