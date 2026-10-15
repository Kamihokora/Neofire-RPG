extends CanvasLayer
## 新火 RPG 的战斗场景。
##
## 根节点用 CanvasLayer：探索场景的 Camera2D 离树后 canvas 变换不会自动重置，
## 战斗 UI 若挂在默认 canvas 上会被整体偏移（实测过），套一层 CanvasLayer 就免疫了。
##
## 版式（按需求，OMORI 式）：我方小头像在左下、敌人大图在中间、意图浮在敌人头顶，
## 释放特定卡牌/切换形态时切一张全身立绘（CutIn）。
##
## 资源（策划稿）：能量每回合 3 点；形态值攒满 10 点 → 进入“文手形态”（持续 5 回合），
## 提前退出按 已用/最大 比例退还。卡组与形态值存在 GameState（autoload）里。

signal battle_finished(player_won: bool)
## 四个应援入口，索引 0～3；目前只有 0 接入既有文手形态。
signal support_triggered(slot_index: int)
signal pile_animation_finished
signal cards_moved(kind: String, count: int)

const ENERGY_PER_TURN := 3
const HAND_SIZE := 5
## 文手形态下的交涉阈值：好感度满就和平解决（代替打空敌人血条）
const MERCY_MAX := 100
const FORM_BONUS_DAMAGE := 2
const FORM_BLOCK_PER_TURN := 3
const FORM_CUTIN_ART := "res://neofire/Neofire-write.png"
const PARTY_AVATAR := "res://assets/avatars/你好_05.png"
const ENEMY_PATH := "res://combat/enemies/enemy_basic.json"
const INTENT_ICON_DIR := "res://assets/ui/intents/"
const BattleHUD := preload("res://combat/battle/battle_hud.gd")
const StatusRow := preload("res://combat/battle/status_row.gd")
const CardFlight := preload("res://combat/battle/card_flight.gd")
const UIShatter := preload("res://combat/battle/ui_shatter.gd")
const WriterDialogue := preload("res://combat/battle/writer_dialogue.gd")
const UITransition := preload("res://combat/battle/ui_transition.gd")
const DoboButtonStyle := preload("res://assets/ui/dobo_button_style.gd")

## 独立预览用（挂进 game.tscn 时由 game.gd 调 initialize）
@export var auto_start: bool = false
## 留空时沿用场景里的背景；可以在检查器里为不同战斗指定贴图。
@export var battle_background: Texture2D

## 全局 run 状态（autoload，兜底自举见 game_state.gd）
var GS: RunState = null

#region 战斗状态
var player_max_hp := 72
var player_hp := 72
var player_block := 0
var player_strength := 0
var player_vulnerable := 0

var energy := 0
var max_energy := ENERGY_PER_TURN

var enemy_name := "敌人"
var enemy_max_hp := 64
var enemy_hp := 64
var enemy_block := 0
var enemy_strength := 0
var enemy_weak := 0
var enemy_vulnerable := 0
var enemy_art := ""
var enemy_intents: Array = []
var intent_index := 0

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []

var turn := 0
var _shake_tweens: Dictionary = {}
var _party_avatar: TextureRect = null
## 我方 HP 条 / 状态文本的缓存引用（第一次搭建时填上，之后直接改值）
var _party_hp_bar: ProgressBar = null
var _party_hp_label: Label = null
var _party_status_row: StatusRow
var _enemy_status_row: StatusRow
var _health_fill_styles: Dictionary[ProgressBar, StyleBoxTexture] = {}
var _health_color_targets: Dictionary[ProgressBar, Color] = {}
var _health_color_tweens: Dictionary[ProgressBar, Tween] = {}
var _busy := false
var _over := false
## 牌堆按钮上一次显示的数量（变了才弹动画）
var _pile_counts: Dictionary = {}
## 每个控件的弹动画 tween（不 kill 旧的会两个 tween 打架 → 鼠标移开了还放大着）
var _bump_tweens: Dictionary = {}
var _enemy_info_visible := false
var _form_entered_this_turn := false
var _support_buttons: Array[Button] = []
var _incoming_views: Dictionary[int, BattleCardView] = {}
var _pending_flights := 0
var _pile_animation_count := 0
var _resolution_depth := 0
var _writer_dialogue: WriterDialogue
var _writer_active := false
var _intro_active := false
var _hidden_battle_ui: Dictionary[CanvasItem, bool] = {}
#endregion

@onready var _hand_box: Control = $Hand
@onready var _end_turn_button: Button = $EndTurn
@onready var _form_button: Button = $FormButton
@onready var _energy_label: Label = $Energy
@onready var _turn_label: Label = $Turn
@onready var _gauge_bar: ProgressBar = $RightGauge/GaugeBar
@onready var _gauge_value: Label = $RightGauge/GaugeValue
@onready var _mercy_label: Label = $RightGauge/Mercy
@onready var _deck_label: Label = $DeckInfo
@onready var _enemy_status: Label = $EnemyArea/EnemyStatus
@onready var _pile_draw: Button = $PileDraw
@onready var _pile_discard: Button = $PileDiscard
@onready var _pile_view: BattlePileView = $PileView
@onready var _toast: Label = $Toast
@onready var _party_box: VBoxContainer = $Party
@onready var _enemy_sprite: TextureRect = $EnemyArea/EnemySprite
@onready var _enemy_name: Label = $EnemyArea/EnemyName
@onready var _enemy_bar: ProgressBar = $EnemyArea/EnemyHealthBar
@onready var _enemy_hp_label: Label = $EnemyArea/EnemyHealthLabel
@onready var _intent_icon: TextureRect = $EnemyArea/IntentBox/IntentIcon
@onready var _intent_value: Label = $EnemyArea/IntentBox/IntentValue
@onready var _cut_in: Control = $CutIn
@onready var _hud: BattleHUD = $BattleHUD


func _ready() -> void:
	GS = RunState.instance
	_hand_box.z_index = 10
	_pile_view.z_index = 60
	_cut_in.z_index = 70
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_form_button.pressed.connect(_on_form_button_pressed)
	_pile_draw.pressed.connect(_on_pile_draw_pressed)
	_pile_discard.pressed.connect(_on_pile_discard_pressed)
	_style_controls()
	_setup_enemy_info()
	_style_gauge_click()
	_hud.configure_support($RightGauge)
	_support_buttons.assign(_hud.support_buttons)
	_hud.support_triggered.connect(_on_support_triggered)
	_hud.menu_requested.connect(_on_menu_requested)
	_writer_dialogue = WriterDialogue.new()
	_writer_dialogue.name = "WriterDialogue"
	_writer_dialogue.z_index = 90
	$HUDOverlay.add_child(_writer_dialogue)
	if battle_background != null:
		$Background.texture = battle_background
	GS.form_value_changed.connect(_on_form_value_changed)
	if auto_start:
		start_battle()


## 点右侧应援量表 = 进入/退出文手形态（不再单摆一个按钮，免得跟牌堆/结束回合堆在一起）
func _style_gauge_click() -> void:
	var gauge: Control = $RightGauge
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in gauge.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_gauge_bar.gui_input.connect(_on_gauge_input)
	_gauge_bar.mouse_entered.connect(_on_gauge_hover.bind(true))
	_gauge_bar.mouse_exited.connect(_on_gauge_hover.bind(false))


func _setup_enemy_info() -> void:
	# HUD 框原本先于敌人绘制；显式提高层级，提示控件忽略鼠标以免干扰出牌。
	var frame: Control = _hud.get_node("EnemyFrame")
	frame.z_index = 5
	_enemy_name.position = Vector2(968, 218)
	_enemy_name.size = Vector2(152, 30)
	_enemy_name.add_theme_font_size_override(&"font_size", 20)
	_enemy_hp_label.position = Vector2(1120, 222)
	_enemy_hp_label.size = Vector2(100, 26)
	_enemy_hp_label.add_theme_font_size_override(&"font_size", 18)
	_enemy_bar.position = Vector2(968, 258)
	_enemy_bar.size = Vector2(252, 22)
	_enemy_status.position = Vector2(968, 285)
	_enemy_status.size = Vector2(252, 24)
	_enemy_status.add_theme_font_size_override(&"font_size", 15)
	for item: Control in [_enemy_name, _enemy_hp_label, _enemy_bar, _enemy_status]:
		item.z_index = 6
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_status_row = StatusRow.new()
	_enemy_status_row.name = "Statuses"
	_enemy_status_row.position = Vector2(500, 440)
	_enemy_status_row.z_index = 7
	_enemy_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite.add_child(_enemy_status_row)
	_set_enemy_info_visible(false)


