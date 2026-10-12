extends VBoxContainer

# AGENT: Genre HUD templates. Compose atoms; user scripts the game.
# INVARIANT: FPS / Dungeon / Shop / Casino rows. Canvas only.
# DO NOT: Load res://demo. Do not own combat or shops.

const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _Bar := preload("res://addons/theme_assist/src/components/bar/ta_bar.gd")
const _Chip := preload("res://addons/theme_assist/src/components/chip/ta_chip.gd")
const _Interact := preload("res://addons/theme_assist/src/components/hint/ta_interact_hint.gd")
const _Feed := preload("res://addons/theme_assist/src/components/feed/ta_kill_feed.gd")
const _Hotbar := preload("res://addons/theme_assist/src/components/hud/ta_hotbar.gd")
const _Minimap := preload("res://addons/theme_assist/src/components/hud/ta_minimap.gd")
const _Party := preload("res://addons/theme_assist/src/components/hud/ta_party_frame.gd")
const _Quest := preload("res://addons/theme_assist/src/components/hud/ta_quest_tracker.gd")
const _Choice := preload("res://addons/theme_assist/src/components/hud/ta_choice_picker.gd")
const _Banner := preload("res://addons/theme_assist/src/components/hud/ta_banner.gd")
const _Shop := preload("res://addons/theme_assist/src/components/hud/ta_shop_card.gd")
const _Stepper := preload("res://addons/theme_assist/src/components/hud/ta_stepper.gd")
const _Splash := preload("res://addons/theme_assist/src/components/hud/ta_win_splash.gd")
const _Speech := preload("res://addons/theme_assist/src/components/hud/ta_speech_bubble.gd")
const _Cell := preload("res://addons/theme_assist/src/components/hud/ta_highlight_cell.gd")
const _Compass := preload("res://addons/theme_assist/src/components/hud/ta_compass.gd")
const _Board := preload("res://addons/theme_assist/src/components/hud/ta_scoreboard.gd")
const _Floater := preload("res://addons/theme_assist/src/components/hud/ta_floater.gd")
const _Scripts := preload("res://addons/theme_assist/playground/playground_recipe_scripts.gd")
const _Plate := preload("res://addons/theme_assist/src/components/buttons/ta_plate_button.gd")

var _host: Control


func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	var blurb := Label.new()
	blurb.text = "Templates: copy the pattern, then script your game. They wear the live look."
	blurb.theme_type_variation = "TaCaption"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)
	_fps()
	_dungeon()
	_shop()
	_casino()


func _fps() -> void:
	var box := VBoxContainer.new()
	var hp = _Bar.new()
	hp.set_caption("HP")
	hp.set_range(100, 100)
	box.add_child(hp)
	var ammo = _Chip.new()
	ammo.set_caption("AMMO")
	ammo.set_pair(30, 90)
	box.add_child(ammo)
	var hint = _Interact.new()
	hint.set_prompt("E", "Pick up ammo")
	box.add_child(hint)
	var feed = _Feed.new()
	feed.push_line("Eliminated cube")
	box.add_child(feed)
	var compass = _Compass.new()
	compass.name = "TaCompass"
	box.add_child(compass)
	_mark("TaCompass")
	var board = _Board.new()
	board.name = "TaScoreboard"
	board.set_rows(PackedStringArray(["You", "Bot"]), PackedStringArray(["12", "7"]))
	box.add_child(board)
	_mark("TaScoreboard")
	_put_recipe("FPS HUD", box, "fps reticle ammo", "FPS", _Scripts.fps())


func _dungeon() -> void:
	var box := VBoxContainer.new()
	var hp = _Bar.new()
	hp.set_caption("HP")
	hp.set_range(72, 100)
	box.add_child(hp)
	var hot = _Hotbar.new()
	hot.slot_count = 4
	hot.paint_demo_icons()
	box.add_child(hot)
	var mini = _Minimap.new()
	box.add_child(mini)
	var party = _Party.new()
	party.set_member_name("Companion")
	box.add_child(party)
	var quest = _Quest.new()
	quest.set_objectives(PackedStringArray(["Clear the crypt"]))
	box.add_child(quest)
	_put_recipe("Dungeon HUD", box, "dungeon hotbar quest", "Dungeon", _Scripts.dungeon())


func _shop() -> void:
	var box := VBoxContainer.new()
	var banner = _Banner.new()
	banner.set_title("WAVE 3")
	banner.set_sub("Shop")
	box.add_child(banner)
	var card = _Shop.new()
	card.set_title("Spud SMG")
	card.set_price("$22")
	box.add_child(card)
	var pick = _Choice.new()
	pick.set_heading("Level up")
	pick.set_choice(0, "Berserk", "+8 Damage")
	pick.set_choice(1, "Shield", "+20 HP")
	pick.set_choice(2, "Haste", "+10% Speed")
	box.add_child(pick)
	_put_recipe("Shop / wave", box, "shop choice banner", "Shop", _Scripts.shop())


func _casino() -> void:
	var box := HBoxContainer.new()
	var step = _Stepper.new()
	step.set_value(5)
	box.add_child(step)
	var splash = _Splash.new()
	splash.set_amount("+54")
	box.add_child(splash)
	var speech = _Speech.new()
	speech.set_text("Pay the debt.")
	box.add_child(speech)
	var cell = _Cell.new()
	cell.name = "TaHighlightCell"
	var lab := Label.new()
	lab.text = "7"
	cell.get_content().add_child(lab)
	cell.set_selected(true)
	box.add_child(cell)
	_mark("TaHighlightCell")
	var floater = _Floater.new()
	floater.name = "TaFloater"
	floater.text = "+12 gold"
	box.add_child(floater)
	_mark("TaFloater")
	var plate = _Plate.new()
	plate.name = "TaPlateButton"
	var swatch := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	swatch.fill(Color(0.88, 0.76, 0.48))
	plate.set_plate(ImageTexture.create_from_image(swatch))
	box.add_child(plate)
	_mark("TaPlateButton")
	_put_recipe("Casino", box, "felt plate vault", "Casino", _Scripts.casino())


func _put_recipe(
		key: String,
		node: Control,
		extra: String,
		copy_id: String,
		script: String
	) -> void:
	var wrap := VBoxContainer.new()
	var copy := Button.new()
	copy.name = "CopyRecipe%s" % copy_id
	copy.text = "Copy recipe"
	copy.pressed.connect(func() -> void:
		if is_instance_valid(_host) and _host.has_method("copy_recipe"):
			_host.copy_recipe(script)
		else:
			DisplayServer.clipboard_set(script)
	)
	wrap.add_child(copy)
	wrap.add_child(node)
	add_child(_UI.cell(key, wrap, extra + " copy recipe"))


func _mark(type_name: String) -> void:
	if is_instance_valid(_host) and _host.has_method("mark_registry_type"):
		_host.mark_registry_type(type_name)
