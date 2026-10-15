extends Control
## 非全屏漫画气泡里的探索画布：词条反弹，镜头可拖动或WASD平移。

signal monologue_requested(context: Dictionary)
const Chip := preload("res://ui/inspiration_chip.gd")
const VIEW_SIZE := Vector2(1180, 420)
var organize_available := true:
	set(value):
		organize_available = value
		_sync_organize()
var _phone: CanvasLayer
var _viewport: Control
var _field: Control
var _organize: Button
var _hint: Label
var _monologue: Label
var _chips: Dictionary = {}
var _velocities: Dictionary = {}
var _selected: Array[String] = []
var _held: Dictionary = {}
var _world_size := VIEW_SIZE
var _camera := Vector2.ZERO
var _dragging := false
var _organized := false
var _rejecting := false
var _rng := RandomNumberGenerator.new()
var _arrange_tween: Tween
var _view_size := VIEW_SIZE
var _bubble: Control
var _cloud: TextureRect
var _heading: Label
var _close: Button
var _tail: Control
var _from_notebook := false
var _origin_page: Control


func configure(phone: CanvasLayer) -> void:
	_phone = phone
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_tail = preload("res://ui/thought_tail.gd").new()
	add_child(_tail)
	var bubble := Control.new()
	_bubble = bubble
	bubble.position = Vector2(545, 100)
	bubble.size = Vector2(1280, 640)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	_cloud = _phone._texture(bubble, "res://assets/ui/phone/thought_cloud.svg", Vector2.ZERO, Vector2(1280, 640))
	_heading = _phone._label(bubble, "文手的思考", Vector2(90, 66), Vector2(800, 54), 35)
	_heading.modulate = Color("17171d")
	var close: Button = _phone._button("返回", Vector2(1040, 65), Vector2(150, 52))
	_close = close
	close.name = "CloseThoughts"
	close.pressed.connect(_phone._back)
	bubble.add_child(close)
	_viewport = Control.new()
	_viewport.name = "ThoughtViewport"
	_viewport.position = Vector2(50, 150)
	_viewport.size = VIEW_SIZE
	_viewport.clip_contents = true
	_viewport.gui_input.connect(_pan_input)
	bubble.add_child(_viewport)
	_field = Control.new()
	_field.name = "ThoughtField"
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_field)
	_hint = _phone._label(bubble, "", Vector2(130, 573), Vector2(1030, 42), 21)
	_hint.modulate = Color("33303a")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_monologue = _phone._label(bubble, "", Vector2(680, 68), Vector2(350, 52), 24)
	_monologue.modulate = Color("8b3450")
	_organize = _phone._button("一键整理：关", Vector2(1590, 950), Vector2(300, 62))
	_organize.name = "OrganizeThoughts"
	_organize.disabled = not organize_available
	_organize.pressed.connect(_toggle_organized)
	add_child(_organize)
	RunState.instance.journey.changed.connect(refresh)
	refresh()


func set_origin(from_notebook: bool, page: Control) -> void:
	_origin_page = page
	if _from_notebook == from_notebook: return
	_from_notebook = from_notebook
	_bubble.position = Vector2(900, 70) if from_notebook else Vector2(545, 100)
	_bubble.size = Vector2(1000, 820) if from_notebook else Vector2(1280, 640)
	_cloud.size = _bubble.size
	_view_size = Vector2(912, 540) if from_notebook else VIEW_SIZE
	_viewport.size = _view_size
	_viewport.position = Vector2(44, 150) if from_notebook else Vector2(50, 150)
	_heading.size.x = 700 if from_notebook else 800
	_close.position.x = 780 if from_notebook else 1040
	_monologue.position.x = 440 if from_notebook else 680
	_monologue.size.x = 290 if from_notebook else 350
	_hint.position.y = _bubble.size.y - 70
	_hint.size.x = _bubble.size.x - 160
	_camera = Vector2.ZERO
	refresh()


