class_name TaFloater
extends Label

# AGENT: Pickup / combo / damage floater. Rises and fades. pop() on the HUD canvas;
# pop_world() over a 3D object, carried by a TaWorldAttach (the same Label).
# INVARIANT: pop() parents to host, then leaves. Reduced motion keeps the
# text on screen for the same hold instead of freeing it immediately.
# DO NOT: Draw in 3D itself (TaWorldAttach does). Do not autoload.

## "+12 gold" or combo number on the HUD canvas, or "-12" over an enemy (pop_world).

static func pop(host: Control, text: String, at: Vector2 = Vector2.ZERO) -> void:
	if host == null:
		return
	var floater = load("res://addons/theme_assist/src/components/hud/ta_floater.gd").new()
	floater.text = text
	floater.theme_type_variation = "TaSceneSuccess"
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floater.position = at
	host.add_child(floater)
	if floater.has_method("_rise"):
		floater._rise()


func _rise() -> void:
	if TaJuice.is_reduced():
		modulate.a = 1.0
		var hold := maxf(TaJuice.open_seconds * 2.0, TaDefaults.MOTION_OPEN_SECONDS)
		get_tree().create_timer(hold).timeout.connect(queue_free)
		return
	var tween := create_tween()
	tween.set_parallel(true)
	var rise := position.y - TaDefaults.FLOATER_RISE
	tween.tween_property(self, "position:y", rise, TaJuice.open_seconds * 2.0)
	tween.tween_property(self, "modulate:a", 0.0, TaJuice.open_seconds * 2.0)
	tween.chain().tween_callback(queue_free)


## "-12" over a 3D object: the floater rides a TaWorldAttach on the HUD canvas (crisp at
## any distance), rises `rise` meters, fades, and removes itself. Returns the attach.
static func pop_world(
		over: Node3D, text: String, rise: float = TaDefaults.FLOATER_WORLD_RISE
	) -> TaWorldAttach:
	if not is_instance_valid(over) or not over.is_inside_tree():
		return null
	var attach := TaWorldAttach.new()
	attach.mode = TaWorldAttach.Mode.SCREEN
	over.add_child(attach)
	var floater: Label = load("res://addons/theme_assist/src/components/hud/ta_floater.gd").new()
	floater.text = text
	floater.theme_type_variation = "TaSceneSuccess"
	floater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach.add_content(floater)
	var hold := maxf(TaJuice.open_seconds * 2.0, TaDefaults.MOTION_OPEN_SECONDS)
	if TaJuice.is_reduced():
		attach.get_tree().create_timer(hold).timeout.connect(attach.queue_free)
		return attach
	var tween := attach.create_tween()
	tween.set_parallel(true)
	tween.tween_property(attach, "position:y", attach.position.y + rise, hold)
	tween.tween_property(floater, "modulate:a", 0.0, hold)
	tween.chain().tween_callback(attach.queue_free)
	return attach