func _process(_delta: float) -> void:
	var hovered := _enemy_sprite.get_global_rect().has_point(_enemy_sprite.get_global_mouse_position())
	hovered = hovered or _enemy_status_row.is_status_hovered()
	var show_info := hovered and turn > 0 and not _intro_active and not _writer_active and not _over and not _pile_view.visible and not _hud.is_menu_open()
	if show_info != _enemy_info_visible or _enemy_name.visible != show_info:
		_set_enemy_info_visible(show_info)


func _set_enemy_info_visible(show_info: bool) -> void:
	_enemy_info_visible = show_info
	for item: CanvasItem in [_hud.get_node("EnemyFrame"), _enemy_name, _enemy_hp_label, _enemy_bar, _enemy_status]:
		item.visible = show_info


func _on_gauge_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_form_button_pressed()


func _on_gauge_hover(on: bool) -> void:
	_gauge_bar.modulate = Color(1.25, 1.25, 1.35) if on else Color.WHITE


func _on_support_triggered(slot_index: int) -> void:
	if _busy or _over or _drag_view != null or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	support_triggered.emit(slot_index)
	if slot_index == 0:
		_on_form_button_pressed()
	else:
		_toast_message("test%d" % (slot_index + 1))


func _on_menu_requested(menu_id: String) -> void:
	if _busy or _over or _drag_view != null or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	if menu_id == "deck":
		_pile_view.open_view("卡组", GS.deck)
	else:
		_hud.show_menu(menu_id)


func _on_form_value_changed(_value: int) -> void:
	if is_node_ready() and turn > 0:
		_update_ui()


## 战斗面板换肤：按钮用 dobo 胶囊，血条/量表换红色/蓝色前景 + 深色底
func _style_controls() -> void:
	var red := _button_style("res://assets/ui/buttons/button_red.png")
	var black := _button_style("res://assets/ui/buttons/button_black.png")
	for button: Button in [_end_turn_button, _form_button]:
		button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		button.add_theme_stylebox_override(&"normal", black)
		button.add_theme_stylebox_override(&"hover", red)
		button.add_theme_stylebox_override(&"pressed", black)
		button.add_theme_stylebox_override(&"focus", red)
		button.add_theme_font_size_override(&"font_size", 22)
		button.add_theme_color_override(&"font_color", Color.WHITE)
		button.add_theme_color_override(&"font_hover_color", Color.WHITE)
		button.add_theme_color_override(&"font_pressed_color", Color(1, 0.9, 0.8))
		button.add_theme_color_override(&"font_outline_color", Color(0.13, 0.02, 0.06))
		button.add_theme_constant_override(&"outline_size", 4)
	# 牌堆：抽牌堆左下角、弃牌堆右下角（sts 的摆法），结束回合放右侧上方
	# （旧版 FormButton 在 (1620,852)、弃牌堆在 (1760,838)、结束回合在 (1620,940) 三者叠在一起）
	_pile_draw.size = Vector2(112.0, 118.0)
	_pile_draw.position = Vector2(30.0, 946.0)
	_pile_discard.size = Vector2(112.0, 118.0)
	_pile_discard.position = Vector2(1778.0, 946.0)
	_end_turn_button.position = Vector2(1420, 810)
	_end_turn_button.size = Vector2(280, 72)
	_end_turn_button.z_index = 12
	_party_box.position = Vector2(168, 678)
	_party_box.size = Vector2(360, 94)
	_party_box.z_index = 5
	_energy_label.position = Vector2(228, 778)
	_energy_label.size = Vector2(178, 38)
	_energy_label.z_index = 5
	# 进入/退出形态改成点右侧应援量表（见 _style_gauge_click）
	_form_button.visible = false
	_deck_label.position = Vector2(150.0, 1004.0)
	_style_pile_button(_pile_draw, "res://assets/ui/combat/draw_pile.png")
	_style_pile_button(_pile_discard, "res://assets/ui/combat/discard_pile.png")
	_enemy_bar.add_theme_stylebox_override(&"background", _meter_style("progressBarBase_black.png"))
	_enemy_bar.add_theme_stylebox_override(&"fill", _meter_style("progressBar_red.png"))
	var gauge_back := StyleBoxFlat.new()
	gauge_back.bg_color = Color(0.045, 0.04, 0.065)
	gauge_back.border_color = Color(0.54, 0.48, 0.6)
	gauge_back.set_border_width_all(3)
	gauge_back.set_corner_radius_all(14)
	var gauge_fill := StyleBoxFlat.new()
	gauge_fill.bg_color = Color(1, 0.42, 0.08)
	gauge_fill.set_corner_radius_all(11)
	gauge_fill.expand_margin_left = -5
	gauge_fill.expand_margin_right = -5
	gauge_fill.expand_margin_top = -5
	gauge_fill.expand_margin_bottom = -5
	_gauge_bar.add_theme_stylebox_override(&"background", gauge_back)
	_gauge_bar.add_theme_stylebox_override(&"fill", gauge_fill)


func _meter_style(filename: String) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/ui/bars/" + filename)
	style.texture_margin_left = 22
	style.texture_margin_right = 22
	style.texture_margin_top = 4
	style.texture_margin_bottom = 4
	if filename != "progressBarBase_black.png":
		style.expand_margin_left = -3
		style.expand_margin_right = -3
		style.expand_margin_top = -3
		style.expand_margin_bottom = -3
	return style


