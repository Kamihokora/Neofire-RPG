@tool
class_name NeofireDialogueBox
extends DialogicLayoutBase
## 新火 RPG 的对话框外壳（Dialogic 自定义 layout base）。
##
## 外观 = 原来 quick_dialogue.tscn 那套（底板/头像/名字牌/正文/继续箭头/尖角），一点没改；
## 但剧本、角色、分支、存档全部交给 Dialogic，quick_dialogue.gd 那套 JSON/剧本解析退休。
##
## 游戏侧只需要两件事：
##   ① NeofireDialogueBox.register_character(角色资源, 场上节点)  → 气泡跟着谁
##   ② NeofireDialogueBox.set_default_actor(节点)                → 没登记的说话者跟谁
## 其余（出现/收场/跟随/尖角/头像/名字）都在这里自动处理。

#region 导出（会出现在 Dialogic 的样式编辑器里）
@export_group("皮肤")
## 手绘素材替换接口：挂 .tres 就接管全部外观，留空用场景里调好的那套
@export var skin: DialogueBoxSkin

@export_group("跟随")
## 框相对锚点头顶再往上的距离（屏幕像素）
@export var head_offset: float = 96.0
## 摄像机式跟随：指数阻尼系数（0 = 硬跟随）
@export var follow_smoothing: float = 10.0
## 目标瞬移超过这个距离就直接吸附，避免跨半屏拖尾
@export var follow_snap_distance: float = 320.0

@export_group("尖角")
@export var tail_enabled: bool = true
@export var tail_root_margin: float = 60.0
@export var tail_root_inset: float = 8.0
@export var tail_tip_gap: float = 0.25
@export var tail_curve: float = 0.5

@export_group("开合动画")
@export var open_duration: float = 0.12
@export var close_duration: float = 0.16
@export var open_from_scale: float = 0.82

@export_group("选项（Dialogic 分支）")
## 一次最多同时显示的选项数（不够会显示不全，多了会自己隐藏）
@export var choice_count: int = 5
@export var choice_font_size: int = 20
## 最窄宽度（文字长了会按文字自动撑宽）
@export var choice_min_width: float = 150.0
@export var choice_height: float = 46.0
@export var choice_separation: float = 10.0
## 选项相对对话框右边缘的偏移（x 往右、y 往下；贴到屏幕边会自己夹住）
@export var choice_offset: Vector2 = Vector2(26.0, 0.0)
## 给左侧小箭头留的内边距（文字往右让开）
@export var choice_text_left: float = 34.0
@export var choice_text_right: float = 18.0
@export var choice_arrow_size: float = 16.0
## 箭头角度：素材朝上，-90 = 指向左（箭头对着选项文字）
@export var choice_arrow_angle: float = -90.0
@export var choice_arrow_x: float = 10.0
@export var choice_font_color: Color = Color(1, 1, 1)
@export var choice_font_outline_color: Color = Color(0.13, 0.02, 0.06)
@export var choice_font_outline_size: int = 4
## 鼠标悬停/键盘选中时把底图调亮
@export var choice_hot_tint: Color = Color(1.15, 1.12, 1.12)
## 选项打开时的确认键（回车/空格/手柄 A 是 ui_accept，按钮自己有焦点就会处理）
@export var choice_confirm_keys: Array[int] = [KEY_E, KEY_F]
## 选项打开时锁住角色（不然一边走一边选，还得回头用鼠标点）
@export var choice_lock_actor: bool = true
## 皮肤替换接口：留空用名字框同款素材（labelAdvanced_red）
@export var choice_bg_texture: Texture2D
@export var choice_arrow_texture: Texture2D

@export_group("配色取舍")
## 是否采用角色的 name_color（角色的 color 字段）。默认关 = 保持白字外观
@export var use_json_colors: bool = false
#endregion

