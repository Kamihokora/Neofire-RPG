@tool
extends MarginContainer

# AGENT: Editor gallery dock. Previews looks, saves one as the project theme, instances
# addon prefabs.
# INVARIANT: Plugin _exit_tree removes this dock. Paths stay inside the addon. Save is
# TaLook.save (the playground's Save); the plugin then points the project theme at it.
# DO NOT: Load res://demo. Do not autoload.

const _SLICE := "res://addons/theme_assist/src/editor/ta_pause_slice.gd"
const _PAUSE := "res://addons/theme_assist/scenes/pause.tscn"
const _HUD := "res://addons/theme_assist/scenes/hud.tscn"
const _PLAYGROUND := "res://addons/theme_assist/playground/playground.tscn"

var _slice: Control
var _look: TaTokens
var _accent: ColorPickerButton
var _radius: SpinBox
var _status: Label


func _ready() -> void:
	if get_child_count() > 0:
		return
	name = "Theme Assist"
	custom_minimum_size = Vector2(240, 360)
	add_theme_constant_override("margin_left", 8)
	add_theme_constant_override("margin_top", 8)
	add_theme_constant_override("margin_right", 8)
	add_theme_constant_override("margin_bottom", 8)
	_build()


func _build() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	add_child(col)
	var title := Label.new()
	title.text = "Theme Assist"
	col.add_child(title)
	var hint := Label.new()
	hint.text = "Pick a look, Save, and every kit component in the project wears it."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	var looks := HBoxContainer.new()
	looks.add_theme_constant_override("separation", 4)
	col.add_child(looks)
	for id in TaDefaults.PRESETS:
		var btn := Button.new()
		btn.text = String(id).capitalize()
		var preset_id := String(id)
		btn.pressed.connect(func() -> void: _apply_look(TaTokens.preset(preset_id)))
		looks.add_child(btn)
	var knobs := HBoxContainer.new()
	knobs.add_theme_constant_override("separation", 6)
	col.add_child(knobs)
	var accent_l := Label.new()
	accent_l.text = "Accent"
	knobs.add_child(accent_l)
	_accent = ColorPickerButton.new()
	_accent.custom_minimum_size = Vector2(48, 24)
	_accent.color_changed.connect(_on_accent)
	knobs.add_child(_accent)
	var rad_l := Label.new()
	rad_l.text = "Radius"
	knobs.add_child(rad_l)
	_radius = SpinBox.new()
	_radius.min_value = 0
	_radius.max_value = 16
	_radius.value_changed.connect(_on_radius)
	knobs.add_child(_radius)
	var script := load(_SLICE) as Script
	if script != null:
		_slice = script.new() as Control
		_slice.custom_minimum_size.y = 160
		col.add_child(_slice)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	col.add_child(save_row)
	var save_btn := Button.new()
	save_btn.text = "Save to project"
	save_btn.tooltip_text = "Writes %s and %s" % [TaLook.look_path(), TaLook.theme_path()]
	save_btn.pressed.connect(_on_save)
	save_row.add_child(save_btn)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	save_row.add_child(_status)
	var play_btn := Button.new()
	play_btn.text = "Open playground"
	play_btn.pressed.connect(_on_open_playground)
	col.add_child(play_btn)
	var tokens_hint := Label.new()
	tokens_hint.text = "F6 the playground for every knob, every component, and its own Save."
	tokens_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tokens_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	col.add_child(row)
	var pause_btn := Button.new()
	pause_btn.text = "Instance pause"
	pause_btn.pressed.connect(func() -> void: _on_instance(_PAUSE))
	row.add_child(pause_btn)
	var hud_btn := Button.new()
	hud_btn.text = "Instance HUD"
	hud_btn.pressed.connect(func() -> void: _on_instance(_HUD))
	row.add_child(hud_btn)
	_apply_look(TaLook.load_saved() if TaLook.has_saved() else TaTokens.new())


func _apply_look(tokens: TaTokens) -> void:
	_look = tokens
	if is_instance_valid(_accent):
		_accent.color = tokens.color_accent
	if is_instance_valid(_radius):
		_radius.set_value_no_signal(tokens.radius)
	if is_instance_valid(_slice):
		TaThemeBuilder.apply_to(_slice, tokens, false)
	if is_instance_valid(_status):
		_status.text = ""


func _on_accent(color: Color) -> void:
	if _look == null:
		return
	_look.color_accent = color
	_apply_look(_look)


func _on_radius(value: float) -> void:
	if _look == null:
		return
	_look.radius = int(value)
	_apply_look(_look)


func _on_save() -> void:
	if _look == null:
		return
	var err := TaLook.save(_look)
	_status.text = "Saved" if err == OK else "Save failed (%s)" % error_string(err)
	if err == OK and Engine.is_editor_hint():
		# The scan fires filesystem_changed; the plugin then sets the project theme.
		EditorInterface.get_resource_filesystem().scan()


func _on_open_playground() -> void:
	if not Engine.is_editor_hint():
		return
	EditorInterface.open_scene_from_path(_PLAYGROUND)


func _on_instance(path: String) -> void:
	if not Engine.is_editor_hint():
		return
	var packed := load(path) as PackedScene
	if packed == null:
		push_warning("Theme Assist: missing %s" % path)
		return
	var edited := EditorInterface.get_edited_scene_root()
	if edited == null:
		push_warning("Theme Assist: open a scene first")
		return
	var node := packed.instantiate() as Node
	edited.add_child(node, true)
	node.owner = edited
	# Leave pause hidden (it is the Esc overlay) and leave its Theme alone: a Theme
	# assigned here was saved into your scene and beat your root look at runtime.
	# Toggle the eye icon to preview it.
	EditorInterface.edit_node(node)
