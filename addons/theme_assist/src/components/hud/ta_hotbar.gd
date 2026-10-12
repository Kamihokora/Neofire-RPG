class_name TaHotbar
extends HBoxContainer

# AGENT: Numbered slot row. Display only; no ability backend.
# INVARIANT: slot_count TaSlots with 1–N captions. Canvas HUD.
# DO NOT: Own cooldowns or inventory.

## Hotbar. get_slot(i) is a TaSlot. Captions are 1..N.

const _Slot := preload("res://addons/theme_assist/src/components/slot/ta_slot.gd")

@export var slot_count: int = TaDefaults.HOTBAR_SLOTS:
	set(value):
		slot_count = maxi(1, value)
		_rebuild()


func _init() -> void:
	theme_type_variation = "TaHotbar"
	_rebuild()


func paint_demo_icons() -> void:
	var look := TaLook.current()
	var colors: Array[Color] = [
		look.color_accent, look.color_success, look.color_warning, look.color_danger
	]
	for i in mini(slot_count, colors.size()):
		var slot := get_slot(i)
		if slot != null:
			slot.icon = _swatch(colors[i])


func get_slot(index: int) -> TaSlot:
	if index < 0 or index >= get_child_count():
		return null
	var wrap := get_child(index)
	if wrap.get_child_count() < 1:
		return null
	return wrap.get_child(0) as TaSlot


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for i in slot_count:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", TaLook.metric(2, 1))
		var slot = _Slot.new()
		col.add_child(slot)
		var cap := Label.new()
		cap.text = str(i + 1)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.theme_type_variation = "TaCaption"
		col.add_child(cap)
		add_child(col)
	var slots: Array = []
	for i in slot_count:
		slots.append(get_slot(i))
	TaFocus.wrap(slots, TaFocus.Axis.HORIZONTAL)


func _swatch(fill: Color) -> Texture2D:
	var size := TaDefaults.SWATCH_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return ImageTexture.create_from_image(img)