## 脚本 extends DialogicLayoutBase(=Node)，静态类型上没有 visible / get_viewport_rect()，
## 所以可见性与视口都从 DialogueBox(Panel) 上取。
const SCREEN_MARGIN := 8.0
## 名字框同款素材的 1/4 小图（184×46）：整张缩到小胶囊尺寸，圆头半径 = 23px，
## 这样九宫格拉伸中间时两头还是圆的（用原图 734×185 直接拉会把圆头挤扁）
const CHOICE_BG_PATH := "res://assets/ui/labels/label_red_small.png"
const CHOICE_BG_CORNER := 23.0
const CHOICE_ARROW_PATH := "res://assets/ui/arrows/arrow_red.png"


@onready var _box: Panel = $DialogueBox
@onready var _avatar: TextureRect = $DialogueBox/Avatar
@onready var _name_plate: TextureRect = $DialogueBox/NamePlate
@onready var _name_label: Label = $DialogueBox/NamePlate/NameLabel
@onready var _text_label: RichTextLabel = $DialogueBox/TextLabel
@onready var _continue_hint: TextureRect = $DialogueBox/ContinueHint
@onready var _tail: Line2D = $DialogueBox/Tail
@onready var _choices: VBoxContainer = $Choices

## 角色资源 → 场上跟随的节点（气泡浮在谁头顶）
var registered_characters: Dictionary = {}
## 没登记的角色（旁白/物件）默认跟谁
var default_actor: Node2D = null

## 选项期间被我们锁住的那个角色 + 锁之前它是动是停
var _choice_locked_actor: Node2D = null
var _choice_lock_prev_active := true
## 当前选中的是第几项（键盘用它；鼠标悬停也会把它挪过去）
var _choice_index := 0

var _box_actor: Node2D = null
var _box_tween: Tween = null
var _open_seq := 0
var _narrator_color := Color(0.8, 0.8, 0.8)
var _name_color_default := Color.WHITE
var _text_color_default := Color.WHITE


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_box.visible = false
	_apply_skin()

	Dialogic.Text.about_to_show_text.connect(_on_about_to_show_text)
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# 分支：Dialogic 会找树上的 DialogicNode_ChoiceButton 来显示选项，我们自己建好
	_build_choice_buttons()
	Dialogic.Choices.question_shown.connect(_on_question_shown)
	Dialogic.Choices.choice_selected.connect(_on_choice_selected)
	_text_label.connect(&"started_revealing_text", func() -> void: _continue_hint.visible = false)
	_text_label.connect(&"finished_revealing_text", func() -> void: _continue_hint.visible = true)


## Dialogic 的 Node 导出在 .tscn 里用相对路径解析不可靠（实测 ".." 会解析成自己），
## 结果旁白只隐藏了文字、留下一个空名字牌。这里直接指定：
## 名字为空时隐藏的是整个名字牌节点。
func _setup_name_label() -> void:
	_name_label.set(&"hide_when_empty", true)
	_name_label.set(&"name_label_root", _name_plate)


#region 游戏侧接口
################################################################################

## 把某个角色绑到场上节点：该角色说话时，气泡就浮在那个节点头顶
func register_character(character: Variant, node: Node2D) -> void:
	if typeof(character) == TYPE_STRING:
		var path_or_name: String = character
		character = load(path_or_name) if "://" in path_or_name else DialogicResourceUtil.get_character_resource(path_or_name)
		if character == null:
			printerr("[NeofireBox] register_character 找不到角色：", path_or_name)
			return
	registered_characters[character] = node


func clear_registrations() -> void:
	registered_characters.clear()


## 没登记的角色（旁白、物件自己）默认浮在谁头顶
func set_default_actor(node: Node2D) -> void:
	default_actor = node


## 立即出现（不播开合动画）
func show_now() -> void:
	_open_box(true)
#endregion


#region Dialogic 回调
################################################################################

func _on_timeline_started() -> void:
	_open_box()


func _on_timeline_ended() -> void:
	Dialogic.Choices.hide_all_choices()
	_choices.visible = true
	_lock_actor_for_choice(false)
	_close_box()


#region 分支选项
################################################################################

