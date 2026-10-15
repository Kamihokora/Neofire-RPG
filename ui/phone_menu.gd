extends "res://ui/phone_stage.gd"
## 应用内容与实际功能；演出/选择/确认交给 phone_stage。

var settings_path := "user://settings.cfg"
var _settings := ConfigFile.new()
var _deck_view: Control
var _meeting_table: Node2D
var _thought_board: Control
var _thinking_return_app := "home"
signal writer_monologue_requested(context: Dictionary)
var inspiration_organize_available := true:
	set(value):
		inspiration_organize_available = value
		if is_instance_valid(_thought_board): _thought_board.organize_available = value


func _ready() -> void:
	super._ready()
	RunState.instance.journey.changed.connect(_sync_thinking)
	thinking_requested.connect(open_thinking)
	closed.connect(func() -> void: _meeting_table = null)
	_sync_thinking()


func _sync_thinking() -> void:
	writer_thinking = RunState.instance.journey.has_combination()
	if view_state == "thinking": _pet_nodes["write"].set_thinking(true, false)


func show_writer_monologue(text: String) -> void:
	if is_instance_valid(_thought_board): _thought_board.show_monologue(text)


func open_thinking(from_notebook: bool = false) -> void:
	if _moving or not is_open or view_state == "thinking": return
	_thinking_from_app = from_notebook and is_instance_valid(_custom_detail)
	_thinking_return_app = current_app if _thinking_from_app else "home"
	if not is_instance_valid(_thought_board):
		_thought_board = preload("res://ui/thought_board.gd").new()
		_thought_board.name = "WriterThoughts"
		_stage.add_child(_thought_board)
		_thought_board.z_index = 35
		_thought_board.configure(self)
		_thought_board.organize_available = inspiration_organize_available
		_thought_board.monologue_requested.connect(func(context: Dictionary) -> void: writer_monologue_requested.emit(context))
	current_app = "inspiration"
	_set_view("thinking")


func _extra_view_changed(target: String) -> void:
	if is_instance_valid(_thought_board):
		if target == "thinking":
			if _thinking_from_app and is_instance_valid(_custom_detail): _custom_detail.show_thinking_panel()
			_thought_board.set_origin(_thinking_from_app, _custom_detail)
		_thought_board.visible = target == "thinking"
		if target != "thinking": _thought_board.clear_input()


func _back_extra_view() -> bool:
	if view_state == "detail" and is_instance_valid(_custom_detail) and _custom_detail.has_method("handle_back"):
		return _custom_detail.handle_back()
	if view_state != "thinking": return false
	if _thinking_from_app and is_instance_valid(_custom_detail):
		_custom_detail.close_detail()
		current_app = _thinking_return_app
		_set_view("detail")
	else:
		show_app(_thinking_return_app)
	return true


func _custom_detail_visible(target: String) -> bool:
	return target == "detail" or (target == "thinking" and _thinking_from_app)


func open_meeting(table: Node2D) -> void:
	_meeting_table = table
	if not can_submit_proposals():
		_meeting_table = null
		return
	open_phone("meeting")


func can_submit_proposals() -> bool:
	if not is_instance_valid(_meeting_table) or shell == null or not shell.save_block_reason().is_empty():
		return false
	var player: Node2D = shell.current_player()
	return player != null and shell.current_map.is_ancestor_of(_meeting_table) and _meeting_table.is_in_group(&"proposal_table") and _meeting_table.is_available(player)


func _build_page(app_id: String) -> void:
	match app_id:
		"save": _slots()
		"party": _party()
		"deck": _deck()
		"inventory": _inventory()
		"settings": _settings_page()
		"notebook", "meeting": _notebook(app_id == "meeting")


func _slots() -> void:
	_title.text = "存读档 / SAVE & LOAD"
	var reason: String = shell.save_block_reason()
	if not reason.is_empty():
		_paragraph(reason)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 24)
	_content.add_child(cards)
	for info: Dictionary in store.list_slots():
		var slot := int(info["slot"])
		var valid := bool(info.get("ok", false))
		var text := "空存档" if info.get("empty", false) else str(info.get("error", ""))
		if valid:
			valid = shell.valid_snapshot(info["data"])
			if valid:
				var data: Dictionary = info["data"]
				var unix_time := Time.get_unix_time_from_datetime_string(str(info["saved_at"]))
				var local_time := unix_time + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
				var minutes := int(float(data["run"]["play_seconds"]) / 60)
				text = "%s\n\n%s\n卡组 %d  ·  %d分" % [shell.map_display_name(str(data["map_id"])), Time.get_datetime_string_from_unix_time(local_time).replace("T", " "), data["run"]["deck"].size(), minutes]
				if info.get("recovered", false):
					text += "\n将使用上一份有效备份"
			else:
				text = "存档内容不兼容"
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(390, 385)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override(&"panel", _style(Color("1e1e24"), 0, Color.WHITE, 2))
		cards.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 20)
		card.add_child(box)
		var heading := Label.new()
		heading.text = "0%d / 存档" % slot
		heading.add_theme_font_size_override(&"font_size", 34)
		heading.add_theme_color_override(&"font_color", ACCENT)
		box.add_child(heading)
		var description := Label.new()
		description.text = text
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.add_theme_font_size_override(&"font_size", 24)
		box.add_child(description)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override(&"separation", 16)
		box.add_child(actions)
		var save := _button("保存", Vector2.ZERO, Vector2(165, 64))
		save.name = "Slot%dSave" % slot
		save.custom_minimum_size.y = 64
		save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save.disabled = not reason.is_empty() or bool(info.get("unsupported", false))
		save.pressed.connect(_confirm_save.bind(slot))
		actions.add_child(save)
		var read := _button("读取", Vector2.ZERO, Vector2(165, 64))
		read.name = "Slot%dLoad" % slot
		read.custom_minimum_size.y = 64
		read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		read.disabled = not reason.is_empty() or not valid
		read.pressed.connect(_confirm_load.bind(slot))
		actions.add_child(read)


