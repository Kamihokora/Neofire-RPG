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

const ENERGY_PER_TURN := 3
const HAND_SIZE := 5
const FORM_BONUS_DAMAGE := 2
const FORM_BLOCK_PER_TURN := 3
const FORM_CUTIN_ART := "res://assets/portraits/xinhuo_normal.png"
const PARTY_AVATAR := "res://assets/avatars/你好_05.png"
const ENEMY_PATH := "res://combat/enemies/enemy_basic.json"
const INTENT_ICON_DIR := "res://assets/ui/intents/"

## 独立预览用（挂进 game.tscn 时由 game.gd 调 initialize）
@export var auto_start: bool = false

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
var _busy := false
var _over := false
var _form_entered_this_turn := false
#endregion

@onready var _hand_box: HBoxContainer = $Hand
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


func _ready() -> void:
	GS = RunState.instance
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	_form_button.pressed.connect(_on_form_button_pressed)
	_pile_draw.pressed.connect(_on_pile_draw_pressed)
	_pile_discard.pressed.connect(_on_pile_discard_pressed)
	if auto_start:
		start_battle()


## game.gd 的入口（兼容旧 combat.tscn 的调用签名）
func initialize(_combat_actors: Array = []) -> void:
	start_battle()


func clear_combat() -> void:
	pass


#region 开局
################################################################################

func start_battle() -> void:
	_over = false
	_busy = false
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
	_start_player_turn()


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
	_draw_cards(HAND_SIZE)
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
	if _busy or _over:
		return
	_end_turn()


func _end_turn() -> void:
	_busy = true
	# 弃掉手牌
	for id in hand:
		discard_pile.append(id)
	hand.clear()
	_update_ui()
	await _enemy_turn()
	if _over:
		return
	_busy = false
	_start_player_turn()


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
	for _i in count:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			draw_pile.shuffle()
		hand.append(draw_pile.pop_back())
	_rebuild_hand()


func _can_play(card: CardData) -> bool:
	if _busy or _over or card == null:
		return false
	if card.cost > energy:
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
	for child in _hand_box.get_children():
		child.queue_free()
	for i in hand.size():
		var card := CardDB.get_card(hand[i])
		if card == null:
			continue
		var view := BattleCardView.new()
		_hand_box.add_child(view)
		view.setup(card)
		view.set_playable(_can_play(card))
		view.pressed.connect(_on_card_pressed.bind(i))


func _on_card_pressed(index: int) -> void:
	await _animate_card_play(index)
	play_card(index)


## 出牌手感：牌抬起来放大再淡出（Container 会接管 position，所以只动 scale/alpha）
func _animate_card_play(index: int) -> void:
	if index < 0 or index >= _hand_box.get_child_count():
		return
	var view: Control = _hand_box.get_child(index)
	if view == null:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(view, ^"scale", Vector2(1.28, 1.28), 0.12).set_trans(Tween.TRANS_SINE)
	tween.tween_property(view, ^"modulate:a", 0.0, 0.16).set_delay(0.04)
	await tween.finished


func play_card(index: int) -> bool:
	if index < 0 or index >= hand.size() or _busy or _over:
		return false
	var card := CardDB.get_card(hand[index])
	if card == null or not _can_play(card):
		return false
	energy -= card.cost
	hand.remove_at(index)
	if card.exhaust:
		pass  # 消耗牌直接进虚空（v1 先不单独做虚空调）
	else:
		discard_pile.append(card.id)
	var entered := _apply_effects(card)
	_update_ui()
	_rebuild_hand()
	if entered:
		await _play_form_cutin()
	return true


## 返回 true 表示这张牌让玩家进入了形态（需要播立绘切入）
func _apply_effects(card: CardData) -> bool:
	var entered_form := false
	for e in card.effects:
		var v := int(e.get("value", 0))
		match CardData.kind_from(str(e.get("kind", "damage"))):
			CardData.EffectKind.DAMAGE:
				_damage_enemy(v)
			CardData.EffectKind.BLOCK:
				player_block += v
				_punch(_party_avatar)
			CardData.EffectKind.DRAW:
				_draw_cards(v)
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
		return false
	return entered_form
#endregion


#region 牌堆查看
################################################################################