## 注意：容器必须一直 visible。
## Dialogic 的 show_current_question() 会先 hide_all_choices()，再用
## get_choice_button() 找按钮 —— 而它要求按钮 is_visible_in_tree()。
## 所以容器一藏，按钮就永远选不中（选项不显示）。按钮本身的显示/隐藏由 Dialogic 管。
func _build_choice_buttons() -> void:
	for child in _choices.get_children():
		child.queue_free()
	for i in choice_count:
		var button := DialogicNode_ChoiceButton.new()
		button.name = "Choice%d" % (i + 1)
		button.custom_minimum_size = Vector2(choice_min_width, choice_height)
		# 不要焦点：Dialogic 的选项按钮有"焦点跟鼠标"逻辑（mouse_entered → grab_focus，
		# 焦点一变还会 warp_mouse），既会把光标拽到别的选项上，又会抢走点击。
		# 我们自己维护 _choice_index + 小箭头，键盘/鼠标两条路都走自己的。
		button.focus_mode = Control.FOCUS_NONE
		# 外观全交给 stylebox + 自己的 Label（不设 flat：flat 的按钮不画 normal 样式，
		# 未被选中的选项会变成只有文字没底图）
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_stylebox_override(&"normal", _make_choice_style(Color.WHITE))
		button.add_theme_stylebox_override(&"hover", _make_choice_style(choice_hot_tint))
		button.add_theme_stylebox_override(&"focus", _make_choice_style(choice_hot_tint))
		button.add_theme_stylebox_override(&"pressed", _make_choice_style(choice_hot_tint))
		button.add_theme_stylebox_override(&"disabled", _make_choice_style(Color(1, 1, 1, 0.5)))
		_add_choice_cursor(button)
		button.add_child(_make_choice_label())
		button.text_node = button.get_node(^"Text")
		# 每颗胶囊按自己的文字宽，右对齐排成一竖列
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		_choices.add_child(button)
		# Dialogic 的按钮在 _ready 里把 mouse_entered 连到 grab_focus；
		# 我们故意不用 Godot 焦点（FOCUS_NONE），那样会每悬停一次就刷一条
		# “This control can't grab focus” 警告——直接拆掉这个连接。
		if button.mouse_entered.is_connected(button.grab_focus):
			button.mouse_entered.disconnect(button.grab_focus)
	_choices.add_theme_constant_override(&"separation", int(choice_separation))
	_choices.visible = true


## 底图：名字框同款红标签（九宫格拉伸中间，两头保留圆头）
func _make_choice_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _choice_bg_texture()
	style.modulate_color = tint
	style.texture_margin_left = CHOICE_BG_CORNER
	style.texture_margin_top = CHOICE_BG_CORNER - 1.0
	style.texture_margin_right = CHOICE_BG_CORNER
	style.texture_margin_bottom = CHOICE_BG_CORNER - 1.0
	style.content_margin_left = choice_text_left
	style.content_margin_right = choice_text_right
	return style


