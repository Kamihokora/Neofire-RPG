extends RefCounted
## 站位和技能元数据；与战斗临时状态、UI分离，方便策划直接替换JSON。

const COSTS := [10, 6, 4, 2]
const MEMBERS := ["write", "draw", "rhythm", "manga"]
const NAMES := {"write":"文手", "draw":"画手", "rhythm":"曲师", "manga":"问号"}
const ART := {"write":"res://neofire/GIF/有个点子_03.png", "draw":"res://neofire/GIF/笔自己画_15.png", "rhythm":"res://neofire/GIF/好耶_09.png", "manga":"res://neofire/GIF/难道说_02.png"}
static var _skills: Dictionary = {}


static func skills() -> Dictionary:
	if _skills.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://gameplay/data/creator_skills.json"))
		if data is Dictionary and data.get("skills") is Dictionary:
			_skills = data["skills"]
	return _skills


static func starting_skills() -> Array[String]:
	var result: Array[String] = []
	for id: String in skills():
		if bool(_skills[id].get("starting", false)):
			result.append(id)
	return result


static func matches_slot(id: String, owner: String, tier: int) -> bool:
	var skill: Dictionary = skills().get(id, {})
	return not skill.is_empty() and str(skill.get("owner")) == owner and int(skill.get("tier", -1)) == tier


static func default_loadouts() -> Dictionary:
	var result: Dictionary = {}
	for member: String in MEMBERS:
		result[member] = {}
		for tier: int in COSTS:
			for id: String in starting_skills():
				if matches_slot(id, member, tier):
					result[member][str(tier)] = id
					break
	return result


static func valid_formation(value: Variant) -> bool:
	if not value is Array or value.size() != 4:
		return false
	var seen: Dictionary = {}
	for member: Variant in value:
		if not member is String or member not in MEMBERS or seen.has(member):
			return false
		seen[member] = true
	return true
