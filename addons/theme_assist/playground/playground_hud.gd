extends VBoxContainer

# AGENT: Genre HUD atoms for the playground: the canvas strip and the in-world attach
# (a small 3D scene with the same TaBar over a crate).
# INVARIANT: Every new HUD registry type is instanced and marked.
# DO NOT: Load res://demo. Do not ResourceLoader.load icons.

const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _Bar := preload("res://addons/theme_assist/src/components/bar/ta_bar.gd")
const _Chip := preload("res://addons/theme_assist/src/components/chip/ta_chip.gd")
const _Badge := preload("res://addons/theme_assist/src/components/badge/ta_badge.gd")
const _Interact := preload("res://addons/theme_assist/src/components/hint/ta_interact_hint.gd")
const _Feed := preload("res://addons/theme_assist/src/components/feed/ta_kill_feed.gd")
const _Reticle := preload("res://addons/theme_assist/src/components/hud/ta_reticle.gd")
const _Vignette := preload("res://addons/theme_assist/src/components/hud/ta_vignette.gd")
const _Hotbar := preload("res://addons/theme_assist/src/components/hud/ta_hotbar.gd")
const _Minimap := preload("res://addons/theme_assist/src/components/hud/ta_minimap.gd")
const _Party := preload("res://addons/theme_assist/src/components/hud/ta_party_frame.gd")
const _Speech := preload("res://addons/theme_assist/src/components/hud/ta_speech_bubble.gd")
const _Shop := preload("res://addons/theme_assist/src/components/hud/ta_shop_card.gd")
const _Stat := preload("res://addons/theme_assist/src/components/hud/ta_stat_row.gd")
const _Choice := preload("res://addons/theme_assist/src/components/hud/ta_choice_picker.gd")
const _Splash := preload("res://addons/theme_assist/src/components/hud/ta_win_splash.gd")
const _Banner := preload("res://addons/theme_assist/src/components/hud/ta_banner.gd")
const _Buffs := preload("res://addons/theme_assist/src/components/hud/ta_buff_strip.gd")
const _Stepper := preload("res://addons/theme_assist/src/components/hud/ta_stepper.gd")
const _Quest := preload("res://addons/theme_assist/src/components/hud/ta_quest_tracker.gd")

var _host: Control
var _feed
var _reticle
var _vig
var _demoed: bool = false

func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	var blurb := Label.new()
	blurb.text = "HUD atoms on the canvas, and the same components in a 3D scene (TaWorldAttach)."
	blurb.theme_type_variation = "TaCaption"
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(blurb)
	# First: the world half is what a canvas-only HUD kit does not have.
	_put("TaWorldAttach", _world_cell(), "world 3d nameplate billboard in-world")
	_mark("TaWorldAttach")
	var bar = _Bar.new()
	bar.name = "HudBar"
	bar.set_caption("HP")
	bar.set_range(72.0, 100.0)
	_put("TaBar", bar, "cur max health")
	var chip = _Chip.new()
	chip.name = "HudChip"
	chip.set_caption("AMMO")
	chip.set_pair(30.0, 90.0)
	_put("TaChip", chip, "mag reserve dual")
	var tones := HBoxContainer.new()
	for spec in [
		["OK", 4],
		["Warn", 5],
		["Rare", 6],
	]:
		var badge = _Badge.new()
		badge.text = String(spec[0])
		badge.tone = spec[1]
		tones.add_child(badge)
	_put("TaBadge", tones, "danger success warning rarity")
	var hint = _Interact.new()
	hint.name = "TaInteractHint"
	hint.set_prompt("E", "Open chest")
	# In a gallery cell, on a panel: plain ink (over a scene it keeps its halo).
	hint.on_scene = false
	_put("TaInteractHint", hint, "keychip interact")
	_mark("TaInteractHint")
	_feed = _Feed.new()
	_feed.name = "TaKillFeed"
	_put("TaKillFeed", _feed, "killfeed combat")
	_mark("TaKillFeed")
	var reticle_wrap := Control.new()
	reticle_wrap.custom_minimum_size = Vector2(_UI.ui(96), _UI.ui(64))
	_reticle = _Reticle.new()
	_reticle.name = "TaReticle"
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle_wrap.add_child(_reticle)
	_put("TaReticle", reticle_wrap, "crosshair hitmarker")
	_mark("TaReticle")
	var vig_wrap := Control.new()
	vig_wrap.custom_minimum_size = Vector2(_UI.ui(220), _UI.ui(96))
	_vig = _Vignette.new()
	_vig.name = "TaVignette"
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig_wrap.add_child(_vig)
	_put("TaVignette", vig_wrap, "damage edge")
	_mark("TaVignette")
	var hot = _Hotbar.new()
	hot.name = "TaHotbar"
	hot.slot_count = 4
	hot.paint_demo_icons()
	_put("TaHotbar", hot, "hotbar slots")
	_mark("TaHotbar")
	var mini = _Minimap.new()
	mini.name = "TaMinimap"
	_put("TaMinimap", mini, "map")
	_mark("TaMinimap")
	var party = _Party.new()
	party.name = "TaPartyFrame"
	party.set_member_name("Companion")
	party.set_health(70.0)
	_put("TaPartyFrame", party, "party")
	_mark("TaPartyFrame")
	var speech = _Speech.new()
	speech.name = "TaSpeechBubble"
	speech.set_text("Pay the debt. Charms help.")
	_put("TaSpeechBubble", speech, "dialogue")
	_mark("TaSpeechBubble")
	var card = _Shop.new()
	card.name = "TaShopCard"
	card.set_title("Spud SMG")
	card.set_price("$22")
	var stat = _Stat.new()
	stat.name = "TaStatRow"
	stat.set_stat("Damage", 8.0)
	card.get_stats().add_child(stat)
	_put("TaShopCard", card, "shop deal")
	_mark("TaShopCard")
	_mark("TaStatRow")
	var picker = _Choice.new()
	picker.name = "TaChoicePicker"
	picker.set_heading("Level up")
	picker.set_choice(0, "Berserk", "+8 Damage")
	picker.set_choice(1, "Shield", "+20 Max HP")
	picker.set_choice(2, "Haste", "+10% Speed")
	_put("TaChoicePicker", picker, "level up offer")
	_mark("TaChoicePicker")
	var splash = _Splash.new()
	splash.name = "TaWinSplash"
	splash.set_title("WIN")
	splash.set_amount("+54")
	_put("TaWinSplash", splash, "combo splash")
	_mark("TaWinSplash")
	var banner = _Banner.new()
	banner.name = "TaBanner"
	banner.set_title("WAVE 3")
	banner.set_sub("12")
	_put("TaBanner", banner, "countdown wave")
	_mark("TaBanner")
	var buffs = _Buffs.new()
	buffs.name = "TaBuffStrip"
	buffs.set_buff(0, "Haste", 4)
	buffs.set_buff(1, "Glass", 5)
	_put("TaBuffStrip", buffs, "buffs")
	_mark("TaBuffStrip")
	var step = _Stepper.new()
	step.name = "TaStepper"
	step.set_value(5)
	_put("TaStepper", step, "bet stake")
	_mark("TaStepper")
	var quest = _Quest.new()
	quest.name = "TaQuestTracker"
	quest.set_title("Quest")
	quest.set_objectives(PackedStringArray(["Clear the crypt", "Loot the chest"]))
	quest.set_progress(40.0)
	_put("TaQuestTracker", quest, "objectives")
	_mark("TaQuestTracker")
	var ping := Button.new()
	ping.text = "Hitmarker / vignette"
	ping.pressed.connect(func() -> void:
		if is_instance_valid(_reticle):
			_reticle.ping_hit()
		if is_instance_valid(_vig):
			_vig.flash(1.0)
			_vig.hold(0.45)
		if is_instance_valid(_feed):
			_feed.push_line("Eliminated cube")
	)
	add_child(ping)
	call_deferred("run_demo")


