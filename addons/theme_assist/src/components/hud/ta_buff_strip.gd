class_name TaBuffStrip
extends HBoxContainer

# AGENT: Small buff / item icon strip. Display only.
# INVARIANT: Children are TaBadge pills. set_buff writes text.
# DO NOT: Own status effects.

## HUD buff row. set_buff(i, "Haste") or empty to hide.

const _Badge := preload("res://addons/theme_assist/src/components/badge/ta_badge.gd")

@export var buff_count: int = TaDefaults.BUFF_COUNT:
	set(value):
		buff_count = maxi(1, value)
		_rebuild()


func _init() -> void:
	theme_type_variation = "TaBuffStrip"
	_rebuild()


func set_buff(index: int, text: String, tone: int = 0) -> void:
	if index < 0 or index >= get_child_count():
		return
	var badge = get_child(index)
	badge.text = text
	badge.tone = tone
	badge.visible = not text.is_empty()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for i in buff_count:
		var badge = _Badge.new()
		badge.visible = false
		add_child(badge)
