class_name TaSpeechBubble
extends PanelContainer

# AGENT: Pointed dialogue panel. Canvas only; not a dialogue system.
# INVARIANT: set_text writes the body. Tail is chrome.
# DO NOT: Own trees or VO.

## Speech / phone pitch bubble.

var _col: VBoxContainer
var _body: Label


func _init() -> void:
	theme_type_variation = "TaSpeechBubble"
	_col = VBoxContainer.new()
	add_child(_col)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_body)
	refresh_metrics()


## An autowrap Label with no width collapses to one letter per line inside a row, so
## the body gets a width: its words on one line, wrapping at the tooltip width.
func refresh_metrics() -> void:
	if is_instance_valid(_body):
		var cap := TaLook.metric(TaDefaults.TOOLTIP_MAX_WIDTH, TaDefaults.PIXEL_TOOLTIP_MAX_WIDTH)
		_body.custom_minimum_size.x = TaItemTooltip.fit_width(_body, cap)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		# The body takes its font after this node hears the change: measure afterwards.
		call_deferred("refresh_metrics")


func set_text(text: String) -> void:
	_body.text = text
	refresh_metrics()


func get_body() -> Label:
	return _body