func _confirm_save(slot: int) -> void:
	request_confirmation("确定保存到存档 %d 吗？\n已有存档会保留一份备份。" % slot, save_requested.emit.bind(slot))


func _confirm_load(slot: int) -> void:
	request_confirmation("确定读取存档 %d 吗？\n当前未保存的进度将被替换。" % slot, load_requested.emit.bind(slot))


func _party() -> void:
	_title.text = "伙伴 / CREATORS"
	var page := preload("res://ui/creator_page.gd").new()
	_content.add_child(page)
	page.configure(self)


func _notebook(meeting: bool) -> void:
	_title.text = "四人桌 / PROPOSAL" if meeting else "笔记本 / NOTEBOOK"
	var page := preload("res://ui/notebook_page.gd").new()
	page.name = "NotebookPage"
	page.z_index = 30
	_stage.add_child(page)
	_custom_detail = page
	page.modulate.a = 0
	page.configure(self)
	page.idea_opened.connect(func() -> void:
		if view_state == "thinking" and not _moving:
			current_app = _thinking_return_app
			_set_view("detail"))



func _deck() -> void:
	_title.text = "卡组 / CARD FILE"
	_deck_view = preload("res://ui/menu_deck_view.gd").new()
	_content.add_child(_deck_view)
	_deck_view.configure(_stage, RunState.instance.deck)


func _handle_app_input(event: InputEvent) -> bool:
	if view_state == "thinking" and is_instance_valid(_thought_board):
		return _thought_board.handle_input(event)
	if current_app == "deck" and view_state == "detail" and is_instance_valid(_deck_view):
		return _deck_view.handle_inspector_input(event)
	return false


func _inventory() -> void:
	_title.text = "背包 / POCKET"
	if RunState.instance.inventory.is_empty():
		_paragraph("背包暂时是空的。")
	else:
		for id: String in RunState.instance.inventory:
			_paragraph("%s  ×%d" % [id, int(RunState.instance.inventory[id])])
	_paragraph("遗物容量：%d" % int(RunState.instance.global_flags.get("max_relic_slots", 1)))


func _fullscreen_active() -> bool:
	if DisplayServer.get_name() == "headless":
		return bool(_settings.get_value("video", "fullscreen", false))
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _load_settings() -> void:
	if _settings.load(settings_path) == OK:
		pet_walk_frequency = float(_settings.get_value("menu", "walk_frequency", 0.5))
		AudioServer.set_bus_volume_linear(0, clampf(float(_settings.get_value("audio", "master", 1.0)), 0, 1))
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(_settings.get_value("video", "fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED)


func _settings_page() -> void:
	_title.text = "设置 / OPTIONS"
	_paragraph("主音量")
	var volume := HSlider.new()
	volume.name = "MasterVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = roundf(AudioServer.get_bus_volume_linear(0) * 100)
	volume.custom_minimum_size.y = 64
	_content.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void:
		AudioServer.set_bus_volume_linear(0, value / 100)
		_settings.set_value("audio", "master", value / 100)
		_settings.save(settings_path))
	var fullscreen := CheckButton.new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.text = "全屏显示"
	fullscreen.custom_minimum_size.y = 76
	fullscreen.button_pressed = _fullscreen_active()
	_content.add_child(fullscreen)
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		var previous := _fullscreen_active()
		if _moving or view_state != "detail":
			fullscreen.set_pressed_no_signal(previous)
			return
		request_confirmation("确定%s全屏显示吗？" % ("开启" if enabled else "关闭"), func() -> void:
			if DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
			_settings.set_value("video", "fullscreen", enabled)
			_settings.save(settings_path), func() -> void:
			if is_instance_valid(fullscreen):
				fullscreen.set_pressed_no_signal(previous)))
	_paragraph("桌宠走动频率")
	var frequency := OptionButton.new()
	frequency.name = "PetWalkFrequency"
	frequency.custom_minimum_size = Vector2(400, 64)
	var values := [0.0, 0.5, 1.0, 2.0]
	for text: String in ["不移动", "0.5倍（默认）", "1倍", "2倍"]:
		frequency.add_item(text)
	frequency.select(maxi(values.find(pet_walk_frequency), 0))
	_content.add_child(frequency)
	frequency.item_selected.connect(func(index: int) -> void:
		pet_walk_frequency = float(values[index])
		_settings.set_value("menu", "walk_frequency", pet_walk_frequency)
		_settings.save(settings_path))
