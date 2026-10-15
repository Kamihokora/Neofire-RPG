extends HBoxContainer
## 复用 StS2 图标，数量保留数字，状态名称仅在悬停提示中显示。

const DEFINITIONS := {
	"block": ["格挡", "res://assets/ui/status/block.png"],
	"strength": ["力量", "res://assets/ui/status/strength.tres"],
	"vulnerable": ["易伤", "res://assets/ui/status/vulnerable.tres"],
}

var _chips: Dictionary[String, Control] = {}


func is_status_hovered() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	for chip: Control in _chips.values():
		if chip.is_visible_in_tree() and (chip == hovered or chip.is_ancestor_of(hovered)):
			return true
	return false


func _ready() -> void:
	custom_minimum_size.y = 30
	add_theme_constant_override(&"separation", 8)
	for id: String in DEFINITIONS:
		var chip := Control.new()
		chip.name = id.capitalize()
		chip.custom_minimum_size = Vector2(56, 30)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(chip)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = load(DEFINITIONS[id][1])
		icon.size = Vector2(30, 30)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(icon)
		var amount := Label.new()
		amount.name = "Amount"
		amount.position = Vector2(25, 5)
		amount.size = Vector2(32, 25)
		amount.add_theme_font_size_override(&"font_size", 19)
		amount.add_theme_color_override(&"font_outline_color", Color.BLACK)
		amount.add_theme_constant_override(&"outline_size", 5)
		amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(amount)
		chip.hide()
		_chips[id] = chip


func update_statuses(values: Dictionary) -> void:
	for id: String in _chips:
		var value := int(values.get(id, 0))
		var chip: Control = _chips[id]
		chip.visible = value != 0
		(chip.get_node("Amount") as Label).text = str(value)
		chip.tooltip_text = "%s：%d" % [DEFINITIONS[id][0], value]
		if id == "vulnerable":
			chip.tooltip_text += "\n受到的攻击伤害增加 50%%。\n剩余 %d 回合。" % value