func run_demo() -> void:
	if is_instance_valid(_vig):
		_vig.hold(0.55)
	if _demoed:
		return
	_demoed = true
	if is_instance_valid(_feed):
		_feed.push_line("Eliminated cube")
	if is_instance_valid(_reticle):
		_reticle.ping_hit()
	if is_instance_valid(_host):
		var floater := load("res://addons/theme_assist/src/components/hud/ta_floater.gd")
		if floater != null:
			floater.pop(_host, "+12", Vector2(48, 72))
	if DisplayServer.get_name() == "headless":
		print("HUD_DEMO_OK")


## A crate in a small 3D scene with a TaBar nameplate over it, beside the same TaBar on
## the canvas: one component, both places, wearing the live look.
func _world_cell() -> Control:
	var row := HBoxContainer.new()
	row.name = "WorldCell"
	row.add_theme_constant_override(
			"separation", TaLook.metric(TaDefaults.SEPARATION * 2, TaDefaults.PIXEL_SEPARATION * 2)
	)
	var view := SubViewportContainer.new()
	view.stretch = true
	view.custom_minimum_size = Vector2(_UI.ui(560), _UI.ui(300))
	row.add_child(view)
	var sub := SubViewport.new()
	sub.own_world_3d = true
	view.add_child(sub)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var camera := Camera3D.new()
	camera.environment = env
	camera.position = Vector3(0.0, 1.4, 2.6)
	camera.rotation_degrees = Vector3(-10.0, 0.0, 0.0)
	sub.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sub.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	ground.mesh = plane
	ground.material_override = _matte(Color(0.3, 0.4, 0.26))
	sub.add_child(ground)
	var crate := MeshInstance3D.new()
	crate.mesh = BoxMesh.new()
	crate.position = Vector3(0.0, 0.5, 0.0)
	crate.rotation_degrees = Vector3(0.0, 25.0, 0.0)
	crate.material_override = _matte(Color(0.55, 0.38, 0.22))
	sub.add_child(crate)
	var plate := TaWorldAttach.new()
	plate.name = "TaWorldAttach"
	plate.position = Vector3(0.0, 0.95, 0.0)
	crate.add_child(plate)
	var world_bar := TaBar.new()
	world_bar.set_caption("Crate")
	world_bar.set_range(60, 100)
	plate.add_content(world_bar)
	var side := VBoxContainer.new()
	row.add_child(side)
	var note := Label.new()
	note.text = "The same TaBar on the canvas:"
	note.theme_type_variation = "TaCaption"
	side.add_child(note)
	var canvas_bar := TaBar.new()
	canvas_bar.set_caption("Crate")
	canvas_bar.set_range(60, 100)
	side.add_child(canvas_bar)
	return row


func _matte(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _put(key: String, node: Control, extra: String = "") -> void:
	add_child(_UI.cell(key, node, extra))


func _mark(type_name: String) -> void:
	if is_instance_valid(_host) and _host.has_method("mark_registry_type"):
		_host.mark_registry_type(type_name)
