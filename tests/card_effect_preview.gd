extends "res://combat/battle/battle.gd"
## F6 专用夹具；test1 仅在此进程注册，不写入正式卡表。

var _opening_prepared := false


func _ready() -> void:
	CardDB.all()["test1"] = CardData.from_json("test1", {
		"name": "test1", "cost": 0, "type": "skill",
		"description": "选择弃掉 2 张手牌。",
		"effects": [{"kind": "discard", "value": 2}],
	})
	for id: String in ["splash", "revise", "test1", "draft", "inspiration"]:
		if not RunState.instance.deck.has(id):
			RunState.instance.deck.append(id)
	super._ready()


func _draw_cards(count: int) -> void:
	if not _opening_prepared:
		_opening_prepared = true
		var desired: Array[String] = ["splash", "revise", "test1", "draft", "inspiration"]
		for id in desired:
			draw_pile.erase(id)
		desired.reverse()
		draw_pile.append_array(desired)
	await super._draw_cards(count)
