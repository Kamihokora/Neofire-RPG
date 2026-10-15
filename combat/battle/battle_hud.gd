extends Control
## 战斗窗口的装饰、顶部入口和应援占位；结算仍由 battle.gd 管理。

signal support_triggered(slot_index: int)
signal menu_requested(menu_id: String)

const PANEL_TEXTURE := "res://assets/ui/panels/panel_black.png"
const SLOT_TEXTURE := "res://assets/ui/slots/item_slot_black.png"
const PortraitStage := preload("res://combat/battle/portrait_stage.gd")
const DoboButtonStyle := preload("res://assets/ui/dobo_button_style.gd")
const SUPPORTS := [
	{"name": "文手", "art": "res://neofire/GIF/有个点子_03.png"},
	{"name": "画手", "art": "res://neofire/GIF/笔自己画_15.png"},
	{"name": "曲师", "art": "res://neofire/GIF/好耶_09.png"},
	{"name": "问号", "art": "res://neofire/GIF/难道说_02.png"},
]

@export var player_frame_rect := Rect2(140, 644, 416, 180)
@export var support_frame_rect := Rect2(1668, 160, 252, 720) # 无框应援区，供碎落截图取区。
@export var enemy_frame_rect := Rect2(950, 208, 288, 112)

var support_buttons: Array[Button] = []
var _energy_pips: Array[ColorRect] = []
var _hover_tweens: Dictionary = {}
var _menu_shade: ColorRect
var _menu_popup: Panel
var _menu_slots: HBoxContainer
var _menu_title: Label
var _hand_frame: Panel
var _frame_tween: Tween
var _idle_rng := RandomNumberGenerator.new()
var _idle_states: Array[Dictionary] = []
var portrait_stage: PortraitStage


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idle_rng.randomize()
	_build_frames()
	_build_top_bar()
	_build_menu()


func _build_frames() -> void:
	_panel(self, "TopBar", Rect2(40, 24, 1840, 80))
	_panel(self, "PlayerFrame", player_frame_rect).z_index = 4
	_panel(self, "EnemyFrame", enemy_frame_rect)
	_hand_frame = _panel(self, "HandFrame", Rect2(820, 824, 280, 240))
	_hand_frame.modulate.a = 0
	portrait_stage = PortraitStage.new()
	portrait_stage.name = "PlayerPortrait"
	add_child(portrait_stage)
	portrait_stage.position = Vector2(0, 168)
	portrait_stage.scale = Vector2.ONE * 1.12
	_label(self, "PlayerCaption", "前台", Rect2(168, 652, 120, 26), 17, Color(0.72, 0.77, 0.87)).z_index = 5
	_texture(self, "EnergyIcon", "res://assets/ui/icons/energy.png", Rect2(174, 778, 34, 34)).z_index = 5
	for i in range(3):
		var pip := ColorRect.new()
		pip.name = "EnergyPip%d" % (i + 1)
		pip.position = Vector2(416 + i * 38, 790)
		pip.size = Vector2(28, 16)
		pip.z_index = 5
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		_energy_pips.append(pip)


func _build_top_bar() -> void:
	_label(self, "GameTitle", "新火", Rect2(72, 43, 132, 42), 30, Color(1, 0.82, 0.6))
	_label(self, "SkillHeading", "角色技能", Rect2(474, 45, 120, 38), 23)
	for i in range(4):
		var slot := _button(self, "SkillSlot%d" % (i + 1), "·", Rect2(600 + i * 58, 38, 48, 50), SLOT_TEXTURE)
		slot.tooltip_text = "test%d" % (i + 1)
		slot.pressed.connect(func() -> void: menu_requested.emit("skills"))
	var skills := _button(self, "SkillsButton", "角色技能", Rect2(1064, 39, 180, 50))
	skills.icon = load("res://assets/ui/icons/skills.png")
	skills.pressed.connect(func() -> void: menu_requested.emit("skills"))
	var deck := _button(self, "DeckButton", "卡组", Rect2(1260, 39, 160, 50))
	deck.pressed.connect(func() -> void: menu_requested.emit("deck"))
	var items := _button(self, "InventoryButton", "物品栏", Rect2(1436, 39, 190, 50))
	items.icon = load("res://assets/ui/icons/inventory.png")
	items.pressed.connect(func() -> void: menu_requested.emit("inventory"))
	var settings := _button(self, "SettingsButton", "设置", Rect2(1642, 39, 202, 50))
	settings.icon = load("res://assets/ui/icons/settings.png")
	settings.disabled = true


func configure_support(gauge: Control) -> void:
	for i in range(SUPPORTS.size()):
		var button := _button(gauge, "Support%d" % (i + 1), "", Rect2(0, 14 + i * 158, 136, 136))
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.set_meta(&"support_index", i)
		var expression := _texture(button, "Expression", SUPPORTS[i]["art"], Rect2(0, 0, 136, 136))
		expression.pivot_offset = Vector2(68, 128)
		_idle_states.append({"wait": _idle_rng.randf_range(1, 5), "elapsed": 0.0, "duration": 2.0, "action": 0, "phase": _idle_rng.randf_range(0, TAU)})
		button.pressed.connect(func() -> void: support_triggered.emit(i))
		button.mouse_entered.connect(_hover_support.bind(button, true))
		button.mouse_exited.connect(_hover_support.bind(button, false))
		support_buttons.append(button)


func set_hand_bounds(left: float, right: float, count: int) -> void:
	var width := clampf(right - left + 72, 280, 1584)
	var x := clampf((left + right - width) * 0.5, 168, 1752 - width)
	var target := Vector2(x, 824)
	var target_size := Vector2(width, 240)
	if _hand_frame.position.is_equal_approx(target) and _hand_frame.size.is_equal_approx(target_size) and is_equal_approx(_hand_frame.modulate.a, 0.86 if count > 0 else 0.0):
		return
	if _frame_tween != null and _frame_tween.is_valid():
		_frame_tween.kill()
	_frame_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_frame_tween.tween_property(_hand_frame, ^"position", target, 0.22)
	_frame_tween.tween_property(_hand_frame, ^"size", target_size, 0.22)
	_frame_tween.tween_property(_hand_frame, ^"modulate:a", 0.86 if count > 0 else 0.0, 0.18)


func _process(delta: float) -> void:
	for i in support_buttons.size():
		var button := support_buttons[i]
		var expression: TextureRect = button.get_node("Expression")
		var state: Dictionary = _idle_states[i]
		var offset := Vector2.ZERO
		var angle := 0.0
		state["phase"] += delta * 1.8
		if not button.disabled and not button.is_hovered():
			state["wait"] -= delta
			if state["wait"] <= 0:
				state["elapsed"] += delta
				var progress := clampf(state["elapsed"] / state["duration"], 0, 1)
				var wave := sin(progress * TAU) * sin(progress * PI)
				match int(state["action"]):
					0: offset = Vector2(wave * 7, -absf(wave) * 2)
					1: offset.y = -absf(wave) * 5
					2: angle = wave * 0.035
				if progress >= 1:
					state["wait"] = _idle_rng.randf_range(3, 7)
					state["elapsed"] = 0.0
					state["duration"] = _idle_rng.randf_range(1.4, 2.6)
					state["action"] = _idle_rng.randi_range(0, 2)
			offset.y += sin(state["phase"]) * 1.2
		expression.position = expression.position.lerp(offset, minf(1, delta * 12))
		expression.rotation = lerpf(expression.rotation, angle, minf(1, delta * 12))


func _hover_support(button: Button, active: bool) -> void:
	if _hover_tweens.has(button):
		var old: Tween = _hover_tweens[button]
		if old != null and old.is_valid():
			old.kill()
	button.pivot_offset = Vector2(button.size.x * 0.5, button.size.y)
	var tween := create_tween()
	_hover_tweens[button] = tween
	tween.tween_property(button, ^"scale", Vector2(1.12, 1.12) if active else Vector2.ONE, 0.12)


