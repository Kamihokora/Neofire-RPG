extends Control
## 战斗内的一轮交涉。复用项目对话皮肤，独立于探索 Dialogic 时间线。

signal choice_selected(index: int)
const DoboButtonStyle := preload("res://assets/ui/dobo_button_style.gd")

var text: RichTextLabel
var choices: Array[Button] = []
var active := false
var revealing := false
var _box: Panel
var _reveal_tween: Tween
var _chosen := false
var _choice_index := 0
var _choice_cursors: Array[TextureRect] = []
var _choice_normal: StyleBox
var _choice_hot: StyleBox
var _stick_axis := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.05, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = Panel.new()
	_box.position = Vector2(490, 770)
	_box.size = Vector2(1340, 250)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxTexture.new()
	skin.texture = load("res://assets/ui/panels/panel_black.png")
	skin.set_texture_margin_all(36)
	_box.add_theme_stylebox_override(&"panel", skin)
	add_child(_box)
	var plate := TextureRect.new()
	plate.position = Vector2(30, -24)
	plate.size = Vector2(250, 62)
	plate.texture = load("res://assets/ui/labels/label_red_small.png")
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(plate)
	_label(plate, "焰铃", Vector2.ZERO, Vector2(250, 62), 29).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text = RichTextLabel.new()
	text.position = Vector2(55, 60)
	text.size = Vector2(1230, 140)
	text.add_theme_font_size_override(&"normal_font_size", 36)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.scroll_active = false
	_box.add_child(text)
	_label(_box, "文手形态", Vector2(1040, 12), Vector2(250, 38), 21).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_choice_normal = DoboButtonStyle.create("res://assets/ui/buttons/button_black.png")
	_choice_hot = DoboButtonStyle.create("res://assets/ui/labels/label_red_small.png")
	for i in 3:
		var button := Button.new()
		button.name = "Choice%d" % (i + 1)
		button.text = "test%d" % (i + 1)
		button.tooltip_text = ["好感度 +10", "敌人获得 1 层易伤", "结束对话"][i]
		button.position = Vector2(1190 + i * 16, 454 + i * 91)
		button.size = Vector2(590, 72)
		# 手动维护唯一的选中项，避免焦点框与鼠标悬停同时高亮两项。
		button.focus_mode = Control.FOCUS_NONE
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		button.add_theme_font_size_override(&"font_size", 29)
		button.pressed.connect(_select.bind(i))
		button.mouse_entered.connect(_set_choice_index.bind(i))
		add_child(button)
		choices.append(button)
		var cursor := TextureRect.new()
		cursor.name = "Cursor"
		cursor.texture = load("res://assets/ui/arrows/arrow_red.png")
		cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cursor.size = Vector2(24, 24)
		cursor.pivot_offset = cursor.size * 0.5
		cursor.rotation = deg_to_rad(90) # 原图尖端朝上；顺时针转90°朝右，指向选项。
		cursor.position = Vector2(-34, 24)
		cursor.hide()
		button.add_child(cursor)
		_choice_cursors.append(cursor)
	_sync_choices()
	hide()


func begin(line: String = "test1") -> int:
	active = true
	_chosen = false
	_choice_index = 0
	_stick_axis = -1
	revealing = true
	text.text = line
	text.visible_characters = 0
	for button in choices:
		button.hide()
	show()
	_box.position.y = 808
	var opening := create_tween()
	opening.tween_property(_box, ^"position:y", 770.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await opening.finished
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(text, ^"visible_characters", line.length(), maxf(0.35, line.length() * 0.065))
	_reveal_tween.tween_callback(_show_choices)
	var selected: int = await choice_selected
	return selected


func _show_choices() -> void:
	revealing = false
	for button in choices:
		button.disabled = false
		button.show()
	_set_choice_index(0)


func _select(index: int) -> void:
	if not active or revealing or _chosen:
		return
	_chosen = true
	for button in choices:
		button.disabled = true
	choice_selected.emit(index)


func finish(feedback: String) -> void:
	for button in choices:
		button.hide()
	text.visible_characters = -1
	text.text = feedback
	await get_tree().create_timer(0.65).timeout
	var closing := create_tween()
	closing.tween_property(_box, ^"position:y", 1120.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await closing.finished
	active = false
	hide()


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and event.pressed:
		accept_event()
		if revealing:
			_complete_text()


func _input(event: InputEvent) -> void:
	if not active or _chosen:
		return
	var step := 0
	var confirm := false
	var handled := false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W, KEY_A, KEY_UP, KEY_LEFT: step = -1
			KEY_S, KEY_D, KEY_DOWN, KEY_RIGHT: step = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E, KEY_F: confirm = true
			KEY_ESCAPE: handled = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT: step = -1
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT: step = 1
			JOY_BUTTON_A: confirm = true
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if event.axis == _stick_axis and absf(event.axis_value) < 0.3:
			_stick_axis = -1
		elif _stick_axis == -1 and absf(event.axis_value) > 0.55:
			_stick_axis = event.axis
			step = 1 if event.axis_value > 0 else -1
	if step != 0:
		if not revealing:
			_set_choice_index(wrapi(_choice_index + step, 0, choices.size()))
		handled = true
	if confirm:
		if revealing:
			_complete_text()
		else:
			_select(_choice_index)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _complete_text() -> void:
	if _reveal_tween == null or not _reveal_tween.is_valid():
		return
	_reveal_tween.kill()
	text.visible_characters = -1
	_show_choices()


func _set_choice_index(index: int) -> void:
	if not active or revealing or _chosen:
		return
	_choice_index = index
	_sync_choices()


func _sync_choices() -> void:
	for i in choices.size():
		var selected := i == _choice_index
		# 所有按钮状态用同一选中来源，鼠标不动时键盘切换也不会留下旧高亮。
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			choices[i].add_theme_stylebox_override(state, _choice_hot if selected else _choice_normal)
		_choice_cursors[i].visible = selected


func _label(parent: Node, value: String, at: Vector2, extent: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = extent
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
