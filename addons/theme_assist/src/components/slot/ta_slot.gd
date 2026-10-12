class_name TaSlot
extends TaButton

# AGENT: Inventory-looking cell. Display only. Component layer.
# INVARIANT: Root is Button. The visible icon is the TextureRect child.
# Button.icon is stored here and not drawn by Button, so it cannot double-paint.
# DO NOT: Own stacks, a database, or drag-drop rules.

## Square slot with optional icon, caption, badge, and hover tooltip.
## caption is words in the cell. badge_text is the corner count.

const _Badge := preload("res://addons/theme_assist/src/components/badge/ta_badge.gd")
const _Tooltip := preload("res://addons/theme_assist/src/components/tooltip/ta_item_tooltip.gd")

signal slot_pressed

@export var selected: bool = false:
	set(value):
		selected = value
		_apply_selected()

@export var tooltip_title: String = "":
	set(value):
		tooltip_title = value
		_sync_tooltip()

@export var tooltip_body: String = "":
	set(value):
		tooltip_body = value
		_sync_tooltip()

@export var badge_text: String = "":
	set(value):
		badge_text = value
		_apply_badge()

@export var caption: String = "":
	set(value):
		caption = value
		_layout_caption()

var _icon_rect: TextureRect
var _center_label: Label
var _caption_label: Label
var _center_text: String = ""
var _badge: TaBadge
var _tooltip: TaItemTooltip
var _item_icon: Texture2D
## Non-zero after set_cell_size, or after the caller changes custom_minimum_size.
var _cell_lock: Vector2 = Vector2.ZERO
var _size_we_wrote: Vector2 = Vector2.ZERO


func _init() -> void:
	theme_type_variation = "TaSlot"
	# A slot is a square: a VBox stretched it into a full-width bar.
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	_sync_cell_size()
	add_theme_constant_override(
		"icon_max_width",
		TaDefaults.SLOT_NATIVE_ICON_MAX_WIDTH
	)
	_icon_rect = TextureRect.new()
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := TaLook.metric(TaDefaults.CONTENT_MARGIN, TaDefaults.PIXEL_CONTENT_MARGIN)
	_icon_rect.offset_left = pad
	_icon_rect.offset_top = pad
	_icon_rect.offset_right = -pad
	_icon_rect.offset_bottom = -pad
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon_rect)
	_center_label = Label.new()
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center_label.visible = false
	add_child(_center_label)
	_caption_label = Label.new()
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption_label.theme_type_variation = "TaCaption"
	_caption_label.visible = false
	_caption_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_caption_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_caption_label)
	pressed.connect(_on_pressed)
	_apply_selected()
	_apply_badge()
	_sync_icon_rect()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"icon":
		_item_icon = value as Texture2D
		_sync_icon_rect()
		if is_instance_valid(_tooltip):
			_tooltip.icon = _item_icon
		return true
	return false


func _get(property: StringName) -> Variant:
	if property == &"icon":
		return _item_icon
	return null


func _ready() -> void:
	_sync_cell_size()
	TaJuice.bind_hover(self)
	_sync_tooltip()
	_sync_icon_rect()


func _notification(what: int) -> void:
	# Do not re-enter _apply_selected on THEME_CHANGED: adding overrides
	# emits THEME_CHANGED and would recurse until stack overflow.
	if what == NOTIFICATION_RESIZED:
		_sync_icon_rect()
		_place_badge()
	elif what == NOTIFICATION_THEME_CHANGED:
		_sync_cell_size()
		_apply_selected()


func set_caption(text: String) -> void:
	caption = text


## Emoji or stage mark drawn in the cell. Theme refresh does not remove it.
func set_center_text(text: String) -> void:
	_center_text = text
	_layout_caption()