func _update_tail() -> void:
	var inverse: Transform2D = _phone._stage.get_global_transform_with_canvas().affine_inverse()
	var target: Vector2
	var origin: Vector2
	if _from_notebook and is_instance_valid(_origin_page):
		target = inverse * _origin_page.thought_anchor_position()
		origin = _bubble.position + Vector2(16, _bubble.size.y * 0.82)
	else:
		var pet: Control = _phone._pet_nodes["write"]
		target = inverse * (pet._button.get_global_transform_with_canvas() * pet.thought_anchor)
		origin = _bubble.position + Vector2(_bubble.size.x * 0.18, _bubble.size.y - 12)
	_tail.point_to(origin, target)


func refresh() -> void:
	if _arrange_tween != null and _arrange_tween.is_valid(): _arrange_tween.kill()
	for chip: Control in _chips.values():
		_field.remove_child(chip)
		chip.queue_free()
	_chips.clear()
	_velocities.clear()
	_selected.clear()
	_rejecting = false
	_sync_organize()
	var journey := RunState.instance.journey
	var total := 0
	for id: String in journey.inspirations: total += int(journey.inspirations[id])
	var extent := sqrt(maxf(1, float(total) / 5.0))
	_world_size = _view_size * extent
	_field.size = _world_size
	for id: String in journey.inspiration_order:
		var count := int(journey.inspirations.get(id, 0))
		if count <= 0: continue
		var data: Dictionary = journey.inspiration()["words"][id]
		var chip := Chip.new()
		chip.name = id
		chip.configure(id, str(data["name"]), count, data.get("kind", "common") == "story")
		_field.add_child(chip)
		chip.position = Vector2(_rng.randf_range(16, _world_size.x - 300), _rng.randf_range(18, _world_size.y - 110))
		chip.picked.connect(_pick)
		chip.gui_input.connect(_pan_input)
		_chips[id] = chip
		_velocities[id] = Vector2.from_angle(_rng.randf_range(0, TAU)) * _rng.randf_range(28, 55)
	if _organized: _arrange()
	_set_camera(_camera)
	_hint.visible = total == 0
	_hint.text = "还没有可用灵感。" if total == 0 else ""


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _phone.view_state != "thinking": return
	_update_tail()
	var direction := Vector2(float(_held.has(KEY_D) or _held.has(KEY_RIGHT)) - float(_held.has(KEY_A) or _held.has(KEY_LEFT)), float(_held.has(KEY_S) or _held.has(KEY_DOWN)) - float(_held.has(KEY_W) or _held.has(KEY_UP)))
	_set_camera(_camera + direction.normalized() * delta * 460)
	if not _organized:
		for id: String in _chips:
			var chip: Control = _chips[id]
			if id in _selected: continue
			var motion: Vector2 = _velocities[id]
			chip.position += motion * delta
			var maximum := _world_size - chip.size - Vector2(16, 18)
			if chip.position.x < 16 or chip.position.x > maximum.x: motion.x *= -1
			if chip.position.y < 18 or chip.position.y > maximum.y: motion.y *= -1
			chip.position = chip.position.clamp(Vector2(16, 18), maximum)
			_velocities[id] = motion


func handle_input(event: InputEvent) -> bool:
	# 松开鼠标即使发生在气泡外，也要结束拖拽，防止词条再也无法选中。
	if event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT] and _dragging:
		_dragging = false
		return true
	if event is InputEventMouseMotion and _dragging:
		_set_camera(_camera - event.relative / _phone._stage.scale.x)
		return true
	if event is InputEventKey and event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		if event.pressed: _held[event.keycode] = true
		else: _held.erase(event.keycode)
		return true
	return false


func clear_input() -> void:
	_held.clear()
	_dragging = false


func _pan_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and not _chips.values().has(get_viewport().gui_get_hovered_control())):
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_set_camera(_camera + Vector2(0, -100 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 100))
	elif event is InputEventMouseMotion and _dragging:
		_set_camera(_camera - event.relative / _phone._stage.scale.x)


