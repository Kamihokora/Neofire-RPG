extends Control
## 可复用的二级应用框体：紧凑列表向左让位，独立展开右侧详情。

var list_window: Control
var detail_window: Control
var list_body: VBoxContainer
var detail_body: VBoxContainer
var list_count: Label
var detail_heading: Label
var detail_open := false
var external_detail := false
var _phone: CanvasLayer
var _connector: Control
var _slide: Tween


func build_frames(phone: CanvasLayer, title: String) -> void:
	_phone = phone
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connector = Control.new()
	_connector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_connector)
	_phone._polygon(_connector, [Vector2(756, 334), Vector2(930, 252), Vector2(965, 492), Vector2(820, 421), Vector2(634, 305)], Color.WHITE)
	_phone._polygon(_connector, [Vector2(760, 347), Vector2(930, 267), Vector2(953, 476), Vector2(827, 411), Vector2(672, 324)], Color("101014"))
	_connector.hide()
	list_window = _frame("NotebookList", Vector2(650, 800), Vector2(650, 105))
	_phone._texture(list_window, "res://assets/ui/phone/pop_bolt.svg", Vector2(-130, 60), Vector2(175, 135))
	_phone._label(list_window, title, Vector2(43, 36), Vector2(460, 65), 43).add_theme_font_override(&"font", _phone.HEAVY_FONT)
	list_count = _phone._label(list_window, "", Vector2(45, 107), Vector2(540, 40), 22)
	list_count.modulate = Color("b4b0ba")
	list_body = _scroll(list_window, Vector2(42, 170), Vector2(565, 510))
	var close: Button = _phone._button("×", Vector2(546, 35), Vector2(62, 58))
	close.name = "CloseNotebook"
	close.pressed.connect(_phone._back)
	list_window.add_child(close)
	detail_window = _frame("NotebookDetail", Vector2(905, 845), Vector2(930, 72))
	var ghost: Label = _phone._label(detail_window, "DETAIL", Vector2(916, 106), Vector2(650, 120), 100)
	ghost.rotation = PI / 2
	ghost.add_theme_font_override(&"font", _phone.HEAVY_FONT)
	detail_heading = _phone._label(detail_window, "", Vector2(45, 40), Vector2(640, 100), 42)
	detail_heading.add_theme_font_override(&"font", _phone.HEAVY_FONT)
	detail_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_body = _scroll(detail_window, Vector2(45, 167), Vector2(700, 600))
	var back: Button = _phone._button("×", Vector2(757, 36), Vector2(62, 58))
	back.name = "CloseIdeaDetail"
	back.pressed.connect(close_detail)
	detail_window.add_child(back)
	detail_window.hide()


func _frame(node_name: String, extent: Vector2, origin: Vector2) -> Control:
	var frame := Control.new()
	frame.name = node_name
	frame.position = origin
	frame.size = extent
	add_child(frame)
	_phone._polygon(frame, [Vector2(5, 20), Vector2(extent.x - 7, 4), extent + Vector2(9, -12), Vector2(16, extent.y)], _phone.ACCENT)
	_phone._polygon(frame, [Vector2.ZERO, Vector2(extent.x - 17, -6), extent - Vector2(3, 24), Vector2(3, extent.y - 13)], Color.WHITE)
	_phone._polygon(frame, [Vector2(9, 10), Vector2(extent.x - 27, 5), extent - Vector2(16, 36), Vector2(15, extent.y - 25)], Color("101014"))
	return frame


func _scroll(parent: Control, origin: Vector2, extent: Vector2) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.position = origin
	scroll.size = extent
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 18)
	scroll.add_child(body)
	return body


func reveal_detail() -> void:
	if detail_open and not external_detail: return
	external_detail = false
	detail_open = true
	detail_window.show()
	_connector.show()
	detail_window.position = Vector2(1000, 72)
	detail_window.modulate.a = 0
	_animate(Vector2(185, 125), true)


func close_detail() -> void:
	if not detail_open: return
	detail_open = false
	external_detail = false
	_animate(Vector2(650, 105), false)


func reveal_external_detail() -> void:
	if external_detail: return
	detail_open = true
	external_detail = true
	detail_window.hide()
	_connector.hide()
	if _slide != null and _slide.is_valid(): _slide.kill()
	_slide = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(list_window, ^"position", Vector2(185, 125), 0.3)


func _animate(list_position: Vector2, opening: bool) -> void:
	if _slide != null and _slide.is_valid(): _slide.kill()
	_slide = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide.tween_property(list_window, ^"position", list_position, 0.3)
	_slide.tween_property(detail_window, ^"position", Vector2(930 if opening else 1000, 72), 0.3)
	_slide.tween_property(detail_window, ^"modulate:a", 1.0 if opening else 0.0, 0.22)
	_slide.tween_property(_connector, ^"modulate:a", 1.0 if opening else 0.0, 0.22)
	if not opening:
		_slide.chain().tween_callback(func() -> void:
			if not detail_open:
				detail_window.hide()
				_connector.hide())


func _exit_tree() -> void:
	if _slide != null and _slide.is_valid(): _slide.kill()