## 用白色底图保留原条槽的高光与轮廓，颜色独立补间，连续刷新不会重启动画。
func _update_health_color(bar: ProgressBar, blocked: bool, mercy: bool = false) -> void:
	var normal := Color("f24e61") if not mercy else Color("f87daf")
	var target := Color("48b6f7") if blocked else normal
	if not _health_fill_styles.has(bar):
		var style := _meter_style("progressBar_white.png")
		style.modulate_color = normal
		bar.add_theme_stylebox_override(&"fill", style)
		_health_fill_styles[bar] = style
	if _health_color_targets.get(bar) == target:
		return
	_health_color_targets[bar] = target
	if _health_color_tweens.has(bar):
		_health_color_tweens[bar].kill()
	var tween := create_tween()
	_health_color_tweens[bar] = tween
	tween.tween_property(_health_fill_styles[bar], ^"modulate_color", target, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _button_style(path: String) -> StyleBox:
	return DoboButtonStyle.create(path)


## 牌堆按钮（sts2 的 NCombatCardPile）：图标精灵 + 底部数字徽章，悬停放大、数量变化时弹一下
func _style_pile_button(button: Button, icon_path: String) -> void:
	button.text = ""
	button.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(&"pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	icon.pivot_offset = button.size * 0.5
	button.add_child(icon)
	var badge := TextureRect.new()
	badge.name = "CountBadge"
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_SCALE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size = Vector2(56.0, 46.0)
	badge.position = Vector2(button.size.x - 62.0, button.size.y - 52.0)
	if ResourceLoader.exists("res://assets/ui/combat/pile_button_count.png"):
		badge.texture = load("res://assets/ui/combat/pile_button_count.png")
	button.add_child(badge)
	var count := Label.new()
	count.name = "Count"
	count.set_anchors_preset(Control.PRESET_FULL_RECT)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override(&"font_size", 26)
	count.add_theme_color_override(&"font_color", Color.WHITE)
	count.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	count.add_theme_constant_override(&"outline_size", 5)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count)
	# 悬停/按下时的缩放反馈（sts2 的 _hoverScale = 1.25）
	button.mouse_entered.connect(func() -> void: _bump_control(icon, Vector2(1.18, 1.18), 0.12))
	button.mouse_exited.connect(func() -> void: _bump_control(icon, Vector2.ONE, 0.25))


## 数量变了弹一下（sts2 的 AddCard/RemoveCard bump）
func _bump_pile_button(button: Button) -> void:
	var icon := button.get_node_or_null(^"Icon") as Control
	if icon != null:
		_bump_control(icon, Vector2.ONE, 0.4, 1.25)


## 刷新牌堆按钮上的数字（变化时弹一下）
func _set_pile_count(button: Button, value: int) -> void:
	var count := button.get_node_or_null(^"CountBadge/Count") as Label
	if count != null:
		count.text = str(value)
	var prev := int(_pile_counts.get(button.name, -1))
	if prev != value:
		if prev >= 0:
			_bump_pile_button(button)
		_pile_counts[button.name] = value


func _bump_control(control: Control, to: Vector2, duration: float, from_scale := -1.0) -> void:
	if control == null:
		return
	# 先 kill 掉同一个控件上一次的 tween：不 kill 的话“进入”的 tween 还在跑，
	# “离开”的 tween 结束时又被它改回放大值 → 鼠标移开了还一直放大着
	var key := control.get_instance_id()
	var old: Tween = _bump_tweens.get(key)
	if old != null and old.is_valid():
		old.kill()
	control.pivot_offset = control.size * 0.5
	if from_scale > 0.0:
		control.scale = Vector2(from_scale, from_scale)
	var tween := create_tween()
	_bump_tweens[key] = tween
	tween.tween_property(control, ^"scale", to, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## game.gd 的入口（兼容旧 combat.tscn 的调用签名）
func initialize(_combat_actors: Array = []) -> void:
	start_battle()


func clear_combat() -> void:
	pass


#region 开局
################################################################################

func start_battle() -> void:
	_over = false
	_busy = true
	turn = 0
	player_hp = player_max_hp
	player_block = 0
	player_strength = 0
	player_vulnerable = 0
	energy = 0
	hand.clear()
	discard_pile.clear()
	draw_pile.clear()
	for id in GS.deck:
		draw_pile.append(id)
	draw_pile.shuffle()
	_load_enemy(ENEMY_PATH)
	_convert_support_to_form()
	_toast_message("遭遇：%s" % enemy_name)
	_update_ui()
	var opening := _battle_ui_items()
	opening.append(_hud.portrait_stage)
	_intro_active = true
	await UITransition.reveal(self, opening)
	_intro_active = false
	await _start_player_turn()


func _load_enemy(path: String) -> void:
	enemy_intents.clear()
	intent_index = 0
	if not FileAccess.file_exists(path):
		push_error("[Battle] 找不到敌人数据：%s" % path)
		return
	var f := FileAccess.open(path, FileAccess.READ)
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	enemy_name = str(d.get("name", "敌人"))
	enemy_max_hp = int(d.get("max_hp", 64))
	enemy_hp = enemy_max_hp
	enemy_art = str(d.get("art", ""))
	var raw: Variant = d.get("intents", [])
	if raw is Array:
		enemy_intents = raw
	if not enemy_art.is_empty() and ResourceLoader.exists(enemy_art):
		_enemy_sprite.texture = load(enemy_art)
#endregion


#region 回合流程
################################################################################

func _start_player_turn() -> void:
	_busy = true
	turn += 1
	# 形态按回合消耗（进入的那一回合不算）
	if GS.in_form() and not _form_entered_this_turn:
		if GS.tick_form_turn():
			_toast_message("文手形态结束了")
	_form_entered_this_turn = false
	player_block = 0
	energy = max_energy
	if GS.in_form():
		player_block += FORM_BLOCK_PER_TURN
	await _draw_cards(HAND_SIZE)
	_busy = false
	_update_ui()


## 开局把场外积累的应援值转成局内形态值（就一次，转完清空）
func _convert_support_to_form() -> void:
	if GS.support_value <= 0:
		return
	var amount := GS.support_value
	GS.add_form_value(amount)
	GS.support_value = 0
	GS.support_changed.emit(0)
	_toast_message("应援值 %d 转化为形态值" % amount)
	_toast_message("第 %d 回合" % turn)


func _on_end_turn_pressed() -> void:
	if _busy or _over or _drag_view != null or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	_end_turn()


func _end_turn() -> void:
	_busy = true
	var indices: Array[int] = []
	for index in hand.size():
		indices.append(index)
	await _discard_hand_cards(indices)
	await _enemy_turn()
	if _over:
		return
	_busy = false
	await _start_player_turn()


func _enemy_turn() -> void:
	enemy_block = 0
	_update_ui()
	await get_tree().create_timer(0.45).timeout
	var intent := _current_intent()
	match str(intent.get("kind", "attack")):
		"attack":
			_damage_player(int(intent.get("value", 6)))
			_toast_message("%s 攻击！" % enemy_name)
		"defend":
			enemy_block += int(intent.get("value", 6))
			_toast_message("%s 摆出防御姿态（+%d 格挡）" % [enemy_name, enemy_block])
		"buff":
			enemy_strength += int(intent.get("value", 2))
			_toast_message("%s 的气势上升了（力量 +%d）" % [enemy_name, int(intent.get("value", 2))])
		"debuff":
			player_vulnerable += int(intent.get("value", 1))
			_toast_message("%s 让你露出破绽（易伤 +%d）" % [enemy_name, int(intent.get("value", 1))])
		"heal":
			enemy_hp = mini(enemy_hp + int(intent.get("value", 5)), enemy_max_hp)
			_toast_message("%s 回复了生命" % enemy_name)
		_:
			_toast_message("%s 在观察你……" % enemy_name)
	_update_ui()
	await get_tree().create_timer(0.5).timeout
	# 回合末结算敌人身上的负面
	if enemy_weak > 0:
		enemy_weak -= 1
	if enemy_vulnerable > 0:
		enemy_vulnerable -= 1
	intent_index = (intent_index + 1) % maxi(enemy_intents.size(), 1)
	_update_ui()


func _current_intent() -> Dictionary:
	if enemy_intents.is_empty():
		return {"kind": "attack", "value": 6}
	return enemy_intents[intent_index % enemy_intents.size()]
#endregion


#region 出牌
################################################################################

func _draw_cards(count: int) -> void:
	var previous_count := hand.size()
	for _i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())
	var added := hand.size() - previous_count
	if added == 0:
		return
	_pile_animation_count += 1
	_rebuild_hand()
	_set_hand_hover(null)
	var views: Array[BattleCardView] = []
	for index in range(previous_count, hand.size()):
		var view := _view_at_hand_index(index)
		if view != null:
			_detach_effect_view(view)
			_incoming_views[index] = view
			view.global_position = _pile_draw.get_global_rect().get_center() - view.size * 0.5
			view.scale = Vector2.ONE * 0.22
			view.rotation = -0.35
			view.modulate = Color.WHITE
			views.append(view)
	_pending_flights = views.size()
	_update_ui()
	for index in views.size():
		_animate_incoming(views[index], index * minf(0.075, 0.45 / maxi(views.size() - 1, 1)))
	if _pending_flights > 0:
		await pile_animation_finished
	_pile_animation_count -= 1
	_update_ui()
	cards_moved.emit("draw", added)


func _animate_incoming(view: BattleCardView, delay: float) -> void:
	var index := int(view.get_meta(&"hand_index", 0))
	var flight := CardFlight.new()
	add_child(flight)
	await flight.fly(view, _hand_slot_global(index), deg_to_rad(_hand_slot_angle(hand.size(), index)), _hand_scale(hand.size()), 0.42, delay)
	flight.queue_free()
	_incoming_views.erase(index)
	if _usable_view(view):
		view.reparent(_hand_box, true)
		view.z_index = 0
		view.resume_layout()
		view.set_layout(view.position, view.rotation, _hand_scale(hand.size()), true)
	_pending_flights -= 1
	if _pending_flights == 0:
		pile_animation_finished.emit()


func _view_at_hand_index(index: int) -> BattleCardView:
	for node: Node in _hand_box.get_children():
		var view := node as BattleCardView
		if int(view.get_meta(&"hand_index", -1)) == index:
			return view
	return null


func _detach_effect_view(view: BattleCardView) -> void:
	if view == _hovered_hand_view:
		_set_hand_hover(null)
	view.begin_free_move()
	view.hover_enabled = false
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.reparent(self, true)
	view.z_index = 30


func _discard_hand_cards(indices: Array[int]) -> void:
	if indices.is_empty():
		return
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	var views: Array[BattleCardView] = []
	for index: int in sorted:
		if index < 0 or index >= hand.size():
			continue
		var view := _view_at_hand_index(index)
		if view != null:
			_detach_effect_view(view)
			views.append(view)
		discard_pile.append(hand[index])
		hand.remove_at(index)
	_pile_animation_count += 1
	_rebuild_hand()
	_update_ui()
	_pending_flights = views.size()
	for index in views.size():
		_animate_discarded(views[index], index * minf(0.055, 0.45 / maxi(views.size() - 1, 1)))
	if _pending_flights > 0:
		await pile_animation_finished
	_pile_animation_count -= 1
	_update_ui()
	cards_moved.emit("discard", views.size())


func _animate_discarded(view: BattleCardView, delay: float) -> void:
	var flight := CardFlight.new()
	add_child(flight)
	await flight.fly(view, _pile_discard.get_global_rect().get_center() - view.size * 0.5, 0.32, 0.14, 0.36, delay, true)
	flight.queue_free()
	view.queue_free()
	_bump_pile_button(_pile_discard)
	_pending_flights -= 1
	if _pending_flights == 0:
		pile_animation_finished.emit()


func _can_play(card: CardData, free: bool = false) -> bool:
	if _busy or _over or card == null:
		return false
	if not free and card.cost > energy:
		return false
	if card.form_only and not GS.in_form():
		return false
	# 形态牌：形态值没满就不给打（不然点了等于白费一张牌）
	for e in card.effects:
		if CardData.kind_from(str(e.get("kind", ""))) == CardData.EffectKind.ENTER_FORM:
			if not GS.can_enter_form():
				return false
	return true


func _rebuild_hand() -> void:
	# 参照 card_fan 的原实例重排：只创建新增的牌，保留其余节点与动画。
	# 同名牌按原顺序逐一复用；拖出的那张仍由 _held_view 持有。
	var available: Dictionary = {}
	for child: Node in _hand_box.get_children():
		var view := child as BattleCardView
		if view != null and view.card != null:
			if not available.has(view.card.id):
				available[view.card.id] = []
			available[view.card.id].append(view)
	var visible_index := 0
	for i in hand.size():
		if _incoming_views.has(i):
			continue
		if _usable_view(_held_view) and not _held_consumed and i == int(_held_view.get_meta(&"hand_index", -1)):
			continue
		var card := CardDB.get_card(hand[i])
		if card == null:
			continue
		var view: BattleCardView
		if available.has(card.id) and not available[card.id].is_empty():
			view = available[card.id].pop_front()
		else:
			view = BattleCardView.new()
			_hand_box.add_child(view)
			view.setup(card)
			view.set_meta(&"fresh", true)
			view.pointer_pressed.connect(_on_card_pointer_pressed)
		view.set_playable(_can_play(card))
		view.hover_enabled = false
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.set_meta(&"hand_index", i)
		_hand_box.move_child(view, visible_index)
		visible_index += 1
	for remaining: Array in available.values():
		for view: BattleCardView in remaining:
			if view == _hovered_hand_view:
				_hovered_hand_view = null
			_hand_box.remove_child(view)
			view.queue_free()
	_layout_hand()


## 手牌排布表：照抄 sts2 的 src/Core/Helpers/HandPosHelper.cs
## （按手牌数给出相对“手牌中心”的位置和角度，基准缩放 0.8，牌多了再缩；hover 时抬起来看）
const HAND_POS := {
	1: [Vector2(0, -50)],
	2: [Vector2(-100, -50), Vector2(100, -50)],
	3: [Vector2(-180, -50), Vector2(0, -59), Vector2(180, -50)],
	4: [Vector2(-240, -25), Vector2(-80, -50), Vector2(80, -50), Vector2(240, -25)],
	5: [Vector2(-340, 10), Vector2(-170, -30), Vector2(0, -50), Vector2(170, -30), Vector2(340, 10)],
	6: [Vector2(-460, 13), Vector2(-273, -25), Vector2(-90, -50), Vector2(90, -50), Vector2(273, -25), Vector2(460, 13)],
	7: [Vector2(-534, 18), Vector2(-365, -14), Vector2(-189, -39), Vector2(0, -50), Vector2(189, -39), Vector2(365, -14), Vector2(534, 18)],
	8: [Vector2(-565, 28), Vector2(-400, -14), Vector2(-231, -39), Vector2(-80, -50), Vector2(80, -50), Vector2(231, -39), Vector2(400, -14), Vector2(565, 28)],
	9: [Vector2(-600, 37), Vector2(-445, -2), Vector2(-300, -29), Vector2(-150, -45), Vector2(0, -50), Vector2(150, -45), Vector2(300, -29), Vector2(445, -2), Vector2(600, 37)],
	10: [Vector2(-610, 38), Vector2(-472, 5), Vector2(-340, -21), Vector2(-200, -41), Vector2(-64, -50), Vector2(64, -50), Vector2(200, -41), Vector2(340, -21), Vector2(472, 5), Vector2(610, 38)],
}
const HAND_ANGLE := {
	1: [0.0],
	2: [-2.0, 2.0],
	3: [-3.0, 0.0, 3.0],
	4: [-8.0, -4.0, 4.0, 8.0],
	5: [-8.0, -4.0, 0.0, 4.0, 8.0],
	6: [-9.0, -6.0, -3.0, 3.0, 6.0, 9.0],
	7: [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0],
	8: [-12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0],
	9: [-12.0, -9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0, 12.0],
	10: [-15.0, -12.0, -9.0, -6.0, -3.0, 3.0, 6.0, 9.0, 12.0, 15.0],
}
const HAND_BASE_SCALE := 1.15
## 不愿意要扇形旋转就把这个改成 false（角度全按 0 处理）
const HAND_USE_ROTATION := true


## 手牌排成 sts2 那种扇形：位置/角度查表，牌多了整体缩
func _layout_hand() -> void:
	var views: Array[Node] = _hand_box.get_children()
	var n := hand.size()
	if n == 0:
		_hud.set_hand_bounds(820, 1100, 0)
		return
	var screen := get_viewport().get_visible_rect().size
	var origin := Vector2(screen.x * 0.5 - _hand_box.global_position.x, _hand_box.size.y * 0.5)
	var hand_scale := _hand_scale(n)
	var left := INF
	var right := -INF
	for index in n:
		var center := screen.x * 0.5 + _hand_slot_pos(n, index).x
		left = minf(left, center - BattleCardView.CARD_SIZE.x * hand_scale * 0.5)
		right = maxf(right, center + BattleCardView.CARD_SIZE.x * hand_scale * 0.5)
	_hud.set_hand_bounds(left, right, n)
	for node: Node in views:
		var view := node as BattleCardView
		view.z_index = 1 if view == _hovered_hand_view else 0
		var i := int(view.get_meta(&"hand_index", 0))
		var p := _hand_slot_pos(n, i)
		view.pivot_offset = BattleCardView.CARD_SIZE * 0.5
		# 只在“刚建好、还没有位置”时直接落位；之后一律补间过去（sts2 的 target + lerp）
		var fresh := view.has_meta(&"fresh")
		if fresh:
			view.remove_meta(&"fresh")
		view.set_layout(origin + p - BattleCardView.CARD_SIZE * 0.5,
			deg_to_rad(_hand_slot_angle(n, i)), hand_scale, fresh)


func _hand_scale(n: int) -> float:
	if n > 12:
		return maxf(0.5, HAND_BASE_SCALE * 0.75 * pow(12.0 / n, 0.35))
	match n:
		8:
			return HAND_BASE_SCALE * 0.95
		9:
			return HAND_BASE_SCALE * 0.9
		10:
			return HAND_BASE_SCALE * 0.85
		11:
			return HAND_BASE_SCALE * 0.8
		12:
			return HAND_BASE_SCALE * 0.75
		_:
			return HAND_BASE_SCALE


## 超过表格的牌数（>10）就自己线性摊开（表格只到 10）
func _hand_slot_pos(n: int, i: int) -> Vector2:
	var slot: Vector2
	if HAND_POS.has(n):
		slot = HAND_POS[n][i]
	else:
		var spread := minf(1220.0, 170.0 * float(n - 1))
		var t := float(i) / float(maxi(n - 1, 1)) - 0.5
		slot = Vector2(spread * t, -50.0 + 38.0 * absf(t) * 2.0)
	# 放大后的扇形边牌也留在画面内，飞入与归位共用同一个目标位置。
	var angle := deg_to_rad(_hand_slot_angle(n, i))
	var half_height := _hand_scale(n) * (absf(sin(angle)) * BattleCardView.CARD_SIZE.x + absf(cos(angle)) * BattleCardView.CARD_SIZE.y) * 0.5
	var center_y := _hand_box.global_position.y + _hand_box.size.y * 0.5
	slot.y = minf(slot.y, get_viewport().get_visible_rect().size.y - 16 - center_y - half_height)
	return slot


func _hand_slot_angle(n: int, i: int) -> float:
	if not HAND_USE_ROTATION:
		return 0.0
	if HAND_ANGLE.has(n):
		return HAND_ANGLE[n][i]
	return -15.0 + 30.0 * float(i) / float(maxi(n - 1, 1))


## 这张牌在手牌里的目标位置（收回时飞回去用）
func _hand_slot_global(index: int, _view: Control = null) -> Vector2:
	var n := hand.size()
	var p := _hand_slot_pos(maxi(n, 1), clampi(index, 0, maxi(n - 1, 0)))
	var screen := get_viewport().get_visible_rect().size
	return Vector2(screen.x * 0.5, _hand_box.global_position.y + _hand_box.size.y * 0.5) 		+ p - BattleCardView.CARD_SIZE * 0.5


## 把手牌里的牌摘到战斗层（拖/点都要先摘出来，不然容器会接管位置）
func _take_card_view(view: BattleCardView) -> void:
	if view.get_parent() != _hand_box:
		return
	view.hover_enabled = false
	_set_hand_hover(null)
	view.begin_free_move()
	_held_view = view
	_held_consumed = false
	_card_motion_active = true
	_show_hand_slot(view)
	# Control.reparent 保持全局位置；不重置旋转/缩放，保留手里拿起的连续姿态。
	view.reparent(self, true)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.z_index = 30
	_update_ui()


func _show_hand_slot(view: BattleCardView) -> void:
	if _hand_slot_marker == null:
		_hand_slot_marker = Panel.new()
		_hand_slot_marker.name = "HandSlotMarker"
		_hand_slot_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hand_slot_marker.z_index = 9
		var outline := StyleBoxFlat.new()
		outline.bg_color = Color(1, 1, 1, 0.035)
		outline.border_color = Color(1, 1, 1, 0.8)
		outline.set_border_width_all(2)
		outline.set_corner_radius_all(10)
		_hand_slot_marker.add_theme_stylebox_override(&"panel", outline)
		add_child(_hand_slot_marker)
		move_child(_hand_slot_marker, _hand_box.get_index())
	_hand_slot_marker.size = BattleCardView.CARD_SIZE
	_hand_slot_marker.pivot_offset = BattleCardView.CARD_SIZE * 0.5
	_hand_slot_marker.position = _hand_slot_global(int(view.get_meta(&"hand_index", 0)))
	_hand_slot_marker.rotation = view.layout_rotation
	_hand_slot_marker.scale = view.layout_scale
	_hand_slot_marker.show()


func _hide_hand_slot() -> void:
	if _hand_slot_marker != null:
		_hand_slot_marker.hide()


#region 出牌 / 拖动（战斗层用 _input 全局跟踪鼠标，不依赖“鼠标还在卡上”）
################################################################################

var _drag_view: BattleCardView = null
var _hovered_hand_view: BattleCardView = null
var _held_view: BattleCardView = null
var _held_consumed := false
var _card_motion_active := false
var _hand_slot_marker: Panel
var _held_pose_tween: Tween
var _drag_press_pos := Vector2.ZERO
var _drag_center_offset := Vector2.ZERO
var _drag_moved := false
## 按下后移动超过这么多像素才算拖动（否则当作点击出牌）
const DRAG_THRESHOLD := 12.0


func _on_card_pointer_pressed(view: BattleCardView, at: Vector2) -> void:
	if _busy or _over or _card_motion_active or _drag_view != null or not _usable_view(view) or view.disabled:
		return
	_drag_view = view
	_drag_press_pos = at
	view.stop_hover_anim()
	_drag_center_offset = view.get_global_transform() * (view.size * 0.5) - at
	_drag_moved = false


## 拖动期间的鼠标跟踪。用 _input 而不是卡片的 _gui_input：
## 手牌是扇形（卡片有旋转），鼠标很容易跑出卡片矩形，那样就跟丢了。
func _input(event: InputEvent) -> void:
	if _drag_view == null:
		if event is InputEventMouseMotion:
			_set_hand_hover(null if _hand_input_blocked() else _hand_card_at(event.position))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _hand_input_blocked():
				var selected := _hand_card_at(event.position)
				if selected != null and not selected.disabled:
					_on_card_pointer_pressed(selected, event.position)
					get_viewport().set_input_as_handled()
		return
	if not _usable_view(_drag_view):
		_drag_view = null
		_set_enemy_drop_highlight(false)
		return
	if event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).global_position
		if not _drag_moved:
			if at.distance_to(_drag_press_pos) <= DRAG_THRESHOLD:
				return
			_drag_moved = true
			_take_card_view(_drag_view)
			_held_pose_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_held_pose_tween.tween_property(_drag_view, ^"rotation", 0.0, 0.12)
			_held_pose_tween.tween_property(_drag_view, ^"scale", Vector2.ONE * 1.05, 0.12)
		_drag_view.global_position = at + _drag_center_offset - _drag_view.size * 0.5
		_set_enemy_drop_highlight(_over_enemy(at))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		var view := _drag_view
		var at := mb.global_position
		_drag_view = null
		_set_enemy_drop_highlight(false)
		get_viewport().set_input_as_handled()
		if _drag_moved:
			if _over_enemy(at):
				await _play_card_view(view)
			else:
				await _return_card_to_hand(view)
		else:
			await _play_card_view(view)


