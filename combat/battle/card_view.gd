class_name BattleCardView
extends Button
## 一张手牌的显示件。全部用代码搭，省得为每张卡建场景。
##
## 版式照着杀戮尖塔2 的卡面（用户给的参考图）：
##   左上六边形费用球 / 顶部名字横幅（颜色=稀有度）/ 中间插画窗（暂时白底）/
##   正式插画边框 / 灰色类型铭牌 / 固定宽高的居中说明。
## 卡框复用正式图集，颜色使用StS2原有HSV材质参数，不把高亮蒙版当卡框。
##
## 换成新火自己的卡面：改「素材」那一段的常量即可。

const CARD_SIZE := Vector2(152.0, 208.0)
## 保留对外逻辑尺寸，内部以608×832排版；不影响已有拖牌、命中和飞行坐标。
const FACE_RESOLUTION := 4.0
const CARD_FONT_PATH := "res://theme/fonts/card_bold.otf"
static var _card_font: FontFile

const TYPE_COLORS := {
	CardData.Type.ATTACK: Color("#a8382f"),
	CardData.Type.SKILL: Color("#2f6ea8"),
	CardData.Type.POWER: Color("#6a4b9a"),
	CardData.Type.TALK: Color("#2f8a63"),
}
## 对照StS2 materials/cards/frames：保留纹理明暗，用色相旋转而非去色相乘。
const FRAME_HSV := {
	CardData.Type.ATTACK: Vector3(0.025, 0.85, 1.0),
	CardData.Type.SKILL: Vector3(0.55, 0.9, 1.0),
	CardData.Type.POWER: Vector3(0.8, 0.9, 1.0),
	CardData.Type.TALK: Vector3(0.32, 0.45, 1.2),
}

#region 素材（都是 sts2 图集里的区域，换成自己的就改这里）
## 名字横幅（ui_atlas_1）
const BANNER_REGION := Rect2(674.0, 1.0, 653.0, 145.0)
## 正式主框（ui_atlas_0）；交涉借技能框，不能使用(1,901)的高亮蒙版。
const FRAME_REGIONS := {
	CardData.Type.ATTACK: Rect2(1320.0, 83.0, 598.0, 844.0),
	CardData.Type.SKILL: Rect2(1221.0, 929.0, 598.0, 844.0),
	CardData.Type.POWER: Rect2(621.0, 929.0, 598.0, 844.0),
	CardData.Type.TALK: Rect2(1221.0, 929.0, 598.0, 844.0),
}
const PORTRAIT_REGIONS := {
	CardData.Type.ATTACK: Rect2(1329, 1, 551, 420),
	CardData.Type.SKILL: Rect2(1313, 423, 551, 420),
	CardData.Type.POWER: Rect2(674, 148, 551, 420),
	CardData.Type.TALK: Rect2(1313, 423, 551, 420),
}
const ENERGY_REGION := Rect2(1440, 1948, 74, 74)
const TYPE_PLAQUE := "res://assets/ui/cards/type_plaque_sts2.png"
const ATLAS_UI0 := "res://assets/ui/cards/ui_atlas_0.png"
const ATLAS_UI1 := "res://assets/ui/cards/ui_atlas_1.png"
const FRAME_SHADER := "res://combat/battle/card_frame.gdshader"
## 图集缺失时的兜底卡框（dobo）
const RARITY_FRAMES := {
	CardData.Rarity.BASIC: "res://assets/ui/cards/card_black.png",
	CardData.Rarity.COMMON: "res://assets/ui/cards/card_blue.png",
	CardData.Rarity.UNCOMMON: "res://assets/ui/cards/card_purple.png",
	CardData.Rarity.RARE: "res://assets/ui/cards/card_yellow.png",
}
## 稀有度 → 名字横幅颜色（参考图里金 = 稀有）
const RARITY_BANNER := {
	CardData.Rarity.BASIC: Color(0.74, 0.74, 0.80),
	CardData.Rarity.COMMON: Color(0.62, 0.78, 0.95),
	CardData.Rarity.UNCOMMON: Color(0.92, 0.84, 0.52),
	CardData.Rarity.RARE: Color(1.0, 0.82, 0.35),
}
## 卡内分区（卡 = 152×208）
## 按StS2 card.tscn的300×422卡面比例映射，说明区额外留出安全边距。
const NAME_RECT := Rect2(23, 3.5, 106, 27)
const ART_RECT := Rect2(12.7, 21.2, 126.6, 93.6)
const PORTRAIT_RECT := Rect2(6.3, 23.2, 139.4, 103.5)
const TYPE_RECT := Rect2(56, 104.5, 40, 18.2)
const DESC_RECT := Rect2(18, 128, 116, 62)
const COST_GEM_RECT := Rect2(-8.1, -7.9, 32.4, 31.6)
#endregion

