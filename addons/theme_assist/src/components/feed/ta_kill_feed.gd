class_name TaKillFeed
extends VBoxContainer

# AGENT: Combat feed strip. Not TaToastHost (that is top-right notices).
# INVARIANT: push_line queues; extras wait. Canvas HUD only.
# DO NOT: Autoload. Do not own kill tracking.

## Fading combat lines. Place top-left so it does not collide with toasts.

const _Toast := preload("res://addons/theme_assist/src/components/toast/ta_toast.gd")

var _pending: PackedStringArray = PackedStringArray()
var _pending_tone: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	theme_type_variation = "TaKillFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push_line(text: String, tone: TaBadge.Tone = TaBadge.Tone.DEFAULT) -> void:
	if _line_count() >= TaDefaults.KILLFEED_MAX:
		_pending.append(text)
		_pending_tone.append(int(tone))
		return
	_spawn(text, tone)


func _spawn(text: String, tone: TaBadge.Tone) -> void:
	var row = _Toast.new()
	row.text = text
	row.tone = tone
	# Combat lines are read, not clicked. A toast row eats clicks and dismisses on click.
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.dismissed.connect(_on_dismissed, CONNECT_ONE_SHOT)
	add_child(row)
	row.present(TaDefaults.KILLFEED_HOLD_SECONDS)


func _line_count() -> int:
	var n := 0
	for child in get_children():
		if child is TaToast:
			n += 1
	return n


func _on_dismissed() -> void:
	call_deferred("_drain")


func _drain() -> void:
	while not _pending.is_empty() and _line_count() < TaDefaults.KILLFEED_MAX:
		var text := _pending[0]
		var tone := _pending_tone[0] as TaBadge.Tone
		_pending.remove_at(0)
		_pending_tone.remove_at(0)
		_spawn(text, tone)