## 文字：Dialogic 会把选项文本写到这个 Label 上（靠 text_node）
func _make_choice_label() -> Label:
	var label := Label.new()
	label.name = "Text"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = choice_text_left
	label.offset_right = -choice_text_right
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", choice_font_size)
	label.add_theme_color_override(&"font_color", choice_font_color)
	label.add_theme_color_override(&"font_outline_color", choice_font_outline_color)
	label.add_theme_constant_override(&"outline_size", choice_font_outline_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_choice_cursor(button: Button) -> void:
	var tex := _choice_arrow_texture()
	if tex == null:
		return
	var cursor := TextureRect.new()
	cursor.name = "Cursor"
	cursor.texture = tex
	# 顺序很关键：TextureRect 默认会用贴图尺寸当最小尺寸，先把 expand_mode 设好，
	# 再定 size（否则 set_size 会被最小尺寸顶成 116×93 的大箭头）
	cursor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	cursor.size = Vector2(choice_arrow_size, choice_arrow_size)
	cursor.pivot_offset = cursor.size * 0.5
	cursor.rotation = deg_to_rad(choice_arrow_angle)
	cursor.position = Vector2(choice_arrow_x, (choice_height - choice_arrow_size) * 0.5)
	cursor.visible = false
	button.add_child(cursor)


## 选项弹出时：贴到对话框右边（跟着对话框走，见 _process），默认选中第一项
func _on_question_shown(_info: Dictionary) -> void:
	_choices.visible = true
	_choice_index = 0
	_fit_choice_widths()
	_place_choices()
	_lock_actor_for_choice(true)


func _visible_choice_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for child: Node in _choices.get_children():
		var button := child as Button
		if button != null and button.visible:
			out.append(button)
	return out


## 选项打开时接管输入：
##   · ↑↓/←→（含 WASD、手柄十字）= 换选中
##   · E/F、回车、空格、手柄 A = 确认
##   · 鼠标左键 = 点在哪个选项上就选哪个（自己吃掉事件，不让 Dialogic 的焦点逻辑抢走）
func _input(event: InputEvent) -> void:
	if not _choices_open():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit := _choice_button_at(mb.position)
			if hit != null:
				get_viewport().set_input_as_handled()
				_select_choice_button(hit)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _is_choice_prev(key):
			_step_choice(-1)
			get_viewport().set_input_as_handled()
		elif _is_choice_next(key):
			_step_choice(1)
			get_viewport().set_input_as_handled()
		elif _is_choice_confirm(key):
			_confirm_choice()
			get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_UP:
				_step_choice(-1)
				get_viewport().set_input_as_handled()
			JOY_BUTTON_DPAD_DOWN:
				_step_choice(1)
				get_viewport().set_input_as_handled()
			JOY_BUTTON_A:
				_confirm_choice()
				get_viewport().set_input_as_handled()


## ↑/← 或 W/A（项目里的 move_* 同时绑了方向键和 WASD，直接用动作名最省事）
func _is_choice_prev(key: InputEventKey) -> bool:
	return key.is_action(&"move_up") or key.is_action(&"move_left") \
		or key.is_action(&"ui_up") or key.is_action(&"ui_left")


func _is_choice_next(key: InputEventKey) -> bool:
	return key.is_action(&"move_down") or key.is_action(&"move_right") \
		or key.is_action(&"ui_down") or key.is_action(&"ui_right")


func _is_choice_confirm(key: InputEventKey) -> bool:
	return choice_confirm_keys.has(key.keycode) or key.keycode == KEY_ENTER \
		or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE or key.is_action(&"ui_accept")


## 上下换选中（到头绕回去）
func _step_choice(step: int) -> void:
	var buttons := _visible_choice_buttons()
	if buttons.is_empty():
		return
	_choice_index = wrapi(_choice_index + step, 0, buttons.size())
	_sync_choice_cursors()


## 确认当前选中项
func _confirm_choice() -> void:
	var buttons := _visible_choice_buttons()
	if buttons.is_empty():
		return
	_select_choice_button(buttons[clampi(_choice_index, 0, buttons.size() - 1)] as DialogicNode_ChoiceButton)


## 走和鼠标点击同一条路：按钮自己发 choice_selected，Dialogic 接
func _select_choice_button(button: DialogicNode_ChoiceButton) -> void:
	if button == null:
		return
	button.choice_selected.emit()


## 这个屏幕坐标下是哪个选项（鼠标左键定点用）
func _choice_button_at(pos: Vector2) -> DialogicNode_ChoiceButton:
	for button: Button in _visible_choice_buttons():
		if button.get_global_rect().has_point(pos):
			return button as DialogicNode_ChoiceButton
	return null


## 选项期间锁住角色。锁之前的状态记下来（对话本身已经锁了的情况不能弄乱），选完还回去。
func _lock_actor_for_choice(lock: bool) -> void:
	if not choice_lock_actor:
		return
	if lock:
		if _choice_locked_actor != null and is_instance_valid(_choice_locked_actor):
			return
		var actor := _controllable_actor()
		if actor == null:
			return
		_choice_locked_actor = actor
		_choice_lock_prev_active = bool(actor.get(&"active"))
		_set_actor_active(actor, false)
	elif _choice_locked_actor != null:
		if is_instance_valid(_choice_locked_actor):
			_set_actor_active(_choice_locked_actor, _choice_lock_prev_active)
		_choice_locked_actor = null


## 该锁谁：登记过的角色里在 player 组的那个（队内角色都挂在主角上），否则找场景里的玩家
func _controllable_actor() -> Node2D:
	for value: Variant in registered_characters.values():
		var candidate := value as Node2D
		if candidate != null and is_instance_valid(candidate) and candidate.is_in_group(&"player"):
			return candidate
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _set_actor_active(actor: Node2D, value: bool) -> void:
	if actor.has_method(&"set_locked"):
		actor.call(&"set_locked", not value)
	elif actor.has_method(&"set_active"):
		actor.call(&"set_active", value)


## Dialogic 已经把文本写进 Label 了（question_shown 在 _load_info 之后），
## 这时才知道每颗胶囊要多宽（Button 不会自动把子 Label 的宽度算进自己的最小尺寸）
func _fit_choice_widths() -> void:
	for child: Node in _choices.get_children():
		if not child is DialogicNode_ChoiceButton:
			continue
		var button := child as DialogicNode_ChoiceButton
		var label := button.get_node_or_null(^"Text") as Label
		var text_w: float = label.get_minimum_size().x if label != null else 0.0
		button.custom_minimum_size.x = maxf(choice_min_width, text_w + choice_text_left + choice_text_right)


func _on_choice_selected(_info: Dictionary) -> void:
	# 容器不能藏（见 _build_choice_buttons 的说明），按钮由 Dialogic 隐藏
	_choices.visible = true
	_lock_actor_for_choice(false)


## 选项贴在对话框右边缘外侧、和对话框垂直居中对齐；贴屏幕边就夹住
func _place_choices() -> void:
	var size := _choices.get_combined_minimum_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# 容器不在任何 Container 里，尺寸得自己收成"刚好包住选项"，
	# 否则会用 .tscn 里那个 600×280 的旧尺寸把胶囊拉得很长
	_choices.size = size
	var view: Vector2 = _box.get_viewport_rect().size
	var pos := Vector2(
		_box.position.x + _box.size.x + choice_offset.x,
		_box.position.y + (_box.size.y - size.y) * 0.5 + choice_offset.y)
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(view.x - size.x - SCREEN_MARGIN, SCREEN_MARGIN))
	pos.y = clampf(pos.y, SCREEN_MARGIN, maxf(view.y - size.y - SCREEN_MARGIN, SCREEN_MARGIN))
	_choices.position = pos


