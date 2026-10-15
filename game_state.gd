class_name RunState
extends Node
## 全局 run 状态中枢。
##
## 想当 autoload 用（project.godot 里注册 GameState），但编辑器会在运行时回写 project.godot
## 把我们手加的 autoload 行搞掉，所以这里带一个静态入口 `RunState.instance`：
## 如果 autoload 没生效，它会自己挂到 /root 下（名字仍叫 GameState）。
##
## 这里只放“跨场景存活”的东西：应援值 / 形态值 / 形态 / 卡组 / 稀有度预算。
## 战斗内的临时状态（能量、手牌、格挡）在 battle.gd 里，不进这里。
##
## 设计口径（见策划稿）：
##   应援值 = 场外（探索中的对话选择/调查/事件）积累
##   形态值 = 场外应援值 + 局内特定行为（特定卡牌/成功格挡/特定交涉）
##   形态   = 消耗 N 点形态值进入的“持续形态”，持续若干回合；
##            提前退出按 已用回合/最大回合 比例退还（ceil），走完窗口则不退。

signal support_changed(value: int)
signal form_value_changed(value: int)
signal form_entered(form_id: String)
signal form_exited(form_id: String, refunded: int)
signal deck_changed()
signal formation_changed
signal loadout_changed

const CreatorRules := preload("res://gameplay/creator_rules.gd")
const JourneyProgress := preload("res://gameplay/journey_progress.gd")

## 进入形态的消耗 / 形态值上限
const FORM_COST := 10
## 形态持续回合数（话疗窗口）
const FORM_TURNS := 1 # 测试阶段：一次进入只进行一轮对话，选择后自然结束。
## 第一章只有文手形态
const FORM_WRITER := "writer"

## 稀有度预算（设计稿：初始卡牌 0 点 / 蓝卡 2 点 / 金卡 3 点，初始预算 5 点）
const RARITY_COST := {"basic": 0, "common": 0, "uncommon": 2, "rare": 3}

const STARTING_DECK_PATH := "res://combat/cards/starting_deck.json"

var support_value: int = 0
var form_value: int = 0
var form_id: String = ""
var form_turns_left: int = 0
var form_turns_used: int = 0
## 好感度（文手形态的“交涉”用；交涉场景做出来之前先留接口）
var mercy: int = 0
var min_deck_size: int = 12 # reset_run从成长配置读取；起始牌组目前12张，硬下限10。
var rarity_budget: int = 5
var deck: Array[String] = []
## 跨场景的提案解锁、技能装配与共享成长；战斗内资源仍归Battle管理。
var global_flags: Dictionary = {"can_sprint": false, "unlock_card_recycle": false, "unlock_leader_ult": false, "max_relic_slots": 1}
var inventory: Dictionary = {}
var skill_loadouts: Dictionary = {}
var known_creator_skills: Array[String] = []
var formation: Array[String] = ["write", "draw", "rhythm", "manga"]
var relics: Array[String] = []
var play_seconds := 0.0
var journey := JourneyProgress.new()

static var _instance: RunState = null

## 全局入口：autoload 没生效就自己挂到 /root 下
static var instance: RunState:
	get:
		if _instance == null or not is_instance_valid(_instance):
			_bootstrap()
		return _instance


static func _bootstrap() -> void:
	# 先把实例建出来、配置好（调用方马上要用），再延迟挂到 /root，
	# 因为 _ready 阶段 /root 可能还在“设置子节点”，那时 add_child 会失败。
	var node: RunState = (load("res://game_state.gd") as GDScript).new()
	node.name = "GameState"
	_instance = node
	node.reset_run()
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.add_child.call_deferred(node)


func _ready() -> void:
	# 真正的 autoload 场景：这时 _instance 还不是自己
	if _instance != self:
		_instance = self
		reset_run()


func reset_run() -> void:
	support_value = 0
	form_value = 0
	form_id = ""
	form_turns_left = 0
	form_turns_used = 0
	mercy = 0
	global_flags = {"can_sprint": false, "unlock_card_recycle": false, "unlock_leader_ult": false, "max_relic_slots": 1}
	inventory.clear()
	skill_loadouts.clear()
	skill_loadouts = CreatorRules.default_loadouts()
	known_creator_skills.assign(CreatorRules.starting_skills())
	formation.assign(["write", "draw", "rhythm", "manga"])
	relics.clear()
	play_seconds = 0.0
	deck = load_starting_deck()
	min_deck_size = int(JourneyProgress.growth().get("starting_minimum_deck", 12))
	rarity_budget = 5
	journey.reset()
	support_changed.emit(support_value)
	form_value_changed.emit(form_value)
	deck_changed.emit()
	formation_changed.emit()
	loadout_changed.emit()


