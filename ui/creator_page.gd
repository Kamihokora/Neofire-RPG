extends VBoxContainer

const Rules := preload("res://gameplay/creator_rules.gd")
var _phone: CanvasLayer
var _selected := "write"


func configure(phone: CanvasLayer) -> void:
	_phone = phone
	add_theme_constant_override(&"separation", 18)
	_rebuild()


func _text(parent: Node, value: String, font_size: int = 25) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override(&"font_size", font_size)
	parent.add_child(label)
	return label


func _blocked() -> bool:
	return not _phone.shell.save_block_reason().is_empty()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var state := RunState.instance
	var next: int = state.journey.next_experience()
	_text(self, "队伍 Lv.%d   ·   经验 %s   ·   养成资源 %d" % [state.journey.level, "%d/%d" % [state.journey.experience, next] if next > 0 else "已达当前上限", state.journey.training_points], 30)
	if _blocked():
		_text(self, "战斗、对话或转场期间可查看，暂不可调整站位、装配和养成。")
	var formation_row := HBoxContainer.new()
	formation_row.add_theme_constant_override(&"separation", 18)
	add_child(formation_row)
	for index in state.formation.size():
		var member: String = state.formation[index]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(292, 190)
		card.add_theme_stylebox_override(&"panel", _phone._style(Color("202027")))
		formation_row.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override(&"separation", 10)
		card.add_child(box)
		_text(box, "%d号位 / %d费%s" % [index + 1, Rules.COSTS[index], " · 队长" if index == 0 else ""], 24)
		var portrait_row := HBoxContainer.new()
		box.add_child(portrait_row)
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(72, 72)
		art.texture = load(Rules.ART[member])
		portrait_row.add_child(art)
		_text(portrait_row, Rules.NAMES[member], 30)
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override(&"separation", 12)
		box.add_child(actions)
		for step: int in [-1, 1]:
			var button: Button = _phone._button("←" if step < 0 else "→", Vector2.ZERO, Vector2(116, 48))
			button.name = "Move%d%s" % [index, "Left" if step < 0 else "Right"]
			button.custom_minimum_size = Vector2(116, 48)
			button.disabled = _blocked() or index + step < 0 or index + step >= 4
			button.pressed.connect(_move.bind(index, step))
			actions.add_child(button)
	_text(self, "技能装配 · 每名创作者各有独立的2 / 4 / 6 / 10费槽", 27)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 16)
	add_child(tabs)
	for member: String in Rules.MEMBERS:
		var button: Button = _phone._button(Rules.NAMES[member], Vector2.ZERO, Vector2(215, 52))
		button.name = member.capitalize() + "Loadout"
		button.custom_minimum_size = Vector2(215, 52)
		if member == _selected:
			button.add_theme_stylebox_override(&"normal", _phone._style(_phone.ACCENT))
		button.pressed.connect(func() -> void:
			_selected = member
			_rebuild())
		tabs.add_child(button)
	for tier: int in [2, 4, 6, 10]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 20)
		add_child(row)
		_text(row, "%d费" % tier, 26).custom_minimum_size.x = 80
		var option := OptionButton.new()
		option.name = "Loadout%d" % tier
		option.custom_minimum_size = Vector2(410, 54)
		option.add_item("未装配")
		var ids: Array[String] = [""]
		for id: String in state.known_creator_skills:
			if Rules.matches_slot(id, _selected, tier):
				option.add_item(str(Rules.skills()[id]["name"]))
				ids.append(id)
		var equipped := state.equipped_creator_skill(_selected, tier)
		option.select(maxi(ids.find(equipped), 0))
		option.disabled = _blocked() or ids.size() == 1
		row.add_child(option)
		var description: String = Rules.skills().get(equipped, {}).get("description", "尚无可用技能")
		var label := _text(row, description, 24)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 650
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.item_selected.connect(_equip.bind(_selected, tier, ids, label))
	var growth_row := HBoxContainer.new()
	growth_row.add_theme_constant_override(&"separation", 20)
	add_child(growth_row)
	for kind: String in ["minimum_deck", "rarity_budget"]:
		var caption := "牌库下限 %d → %d" % [state.min_deck_size, maxi(10, state.min_deck_size - 1)] if kind == "minimum_deck" else "稀有度预算 %d → %d" % [state.rarity_budget, state.rarity_budget + 1]
		var cost := int(state.journey.growth()["growth_cost"])
		var button: Button = _phone._button("%s（消耗%d）" % [caption, cost], Vector2.ZERO, Vector2(570, 60))
		button.name = "GrowMinimum" if kind == "minimum_deck" else "GrowRarity"
		button.custom_minimum_size = Vector2(570, 60)
		button.disabled = _blocked() or state.journey.training_points < cost or (kind == "minimum_deck" and state.min_deck_size <= 10)
		button.pressed.connect(_grow.bind(kind))
		growth_row.add_child(button)


func _move(index: int, step: int) -> void:
	if not _blocked() and not _phone._moving and RunState.instance.swap_formation(index, index + step):
		_rebuild()


func _equip(index: int, member: String, tier: int, ids: Array[String], label: Label) -> void:
	if _blocked() or _phone._moving:
		return
	if RunState.instance.equip_creator_skill(member, tier, ids[index]):
		label.text = str(Rules.skills().get(ids[index], {}).get("description", "未装配"))


func _grow(kind: String) -> void:
	if _blocked() or _phone._moving:
		return
	_phone.request_confirmation("消耗养成资源，%s吗？" % ("降低牌库下限" if kind == "minimum_deck" else "增加稀有度预算"), func() -> void:
		if not _blocked() and RunState.instance.journey.buy_growth(kind, RunState.instance):
			_rebuild())
