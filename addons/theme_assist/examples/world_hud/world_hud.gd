extends Node3D

# AGENT: In-world HUD example. Crates in a 3D scene wear TaBar nameplates (TaWorldAttach)
# while the canvas strip (scenes/hud.tscn) shows the same TaBar. Not a game.
# INVARIANT: Both halves wear the active look; 1-4 switch preset and both follow.
# Headless prints WORLD_HUD_OK.
# DO NOT: Add gameplay. Load res://demo.

const _HUD := "res://addons/theme_assist/scenes/hud.tscn"

var _canvas: Control
var _crates: Array[MeshInstance3D] = []


func _ready() -> void:
	_build_world()
	var layer := CanvasLayer.new()
	add_child(layer)
	_canvas = Control.new()
	_canvas.name = "Ui"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_canvas)
	# The look you saved in the playground (Flat until you Save one).
	TaLook.apply_saved(_canvas)
	var strip := (load(_HUD) as PackedScene).instantiate() as Control
	_canvas.add_child(strip)
	var hint := Label.new()
	hint.text = "1 Flat   2 Modern   3 Framed   4 Pixel"
	hint.theme_type_variation = "TaCaption"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position.y -= 32
	hint.position.x += 16
	_canvas.add_child(hint)
	if DisplayServer.get_name() == "headless":
		print("WORLD_HUD_OK")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := key.keycode - KEY_1
	if index >= 0 and index < TaLook.IDS.size():
		# One call: the canvas re-themes and every TaWorldAttach follows the bound look.
		TaThemeBuilder.apply_to(_canvas, TaTokens.preset(TaLook.IDS[index]))


func get_canvas() -> Control:
	return _canvas


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var camera := Camera3D.new()
	camera.environment = env
	camera.position = Vector3(0.0, 2.4, 6.5)
	camera.rotation_degrees = Vector3(-14.0, 0.0, 0.0)
	add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	ground.mesh = plane
	ground.material_override = _matte(Color(0.3, 0.4, 0.26))
	add_child(ground)
	for i in 3:
		var crate := MeshInstance3D.new()
		crate.name = "Crate%d" % (i + 1)
		crate.mesh = BoxMesh.new()
		# Apart enough that nameplates with room for their value do not overlap.
		crate.position = Vector3(-3.6 + i * 3.6, 0.5, -i * 0.8)
		crate.rotation_degrees = Vector3(0.0, 20.0 * i, 0.0)
		crate.material_override = _matte(Color(0.55, 0.38, 0.22))
		add_child(crate)
		_crates.append(crate)
		var plate := TaWorldAttach.new()
		plate.name = "Nameplate"
		plate.position = Vector3(0.0, 0.9, 0.0)
		plate.max_distance = 30.0
		crate.add_child(plate)
		# The name over the bar, not beside it: the plate is as narrow as the bar, so plates
		# side by side do not overlap (an inline caption made Crate 3 clip to "ate 3"). The
		# name sits on a tag, a surface of its own: small light type with only an outline
		# was lost on a mid-blue sky.
		var tag := TaTag.new()
		tag.text = "Crate %d" % (i + 1)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		plate.add_content(tag)
		# The bar sizes itself so its value sits wholly in the fill or the track.
		var hp := TaBar.new()
		hp.set_range(100 - i * 30, 100)
		plate.add_content(hp)
	# The same component pinned to the canvas over a 3D point instead.
	var pin := TaWorldAttach.new()
	pin.name = "LootLabel"
	pin.mode = TaWorldAttach.Mode.SCREEN
	pin.position = Vector3(2.6, 0.4, 1.2)
	add_child(pin)
	var loot := TaChip.new()
	loot.set_caption("Loot")
	loot.set_text("12 gold")
	pin.add_content(loot)


func get_crates() -> Array[MeshInstance3D]:
	return _crates


func _matte(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat
