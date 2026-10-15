extends CanvasLayer
## 手机菜单的三态演出：浏览应用、详情页、重要操作确认。

@warning_ignore("unused_signal") # 由应用页派生类发出。
signal save_requested(slot: int)
@warning_ignore("unused_signal")
signal load_requested(slot: int)
signal closed
signal pet_interacted(member_id: String)
signal thinking_requested

const MenuPet := preload("res://ui/menu_pet.gd")
const DOTS := preload("res://ui/pop_halftone.gdshader")
const HEAVY_FONT := preload("res://theme/fonts/menu_heavy.otf")
const APPS := [
	["save", "存读档", "res://assets/ui/phone/save.png", "SAVE / LOAD", "记录进度，或继续之前的冒险。\n三个手动存档位，各自提供保存与读取。"],
	["party", "伙伴", "res://assets/ui/icons/skills.png", "CREATORS", "调整四人站位与各档应援技能。\n查看共享等级，使用养成资源。"],
	["deck", "卡组", "res://assets/ui/combat/draw_pile.png", "CARD FILE", "查看已有卡牌、数量和效果。\n下一场战斗，从这里准备。"],
	["inventory", "背包", "res://assets/ui/icons/inventory.png", "POCKET", "查看携带的物品和遗物容量。"],
	["settings", "设置", "res://assets/ui/icons/settings.png", "OPTIONS", "调整音量与显示方式。\n全屏切换将在确认后生效。"],
	["notebook", "笔记本", "res://assets/ui/icons/skills.png", "NOTEBOOK", "收纳已经拼合的想法，或将两个灵感词条组合。\n带着想法回到四人桌，再提交提案。"],
]
const MEMBERS := {"write": "文手", "draw": "画手", "rhythm": "曲师", "manga": "问号"}
const PET_ART := ["res://neofire/GIF/有个点子_03.png", "res://neofire/GIF/笔自己画_15.png", "res://neofire/GIF/好耶_09.png", "res://neofire/GIF/难道说_02.png"]
const ACCENT := Color("ff4263")

var shell: Node
var store: RefCounted
var is_open := false
var current_app := "home"
var view_state := "home"
var pet_walk_frequency := 0.5:
	set(value):
		pet_walk_frequency = clampf(value, 0, 2)
		for pet: MenuPet in _pet_nodes.values():
			pet.walk_frequency = pet_walk_frequency
var writer_thinking := false:
	set(value):
		writer_thinking = value
		if _pet_nodes.has("write"):
			_pet_nodes["write"].set_thinking(value)

var _root: Control
var _stage: Control
var _shade: ColorRect
var _phone: Control
var _launcher: Control
var _app_buttons: Array[Button] = []
var _app_index := 0
var _description: Control
var _hero: Label
var _ghost: Label
var _explanation: Label
var _detail: Control
var _title: Label
var _content: VBoxContainer
## 需要独立双框布局的应用可接管详情舞台，仍复用暂停、确认与返回流程。
var _custom_detail: Control
var _notice: Label
var _hints: Label
var _pets: Control
var _pet_nodes: Dictionary = {}
var _confirm: Control
var _confirm_ok: Button
var _confirm_text: Label
var _warning: TextureRect
var _pending_action := Callable()
var _pending_cancel := Callable()
var _focus_before_confirm: Control
var _confirmation_return := "detail"
var _thinking_from_app := false
var _tween: Tween
var _moving := false
var _close_requested := false
var _was_paused := false


func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"phone_menu")
	_root = Control.new()
	_root.name = "PhoneRoot"
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = Theme.new()
	_root.theme.default_font = load("res://theme/fonts/思源黑体.otf")
	_root.theme.default_font_size = 25
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0)
	_root.add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and view_state == "home":
			close_phone())
	_stage = Control.new()
	_stage.name = "PopStage"
	_stage.size = Vector2(1920, 1080)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stage)
	_build_description()
	_build_phone()
	_phone.z_index = 10
	_build_pets()
	_pets.z_index = 20
	_build_detail()
	_detail.z_index = 30
	_build_confirmation()
	_confirm.z_index = 40
	_notice = _label(_stage, "", Vector2(690, 718), Vector2(1130, 72), 26)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hints = _label(_root, "WASD / 方向键  选择      回车 / E / F  确认      ESC  返回", Vector2.ZERO, Vector2(1050, 40), 22)
	_hints.z_index = 100
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hints.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hints.add_theme_constant_override(&"outline_size", 5)
	_load_settings()
	_root.hide()
	get_viewport().size_changed.connect(_resize)
	_resize()


func configure(game: Node, saves: RefCounted) -> void:
	shell = game
	store = saves


func _build_description() -> void:
	_description = Control.new()
	_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_description)
	var tape := ColorRect.new()
	tape.position = Vector2(820, 50)
	tape.size = Vector2(1200, 90)
	tape.rotation = -0.035
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = DOTS
	tape.material = material
	_description.add_child(tape)
	_ghost = _label(_description, "SAVE / LOAD", Vector2(675, 205), Vector2(1370, 220), 150)
	_ghost.add_theme_font_override(&"font", HEAVY_FONT)
	_ghost.modulate.a = 0.16
	_ghost.rotation = -0.035
	_hero = _label(_description, "存档", Vector2(710, 264), Vector2(1130, 150), 112)
	_hero.add_theme_font_override(&"font", load("res://theme/fonts/card_bold.otf"))
	_hero.add_theme_constant_override(&"outline_size", 12)
	_hero.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_explanation = _label(_description, "", Vector2(735, 467), Vector2(1030, 174), 34)
	_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(_description, "→", Vector2(675, 473), Vector2(60, 60), 46).modulate = ACCENT


func _build_phone() -> void:
	_phone = Control.new()
	_phone.name = "Phone"
	_phone.size = Vector2(360, 760)
	_phone.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_phone)
	var texture: Texture2D = load("res://assets/ui/phone/phone_collage.png")
	var art := Sprite2D.new()
	art.name = "HalftonePhone"
	art.texture = texture
	art.centered = false
	var original_scale := 760.0 / 3350.0
	art.scale = Vector2.ONE * original_scale * 9449.0 / texture.get_width()
	art.rotation = -PI / 2
	art.position = Vector2(-2530, 8590) * original_scale
	_phone.add_child(art)
	_launcher = Control.new()
	_launcher.size = _phone.size
	_launcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone.add_child(_launcher)
	_label(_launcher, "新火", Vector2(28, 38), Vector2(296, 76), 52)
	_label(_launcher, "CREATOR / MENU", Vector2(30, 112), Vector2(310, 40), 22)
	var grid := GridContainer.new()
	grid.name = "Apps"
	grid.position = Vector2(24, 198)
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 13)
	grid.add_theme_constant_override(&"v_separation", 24)
	_launcher.add_child(grid)
	for index in APPS.size():
		var app: Array = APPS[index]
		var button := _button("", Vector2.ZERO, Vector2(96, 112))
		button.name = str(app[0]).capitalize() + "App"
		button.custom_minimum_size = Vector2(96, 112)
		button.rotation = -0.025 if index % 2 == 0 else 0.025
		button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		grid.add_child(button)
		var icon := _texture(button, str(app[2]), Vector2(16, 10), Vector2(64, 64))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(button, str(app[1]), Vector2(4, 79), Vector2(88, 30), 20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.mouse_entered.connect(_hover_app.bind(index))
		button.focus_entered.connect(_select_app.bind(index))
		button.pressed.connect(_activate_app.bind(index))
		_app_buttons.append(button)
	_label(_launcher, "SELECT AN APP", Vector2(26, 600), Vector2(310, 38), 23)
	_warning = _texture(_phone, "res://assets/ui/phone/pop_warning.svg", Vector2(37, 217), Vector2(280, 252))
	_warning.hide()


func _build_pets() -> void:
	_pets = Control.new()
	_pets.name = "MenuPets"
	_pets.size = Vector2(820, 210)
	_pets.scale = Vector2.ONE * 1.5
	_pets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_pets)
	var ids := ["write", "draw", "rhythm", "manga"]
	for index in ids.size():
		var pet := MenuPet.new()
		pet.name = str(ids[index]).capitalize() + "Pet"
		pet.setup(str(ids[index]), str(PET_ART[index]), 205)
		pet.position = Vector2(index * 205, 0)
		pet.walk_frequency = pet_walk_frequency
		_pets.add_child(pet)
		pet.interacted.connect(_on_pet_interacted)
		_pet_nodes[str(ids[index])] = pet
	_pet_nodes["write"].set_thinking(writer_thinking)


func _build_detail() -> void:
	_detail = Control.new()
	_detail.name = "AppWindow"
	_detail.position = Vector2(400, 65)
	_detail.size = Vector2(1450, 870)
	_detail.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage.add_child(_detail)
	_polygon(_detail, [Vector2(15, 44), Vector2(1406, 10), Vector2(1450, 832), Vector2(29, 870)], ACCENT)
	_polygon(_detail, [Vector2(0, 24), Vector2(1390, 0), Vector2(1430, 810), Vector2(15, 845)], Color.WHITE)
	_polygon(_detail, [Vector2(13, 36), Vector2(1376, 14), Vector2(1415, 796), Vector2(29, 830)], Color("101014"))
	_texture(_detail, "res://assets/ui/phone/pop_bolt.svg", Vector2(-155, 90), Vector2(210, 160))
	_title = _label(_detail, "", Vector2(64, 45), Vector2(1000, 76), 50)
	var close := _button("← 返回手机", Vector2(1110, 44), Vector2(240, 62))
	_detail.add_child(close)
	close.pressed.connect(_back)
	var scroll := ScrollContainer.new()
	scroll.name = "PageScroll"
	scroll.position = Vector2(65, 157)
	scroll.size = Vector2(1290, 601)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override(&"separation", 22)
	scroll.add_child(_content)
	_detail.hide()


func _build_confirmation() -> void:
	_confirm = Control.new()
	_confirm.name = "ImportantAction"
	_confirm.size = Vector2(1920, 1080)
	_stage.add_child(_confirm)
	var blocker := Control.new()
	blocker.size = _confirm.size
	_confirm.add_child(blocker)
	var question := Control.new()
	question.position = Vector2(915, 157)
	question.size = Vector2(770, 510)
	_confirm.add_child(question)
	var heading := _label(question, "请确认", Vector2(30, -100), Vector2(710, 180), 124)
	heading.name = "ConfirmHeading"
	heading.modulate = ACCENT
	heading.add_theme_font_override(&"font", HEAVY_FONT)
	_texture(question, "res://assets/ui/phone/pop_bubble.svg", Vector2.ZERO, Vector2(770, 400))
	_confirm_text = _label(question, "", Vector2(85, 66), Vector2(600, 174), 34)
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_ok = _button("确定", Vector2(116, 411), Vector2(260, 74))
	_confirm_ok.name = "ConfirmAction"
	question.add_child(_confirm_ok)
	_confirm_ok.pressed.connect(_accept_confirmation)
	var cancel := _button("取消", Vector2(431, 411), Vector2(260, 74))
	cancel.name = "CancelAction"
	question.add_child(cancel)
	cancel.pressed.connect(_cancel_confirmation)
	_confirm.hide()


func _resize() -> void:
	if _stage == null:
		return
	var area := get_viewport().get_visible_rect().size
	var factor := minf(area.x / 1920, area.y / 1080)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (area - Vector2(1920, 1080) * factor) * 0.5
	if _hints != null:
		_hints.scale = Vector2.ONE * factor
		_hints.position = area - (_hints.size + Vector2(24, 18)) * factor


func open_phone(app_id: String = "home") -> void:
	if _moving:
		return
	if is_open:
		show_app(app_id)
		return
	if shell == null or not shell.menu_open_reason().is_empty():
		return
	_was_paused = get_tree().paused
	get_tree().paused = true
	is_open = true
	_root.show()
	_shade.color.a = 0
	_phone.position = Vector2(180, 1400)
	_phone.rotation = 0.78
	_phone.scale = Vector2.ONE
	_pets.position = Vector2(620, 1160)
	current_app = "home"
	_select_app(_app_index)
	if app_id != "home":
		_build_app(app_id)
	await _set_view("home" if app_id == "home" else "detail")


func close_phone() -> void:
	if not is_open:
		return
	if _moving:
		if not _close_requested:
			_close_requested = true
			await _tween.finished
			_close_requested = false
			if is_open:
				close_phone()
		return
	_pending_action = Callable()
	_pending_cancel = Callable()
	_confirm.hide()
	_moving = true
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_phone, ^"position", Vector2(180, 1400), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_phone, ^"rotation", 0.78, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_pets, ^"position:y", 1190.0, 0.24)
	_tween.tween_property(_detail, ^"modulate:a", 0.0, 0.16)
	if is_instance_valid(_custom_detail):
		_tween.tween_property(_custom_detail, ^"modulate:a", 0.0, 0.16)
	_tween.tween_property(_description, ^"modulate:a", 0.0, 0.16)
	_tween.tween_property(_shade, ^"color:a", 0.0, 0.24)
	await _tween.finished
	_root.hide()
	_detail.hide()
	is_open = false
	_moving = false
	get_tree().paused = _was_paused
	closed.emit()


func _exit_tree() -> void:
	if is_open and get_tree() != null:
		get_tree().paused = _was_paused


func _set_view(target: String) -> void:
	_moving = true
	view_state = target
	_hints.text = "WASD / 方向键探索     鼠标选两条 / 右键拖动     ESC 返回" if target == "thinking" else "WASD / 方向键  选择      回车 / E / F  确认      ESC  返回"
	_extra_view_changed(target)
	_notice.position = Vector2(690, 718) if target == "home" else Vector2(470, 851)
	for button: Button in _app_buttons:
		button.disabled = target != "home"
		button.focus_mode = Control.FOCUS_ALL if target == "home" else Control.FOCUS_NONE
	_launcher.visible = target != "confirm"
	_warning.visible = target == "confirm"
	_confirm.visible = target == "confirm"
	if target == "detail" and not is_instance_valid(_custom_detail):
		if not _detail.visible:
			_detail.position = Vector2(475, 88)
			_detail.scale = Vector2.ONE * 0.96
		_detail.show()
	elif target == "detail":
		_detail.hide()
	var position := Vector2(145, 128)
	var phone_rotation := 0.105
	var phone_scale := Vector2.ONE
	var pets_position := Vector2(620, 730)
	var pets_scale := Vector2.ONE * 1.5
	if target == "detail":
		position = Vector2(-230, 396)
		pets_position = Vector2(555, 950)
	elif target == "thinking":
		position = Vector2(-340, 410) if _thinking_from_app else Vector2(-180, 290)
		phone_scale = Vector2.ONE * 1.22
		pets_position = Vector2(400, 970) if _thinking_from_app else Vector2(470, 795)
		pets_scale = Vector2.ONE * 1.8
	elif target == "confirm":
		position = Vector2(450, 108)
		phone_rotation = -0.07
		phone_scale = Vector2.ONE * 1.08
		pets_position = Vector2(425, 735)
		pets_scale = Vector2.ONE * 1.8
	_pets.z_index = 5 if target == "confirm" else 20
	for pet: MenuPet in _pet_nodes.values():
		pet._button.disabled = target != "home"
	_pet_nodes["write"].set_thinking(true if target == "thinking" else writer_thinking, target != "thinking")
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_phone, ^"position", position, 0.32)
	_tween.tween_property(_phone, ^"rotation", phone_rotation, 0.32)
	_tween.tween_property(_phone, ^"scale", phone_scale, 0.32)
	_tween.tween_property(_pets, ^"position", pets_position, 0.32)
	_tween.tween_property(_pets, ^"scale", pets_scale, 0.32)
	for pet: MenuPet in _pet_nodes.values():
		_tween.tween_property(pet, ^"defocus", 9.0 if target == "confirm" else 0.0, 0.32)
	_tween.tween_property(_description, ^"modulate:a", 1.0 if target == "home" else 0.0, 0.22)
	_tween.tween_property(_detail, ^"modulate:a", 1.0 if target == "detail" else 0.0, 0.24)
	if is_instance_valid(_custom_detail):
		_custom_detail.visible = _custom_detail_visible(target)
		_tween.tween_property(_custom_detail, ^"modulate:a", 1.0 if _custom_detail_visible(target) else 0.0, 0.24)
	_tween.tween_property(_detail, ^"position", Vector2(400, 65) if target == "detail" else Vector2(475, 88), 0.32)
	_tween.tween_property(_detail, ^"scale", Vector2.ONE if target == "detail" else Vector2.ONE * 0.96, 0.32)
	_tween.tween_property(_shade, ^"color:a", 0.69, 0.24)
	await _tween.finished
	_detail.visible = target == "detail" and not is_instance_valid(_custom_detail)
	_moving = false
	if target == "home":
		_app_buttons[_app_index].grab_focus()
	elif target == "confirm":
		_confirm_ok.grab_focus()
	elif target == "thinking":
		get_viewport().gui_release_focus()
	else:
		_focus_page()


func _hover_app(index: int) -> void:
	if view_state == "home" and not _moving:
		_app_buttons[index].grab_focus()
		_select_app(index)


func _select_app(index: int) -> void:
	_app_index = index
	var app: Array = APPS[index]
	_hero.text = str(app[1])
	_ghost.text = str(app[3])
	_explanation.text = str(app[4])
	for ordinal in _app_buttons.size():
		_app_buttons[ordinal].add_theme_stylebox_override(&"normal", _style(ACCENT if ordinal == index else Color("17171c"), 3, Color.WHITE, 3))


func _activate_app(index: int) -> void:
	if _moving or view_state != "home":
		return
	_select_app(index)
	show_app(str(APPS[index][0]))


func show_app(app_id: String) -> void:
	if _moving:
		return
	_notice.text = ""
	if app_id == "home":
		current_app = "home"
		_set_view("home")
		return
	_build_app(app_id)
	_set_view("detail")