func _set_camera(value: Vector2) -> void:
	_camera = value.clamp(Vector2.ZERO, (_world_size - _view_size).max(Vector2.ZERO))
	_field.position = -_camera


func _pick(id: String) -> void:
	if _phone._moving or _phone.view_state != "thinking" or _dragging or _rejecting: return
	if _arrange_tween != null and _arrange_tween.is_running(): return
	if id in _selected: _selected.erase(id)
	else: _selected.append(id)
	for word: String in _chips: _chips[word].set_chosen(word in _selected)
	_sync_organize()
	monologue_requested.emit({"event":"selected", "words":_selected.duplicate()})
	if _selected.size() != 2: return
	var a := _selected[0]
	var b := _selected[1]
	var journey := RunState.instance.journey
	var recipe := journey.find_recipe(a, b)
	if recipe.is_empty() or not journey.can_compose(recipe):
		_reject_pair()
		return
	monologue_requested.emit({"event":"before_compose", "words":[a,b], "recipe":recipe})
	_phone.request_confirmation("开始构想“%s”吗？" % journey.inspiration()["recipes"][recipe]["name"], func() -> void:
		var result: String = journey.compose(a, b)
		if not result.is_empty():
			show_monologue("想法已收入笔记本。")
			monologue_requested.emit({"event":"composed", "recipe":result}), func() -> void:
			_selected.clear()
			_sync_organize()
			for chip: Button in _chips.values(): chip.set_chosen(false))


func _toggle_organized() -> void:
	if not organize_available or _rejecting or not _selected.is_empty(): return
	_organized = not _organized
	_organize.text = "一键整理：开" if _organized else "一键整理：关"
	if _organized: _arrange()
	else:
		if _arrange_tween != null and _arrange_tween.is_valid(): _arrange_tween.kill()
		var total := 0
		for count: Variant in RunState.instance.journey.inspirations.values(): total += int(count)
		_world_size = _view_size * sqrt(maxf(1, float(total) / 5.0))
		_field.size = _world_size
		_set_camera(_camera)


func _arrange() -> void:
	if _arrange_tween != null and _arrange_tween.is_valid(): _arrange_tween.kill()
	var columns := maxi(1, int((_view_size.x - 20) / 290))
	_world_size = Vector2(_view_size.x, maxf(_view_size.y, ceilf(_chips.size() / float(columns)) * 114 + 24))
	_field.size = _world_size
	_set_camera(Vector2.ZERO)
	if _chips.is_empty(): return
	_arrange_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var index := 0
	for id: String in RunState.instance.journey.inspiration_order:
		if not _chips.has(id): continue
		_arrange_tween.tween_property(_chips[id], ^"position", Vector2(16 + (index % columns) * 290, 24 + floorf(index / float(columns)) * 114), 0.3)
		index += 1


func show_monologue(text: String) -> void:
	_monologue.text = text


func _sync_organize() -> void:
	if _organize == null: return
	_organize.disabled = not organize_available or not _selected.is_empty() or _rejecting
	_organize.tooltip_text = "请先取消选中的灵感，再切换整理。" if not _selected.is_empty() else "按获得顺序吸附排列；关闭后恢复自由弹跳。"


func _reject_pair() -> void:
	_rejecting = true
	monologue_requested.emit({"event":"incompatible", "words":_selected.duplicate()})
	var tween := create_tween().set_parallel(true)
	for id: String in _selected:
		var chip: Button = _chips[id]
		chip.set_invalid(true)
		var home := chip.position
		tween.tween_method(func(progress: float) -> void:
			if is_instance_valid(chip): chip.position = home + Vector2(sin(progress * TAU * 4) * (1 - progress) * 12, 0), 0.0, 1.0, 0.4)
	tween.chain().tween_callback(func() -> void:
		for chip: Button in _chips.values():
			chip.set_invalid(false)
			chip.set_chosen(false)
		_selected.clear()
		_rejecting = false)
	tween.tween_callback(_sync_organize)


func _exit_tree() -> void:
	if _arrange_tween != null and _arrange_tween.is_valid(): _arrange_tween.kill()
