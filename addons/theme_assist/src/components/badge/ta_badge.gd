@tool
class_name TaBadge
extends PanelContainer

# AGENT: Compact status pill. Component layer.
# INVARIANT: Root is PanelContainer, not a wrapped Button.
# DO NOT: Invent colors. Tone maps to TaDefaults / Theme variations.

## Small pill for counts and status. Tone uses Theme Assist defaults.
## TaBadge.attach(button, "3") pins one to the corner of any control.

const ATTACH_NAME := "_TaBadgeAttached"

enum Tone {
	DEFAULT,
	ACCENT,
	MUTED,
	DANGER,
	SUCCESS,
	WARNING,
	RARITY,
	## A count on a slot: a plate of the look's ink with page-colour digits.
	COUNT,
}

@export var text: String = "":
	set(value):
		text = value
		_apply_text()

@export var tone: Tone = Tone.DEFAULT:
	set(value):
		tone = value
		_apply_tone()

## A tone from look.tones ("money"). Wins over tone while not empty.
@export var tone_name: String = "":
	set(value):
		tone_name = value
		_apply_tone()

var _label: Label
var _painting: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inline: a VBox or a tall row must not stretch a badge into a bar.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_apply_text()
	_apply_tone()


## Pin a badge to a corner of host (an unread count on a button, a phone tile).
## Reuses the one already there. Empty text hides it. Returns the badge.
static func attach(
		host: Control,
		badge_text: String,
		badge_tone: Tone = Tone.DANGER,
		corner: Corner = CORNER_TOP_RIGHT
	) -> TaBadge:
	if not is_instance_valid(host):
		return null
	var badge := host.get_node_or_null(ATTACH_NAME) as TaBadge
	if badge == null:
		badge = TaBadge.new()
		badge.name = ATTACH_NAME
		badge.z_index = 1
		host.add_child(badge)
	badge.text = badge_text
	badge.tone = badge_tone
	badge.visible = not badge_text.is_empty()
	var right := corner == CORNER_TOP_RIGHT or corner == CORNER_BOTTOM_RIGHT
	var bottom := corner == CORNER_BOTTOM_LEFT or corner == CORNER_BOTTOM_RIGHT
	# Zero offsets plus GROW_DIRECTION_BOTH centre the badge on the corner.
	badge.anchor_left = 1.0 if right else 0.0
	badge.anchor_right = badge.anchor_left
	badge.anchor_top = 1.0 if bottom else 0.0
	badge.anchor_bottom = badge.anchor_top
	badge.offset_left = 0.0
	badge.offset_right = 0.0
	badge.offset_top = 0.0
	badge.offset_bottom = 0.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	return badge


## A row of cost chips anywhere (a confirm card, a shop row, a HUD):
## [["⏱", "15 min"], ["⚡", "-2"], "Free"]. Each entry is [glyph, text] with an
## optional tone, or a plain String. TaModal.add_costs uses it.
## Colour emoji keep their own colours (Godot does not tint them, and U+FE0E does not
## make them plain): a gold ⚡ vanishes on a Warning fill. Keep them on DEFAULT or MUTED
## chips; on a toned chip use a glyph your font draws in one colour (it takes the ink).
static func cost_row(costs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for cost in costs:
		var badge := TaBadge.new()
		if cost is Array:
			var parts: Array = cost
			badge.text = " ".join(PackedStringArray([str(parts[0]), str(parts[1])]))
			if parts.size() > 2:
				badge.tone = int(parts[2]) as TaBadge.Tone
		else:
			badge.text = str(cost)
		row.add_child(badge)
	return row


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_PARENTED:
		_paint_ink()


func _ready() -> void:
	_paint_ink()


func _apply_text() -> void:
	if is_instance_valid(_label):
		_label.text = text


func _apply_tone() -> void:
	if not tone_name.is_empty():
		theme_type_variation = TaThemeBuilder.tone_type("TaBadge", tone_name)
		_paint_ink()
		return
	match tone:
		Tone.ACCENT:
			theme_type_variation = "TaBadgeAccent"
		Tone.MUTED:
			theme_type_variation = "TaBadgeMuted"
		Tone.DANGER:
			theme_type_variation = "TaBadgeDanger"
		Tone.SUCCESS:
			theme_type_variation = "TaBadgeSuccess"
		Tone.WARNING:
			theme_type_variation = "TaBadgeWarning"
		Tone.RARITY:
			theme_type_variation = "TaBadgeRarity"
		Tone.COUNT:
			theme_type_variation = "TaBadgeCount"
		_:
			theme_type_variation = "TaBadge"
	_paint_ink()


## The tone's ink from the nearest Theme that has it, so a game panel with a Theme of
## its own does not hide the kit's (it left body text on the warning fill).
func _paint_ink() -> void:
	if _painting or not is_instance_valid(_label):
		return
	var type_name := StringName(theme_type_variation)
	var source := TaThemeBuilder.theme_with_color(self, "font_color", type_name)
	if source == null or type_name.is_empty():
		return
	_painting = true
	TaThemeBuilder.paint_label(_label, source, type_name)
	_painting = false