func _process(delta: float) -> void:
	play_seconds += delta


func to_save_data() -> Dictionary:
	return {"support_value": support_value, "form_value": form_value, "mercy": mercy,
		"min_deck_size": min_deck_size, "rarity_budget": rarity_budget, "deck": deck.duplicate(),
		"global_flags": global_flags.duplicate(true), "inventory": inventory.duplicate(true),
		"skill_loadouts": skill_loadouts.duplicate(true), "formation": formation.duplicate(),
		"relics": relics.duplicate(), "play_seconds": play_seconds,
		"known_creator_skills": known_creator_skills.duplicate(), "journey":journey.to_save_data()}


static func valid_save_data(data: Dictionary) -> bool:
	for key: String in ["support_value", "form_value", "mercy", "min_deck_size", "rarity_budget", "play_seconds"]:
		var value: Variant = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 1000000000:
			return false
		if key != "play_seconds" and float(value) != floor(float(value)):
			return false
	if float(data["form_value"]) > FORM_COST:
		return false
	for key: String in ["deck", "formation", "relics"]:
		if not data.get(key) is Array or data[key].size() > 1000:
			return false
		for value: Variant in data[key]:
			if not value is String:
				return false
	for card_id: String in data["deck"]:
		if not CardDB.all().has(card_id):
			return false
	if data["formation"].size() != 4:
		return false
	var seen: Dictionary = {}
	for member: String in data["formation"]:
		if member not in ["write", "draw", "rhythm", "manga"] or seen.has(member):
			return false
		seen[member] = true
	for key: String in ["global_flags", "inventory", "skill_loadouts"]:
		if not data.get(key) is Dictionary:
			return false
	for key: String in ["can_sprint", "unlock_card_recycle", "unlock_leader_ult"]:
		if not data["global_flags"].get(key) is bool:
			return false
	var capacity: Variant = data["global_flags"].get("max_relic_slots")
	if not (capacity is int or capacity is float) or float(capacity) != floor(float(capacity)) or float(capacity) < 1 or float(capacity) > 64:
		return false
	for id: Variant in data["inventory"]:
		var count: Variant = data["inventory"][id]
		if not id is String or not (count is int or count is float) or not is_finite(float(count)) or float(count) != floor(float(count)) or float(count) < 0 or float(count) > 1000000000:
			return false
	if data.has("known_creator_skills"):
		if not data["known_creator_skills"] is Array:
			return false
		for id: Variant in data["known_creator_skills"]:
			if not id is String or not CreatorRules.skills().has(id):
				return false
		for member: Variant in data["skill_loadouts"]:
			if member not in CreatorRules.MEMBERS or not data["skill_loadouts"][member] is Dictionary:
				return false
			for tier: Variant in data["skill_loadouts"][member]:
				var id: Variant = data["skill_loadouts"][member][tier]
				if not tier is String or not tier.is_valid_int() or int(tier) not in CreatorRules.COSTS or not id is String:
					return false
				if not id.is_empty() and (not CreatorRules.matches_slot(id, member, int(tier)) or id not in data["known_creator_skills"]):
					return false
	if data.has("journey") and not JourneyProgress.valid_save_data(data["journey"]):
		return false
	return true


func apply_save_data(data: Dictionary) -> bool:
	if not valid_save_data(data):
		return false
	support_value = int(data["support_value"])
	form_value = int(data["form_value"])
	mercy = int(data["mercy"])
	min_deck_size = int(data["min_deck_size"])
	rarity_budget = int(data["rarity_budget"])
	play_seconds = float(data["play_seconds"])
	deck.assign(data["deck"])
	formation.assign(data["formation"])
	relics.assign(data["relics"])
	global_flags = data["global_flags"].duplicate(true)
	inventory = data["inventory"].duplicate(true)
	known_creator_skills.assign(data.get("known_creator_skills", CreatorRules.starting_skills()))
	skill_loadouts = data["skill_loadouts"].duplicate(true) if data.has("known_creator_skills") else CreatorRules.default_loadouts()
	form_id = ""
	form_turns_left = 0
	form_turns_used = 0
	if data.has("journey"):
		journey.apply_save_data(data["journey"])
	else:
		journey.reset()
	support_changed.emit(support_value)
	form_value_changed.emit(form_value)
	deck_changed.emit()
	formation_changed.emit()
	loadout_changed.emit()
	return true