## Keep this cell size across theme changes. Vector2.ZERO returns to 48 (20 in pixel).
func set_cell_size(size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		_cell_lock = Vector2.ZERO
	else:
		_cell_lock = size
	_sync_cell_size()


func refresh_metrics() -> void:
	_sync_cell_size()
	_layout_caption()
	_apply_selected()
	_sync_icon_rect()


func _layout_caption() -> void:
	var pad := TaLook.metric(TaDefaults.CONTENT_MARGIN, TaDefaults.PIXEL_CONTENT_MARGIN)
	var strip := 0
	if not caption.is_empty():
		var face := TaLook.metric(
				TaDefaults.FONT_SIZE_CAPTION, TaDefaults.PIXEL_FONT_SIZE_CAPTION
		)
		strip = face + 4
	if is_instance_valid(_caption_label):
		_caption_label.text = caption
		_caption_label.visible = not caption.is_empty()
		_caption_label.offset_left = 2
		_caption_label.offset_right = -2
		_caption_label.offset_bottom = -2
		_caption_label.offset_top = -strip
	if is_instance_valid(_center_label):
		_center_label.text = _center_text
		_center_label.visible = not _center_text.is_empty()
		_center_label.offset_left = pad
		_center_label.offset_top = pad
		_center_label.offset_right = -pad
		_center_label.offset_bottom = -(pad + strip)
	if is_instance_valid(_icon_rect):
		_icon_rect.offset_left = pad
		_icon_rect.offset_top = pad
		_icon_rect.offset_right = -pad
		_icon_rect.offset_bottom = -(pad + strip)


func _sync_cell_size() -> void:
	if _cell_lock == Vector2.ZERO and _size_we_wrote != Vector2.ZERO:
		var current := custom_minimum_size
		if current.x > 0.0 and current.y > 0.0 and current != _size_we_wrote:
			_cell_lock = current
	if _cell_lock != Vector2.ZERO:
		custom_minimum_size = _cell_lock
		_size_we_wrote = _cell_lock
		return
	var cell := TaLook.metric(TaDefaults.SLOT_SIZE, TaDefaults.PIXEL_SLOT_SIZE)
	custom_minimum_size = Vector2(cell, cell)
	_size_we_wrote = custom_minimum_size


func _on_pressed() -> void:
	slot_pressed.emit()


func _sync_icon_rect() -> void:
	if not is_instance_valid(_icon_rect):
		return
	_icon_rect.texture = _item_icon
	_icon_rect.visible = _item_icon != null


var _applying_selected: bool = false


func _apply_selected() -> void:
	if _applying_selected:
		return
	_applying_selected = true
	if selected:
		var pressed_box := get_theme_stylebox("pressed", theme_type_variation)
		if pressed_box:
			add_theme_stylebox_override("normal", pressed_box)
			add_theme_stylebox_override("hover", pressed_box)
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
	_applying_selected = false


func _apply_badge() -> void:
	if badge_text.is_empty():
		if is_instance_valid(_badge):
			_badge.visible = false
		return
	if not is_instance_valid(_badge):
		_badge = _Badge.new()
		# A plate of the look's ink: it reads on any slot (a cream count vanished on a
		# cream Modern slot).
		_badge.tone = TaBadge.Tone.COUNT
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Over whatever sits above the slot's top edge, which may draw after this one.
		_badge.z_index = 1
		_badge.minimum_size_changed.connect(_place_badge)
		add_child(_badge)
	_badge.text = badge_text
	_badge.visible = true
	_place_badge()


## The count sits in the slot's top-right corner, inside the slot's width, on its top
## frame: it reaches into the slot no further than the slot's padding, so it never covers
## the icon, and rises over the top edge by the rest (count_room). 2.2 hung a two-digit
## count past the slot's side, onto the next slot. Whole art pixels on pixel looks.
func _place_badge() -> void:
	if not is_instance_valid(_badge) or not _badge.visible:
		return
	var b := _badge.get_combined_minimum_size()
	_badge.size = b
	var at := Vector2(size.x - b.x, minf(0.0, _icon_rect.offset_top - b.y))
	var art := float(TaLook.scale())
	_badge.position = (at / art).round() * art


## How far a count rises over the top edge of a slot under `control`'s theme, plus air:
## the gap a row of slots above needs. TaSlotGrid keeps it between rows; keep it in a
## grid of your own. 0 off-tree.
static func count_room(control: Control) -> int:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return 0
	var type_name := &"TaBadgeCount"
	var font := control.get_theme_font("font", type_name)
	var plate := control.get_theme_stylebox("panel", type_name)
	if font == null or plate == null:
		return 0
	var tall := font.get_height(control.get_theme_font_size("font_size", type_name))
	tall += plate.get_minimum_size().y
	var pad := TaLook.metric(TaDefaults.CONTENT_MARGIN, TaDefaults.PIXEL_CONTENT_MARGIN)
	var air := TaLook.metric(TaDefaults.COUNT_MARGIN, TaDefaults.PIXEL_COUNT_MARGIN)
	return maxi(0, ceili(tall) - pad) + air


func _sync_tooltip() -> void:
	if tooltip_title.is_empty() and tooltip_body.is_empty():
		# Detach: a hidden tooltip still answered the next hover with an empty box.
		if is_instance_valid(_tooltip):
			_tooltip.queue_free()
		_tooltip = null
		return
	if not is_instance_valid(_tooltip):
		_tooltip = _Tooltip.new()
		add_child(_tooltip)
		_tooltip.attach(self)
	_tooltip.title = tooltip_title
	_tooltip.body = tooltip_body
	_tooltip.icon = _item_icon
