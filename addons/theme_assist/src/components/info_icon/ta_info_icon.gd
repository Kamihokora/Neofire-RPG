class_name TaInfoIcon
extends TaButton

# AGENT: Compact [i] control. Hover tooltip; click opens TaInfoPopup.
# INVARIANT: popup_message uses body (or title). Does not persist.
# DO NOT: Nested CK3 tooltips. Do not autoload.

## [i] info control. Hover for tooltip; click for TaInfoPopup.

signal info_pressed

@export var title: String = "":
	set(value):
		title = value
		_sync_tip()

@export var body: String = "":
	set(value):
		body = value
		_sync_tip()

var _popup: TaInfoPopup
var _tip: TaItemTooltip


func _init() -> void:
	theme_type_variation = "TaInfoIcon"
	text = "i"
	flat = false
	focus_mode = Control.FOCUS_ALL
	refresh_metrics()


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	TaJuice.bind_hover(self)
	_sync_tip()


func refresh_metrics() -> void:
	var cell := TaLook.metric(TaDefaults.INFO_ICON_SIZE, TaDefaults.PIXEL_INFO_ICON_SIZE)
	custom_minimum_size = Vector2(cell, cell)


func _on_pressed() -> void:
	info_pressed.emit()
	var copy := body if not body.is_empty() else title
	if copy.is_empty():
		return
	if not is_instance_valid(_popup):
		_popup = TaInfoPopup.new()
		add_child(_popup)
	_popup.popup_message(copy, self)


func _sync_tip() -> void:
	# TaItemTooltip is the tooltip. A native tooltip_text too showed two boxes on hover.
	tooltip_text = ""
	if title.is_empty() and body.is_empty():
		# Detach, or the last text kept showing on hover.
		if is_instance_valid(_tip):
			_tip.queue_free()
		_tip = null
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(_tip):
		_tip = TaItemTooltip.new()
		_tip.attach(self)
	_tip.title = title if not title.is_empty() else "Info"
	_tip.body = body
