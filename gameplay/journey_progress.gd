extends RefCounted
## 共享成长、灵感数量与想法账本。合成不直接解锁，立项由四人桌入口调用。

signal changed
const CreatorRules := preload("res://gameplay/creator_rules.gd")
const LIMIT := 1000000000
static var _growth: Dictionary = {}
static var _inspiration: Dictionary = {}

var level := 1
var experience := 0
var training_points := 0
var inspirations: Dictionary = {}
var ideas: Dictionary = {}
var approved: Array[String] = []
var inspiration_order: Array[String] = []
var used_story: Array[String] = []


static func growth() -> Dictionary:
	if _growth.is_empty():
		_growth = JSON.parse_string(FileAccess.get_file_as_string("res://gameplay/data/progression.json"))
	return _growth


static func inspiration() -> Dictionary:
	if _inspiration.is_empty():
		_inspiration = JSON.parse_string(FileAccess.get_file_as_string("res://gameplay/data/inspiration.json"))
	return _inspiration


func reset() -> void:
	level = 1
	experience = 0
	training_points = 0
	inspirations.clear()
	ideas.clear()
	approved.clear()
	inspiration_order.clear()
	used_story.clear()
	changed.emit()


func award_experience(amount: int, state: Node) -> int:
	if amount <= 0:
		return 0
	experience = mini(experience + amount, LIMIT)
	var gained := 0
	for reward: Dictionary in growth()["levels"]:
		if int(reward["level"]) > level and experience >= int(reward["experience"]):
			level = int(reward["level"])
			gained += 1
			training_points = mini(training_points + int(reward.get("training_points", 0)), LIMIT)
			for id: String in reward.get("cards", []):
				if CardDB.has_card(id): state.add_card(id)
			for id: String in reward.get("creator_skills", []):
				if CreatorRules.skills().has(id) and id not in state.known_creator_skills:
					state.known_creator_skills.append(id)
					state.loadout_changed.emit()
	changed.emit()
	return gained


func next_experience() -> int:
	for reward: Dictionary in growth()["levels"]:
		if int(reward["level"]) > level:
			return int(reward["experience"])
	return -1


func buy_growth(kind: String, state: Node) -> bool:
	var cost := int(growth().get("growth_cost", 1))
	if training_points < cost:
		return false
	match kind:
		"minimum_deck":
			if state.min_deck_size <= int(growth()["minimum_deck_hard_limit"]): return false
			state.min_deck_size -= 1
		"rarity_budget":
			if state.rarity_budget >= LIMIT: return false
			state.rarity_budget += 1
		_: return false
	training_points -= cost
	changed.emit()
	return true


func add_inspiration(id: String, amount: int = 1) -> bool:
	if not inspiration()["words"].has(id) or amount <= 0:
		return false
	var story: bool = inspiration()["words"][id].get("kind", "common") == "story"
	if story and (id in used_story or int(inspirations.get(id, 0)) > 0): return false
	if int(inspirations.get(id, 0)) <= 0:
		inspiration_order.erase(id)
		inspiration_order.append(id)
	inspirations[id] = 1 if story else mini(int(inspirations.get(id, 0)) + amount, LIMIT)
	changed.emit()
	return true