var card: CardData = null
var _face: Control

var _base: Panel
var _frame: TextureRect
var _banner: TextureRect
var _art: TextureRect
var _art_bg: ColorRect
var _art_border: TextureRect
var _cost_gem: TextureRect
var _cost: Label
var _title: Label
var _desc: RichTextLabel
var _type_plate: Panel
var _type: Label
## 视觉倍率由外层控制；内部高精度卡面不改变根节点的交互尺寸。

## 按下时通知战斗层（后续的拖动/点击判定全部由战斗层用 _input 全局跟踪鼠标，
## 不依赖“鼠标还在卡上”——卡片带扇形旋转时鼠标很容易跑出卡片矩形）
signal pointer_pressed(view: BattleCardView, at: Vector2)

## 悬停放大到绝对倍率，普通手牌基准1.15；多牌时仍可抬起阅读。
const HOVER_ABS_SCALE := 1.6
const HOVER_LIFT := 75.0
## 实例级别的悬停参数：牌堆里不需要抬起来，放大也小一点（免得捅出格子）
var hover_scale := HOVER_ABS_SCALE
var hover_lift := HOVER_LIFT
var hover_enabled := true


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	focus_mode = Control.FOCUS_NONE
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_face = Control.new()
	_face.name = "Face"
	_face.size = CARD_SIZE * FACE_RESOLUTION
	_face.scale = Vector2.ONE / FACE_RESOLUTION
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	# 卡底：深色底板 + 类型色描边（参考图里卡片本体是“深色版类型色”）
	_base = Panel.new()
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_base)
	_base.hide() # 正式卡框已有实体底色，不再叠加另一个圆角框。

	# 卡框（sts2 图集；颜色由 shader 染成类型色）
	_frame = TextureRect.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FRAME_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(FRAME_SHADER)
		_frame.material = mat
	_face.add_child(_frame)

	# 名字横幅（颜色 = 稀有度）
	_banner = TextureRect.new()
	_banner.position = Vector2(-6.6, 2.0)
	_banner.size = Vector2(165.7, 40.9)
	_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner.stretch_mode = TextureRect.STRETCH_SCALE
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(FRAME_SHADER):
		var mat := ShaderMaterial.new()
		mat.shader = load(FRAME_SHADER)
		_banner.material = mat
	_face.add_child(_banner)

	# 插画窗：暂时白底（用户：插画位置先填白）
	_art_bg = ColorRect.new()
	_art_bg.position = ART_RECT.position
	_art_bg.size = ART_RECT.size
	_art_bg.color = Color(0.97, 0.97, 0.95)
	_art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_art_bg)

	_art = TextureRect.new()
	_art.position = ART_RECT.position
	_art.size = ART_RECT.size
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_art)

	# 插画窗外框（类型色细边）
	_art_border = TextureRect.new()
	_art_border.position = PORTRAIT_RECT.position
	_art_border.size = PORTRAIT_RECT.size
	_art_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_border.stretch_mode = TextureRect.STRETCH_SCALE
	_art_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(_art_border)

	# 类型小金板（压在插画窗下沿，参考图里的「技能」）
	_type_plate = Panel.new()
	_type_plate.position = TYPE_RECT.position
	_type_plate.size = TYPE_RECT.size
	_type_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_plate.add_theme_stylebox_override(&"panel", preload("res://assets/ui/dobo_button_style.gd").create(TYPE_PLAQUE))
	_face.add_child(_type_plate)

	# 左上费用球（故意压出卡片边缘，和参考图一样）
	_cost_gem = TextureRect.new()
	_cost_gem.position = COST_GEM_RECT.position
	_cost_gem.size = COST_GEM_RECT.size
	_cost_gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cost_gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cost_gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 正式card.tscn同样使用此74×74宝石，按原场景比例绘制，不再夸大为48px圆球。
	_cost_gem.texture = _atlas_region(ATLAS_UI0, ENERGY_REGION)
	_face.add_child(_cost_gem)

	_cost = _make_label(COST_GEM_RECT.position, COST_GEM_RECT.size, 18)
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title = _make_label(NAME_RECT.position, NAME_RECT.size, 16)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type = _make_label(TYPE_RECT.position, TYPE_RECT.size, 10)
	_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc = RichTextLabel.new()
	_desc.position = DESC_RECT.position * FACE_RESOLUTION
	_desc.size = DESC_RECT.size * FACE_RESOLUTION
	_desc.add_theme_font_override(&"normal_font", _get_card_font())
	_desc.add_theme_color_override(&"default_color", Color(1, 0.965, 0.89))
	_desc.add_theme_color_override(&"font_outline_color", Color(0.07, 0.055, 0.035, 0.95))
	_desc.add_theme_constant_override(&"outline_size", 6)
	_desc.add_theme_constant_override(&"line_separation", -3)
	_desc.bbcode_enabled = true
	_desc.scroll_active = false
	_desc.fit_content = false
	_desc.clip_contents = true
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face.add_child(_desc)
	# 只有卡面使用高精度坐标，卡片根节点继续维持152×208的交互尺寸。
	for child: Control in _face.get_children():
		if child != _base and child != _frame and child != _desc:
			child.position *= FACE_RESOLUTION
			child.size *= FACE_RESOLUTION
		if child is Label:
			child.add_theme_font_size_override(&"font_size", int(child.get_theme_font_size(&"font_size") * FACE_RESOLUTION))
			child.add_theme_constant_override(&"outline_size", 8)
	_type.add_theme_color_override(&"font_color", Color(0.14, 0.13, 0.11))
	_type.add_theme_constant_override(&"outline_size", 0)
	# 正式分层：插画在主框后面，主框遮住插画底边，描边/横幅覆盖在最上层。
	_face.move_child(_art_bg, 1)
	_face.move_child(_art, 2)
	_face.move_child(_frame, 3)
	_face.move_child(_art_border, 4)
	_face.move_child(_banner, 5)

	# 悬停抬手 + 变亮（出牌手感）
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