func _on_pile_draw_pressed() -> void:
	_pile_view.open_view("抽牌堆", draw_pile)


func _on_pile_discard_pressed() -> void:
	_pile_view.open_view("弃牌堆", discard_pile)
#endregion


#region 形态
################################################################################

func _on_form_button_pressed() -> void:
	if _busy or _over:
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


## 全身立绘图切入（OMORI 式的演出）
func _play_form_cutin() -> void:
	_busy = true
	_end_turn_button.disabled = true
	await _cut_in.play(GS.FORM_WRITER, "文手形态", FORM_CUTIN_ART)
	_busy = false
	_end_turn_button.disabled = false
	_update_ui()
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
	if GS.mercy >= 100 and not _over:
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
	# 右侧竖排「应援量表」：形态值进度；进入形态后显示剩余回合
	_gauge_bar.max_value = GS.FORM_COST
	if GS.in_form():
		_gauge_bar.value = GS.form_turns_left
		_gauge_value.text = "形态 %d 回合" % GS.form_turns_left
	else:
		_gauge_bar.value = GS.form_value
		_gauge_value.text = "%d/%d" % [GS.form_value, GS.FORM_COST]
	_form_button.text = "退出文手形态" if GS.in_form() else "进入文手形态"
	_form_button.disabled = _over or (not GS.in_form() and not GS.can_enter_form())
	_mercy_label.text = "好感度 %d" % GS.mercy
	_deck_label.text = "卡组 %d" % GS.deck.size()
	_pile_draw.text = "抽牌堆 %d" % draw_pile.size()
	_pile_discard.text = "弃牌堆 %d" % discard_pile.size()
	_enemy_name.text = enemy_name
	_enemy_bar.max_value = maxi(enemy_max_hp, 1)
	_enemy_bar.value = enemy_hp
	var enemy_status: PackedStringArray = PackedStringArray()
	if enemy_block > 0:
		enemy_status.append("格挡 %d" % enemy_block)
	if enemy_strength > 0:
		enemy_status.append("力量 %d" % enemy_strength)
	if enemy_weak > 0:
		enemy_status.append("虚弱 %d" % enemy_weak)
	if enemy_vulnerable > 0:
		enemy_status.append("易伤 %d" % enemy_vulnerable)
	_enemy_hp_label.text = "%d/%d" % [enemy_hp, enemy_max_hp]
	_enemy_status.text = "  ".join(enemy_status)
	_update_intent()
	_rebuild_party()


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
	if _party_box.get_child_count() > 0:
		var slot: Control = _party_box.get_child(0)
		var hp: ProgressBar = slot.get_node_or_null(^"Hp")
		if hp != null:
			hp.value = player_hp
			hp.show_percentage = false
		var info: Label = slot.get_node_or_null(^"Info")
		if info != null:
			info.text = _player_status_text()
		return
	# 第一次搭版式：小头像 + HP（OMORI 式）
	var row := HBoxContainer.new()
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
	col.add_theme_constant_override(&"separation", 4)
	var name_label := Label.new()
	name_label.text = "焰铃"
	name_label.add_theme_font_size_override(&"font_size", 26)
	name_label.add_theme_color_override(&"font_color", Color.WHITE)
	name_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override(&"outline_size", 5)
	col.add_child(name_label)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "Hp"
	hp_bar.custom_minimum_size = Vector2(180, 22)
	hp_bar.max_value = player_max_hp
	hp_bar.value = player_hp
	hp_bar.show_percentage = false
	col.add_child(hp_bar)
	var info_label := Label.new()
	info_label.name = "Info"
	info_label.add_theme_font_size_override(&"font_size", 20)
	info_label.add_theme_color_override(&"font_color", Color.WHITE)
	info_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	info_label.add_theme_constant_override(&"outline_size", 4)
	info_label.text = _player_status_text()
	col.add_child(info_label)
	row.add_child(col)
	_party_box.add_child(row)


func _player_status_text() -> String:
	var s := "%d/%d" % [player_hp, player_max_hp]
	if player_block > 0:
		s += "  格挡 %d" % player_block
	if player_vulnerable > 0:
		s += "  易伤 %d" % player_vulnerable
	return s


func _toast_message(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_toast, ^"modulate:a", 0.0, 1.6).set_delay(1.0)
#endregion