func _hand_input_blocked() -> bool:
	return _busy or _over or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0 or _pile_view.visible or _hud.is_menu_open() or _cut_in.visible


## 内化 card_fan::_get_card_at_pos 的旋转矩形判定，使用原槽位而非悬停变换。
## 从右往左匹配稳定命中区，密集重叠时每张牌仍有可选区域。
func _hand_card_at(at: Vector2) -> BattleCardView:
	# 下移后的结束回合保持在密集手牌上层，鼠标也按同样的覆盖顺序命中。
	if _end_turn_button.visible and _end_turn_button.get_global_rect().has_point(at):
		return null
	var point := _hand_box.get_global_transform().affine_inverse() * at
	var views := _hand_box.get_children()
	for index in range(views.size() - 1, -1, -1):
		var view := views[index] as BattleCardView
		var center := view.layout_position + view.pivot_offset
		var local := (point - center).rotated(-view.layout_rotation) / view.layout_scale + view.pivot_offset
		if Rect2(Vector2.ZERO, view.size).has_point(local):
			return view
	# 指针向上移入大卡时继续保持选中；邻牌原槽位优先，避免大卡吞掉邻牌命中区。
	if _usable_view(_hovered_hand_view):
		var local := _hovered_hand_view.get_global_transform().affine_inverse() * at
		if Rect2(Vector2.ZERO, _hovered_hand_view.size).has_point(local):
			return _hovered_hand_view
	return null


