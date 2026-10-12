class_name TaInfoPopup
extends PopupPanel

# AGENT: Non-modal info bubble. Component layer.
# INVARIANT: popup_message shows copy. Not a confirm dialog.
# DO NOT: Nested CK3 tooltips. Do not autoload.

## Short info popup. Use show_dialog on TaDialog for confirm/cancel.

var _label: Label


func _init() -> void:
	theme_type_variation = "TaInfoPopup"
	unresizable = true
	exclusive = false
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)
	refresh_metrics()


func refresh_metrics() -> void:
	if is_instance_valid(_label):
		_label.custom_minimum_size.x = _width()


func popup_message(text: String, anchor: Control = null) -> void:
	_label.text = text
	if is_instance_valid(anchor) and anchor.is_inside_tree():
		# Screen space, as OptionButton places its popup: global_position is canvas
		# space and drifts from popup coordinates under canvas_items stretch.
		var at := anchor.get_screen_transform() * Vector2(0.0, anchor.size.y)
		var host := anchor.get_viewport() as Window
		if host != null and not host.gui_embed_subwindows:
			at += Vector2(host.position)
		popup(Rect2i(Vector2i(at), Vector2i(_width(), 0)))
	else:
		popup_centered()


func _width() -> int:
	return TaLook.metric(TaDefaults.TOOLTIP_MAX_WIDTH, TaDefaults.PIXEL_TOOLTIP_MAX_WIDTH)