func set_formation(members: Array) -> bool:
	if not CreatorRules.valid_formation(members):
		return false
	formation.assign(members)
	formation_changed.emit()
	return true


func swap_formation(a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= 4 or b >= 4:
		return false
	var members := formation.duplicate()
	var previous: String = members[a]
	members[a] = members[b]
	members[b] = previous
	return set_formation(members)


func equipped_creator_skill(member: String, tier: int) -> String:
	return str(skill_loadouts.get(member, {}).get(str(tier), ""))


func equip_creator_skill(member: String, tier: int, id: String) -> bool:
	if member not in CreatorRules.MEMBERS or tier not in CreatorRules.COSTS:
		return false
	if not id.is_empty() and (not CreatorRules.matches_slot(id, member, tier) or id not in known_creator_skills):
		return false
	if not skill_loadouts.has(member):
		skill_loadouts[member] = {}
	skill_loadouts[member][str(tier)] = id
	loadout_changed.emit()
	return true


#region 应援值 / 形态值
################################################################################

## 全局可调用：任何场合（调查选项 / 直接获得 / 破冰小游戏）都能加应援值
func add_support(amount: int) -> void:
	support_value += amount
	support_changed.emit(support_value)


## 局内加形态值（特定卡牌 / 成功格挡 / 交涉）
func add_form_value(amount: int) -> void:
	form_value = clampi(form_value + amount, 0, FORM_COST)
	form_value_changed.emit(form_value)


func set_form_value(value: int) -> void:
	form_value = clampi(value, 0, FORM_COST)
	form_value_changed.emit(form_value)
#endregion


#region 形态
################################################################################

func can_enter_form() -> bool:
	return form_id.is_empty() and form_value >= FORM_COST


func enter_form(id: String = FORM_WRITER) -> bool:
	if not can_enter_form():
		return false
	form_id = id
	form_value -= FORM_COST
	form_turns_used = 0
	form_turns_left = FORM_TURNS
	form_value_changed.emit(form_value)
	form_entered.emit(form_id)
	return true


## 退出形态。early = 提前退出，按 已用/最大 比例扣掉，其余退还。
## 返回退还的形态值。
func exit_form(early: bool = true) -> int:
	if form_id.is_empty():
		return 0
	var refunded := 0
	if early and FORM_TURNS > 0:
		var lost := int(ceil(float(form_turns_used) / float(FORM_TURNS) * float(FORM_COST)))
		refunded = maxi(FORM_COST - lost, 0)
	form_value = clampi(form_value + refunded, 0, FORM_COST)
	var exited := form_id
	form_id = ""
	form_turns_left = 0
	form_turns_used = 0
	form_value_changed.emit(form_value)
	form_exited.emit(exited, refunded)
	return refunded


## 每过一个玩家回合调用一次。返回 true 表示形态刚好在本回合走完（自然结束，不退还）
func tick_form_turn() -> bool:
	if form_id.is_empty():
		return false
	form_turns_used += 1
	form_turns_left = maxi(FORM_TURNS - form_turns_used, 0)
	if form_turns_left <= 0:
		exit_form(false)
		return true
	return false


func in_form() -> bool:
	return not form_id.is_empty()
#endregion


#region 卡组
################################################################################

func load_starting_deck() -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(STARTING_DECK_PATH):
		return out
	var f := FileAccess.open(STARTING_DECK_PATH, FileAccess.READ)
	if f == null:
		return out
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Array:
		for id: Variant in data:
			out.append(str(id))
	return out


func add_card(card_id: String) -> void:
	deck.append(card_id)
	deck_changed.emit()


func remove_card(card_id: String) -> bool:
	if deck.size() <= maxi(min_deck_size, int(JourneyProgress.growth()["minimum_deck_hard_limit"])):
		return false
	var idx := deck.find(card_id)
	if idx < 0:
		return false
	deck.remove_at(idx)
	deck_changed.emit()
	return true


func deck_rarity_cost() -> int:
	var total := 0
	for id in deck:
		var card := CardDB.get_card(id)
		if card != null:
			total += [0, 0, 2, 3][int(card.rarity)]
	return total
#endregion