func _set_hand_hover(view: BattleCardView) -> void:
	if view == _hovered_hand_view:
		return
	if _usable_view(_hovered_hand_view):
		_hovered_hand_view.set_hovered(false)
		_hovered_hand_view.z_index = 0
	_hovered_hand_view = view
	if _usable_view(view):
		view.z_index = 1
		view.set_hovered(true)


## 出一张牌：抬到敌人脸上 → 结算 → 淡出
func _play_card_view(view: BattleCardView) -> void:
	if not _usable_view(view):
		return
	var index := int(view.get_meta(&"hand_index", -1))
	if index < 0:
		return
	_take_card_view(view)
	_stop_held_pose()
	await _fly_view_to_enemy(view)
	if not await play_card(index):
		_held_consumed = false
		await _return_card_to_hand(view)
		return
	await _send_card_away(view)
	_held_view = null
	_held_consumed = false
	_card_motion_active = false
	_update_ui()


## 收回：牌还在手牌区 / 没拖到敌人 → 飞回它自己的槽位，然后重排
func _return_card_to_hand(view: BattleCardView) -> void:
	if not _usable_view(view):
		return
	_stop_held_pose()
	var index := int(view.get_meta(&"hand_index", -1))
	if view.get_parent() != _hand_box:
		view.reparent(_hand_box, true)
	_hand_box.move_child(view, clampi(index, 0, _hand_box.get_child_count() - 1))
	view.z_index = 0
	view.resume_layout()
	_held_view = null
	_layout_hand()
	# 同一节点直接吸附回完整手牌槽位；取消旧版淡出、销毁、重建的第二段跳动。
	await get_tree().create_timer(0.2).timeout
	if _usable_view(view):
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_hand_slot()
	_card_motion_active = false
	_update_ui()