func find_recipe(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	for id: String in inspiration()["recipes"]:
		var inputs: Array = inspiration()["recipes"][id]["inputs"].duplicate()
		inputs.sort()
		if inputs == pair: return id
	return ""


func can_compose(id: String) -> bool:
	var recipe: Dictionary = inspiration()["recipes"].get(id, {})
	if recipe.is_empty(): return false
	var needed: Dictionary = {}
	for word: String in recipe["inputs"]:
		needed[word] = int(needed.get(word, 0)) + 1
	for word: String in needed:
		if int(inspirations.get(word, 0)) < int(needed[word]): return false
	return true


func has_combination() -> bool:
	for id: String in inspiration()["recipes"]:
		if can_compose(id): return true
	return false


func compose(a: String, b: String) -> String:
	var id := find_recipe(a, b)
	if not can_compose(id): return ""
	# 校验完整配方后一次性扣数量，同一个词出现两次也需要两个。
	for word: String in inspiration()["recipes"][id]["inputs"]:
		inspirations[word] = int(inspirations[word]) - 1
		if inspiration()["words"][word].get("kind", "common") == "story" and word not in used_story:
			used_story.append(word)
	ideas[id] = mini(int(ideas.get(id, 0)) + 1, LIMIT)
	changed.emit()
	return id


func implement_idea(id: String, state: Node) -> bool:
	var recipe: Dictionary = inspiration()["recipes"].get(id, {})
	if recipe.is_empty() or int(ideas.get(id, 0)) <= 0:
		return false
	if str(recipe["kind"]) == "major" and id in approved:
		return false
	ideas[id] = int(ideas[id]) - 1
	if id not in approved: approved.append(id)
	for key: String in recipe.get("flags", {}):
		var value: Variant = recipe["flags"][key]
		if key == "max_relic_slots":
			state.global_flags[key] = maxi(int(state.global_flags.get(key, 1)), int(value))
		else:
			state.global_flags[key] = value
	for item: String in recipe.get("items", {}):
		state.inventory[item] = mini(int(state.inventory.get(item, 0)) + int(recipe["items"][item]), LIMIT)
	changed.emit()
	return true


func to_save_data() -> Dictionary:
	return {"level":level, "experience":experience, "training_points":training_points,
		"inspirations":inspirations.duplicate(), "ideas":ideas.duplicate(), "approved":approved.duplicate(),
		"inspiration_order":inspiration_order.duplicate(), "used_story":used_story.duplicate()}


static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= LIMIT


static func valid_save_data(data: Variant) -> bool:
	if not data is Dictionary: return false
	for key: String in ["level", "experience", "training_points"]:
		if not _count(data.get(key)): return false
	if int(data["level"]) < 1 or int(data["level"]) > 999: return false
	for key: String in ["inspirations", "ideas"]:
		if not data.get(key) is Dictionary: return false
		var catalog: Dictionary = inspiration()["words" if key == "inspirations" else "recipes"]
		for id: Variant in data[key]:
			if not id is String or not catalog.has(id) or not _count(data[key][id]): return false
			if key == "inspirations" and data.has("used_story") and catalog[id].get("kind", "common") == "story" and int(data[key][id]) > 1: return false
	if not data.get("approved") is Array or data["approved"].size() > inspiration()["recipes"].size(): return false
	var seen: Dictionary = {}
	for id: Variant in data["approved"]:
		if not id is String or not inspiration()["recipes"].has(id) or seen.has(id): return false
		seen[id] = true
	for key: String in ["inspiration_order", "used_story"]:
		if not data.has(key): continue # 兼容本阶段早期的成长存档。
		if not data[key] is Array or data[key].size() > inspiration()["words"].size(): return false
		seen.clear()
		for id: Variant in data[key]:
			if not id is String or not inspiration()["words"].has(id) or seen.has(id): return false
			if key == "used_story" and (inspiration()["words"][id].get("kind", "common") != "story" or int(data["inspirations"].get(id, 0)) > 0): return false
			seen[id] = true
	return true


func apply_save_data(data: Dictionary) -> void:
	level = int(data["level"])
	experience = int(data["experience"])
	training_points = int(data["training_points"])
	inspirations = data["inspirations"].duplicate()
	ideas = data["ideas"].duplicate()
	approved.assign(data["approved"])
	inspiration_order.assign(data.get("inspiration_order", inspirations.keys()))
	used_story.assign(data.get("used_story", []))
	if not data.has("used_story"):
		for id: String in inspirations:
			if inspiration()["words"][id].get("kind", "common") == "story":
				inspirations[id] = mini(1, int(inspirations[id]))
	changed.emit()
