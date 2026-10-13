class_name CardData
extends Resource
## 一张卡牌的数据（从 combat/cards/cards.json 读出来）。
## 故意做成 Resource + JSON：策划/文手直接改 JSON 就能调卡，不用碰代码。

enum Type { ATTACK, SKILL, POWER, TALK }
enum Rarity { BASIC, COMMON, UNCOMMON, RARE }

## effect.kind 的全部取值
enum EffectKind { DAMAGE, BLOCK, DRAW, FORM, ENERGY, HEAL, WEAK, VULNERABLE, MERCY, ENTER_FORM }

@export var id: String = ""
@export var name: String = ""
@export var cost: int = 1
@export var type: Type = Type.ATTACK
@export var rarity: Rarity = Rarity.BASIC
@export var description: String = ""
@export var exhaust: bool = false
## 只有进入形态时才打得出去
@export var form_only: bool = false
@export var effects: Array[Dictionary] = []
## 卡面插图（手绘素材接口；留空用纯色卡面）
@export var art: String = ""


static func type_from(text: String) -> Type:
	match text.to_lower():
		"skill":
			return Type.SKILL
		"power":
			return Type.POWER
		"talk":
			return Type.TALK
		_:
			return Type.ATTACK


static func rarity_from(text: String) -> Rarity:
	match text.to_lower():
		"common":
			return Rarity.COMMON
		"uncommon":
			return Rarity.UNCOMMON
		"rare":
			return Rarity.RARE
		_:
			return Rarity.BASIC


static func kind_from(text: String) -> EffectKind:
	match text.to_lower():
		"block":
			return EffectKind.BLOCK
		"draw":
			return EffectKind.DRAW
		"form":
			return EffectKind.FORM
		"energy":
			return EffectKind.ENERGY
		"heal":
			return EffectKind.HEAL
		"weak":
			return EffectKind.WEAK
		"vulnerable":
			return EffectKind.VULNERABLE
		"mercy":
			return EffectKind.MERCY
		"enter_form":
			return EffectKind.ENTER_FORM
		_:
			return EffectKind.DAMAGE


## 从 JSON 的一条字典建卡
static func from_json(card_id: String, data: Dictionary) -> CardData:
	var card := CardData.new()
	card.id = card_id
	card.name = str(data.get("name", card_id))
	card.cost = int(data.get("cost", 1))
	card.type = type_from(str(data.get("type", "attack")))
	card.rarity = rarity_from(str(data.get("rarity", "basic")))
	card.description = str(data.get("description", ""))
	card.exhaust = bool(data.get("exhaust", false))
	card.form_only = bool(data.get("form_only", false))
	card.art = str(data.get("art", ""))
	var raw_effects: Variant = data.get("effects", [])
	var out: Array[Dictionary] = []
	if raw_effects is Array:
		for e: Variant in raw_effects:
			if e is Dictionary:
				out.append(e)
	card.effects = out
	# 描述留空就按效果自动生成一句，省得两头维护
	if card.description.is_empty():
		card.description = card.auto_description()
	return card


func auto_description() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e in effects:
		var v := int(e.get("value", 0))
		match kind_from(str(e.get("kind", "damage"))):
			EffectKind.DAMAGE:
				parts.append("造成 %d 点伤害" % v)
			EffectKind.BLOCK:
				parts.append("获得 %d 点格挡" % v)
			EffectKind.DRAW:
				parts.append("抽 %d 张牌" % v)
			EffectKind.FORM:
				parts.append("获得 %d 点形态值" % v)
			EffectKind.ENERGY:
				parts.append("获得 %d 点能量" % v)
			EffectKind.HEAL:
				parts.append("回复 %d 点生命" % v)
			EffectKind.WEAK:
				parts.append("施加 %d 层虚弱" % v)
			EffectKind.VULNERABLE:
				parts.append("施加 %d 层易伤" % v)
			EffectKind.MERCY:
				parts.append("好感度 +%d" % v)
			EffectKind.ENTER_FORM:
				parts.append("进入文手形态")
	return "，".join(parts) + "。"


func type_name() -> String:
	match type:
		Type.SKILL:
			return "技能"
		Type.POWER:
			return "能力"
		Type.TALK:
			return "交涉"
		_:
			return "攻击"