func _stop_held_pose() -> void:
	if _held_pose_tween != null and _held_pose_tween.is_valid():
		_held_pose_tween.kill()
	_held_pose_tween = null


## view 还活着且没被标记删除
func _usable_view(view: BattleCardView) -> bool:
	return view != null and is_instance_valid(view) and not view.is_queued_for_deletion()


## 拖动中鼠标是不是在敌人身上（判定区比立绘大一圈，好点）
func _over_enemy(at: Vector2) -> bool:
	return _enemy_sprite.get_global_rect().grow(48.0).has_point(at)


func _set_enemy_drop_highlight(on: bool) -> void:
	_enemy_sprite.modulate = Color(1.3, 1.05, 1.05) if on else Color.WHITE
#endregion


## 把牌飞到敌人脸上（目标点夹在屏幕内，避免“卡飞出屏幕”）
func _fly_view_to_enemy(view: Control) -> void:
	if view == null or not is_instance_valid(view):
		return
	var enemy_rect := _enemy_sprite.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var target := enemy_rect.get_center() - view.size * 0.5
	target.x = clampf(target.x, 8.0, maxf(screen.x - view.size.x - 8.0, 8.0))
	target.y = clampf(target.y, 8.0, maxf(screen.y - view.size.y - 8.0, 8.0))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, ^"global_position", target, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, ^"scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(view, ^"rotation", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


## 结算完把牌收走（缩一下 + 淡出）
func _send_card_away(view: BattleCardView) -> void:
	if view == null or not is_instance_valid(view):
		return
	var flight := CardFlight.new()
	add_child(flight)
	await flight.fly(view, _pile_discard.get_global_rect().get_center() - view.size * 0.5, 0.32, 0.14, 0.36, 0, true)
	flight.queue_free()
	view.queue_free()
	_bump_pile_button(_pile_discard)


func play_card(index: int, free: bool = false) -> bool:
	if index < 0 or index >= hand.size() or _busy or _over or (_resolution_depth > 0 and not free):
		return false
	var card := CardDB.get_card(hand[index])
	if card == null or not _can_play(card, free):
		return false
	_resolution_depth += 1
	_update_ui()
	var planned: Dictionary = {}
	if not card.effects.is_empty():
		var first: Dictionary = card.effects[0]
		var kind := CardData.kind_from(str(first.get("kind", "")))
		if kind in [CardData.EffectKind.PLAY_FREE, CardData.EffectKind.DISCARD]:
			var choice := await _choose_effect_targets(kind, int(first.get("value", 1)), index, true)
			if choice["cancelled"]:
				_resolution_depth -= 1
				_update_ui()
				return false
			planned[0] = choice["targets"]
	# 确认后才扣费和移牌，取消时可原样归位。
	var source_view := _view_at_hand_index(index)
	if source_view != null:
		_hand_box.remove_child(source_view)
		source_view.queue_free()
	energy -= 0 if free else card.cost
	hand.remove_at(index)
	_held_consumed = true
	_hide_hand_slot()
	if card.exhaust:
		pass  # 消耗牌直接进虚空（v1 先不单独做虚空调）
	else:
		discard_pile.append(card.id)
	_rebuild_hand()
	var entered := await _apply_effects(card, planned)
	_update_ui()
	_rebuild_hand()
	if entered:
		await _play_form_cutin()
	_resolution_depth -= 1
	_update_ui()
	return true


func _choose_effect_targets(kind: CardData.EffectKind, requested: int, source: int = -1, allow_cancel: bool = false) -> Dictionary:
	var ids: Array[String] = []
	var sources: Array[int] = []
	var eligible: Array[bool] = []
	var available_free := _free_target_indices(source)
	for index in hand.size():
		if index == source:
			continue
		ids.append(hand[index])
		sources.append(index)
		eligible.append(kind == CardData.EffectKind.DISCARD or available_free.has(index))
	var amount := mini(requested, ids.size() if kind == CardData.EffectKind.DISCARD else available_free.size())
	if amount <= 0:
		if kind == CardData.EffectKind.PLAY_FREE:
			_toast_message("没有可免费打出的手牌")
		return {"cancelled": allow_cancel and kind == CardData.EffectKind.PLAY_FREE, "targets": []}
	var title := "选择手牌免费打出" if kind == CardData.EffectKind.PLAY_FREE else "选择要弃掉的手牌"
	var chosen: Array[int] = await _pile_view.choose_cards(title, ids, sources, amount, eligible, allow_cancel)
	var targets: Array[BattleCardView] = []
	for index in chosen:
		var view := _view_at_hand_index(index)
		if view != null:
			targets.append(view)
	return {"cancelled": chosen.size() != amount, "targets": targets}


func _free_target_indices(source: int) -> Array[int]:
	var result: Array[int] = []
	for index in hand.size():
		if index == source:
			continue
		var candidate := CardDB.get_card(hand[index])
		if not _can_play(candidate, true):
			continue
		var needs_target := candidate.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "play_free")
		if needs_target:
			var has_terminal := false
			for other in hand.size():
				if other in [source, index]:
					continue
				var terminal := CardDB.get_card(hand[other])
				if _can_play(terminal, true) and not terminal.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "play_free"):
					has_terminal = true
			if not has_terminal:
				continue
		result.append(index)
	return result


func _play_selected_free(view: BattleCardView) -> void:
	if not _usable_view(view) or view.get_parent() != _hand_box or not _can_play(view.card, true):
		return
	var index := int(view.get_meta(&"hand_index", -1))
	_detach_effect_view(view)
	view.set_display_cost(0)
	await _fly_view_to_enemy(view)
	if await play_card(index, true):
		await _send_card_away(view)
	else:
		view.reparent(_hand_box, true)
		view.set_display_cost(view.card.cost)
		view.resume_layout()
		_layout_hand()