func _choices_open() -> bool:
	for child: Node in _choices.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			return true
	return false


## 小箭头只跟着当前选中项；鼠标悬停也算选中（这样"点的"和"选的"一致）
func _sync_choice_cursors() -> void:
	var buttons := _visible_choice_buttons()
	for i in buttons.size():
		if buttons[i].is_hovered():
			_choice_index = i
			break
	for i in buttons.size():
		var cursor := buttons[i].get_node_or_null(^"Cursor") as CanvasItem
		if cursor == null:
			continue
		var on := i == _choice_index
		if cursor.visible != on:
			cursor.visible = on


func _choice_bg_texture() -> Texture2D:
	if choice_bg_texture != null:
		return choice_bg_texture
	return load(CHOICE_BG_PATH) as Texture2D


func _choice_arrow_texture() -> Texture2D:
	if choice_arrow_texture != null:
		return choice_arrow_texture
	return load(CHOICE_ARROW_PATH) as Texture2D
#endregion


func _on_about_to_show_text(info: Dictionary) -> void:
	var character: DialogicCharacter = info.get("character", null)
	if character == null:
		# 旁白：名字牌整块收起来（Dialogic 的 update_name_label 在"始终是旁白"时会提前 return，
		# 不会替我们隐藏，所以这里自己处理）
		_name_plate.visible = false
		_avatar.visible = false
		_text_label.add_theme_color_override(&"default_color", _narrator_color)
		_box_actor = default_actor
	else:
		_apply_character(character)
		_box_actor = registered_characters.get(character, default_actor)
	# 换说话者时直接落位，不做跨屏滑行
	_box.position = _target_box_position()
	_update_tail()