func update_resources(current_energy: int, energy_max: int, locked: bool) -> void:
	for i in range(_energy_pips.size()):
		_energy_pips[i].color = Color(1, 0.81, 0.42) if i < mini(current_energy, energy_max) else Color(0.24, 0.26, 0.34)
	for button in support_buttons:
		button.disabled = locked


func show_menu(menu_id: String) -> void:
	_menu_title.text = "角色技能" if menu_id == "skills" else "物品栏"
	for child in _menu_slots.get_children():
		_menu_slots.remove_child(child)
		child.queue_free()
	for i in range(4):
		var slot := _panel(_menu_slots, "Slot%d" % (i + 1), Rect2(0, 0, 156, 188))
		slot.custom_minimum_size = Vector2(156, 188)
		slot.add_theme_stylebox_override(&"panel", _texture_style(SLOT_TEXTURE, 14))
		_texture(slot, "Icon", "res://assets/ui/icons/skills.png" if menu_id == "skills" else "res://assets/ui/icons/inventory.png", Rect2(44, 32, 68, 68))
		_label(slot, "Placeholder", "test%d" % (i + 1), Rect2(12, 132, 132, 34), 24).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_shade.show()
	_menu_popup.show()


func close_menu() -> void:
	_menu_shade.hide()
	_menu_popup.hide()


func is_menu_open() -> bool:
	return _menu_popup.visible


func _build_menu() -> void:
	# 单独的末尾节点同时保证绘制和 GUI 命中顺序；z_index 本身不改变鼠标判定顺序。
	var overlay: Control = get_parent().get_node("HUDOverlay")
	_menu_shade = ColorRect.new()
	_menu_shade.name = "MenuShade"
	_menu_shade.color = Color(0.02, 0.025, 0.05, 0.72)
	_menu_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_menu_shade)
	_menu_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			close_menu())
	_menu_popup = _panel(overlay, "MenuPopup", Rect2(500, 290, 920, 460))
	_menu_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_title = _label(_menu_popup, "Title", "", Rect2(46, 30, 700, 50), 34)
	var close := _button(_menu_popup, "Close", "×", Rect2(814, 24, 70, 54))
	close.pressed.connect(close_menu)
	_menu_slots = HBoxContainer.new()
	_menu_slots.name = "Slots"
	_menu_slots.position = Vector2(80, 142)
	_menu_slots.add_theme_constant_override(&"separation", 42)
	_menu_popup.add_child(_menu_slots)
	close_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if _menu_popup.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_menu()
		get_viewport().set_input_as_handled()


func _texture_style(path: String, margin: float = 28) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load(path)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
	return style


func _panel(parent: Node, node_name: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(&"panel", _texture_style(PANEL_TEXTURE, 36))
	parent.add_child(panel)
	return panel


func _label(parent: Node, node_name: String, text: String, rect: Rect2, font_size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	parent.add_child(label)
	return label


func _texture(parent: Node, node_name: String, path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.name = node_name
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.position = rect.position
	image.size = rect.size
	image.texture = load(path)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image


func _button(parent: Node, node_name: String, text: String, rect: Rect2, skin: String = "res://assets/ui/buttons/button_black.png") -> Button:
	var button := Button.new()
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.name = node_name
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.add_theme_constant_override(&"icon_max_width", 28)
	button.add_theme_font_size_override(&"font_size", 23)
	var normal: StyleBox = _texture_style(skin, 14) if skin == SLOT_TEXTURE else DoboButtonStyle.create(skin)
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", DoboButtonStyle.create("res://assets/ui/buttons/button_red.png"))
	button.add_theme_stylebox_override(&"pressed", normal)
	button.add_theme_stylebox_override(&"disabled", normal)
	parent.add_child(button)
	return button