## 返回 true 表示这张牌让玩家进入了形态（需要播立绘切入）
func _apply_effects(card: CardData, planned: Dictionary = {}) -> bool:
	var entered_form := false
	for ordinal in card.effects.size():
		var e: Dictionary = card.effects[ordinal]
		var v := int(e.get("value", 0))
		var kind := CardData.kind_from(str(e.get("kind", "damage")))
		if kind in [CardData.EffectKind.DISCARD, CardData.EffectKind.PLAY_FREE] and not planned.has(ordinal):
			var choice := await _choose_effect_targets(kind, v)
			planned[ordinal] = choice["targets"]
		match kind:
			CardData.EffectKind.DAMAGE:
				_damage_enemy(v)
			CardData.EffectKind.BLOCK:
				player_block += v
				_punch(_party_avatar)
			CardData.EffectKind.DRAW:
				await _draw_cards(v)
			CardData.EffectKind.DISCARD:
				var indices: Array[int] = []
				for view: BattleCardView in planned.get(ordinal, []):
					if _usable_view(view) and view.get_parent() == _hand_box:
						indices.append(int(view.get_meta(&"hand_index", -1)))
				await _discard_hand_cards(indices)
			CardData.EffectKind.PLAY_FREE:
				for view: BattleCardView in planned.get(ordinal, []):
					await _play_selected_free(view)
			CardData.EffectKind.FORM:
				GS.add_form_value(v)
			CardData.EffectKind.ENERGY:
				energy += v
			CardData.EffectKind.HEAL:
				player_hp = mini(player_hp + v, player_max_hp)
			CardData.EffectKind.WEAK:
				enemy_weak += v
			CardData.EffectKind.VULNERABLE:
				enemy_vulnerable += v
			CardData.EffectKind.MERCY:
				GS.mercy += v
				_toast_message("好感度 +%d" % v)
				_check_mercy_win()
			CardData.EffectKind.ENTER_FORM:
				entered_form = _try_enter_form()
		if _over:
			break
	if _over:
		return false
	return entered_form
#endregion


#region 牌堆查看
################################################################################

func _on_pile_draw_pressed() -> void:
	if _busy or _over or _drag_view != null or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	_pile_view.open_view("抽牌堆", draw_pile)


func _on_pile_discard_pressed() -> void:
	if _busy or _over or _drag_view != null or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	_pile_view.open_view("弃牌堆", discard_pile)
#endregion


#region 形态
################################################################################

func _on_form_button_pressed() -> void:
	if _busy or _over or _card_motion_active or _drag_view != null or _pile_animation_count > 0 or _resolution_depth > 0:
		return
	if GS.in_form():
		var refunded := GS.exit_form(true)
		_toast_message("退出文手形态，退还 %d 点形态值" % refunded)
		_update_ui()
		return
	if not GS.can_enter_form():
		_toast_message("形态值不足（%d/%d）" % [GS.form_value, GS.FORM_COST])
		return
	_try_enter_form()
	await _play_form_cutin()


func _try_enter_form() -> bool:
	if not GS.can_enter_form():
		return false
	if not GS.enter_form(GS.FORM_WRITER):
		return false
	_form_entered_this_turn = true
	player_block += 5
	_toast_message("进入文手形态！")
	_update_ui()
	return true


## 一轮交涉：眼部切入 → 立绘发光/界面碎落 → 对话选择 → 快速反向变身。
func _play_form_cutin() -> void:
	if _writer_active or not GS.in_form():
		return
	_writer_active = true
	_busy = true
	_update_ui()
	await _cut_in.play(GS.FORM_WRITER, "文手形态", FORM_CUTIN_ART)
	_hud.portrait_stage.transform_to(true)
	await _shatter_battle_ui()
	var choice := await _writer_dialogue.begin("test1")
	var feedback := "test3"
	match choice:
		0:
			GS.mercy += 10
			feedback = "好感度 +10"
		1:
			enemy_vulnerable += 1
			feedback = "敌人获得易伤"
	_update_ui()
	await _writer_dialogue.finish(feedback)
	GS.tick_form_turn()
	_form_entered_this_turn = false
	await _hud.portrait_stage.transform_to(false)
	await _restore_battle_ui()
	_writer_active = false
	_busy = false
	_update_ui()
	_check_mercy_win()


func _shatter_battle_ui() -> void:
	await RenderingServer.frame_post_draw
	var snapshot := ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	_hidden_battle_ui.clear()
	# 只隐藏真实界面；立绘和敌人仍是舞台的一部分，碎片另用刚体表现。
	for item in _battle_ui_items():
		_hide_for_dialogue(item)
	if _usable_view(_held_view):
		_hide_for_dialogue(_held_view)
	var regions: Array[Rect2] = [Rect2(40, 24, 1840, 80), _hud.player_frame_rect, _hud.support_frame_rect, _hud.get_node("HandFrame").get_global_rect(), Rect2(30, 946, 112, 118), Rect2(1778, 946, 112, 118), _end_turn_button.get_global_rect(), Rect2(850, 108, 220, 82)]
	if _hidden_battle_ui.get(_hud.get_node("EnemyFrame"), false):
		regions.append(_hud.enemy_frame_rect)
	var shatter := UIShatter.new()
	shatter.name = "UIShatter"
	shatter.z_index = 40
	add_child(shatter)
	shatter.burst(snapshot, regions, get_viewport().get_visible_rect().size)
	await get_tree().create_timer(0.9).timeout


func _hide_for_dialogue(node: CanvasItem) -> void:
	_hidden_battle_ui[node] = node.visible
	node.hide()


func _restore_battle_ui() -> void:
	var items: Array[CanvasItem] = []
	for node: CanvasItem in _hidden_battle_ui:
		if is_instance_valid(node):
			node.visible = _hidden_battle_ui[node]
			items.append(node)
	_hidden_battle_ui.clear()
	await UITransition.reveal(self, items)


func _battle_ui_items() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	for path: String in ["TopBar", "GameTitle", "SkillHeading", "SkillSlot1", "SkillSlot2", "SkillSlot3", "SkillSlot4", "SkillsButton", "DeckButton", "InventoryButton", "SettingsButton", "PlayerFrame", "EnemyFrame", "HandFrame", "PlayerCaption", "EnergyIcon", "EnergyPip1", "EnergyPip2", "EnergyPip3"]:
		items.append(_hud.get_node(path) as CanvasItem)
	for path: String in ["RightGauge", "Hand", "EndTurn", "FormButton", "Energy", "Turn", "DeckInfo", "PileDraw", "PileDiscard", "Toast", "Party", "EnemyArea/IntentBox", "EnemyArea/EnemyName", "EnemyArea/EnemyHealthBar", "EnemyArea/EnemyHealthLabel", "EnemyArea/EnemyStatus", "EnemyArea/EnemySprite/Statuses"]:
		items.append(get_node(path) as CanvasItem)
	return items
#endregion


#region 伤害结算
################################################################################

func _damage_enemy(raw: int) -> void:
	var value := raw + player_strength
	if GS.in_form():
		value += FORM_BONUS_DAMAGE
	if enemy_vulnerable > 0:
		value = int(ceil(value * 1.5))
	var blocked := mini(enemy_block, value)
	enemy_block -= blocked
	var dealt := value - blocked
	enemy_hp = maxi(enemy_hp - dealt, 0)
	if dealt > 0:
		_damage_number(_enemy_sprite.position + Vector2(_enemy_sprite.size.x * 0.5 - 30.0, 40.0), dealt, Color(1, 0.85, 0.4))
	_shake(_enemy_sprite)
	_flash(_enemy_sprite)
	_update_ui()
	if enemy_hp <= 0:
		_finish(true)


func _damage_player(raw: int) -> void:
	var value := raw + enemy_strength
	if enemy_weak > 0:
		value = int(floor(value * 0.75))
	if player_vulnerable > 0:
		value = int(ceil(value * 1.5))
	var blocked := mini(player_block, value)
	player_block -= blocked
	var taken := value - blocked
	player_hp = maxi(player_hp - taken, 0)
	if taken > 0 and _party_avatar != null:
		_damage_number(_party_avatar.global_position + Vector2(0.0, -30.0), taken, Color(1, 0.42, 0.42))
	if _party_avatar != null:
		_shake(_party_avatar)
	_update_ui()
	if player_hp <= 0:
		_finish(false)