static func _get_card_font() -> FontFile:
	if _card_font == null:
		# 独立字体资源，不修改全局字体或导入设置；同一副牌共享字形缓存。
		_card_font = FontFile.new()
		_card_font.multichannel_signed_distance_field = true
		_card_font.msdf_size = 96
		_card_font.msdf_pixel_range = 32
		_card_font.data = (load(CARD_FONT_PATH) as FontFile).data
	return _card_font


## 从图集里切一块（图不存在就返回 null，调用处自己兜底）
func _atlas_region(atlas_path: String, region: Rect2) -> AtlasTexture:
	if not ResourceLoader.exists(atlas_path):
		return null
	var tex := AtlasTexture.new()
	tex.atlas = load(atlas_path)
	tex.region = region
	return tex


func _make_label(pos: Vector2, box: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = box
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_font_override(&"font", _get_card_font())
	l.add_theme_color_override(&"font_color", Color(1, 1, 1))
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(l)
	return l


## 必须先 add_child 再调 setup（子节点是 _ready 里建的）
func setup(data: CardData) -> void:
	card = data
	if data == null:
		return
	if _cost == null or _title == null or _type == null or _desc == null or _frame == null:
		# 子节点是在 _ready 里建的；没进树就 setup 会往 null 上写 text（踩过）
		push_warning("[BattleCardView] setup() 必须在 add_child 之后再调")
		return
	var banner_color: Color = RARITY_BANNER.get(data.rarity, RARITY_BANNER[CardData.Rarity.BASIC])
	_cost.text = str(data.cost)
	_title.text = data.name
	_type.text = data.type_name()
	var description := data.description.replace("。", "。\n").replace("，", "，\n").strip_edges()
	_desc.text = "[center]" + description.replace("[", "[lb]") + "[/center]"
	# 固定宽高的富文本不会受字形最小宽度撑大；按真实排版高度缩字号。
	for font_size: int in range(13, 8, -1):
		_desc.add_theme_font_size_override(&"normal_font_size", int(font_size * FACE_RESOLUTION))
		if _desc.get_content_height() <= _desc.size.y - 8:
			break
	# 卡底 / 插画窗外框跟着类型色
	_art_border.texture = _atlas_region(ATLAS_UI1, PORTRAIT_REGIONS.get(data.type, PORTRAIT_REGIONS[CardData.Type.SKILL]))
	_art_border.material = _banner.material
	_type_plate.material = _banner.material
	# 卡框：图集区域 + shader 染成类型色（图集缺失就退回 dobo 卡框）
	_frame.texture = _atlas_region(ATLAS_UI0, FRAME_REGIONS.get(data.type, FRAME_REGIONS[CardData.Type.ATTACK]))
	if _frame.material is ShaderMaterial:
		var hsv: Vector3 = FRAME_HSV.get(data.type, FRAME_HSV[CardData.Type.SKILL])
		(_frame.material as ShaderMaterial).set_shader_parameter(&"h", hsv.x)
		(_frame.material as ShaderMaterial).set_shader_parameter(&"s", hsv.y)
		(_frame.material as ShaderMaterial).set_shader_parameter(&"v", hsv.z)
	if _frame.texture == null:
		var fallback := str(RARITY_FRAMES.get(data.rarity, RARITY_FRAMES[CardData.Rarity.BASIC]))
		_frame.texture = load(fallback) if ResourceLoader.exists(fallback) else null
		_frame.material = null
	# 名字横幅：颜色随稀有度，标题用对比色
	_banner.texture = _atlas_region(ATLAS_UI1, BANNER_REGION)
	if _banner.texture is AtlasTexture:
		(_banner.texture as AtlasTexture).margin = Rect2(1, 23, 2, 25)
	if _banner.material is ShaderMaterial:
		(_banner.material as ShaderMaterial).set_shader_parameter(&"h", 1.0)
		(_banner.material as ShaderMaterial).set_shader_parameter(&"s", 0.0)
		(_banner.material as ShaderMaterial).set_shader_parameter(&"v", 0.85)
	_banner.modulate = banner_color.lightened(0.35)
	_art_border.modulate = _banner.modulate
	# 标题统一白字 + 深描边（参考图就是白字压在金横幅上）
	_title.add_theme_color_override(&"font_color", Color.WHITE)
	_title.add_theme_color_override(&"font_outline_color", Color(0.06, 0.05, 0.08, 0.95))
	_title.add_theme_constant_override(&"outline_size", int(2 * FACE_RESOLUTION))
	# 插画：有图就铺满窗口，没有就留白底
	if not data.art.is_empty() and ResourceLoader.exists(data.art):
		_art.texture = load(data.art)
		_art.visible = true
		_art_bg.color = Color(0.97, 0.97, 0.95)
	else:
		_art.visible = false
		_art_bg.color = Color(0.97, 0.97, 0.95)


func set_playable(value: bool) -> void:
	disabled = not value
	modulate = Color.WHITE if value else Color(0.55, 0.55, 0.6, 0.85)


func set_display_cost(value: int) -> void:
	_cost.text = str(value)


## 版式目标（sts2 的 NHandCardHolder 是 SetTargetPosition/Angle/Scale + 每帧 Lerp，
## 这里用“设目标 + 补间过去”达到同样效果：**任何位置/旋转变化都不瞬移**）
var layout_position := Vector2.ZERO
var layout_rotation := 0.0
var layout_scale := Vector2.ONE
## 手牌里的卡参与版式动画；被拖走/打出去的卡由战斗层直接摆位置（关掉自动版式）
var _auto_layout := true
var _hovered := false
var _target_tween: Tween = null


## 由外层（牌堆查看器）设定本张卡的基准缩放（不参与手牌版式动画）
func set_visual_scale(value: float) -> void:
	layout_scale = Vector2(value, value)
	if not _auto_layout:
		scale = layout_scale


func set_hover_style(scale_mult: float, lift: float) -> void:
	hover_scale = scale_mult
	hover_lift = lift


## 手牌版式：设目标位置/角度/缩放，然后补间过去（instant = 直接落位）
func set_layout(pos: Vector2, rot: float, scl: float, instant := false) -> void:
	layout_position = pos
	layout_rotation = rot
	layout_scale = Vector2(scl, scl)
	_animate_to_target(instant)


## 交给战斗层直接摆位置（拖动/飞出时用），停止自动版式
func begin_free_move() -> void:
	_auto_layout = false
	_hovered = false
	if _target_tween != null and _target_tween.is_valid():
		_target_tween.kill()


## 收回时继续使用同一张卡，从当前姿态补间回槽位，不重置变换。
func resume_layout() -> void:
	stop_hover_anim()
	_auto_layout = true
	_hovered = false


func _target_position() -> Vector2:
	return layout_position + Vector2(0.0, -hover_lift if _hovered else 0.0)


func _target_scale() -> Vector2:
	return Vector2(hover_scale, hover_scale) if _hovered else layout_scale


func _animate_to_target(instant := false) -> void:
	if _target_tween != null and _target_tween.is_valid():
		_target_tween.kill()
	if instant or not is_inside_tree():
		position = _target_position()
		rotation = layout_rotation
		scale = _target_scale()
		return
	_target_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_target_tween.tween_property(self, ^"position", _target_position(), 0.18)
	_target_tween.tween_property(self, ^"rotation", layout_rotation, 0.18)
	_target_tween.tween_property(self, ^"scale", _target_scale(), 0.12)


## 悬停：不动手牌版式，只把目标抬起来放大
func _on_hover(on: bool) -> void:
	if disabled or not hover_enabled:
		return
	set_hovered(on)


## 手牌由牌扇按稳定槽位选中；视觉放大不参与命中判断。
func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	if _auto_layout:
		_animate_to_target()
		return
	# 不参与版式的卡（牌堆查看器里的）：位置由格子管，这里只缩放（pivot 在中心，不会捅出格子）
	if _target_tween != null and _target_tween.is_valid():
		_target_tween.kill()
	_target_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_target_tween.tween_property(self, ^"scale", _target_scale(), 0.10)


## 按下就是“我要拖这张牌”——后续交给战斗层（拖动/点击/收回都在那里判）
func _gui_input(event: InputEvent) -> void:
	if disabled or card == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			pointer_pressed.emit(self, mb.global_position)


## kill 掉版式补间（拿牌/飞行前用），但保留当前 scale/rotation（不瞬间跳回去）
func stop_hover_anim() -> void:
	if _target_tween != null and _target_tween.is_valid():
		_target_tween.kill()


## 被拖回手牌 / 没拖成：恢复成“没悬停”的样子
func reset_visual() -> void:
	stop_hover_anim()
	_hovered = false
	scale = layout_scale
	rotation = 0.0
	self_modulate = Color.WHITE
