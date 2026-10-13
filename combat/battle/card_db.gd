class_name CardDB
extends RefCounted
## 卡牌总表：读 combat/cards/cards.json，缓存成 CardData。
## 想热改数值：改 JSON 后重启游戏即可（JSON 不进 Godot 的资源系统，直接 FileAccess 读）。

const CARDS_PATH := "res://combat/cards/cards.json"

static var _cards: Dictionary = {}
static var _loaded: bool = false


static func all() -> Dictionary:
	_ensure_loaded()
	return _cards


static func get_card(card_id: String) -> CardData:
	_ensure_loaded()
	if not _cards.has(card_id):
		push_warning("[CardDB] 没有这张卡：%s" % card_id)
		return null
	return _cards[card_id]


static func has_card(card_id: String) -> bool:
	_ensure_loaded()
	return _cards.has(card_id)


static func ids() -> Array:
	_ensure_loaded()
	return _cards.keys()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cards.clear()
	if not FileAccess.file_exists(CARDS_PATH):
		push_error("[CardDB] 找不到卡牌表：%s" % CARDS_PATH)
		return
	var f := FileAccess.open(CARDS_PATH, FileAccess.READ)
	if f == null:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		push_error("[CardDB] cards.json 解析失败：%s" % json.get_error_message())
		f.close()
		return
	f.close()
	var data: Variant = json.data
	if not (data is Dictionary) or not data.has("cards"):
		push_error("[CardDB] cards.json 顶层要是个带 cards 的对象")
		return
	for card_id: Variant in (data["cards"] as Dictionary):
		var entry: Variant = data["cards"][card_id]
		if entry is Dictionary:
			_cards[str(card_id)] = CardData.from_json(str(card_id), entry)