func _apply_character(character: DialogicCharacter) -> void:
	var avatar_path := _avatar_path_for(character)
	if not avatar_path.is_empty() and ResourceLoader.exists(avatar_path):
		_avatar.texture = load(avatar_path)
		_avatar.visible = true
	else:
		_avatar.visible = false
	if use_json_colors:
		_name_label.add_theme_color_override(&"font_color", character.color)
	else:
		_name_label.add_theme_color_override(&"font_color", _name_color_default)
	_text_label.add_theme_color_override(&"default_color", _text_color_default)


## 头像取 custom_info.avatar（会动的表情 GIF），否则退回 default_portrait 的 image
func _avatar_path_for(character: DialogicCharacter) -> String:
	var info: Dictionary = character.custom_info
	if info.has("avatar") and not str(info["avatar"]).is_empty():
		return str(info["avatar"])
	var portrait: Dictionary = character.get_portrait_info(character.default_portrait)
	var overrides: Dictionary = portrait.get("export_overrides", {})
	if overrides.has("image"):
		return str(overrides["image"])
	return ""
#endregion


#region 跟随 / 尖角
################################################################################

func _process(delta: float) -> void:
	_sync_choice_cursors()
	if not _box.visible:
		return
	_update_box_position(delta)
	_update_tail()
	# 选项跟着对话框一起动（对话框在追说话者，选项别脱队）
	if _choices_open():
		_place_choices()


func _anchor_screen_pos() -> Vector2:
	var world_pos: Vector2 = _box_actor.global_position
	if _box_actor.has_method(&"get_bubble_anchor"):
		world_pos = _box_actor.get_bubble_anchor()
	return get_viewport().get_canvas_transform() * world_pos


## 边缘影响：锚点越贴屏幕边，越把气泡朝屏幕中心推。
## 借自 Dialogic 的 Layer_Textbubble/text_bubble.gd（edge_influence），替掉纯硬 clamp。
func _edge_influence(anchor: Vector2, view_size: Vector2) -> Vector2:
	var scr_center := view_size * 0.5
	var x_e := scr_center.x - _box.size.x
	var y_e := scr_center.y - _box.size.y
	var influence := Vector2(
		remap(clampf(absf(anchor.x - scr_center.x), x_e, scr_center.x), x_e, scr_center.x * 0.8, 0.0, 1.0),
		remap(clampf(absf(anchor.y - scr_center.y), y_e, scr_center.y), y_e, scr_center.y * 0.8, 0.0, 1.0))
	if anchor.x > scr_center.x:
		influence.x = -influence.x
	if anchor.y > scr_center.y:
		influence.y = -influence.y
	return influence


func _target_box_position() -> Vector2:
	var view_size: Vector2 = _box.get_viewport_rect().size
	var target_pos: Vector2
	if _box_actor != null and is_instance_valid(_box_actor):
		var anchor := _anchor_screen_pos()
		var gap := head_offset + _box.size.y * 0.5
		var dir := (Vector2.UP + _edge_influence(anchor, view_size)).normalized()
		var center := anchor + dir * (gap / maxf(absf(dir.y), 0.35))
		target_pos = center - _box.size * 0.5
	else:
		target_pos = Vector2((view_size.x - _box.size.x) * 0.5, view_size.y * 0.5 - _box.size.y)
	target_pos.x = clampf(target_pos.x, SCREEN_MARGIN, view_size.x - _box.size.x - SCREEN_MARGIN)
	target_pos.y = clampf(target_pos.y, SCREEN_MARGIN, view_size.y - _box.size.y - SCREEN_MARGIN)
	return target_pos


## 指数阻尼追目标：起步快、尾端平滑收敛（同 Camera2D 的 smoothing 手感），且与帧率无关
func _update_box_position(delta: float) -> void:
	var target_pos := _target_box_position()
	if follow_smoothing <= 0.0 or _box.position.distance_to(target_pos) > follow_snap_distance:
		_box.position = target_pos
		return
	_box.position = _box.position.lerp(target_pos, 1.0 - exp(-follow_smoothing * delta))