## 飘出的伤害数字
func _damage_number(at: Vector2, amount: int, color: Color, prefix := "") -> void:
	var label := Label.new()
	label.name = "DamageNumber"
	label.text = "%s%d" % [prefix, amount]
	label.position = at
	label.add_theme_font_size_override(&"font_size", 52)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override(&"outline_size", 8)
	add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, ^"position", at + Vector2(0.0, -90.0), 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, ^"modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## 受击抖动：阻尼正弦（公式借自杀戮尖塔2 Core/Nodes/Combat/NCreature.cs 的 AnimShake）
func _shake(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	if _shake_tweens.has(node) and is_instance_valid(_shake_tweens[node]) and (_shake_tweens[node] as Tween).is_running():
		return
	var base: Vector2 = node.position
	var tween := create_tween()
	_shake_tweens[node] = tween
	tween.tween_method(func(progress: float) -> void:
			node.position = base + Vector2.RIGHT * 12.0 * sin(progress * 4.0) * sin(progress * 0.5),
		0.0, PI * 2.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(func() -> void: node.position = base)


## 缩放脉冲（借自 NCreature 的力量闪烁：scale → One*n，EASE_INOUT/SINE）
func _punch(node: CanvasItem, amount := 1.18) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base: Vector2 = node.scale
	var tween := create_tween()
	tween.tween_property(node, ^"scale", base * amount, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, ^"scale", base, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _flash(node: CanvasItem) -> void:
	var tween := create_tween()
	tween.tween_property(node, ^"modulate", Color(1.6, 0.7, 0.7), 0.06)
	tween.tween_property(node, ^"modulate", Color.WHITE, 0.18)


func _check_mercy_win() -> void:
	if GS.mercy >= MERCY_MAX and not _over:
		_toast_message("说服成功——和平解决！")
		_finish(true)


func _finish(player_won: bool) -> void:
	if _over:
		return
	_over = true
	_busy = true
	_toast_message("战斗胜利！" if player_won else "你倒下了……")
	_update_ui()
	await get_tree().create_timer(1.4).timeout
	battle_finished.emit(player_won)
#endregion


#region 界面刷新
################################################################################

func _update_ui() -> void:
	_energy_label.text = "能量 %d/%d" % [energy, max_energy]
	_turn_label.text = "回合 %d" % maxi(turn, 1)
	# 应援条在表情脚下；进入形态后按真实持续回合显示剩余量。
	_gauge_bar.max_value = GS.FORM_TURNS if GS.in_form() else GS.FORM_COST
	if GS.in_form():
		_gauge_bar.value = GS.form_turns_left
		_gauge_value.text = "%d/%d" % [GS.form_turns_left, GS.FORM_TURNS]
	else:
		_gauge_bar.value = GS.form_value
		_gauge_value.text = "%d/%d" % [GS.form_value, GS.FORM_COST]
	_form_button.text = "退出文手形态" if GS.in_form() else "进入文手形态"
	var locked := _over or _busy or _card_motion_active or _pile_animation_count > 0 or _resolution_depth > 0
	_form_button.disabled = locked or (not GS.in_form() and not GS.can_enter_form())
	_end_turn_button.disabled = locked
	_mercy_label.visible = false
	_mercy_label.text = "好感度 %d" % GS.mercy
	_deck_label.text = "卡组 %d" % GS.deck.size()
	_pile_draw.text = ""
	_pile_discard.text = ""
	_set_pile_count(_pile_draw, draw_pile.size())
	_set_pile_count(_pile_discard, discard_pile.size())
	var enemy_status: PackedStringArray = PackedStringArray()
	if enemy_block > 0:
		enemy_status.append("格挡 %d" % enemy_block)
	if enemy_strength > 0:
		enemy_status.append("力量 %d" % enemy_strength)
	if enemy_weak > 0:
		enemy_status.append("虚弱 %d" % enemy_weak)
	_enemy_status_row.update_statuses({"vulnerable": enemy_vulnerable})
	if GS.in_form():
		# 文手形态：不打架，谈。血条位置换成好感度条（满 MERCY_MAX = 和平解决）
		_enemy_name.text = "%s（交涉中）" % enemy_name
		_enemy_bar.max_value = MERCY_MAX
		_enemy_bar.value = clampi(GS.mercy, 0, MERCY_MAX)
		_enemy_hp_label.text = "好感度 %d/%d" % [GS.mercy, MERCY_MAX]
		enemy_status.append("好感度 %d/%d" % [GS.mercy, MERCY_MAX])
	else:
		_enemy_name.text = enemy_name
		_enemy_bar.max_value = maxi(enemy_max_hp, 1)
		_enemy_bar.value = enemy_hp
		_enemy_hp_label.text = "%d/%d" % [enemy_hp, enemy_max_hp]
	_enemy_status.text = "  ".join(enemy_status)
	_update_intent()
	_rebuild_party()
	_update_health_color(_party_hp_bar, player_block > 0)
	_update_health_color(_enemy_bar, enemy_block > 0, GS.in_form())
	_hud.update_resources(energy, max_energy, locked)
	for node: Node in _hand_box.get_children():
		var view := node as BattleCardView
		view.set_playable(_can_play(view.card))


func _update_intent() -> void:
	var intent := _current_intent()
	var kind := str(intent.get("kind", "attack"))
	var icon_path := INTENT_ICON_DIR + kind + ".png"
	if not ResourceLoader.exists(icon_path):
		icon_path = INTENT_ICON_DIR + "unknown.png"
	if ResourceLoader.exists(icon_path):
		_intent_icon.texture = load(icon_path)
	var v := int(intent.get("value", 0))
	_intent_value.text = str(v) if v > 0 else ""
	if kind == "buff":
		_intent_value.text = "+%d" % v
	_intent_icon.modulate = Color(1, 0.6, 0.6) if kind == "attack" else Color.WHITE


func _rebuild_party() -> void:
	# 第一次搭完版式后，HP 条藏在 row→col→Hp 两层下面，
	# 直接 get_node_or_null("Hp") 会拿到 null → 我方 HP 永远停在初始值，
	# 看起来就是“被打也不掉血”。缓存引用一次，之后直接改值。
	if _party_hp_bar != null and is_instance_valid(_party_hp_bar):
		_party_hp_bar.max_value = maxi(player_max_hp, 1)
		_party_hp_bar.value = player_hp
		_party_hp_label.text = "%d/%d" % [player_hp, player_max_hp]
		_party_status_row.update_statuses({"block": player_block, "strength": player_strength, "vulnerable": player_vulnerable})
		return
	# 第一次搭版式：小头像 + HP（OMORI 式）
	var row := HBoxContainer.new()
	row.name = "Player"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 12)
	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(84, 84)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PARTY_AVATAR):
		avatar.texture = load(PARTY_AVATAR)
	_party_avatar = avatar
	row.add_child(avatar)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 4)
	var header := HBoxContainer.new()
	header.name = "Header"
	col.add_child(header)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text = "焰铃"
	name_label.add_theme_font_size_override(&"font_size", 26)
	name_label.add_theme_color_override(&"font_color", Color.WHITE)
	name_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override(&"outline_size", 5)
	header.add_child(name_label)
	_party_hp_label = Label.new()
	_party_hp_label.name = "Health"
	_party_hp_label.text = "%d/%d" % [player_hp, player_max_hp]
	_party_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_party_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_party_hp_label.add_theme_font_size_override(&"font_size", 22)
	header.add_child(_party_hp_label)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "Hp"
	hp_bar.custom_minimum_size = Vector2(0, 24)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.add_theme_stylebox_override(&"background", _meter_style("progressBarBase_black.png"))
	hp_bar.add_theme_stylebox_override(&"fill", _meter_style("progressBar_red.png"))
	hp_bar.max_value = player_max_hp
	hp_bar.value = player_hp
	hp_bar.show_percentage = false
	col.add_child(hp_bar)
	_party_status_row = StatusRow.new()
	_party_status_row.name = "Statuses"
	col.add_child(_party_status_row)
	row.add_child(col)
	_party_box.add_child(row)
	_party_hp_bar = hp_bar
	_party_status_row.update_statuses({"block": player_block, "strength": player_strength, "vulnerable": player_vulnerable})


func _toast_message(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_toast, ^"modulate:a", 0.0, 1.6).set_delay(1.0)
#endregion