func _build_app(app_id: String) -> void:
	current_app = "save" if app_id == "load" else app_id
	if is_instance_valid(_custom_detail):
		_stage.remove_child(_custom_detail)
		_custom_detail.queue_free()
		_custom_detail = null
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_build_page(current_app)


func _focus_page() -> void:
	var page: Control = _custom_detail if is_instance_valid(_custom_detail) else _content
	for control: Node in page.find_children("*", "BaseButton", true, false):
		if not control.disabled:
			control.grab_focus()
			return


func request_confirmation(message: String, action: Callable, cancel: Callable = Callable()) -> void:
	if _moving or view_state not in ["detail", "thinking"]:
		return
	_confirmation_return = view_state
	_pending_action = action
	_pending_cancel = cancel
	_focus_before_confirm = get_viewport().gui_get_focus_owner()
	_confirm_text.text = message
	_notice.text = ""
	_set_view("confirm")


func _accept_confirmation() -> void:
	if _moving or view_state != "confirm":
		return
	var action := _pending_action
	_pending_action = Callable()
	_pending_cancel = Callable()
	await _set_view(_confirmation_return)
	if action.is_valid():
		action.call()


func _cancel_confirmation() -> void:
	if _moving or view_state != "confirm":
		return
	var cancel := _pending_cancel
	_pending_action = Callable()
	_pending_cancel = Callable()
	await _set_view(_confirmation_return)
	if cancel.is_valid():
		cancel.call()
	if is_instance_valid(_focus_before_confirm) and _focus_before_confirm.is_visible_in_tree():
		_focus_before_confirm.grab_focus()


func _back() -> void:
	if _moving:
		return
	if _back_extra_view(): return
	if view_state == "confirm":
		_cancel_confirmation()
	elif view_state == "detail":
		show_app("home")
	else:
		close_phone()


func _input(event: InputEvent) -> void:
	if is_open and not _moving and _handle_app_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_open:
			if _moving and view_state == "home":
				close_phone()
			else:
				_back()
		else:
			open_phone()
	elif is_open and event is InputEventKey and event.pressed and not _moving:
		var focus := get_viewport().gui_get_focus_owner()
		var side := int({KEY_W: SIDE_TOP, KEY_A: SIDE_LEFT, KEY_S: SIDE_BOTTOM, KEY_D: SIDE_RIGHT}.get(event.keycode, -1))
		if side != -1 and focus != null:
			var next := focus.find_valid_focus_neighbor(side)
			if next != null:
				next.grab_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_E, KEY_F] and focus is Button:
			if focus is OptionButton:
				focus.show_popup()
			elif focus.toggle_mode:
				focus.button_pressed = not focus.button_pressed
			focus.pressed.emit()
			get_viewport().set_input_as_handled()


func _on_pet_interacted(id: String, thinking: bool) -> void:
	if view_state != "home" or _moving:
		return
	pet_interacted.emit(id)
	if id == "write" and thinking:
		thinking_requested.emit()
		if thinking_requested.get_connections().is_empty():
			notify("思考界面尚未开放。")


func notify(text: String) -> void:
	_notice.text = text


func _build_page(_app_id: String) -> void:
	pass


func _load_settings() -> void:
	pass


func _handle_app_input(_event: InputEvent) -> bool:
	return false


func _extra_view_changed(_target: String) -> void:
	pass


func _custom_detail_visible(target: String) -> bool:
	return target == "detail"


func _back_extra_view() -> bool:
	return false


func _paragraph(text: String, font_size: int = 28) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	_content.add_child(label)
	return label


func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label


func _texture(parent: Node, path: String, position: Vector2, size: Vector2) -> TextureRect:
	var texture := TextureRect.new()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.texture = load(path)
	texture.position = position
	texture.size = size
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)
	return texture


func _polygon(parent: Node, points: Array, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = color
	shape.antialiased = true
	parent.add_child(shape)


func _style(color: Color, radius: int = 0, border: Color = Color.WHITE, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(14)
	return style


func _button(text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override(&"font_size", 28)
	button.add_theme_stylebox_override(&"normal", _style(Color("17171c")))
	button.add_theme_stylebox_override(&"hover", _style(ACCENT, 0, Color.WHITE, 3))
	button.add_theme_stylebox_override(&"pressed", _style(Color("b91f41")))
	button.add_theme_stylebox_override(&"disabled", _style(Color("303038"), 0, Color("5c5c64")))
	button.add_theme_stylebox_override(&"focus", _style(Color.TRANSPARENT, 0, ACCENT, 4))
	return button