## 尖角：从底板下边缘牵一条线指向说话者（Curve2D 手法借自 Dialogic text_bubble.gd）
func _update_tail() -> void:
	if not tail_enabled or _box_actor == null or not is_instance_valid(_box_actor):
		_tail.visible = false
		return
	_tail.visible = true
	var speaker_local := _anchor_screen_pos() - _box.position
	var root_x := clampf(speaker_local.x, tail_root_margin, _box.size.x - tail_root_margin)
	var root := Vector2(root_x, _box.size.y - tail_root_inset)
	var tip := root.lerp(speaker_local, 1.0 - tail_tip_gap)
	var curve := Curve2D.new()
	curve.add_point(root, Vector2.ZERO, Vector2(0.0, (tip.y - root.y) * tail_curve))
	curve.add_point(tip)
	_tail.points = curve.tessellate(6)
#endregion


#region 出现 / 收场
################################################################################

func _open_box(instant := false) -> void:
	_open_seq += 1
	_box.visible = true
	_box.pivot_offset = _box.size * 0.5
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
	if instant:
		_box.scale = Vector2.ONE
		_box.modulate.a = 1.0
		return
	_box_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_box_tween.tween_property(_box, ^"scale", Vector2.ONE, open_duration).from(Vector2.ONE * open_from_scale)
	_box_tween.tween_property(_box, ^"modulate:a", 1.0, open_duration).from(0.0)


func _close_box() -> void:
	if not _box.visible:
		return
	_open_seq += 1
	var seq := _open_seq
	if _box_tween != null and _box_tween.is_valid():
		_box_tween.kill()
	if close_duration <= 0.0:
		_box.visible = false
		return
	_box_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_box_tween.tween_property(_box, ^"scale", Vector2.ONE * open_from_scale, close_duration)
	_box_tween.tween_property(_box, ^"modulate:a", 0.0, close_duration)
	_box_tween.chain().tween_callback(func() -> void:
		if seq == _open_seq:
			_box.visible = false)
#endregion


#region 皮肤
################################################################################

## 应用皮肤：skin 为空则完全不动（继续用场景里调好的那套）
func _apply_skin() -> void:
	_box.pivot_offset = _box.size * 0.5
	if skin == null:
		_text_color_default = _text_label.get_theme_color(&"default_color")
		return
	_box.size = skin.box_size
	if skin.panel_style != null:
		_box.add_theme_stylebox_override(&"panel", skin.panel_style)
	_apply_rect(_avatar, skin.avatar_rect)
	_apply_rect(_name_plate, skin.name_plate_rect)
	_apply_rect(_text_label, skin.text_rect)
	_apply_rect(_continue_hint, skin.continue_rect)
	if skin.name_plate_texture != null:
		_name_plate.texture = skin.name_plate_texture
	if skin.continue_texture != null:
		_continue_hint.texture = skin.continue_texture
	if skin.font != null:
		_name_label.add_theme_font_override(&"font", skin.font)
		_text_label.add_theme_font_override(&"normal_font", skin.font)
	_name_label.add_theme_font_size_override(&"font_size", skin.name_font_size)
	_text_label.add_theme_font_size_override(&"normal_font_size", skin.text_font_size)
	_name_label.add_theme_color_override(&"font_outline_color", skin.name_outline_color)
	_name_label.add_theme_constant_override(&"outline_size", skin.name_outline_size)
	_text_color_default = skin.text_color
	_text_label.add_theme_color_override(&"default_color", skin.text_color)
	_name_color_default = skin.name_color
	_narrator_color = skin.narrator_text_color
	use_json_colors = skin.use_json_colors
	tail_enabled = skin.tail_enabled
	tail_root_margin = skin.tail_root_margin
	tail_root_inset = skin.tail_root_inset
	tail_tip_gap = skin.tail_tip_gap
	tail_curve = skin.tail_curve
	_tail.default_color = skin.tail_color
	_tail.width = skin.tail_root_width
	open_duration = skin.open_duration
	close_duration = skin.close_duration
	open_from_scale = skin.open_from_scale
	_box.pivot_offset = _box.size * 0.5


func _apply_rect(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size
#endregion
