extends "res://ui/split_app_page.gd"
## 笔记本保留标题/摘要列表，点击后左移，并在右侧查看提案与产物。

var _detail_id := ""
var _compose: Button
signal idea_opened


func configure(phone: CanvasLayer) -> void:
	build_frames(phone, "四人桌" if phone.can_submit_proposals() else "笔记本")
	var compose: Button = phone._button("＋  灵感合成", Vector2(42, 709), Vector2(565, 60))
	compose.name = "ComposeTab"
	_compose = compose
	compose.pressed.connect(func() -> void: phone.open_thinking(true))
	list_window.add_child(compose)
	RunState.instance.journey.changed.connect(_on_changed)
	_rebuild()


func _on_changed() -> void:
	_rebuild.call_deferred()


func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _text(parent: Node, value: String, font_size: int = 26) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label


func _rebuild() -> void:
	_clear(list_body)
	var journey := RunState.instance.journey
	var entries := 0
	for major: bool in [true, false]:
		for id: String in journey.inspiration()["recipes"]:
			var recipe: Dictionary = journey.inspiration()["recipes"][id]
			if (recipe["kind"] == "major") != major: continue
			var count := int(journey.ideas.get(id, 0))
			if count <= 0 and id not in journey.approved: continue
			entries += 1
			_build_row(id, recipe, count)
	list_count.text = "全部想法  ·  %d篇  /  大提案置顶" % entries
	if entries == 0: _text(list_body, "还没有想法。\n先去灵感合成，把两个词条组合起来。", 25)
	if not _detail_id.is_empty(): _build_detail()


func _build_row(id: String, recipe: Dictionary, count: int) -> void:
	var button: Button = _phone._button("", Vector2.ZERO, Vector2(550, 156))
	button.name = "Idea_" + id
	button.custom_minimum_size = Vector2(0, 156)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected := id == _detail_id and detail_open
	var normal: StyleBoxFlat = _phone._style(Color("29232c") if selected else Color("101014"), 0, _phone.ACCENT if selected else Color("35323b"), 0)
	normal.border_width_bottom = 1
	normal.border_width_left = 3 if selected else 0
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", _phone._style(Color("27232b"), 0, _phone.ACCENT, 2))
	list_body.add_child(button)
	var title_x := 46 if recipe["kind"] == "major" else 16
	if recipe["kind"] == "major":
		_phone._texture(button, "res://assets/ui/phone/proposal_pin.svg", Vector2(12, 18), Vector2(25, 30))
	var title: Label = _phone._label(button, str(recipe["name"]), Vector2(title_x, 13), Vector2(410, 43), 30)
	title.add_theme_font_override(&"font", _phone.HEAVY_FONT)
	var summary: Label = _phone._label(button, str(recipe["description"]), Vector2(16, 64), Vector2(510, 35), 23)
	summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var done: bool = recipe["kind"] == "major" and id in RunState.instance.journey.approved
	_phone._label(button, "已立项" if done else "待提交 ×%d" % count, Vector2(16, 108), Vector2(510, 30), 21).modulate = Color("b4b0ba")
	button.pressed.connect(_select_idea.bind(id))


func _select_idea(id: String) -> void:
	_detail_id = id
	reveal_detail()
	_rebuild()
	var selected := list_body.find_child("Idea_" + id, true, false) as Button
	if selected != null: selected.grab_focus()
	idea_opened.emit()


func show_thinking_panel() -> void:
	_detail_id = ""
	reveal_external_detail()
	_rebuild()


func thought_anchor_position() -> Vector2:
	var font: Font = _compose.get_theme_font(&"font")
	var font_size := _compose.get_theme_font_size(&"font_size")
	var text_width := font.get_string_size(_compose.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var plus_width := font.get_string_size("＋", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return _compose.get_global_transform_with_canvas() * Vector2((_compose.size.x - text_width + plus_width) * 0.5, _compose.size.y * 0.5)


func close_detail() -> void:
	super.close_detail()
	_detail_id = ""
	_rebuild()
	var first := list_body.find_child("Idea_*", true, false) as Button
	if first != null: first.grab_focus()


func handle_back() -> bool:
	if not detail_open: return false
	close_detail()
	return true


func _build_detail() -> void:
	_clear(detail_body)
	var journey := RunState.instance.journey
	var recipe: Dictionary = journey.inspiration()["recipes"][_detail_id]
	detail_heading.text = str(recipe["name"])
	_text(detail_body, "立项大提案" if recipe["kind"] == "major" else "便签提案", 24).modulate = _phone.ACCENT
	_text(detail_body, str(recipe["description"]), 30)
	_text(detail_body, "构想来源", 23).modulate = Color("b4b0ba")
	for word: String in recipe["inputs"]:
		_text(detail_body, "· " + str(journey.inspiration()["words"][word]["name"]), 26)
	for item: String in recipe.get("items", {}):
		var data: Dictionary = journey.inspiration().get("items", {}).get(item, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 24)
		detail_body.add_child(row)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(92, 92)
		icon.texture = load(str(data.get("icon", "res://assets/ui/icons/inventory.png")))
		row.add_child(icon)
		var description: Label = _text(row, "合成产物：%s ×%d\n%s" % [data.get("name", item), int(recipe["items"][item]), data.get("description", "")], 27)
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done: bool = recipe["kind"] == "major" and _detail_id in journey.approved
	_text(detail_body, "已在四人桌立项。" if done else "现有想法 ×%d。%s" % [int(journey.ideas.get(_detail_id, 0)), "带回四人桌提交后生效。" if recipe["kind"] == "major" else "可重复构想和提交。"], 24)
	var action: Button = _phone._button("已立项" if done else "提交提案", Vector2.ZERO, Vector2(400, 64))
	action.name = "DetailSubmit"
	action.custom_minimum_size = Vector2(400, 64)
	action.disabled = not _phone.can_submit_proposals() or int(journey.ideas.get(_detail_id, 0)) <= 0 or done
	action.tooltip_text = "请到四人桌提交" if not _phone.can_submit_proposals() else ""
	action.pressed.connect(_confirm_proposal.bind(_detail_id))
	detail_body.add_child(action)


func _confirm_proposal(id: String) -> void:
	if not _phone.can_submit_proposals(): return
	var journey := RunState.instance.journey
	_phone.request_confirmation("在四人桌提交提案\n“%s”吗？" % journey.inspiration()["recipes"][id]["name"], func() -> void:
		if _phone.can_submit_proposals(): journey.implement_idea(id, RunState.instance))
