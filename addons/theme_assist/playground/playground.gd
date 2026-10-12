extends Control

# AGENT: Official in-addon playground. Tabs + live tokens + every Control and Ta*.
# Opens on your saved look (Flat the first time); Save writes it into the project.
# INVARIANT: Headless prints PLAYGROUND_OK. missing_registry_types() is empty. Switching
# preset rebuilds the Theme only: the same nodes stay instanced.
# DO NOT: Load res://demo. Do not TaLook.apply Pixel framebuffer (gallery is HD).

const _TokensPanel := preload("res://addons/theme_assist/playground/playground_tokens.gd")
const _Stock := preload("res://addons/theme_assist/playground/playground_stock.gd")
const _Composites := preload("res://addons/theme_assist/playground/playground_composites.gd")
const _Coverage := preload("res://addons/theme_assist/playground/playground_coverage.gd")
const _Fanfare := preload("res://addons/theme_assist/playground/playground_fanfare.gd")
const _Kit := preload("res://addons/theme_assist/playground/playground_kit.gd")
const _Showcase := preload("res://addons/theme_assist/playground/playground_showcase.gd")
const _Hud := preload("res://addons/theme_assist/playground/playground_hud.gd")
const _Recipes := preload("res://addons/theme_assist/playground/playground_recipes.gd")
const _Registry := preload("res://addons/theme_assist/src/core/ta_registry.gd")
const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _PAUSE := "res://addons/theme_assist/scenes/pause.tscn"

var _live: TaTokens
var _bg: ColorRect
var _tokens: Control
var _stock: Control
var _composites: Control
var _coverage: Control
var _hud: Control
var _recipes: Control
var _fanfare: Control
var _kit: Control
var _showcase: Control
## The playground's own controls (preset bar, token panel) keep Flat, so the tool stays
## usable in every look; only the preview wears the live look.
var _tool_theme: Theme
var _tabs: TabContainer
var _toast_host: TaToastHost
var _dialog: TaDialog
var _info: TaInfoPopup
var _pause: Control
var _shown: Dictionary = {}
var _score: Label
var _meter: Label
var _accent: ColorPickerButton
var _status: Label
var _dirty: bool = false
## Where the last Save or Revert pointed (empty is the project folder); dirty compares to it.
var _saved_dir: String = ""


func _ready() -> void:
	add_to_group("ta_playground")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	# Load applies the saved look; the first open (nothing saved) is Flat.
	_live = TaLook.load_saved()
	if _live == null:
		_live = TaTokens.new()
	_build()
	_apply_live()
	TaJuice.bind_tree(self)
	_print_smoke_if_headless()


func apply_preset(id: String) -> void:
	_set_look(TaTokens.preset(id))
	_refresh_dirty()


## Save the live look and its Theme into the project (TaLook.save). Returns the error.
func save_look(dir: String = "") -> Error:
	var err := TaLook.save(_live, dir)
	if err == OK:
		_saved_dir = dir
		_mark_dirty(false)
		var where := TaLook.look_path(dir).get_base_dir()
		_toast("Saved to %s. The editor sets it as the project theme." % where)
	else:
		_toast("Save failed: %s" % error_string(err))
	return err


## Go back to the saved look (Flat if nothing is saved).
func revert_look(dir: String = "") -> void:
	_saved_dir = dir
	var saved := TaLook.load_saved(dir)
	_set_look(saved if saved != null else TaTokens.new())
	_mark_dirty(false)


func is_dirty() -> bool:
	return _dirty


func _set_look(look: TaTokens) -> void:
	_live = look
	if is_instance_valid(_tokens) and _tokens.has_method("bind"):
		_tokens.bind(_live)
	if is_instance_valid(_accent):
		_accent.color = _live.color_accent
	_apply_live()


## Unsaved means the live look differs from the saved one (Flat when nothing is saved),
## so re-picking the preset you already wear is not a change.
func _refresh_dirty() -> void:
	var saved := TaLook.load_saved(_saved_dir)
	_mark_dirty(not TaLook.same(_live, saved if saved != null else TaTokens.new()))


## The status names what the project wears, so a preset picked over a saved look reads
## as a choice not yet saved, not as an error ("Unsaved changes" on a fresh Framed pick
## read as if the pick itself were wrong).
func _mark_dirty(on: bool) -> void:
	_dirty = on
	if not is_instance_valid(_status):
		return
	var wearing := _wearing(TaLook.load_saved(_saved_dir))
	if on:
		_status.text = "Not saved (project: %s)" % wearing
	elif TaLook.has_saved(_saved_dir):
		_status.text = "Saved (project: %s)" % wearing
	else:
		_status.text = "Factory Flat"


## The saved look by name: a preset it equals, else "your look"; Flat when none.
static func _wearing(saved: TaTokens) -> String:
	if saved == null:
		return "Flat"
	for id in TaDefaults.PRESETS:
		if TaLook.same(saved, TaTokens.preset(id)):
			return String(id).capitalize()
	return "your look"


func _toast(text: String) -> void:
	if is_instance_valid(_toast_host):
		_toast_host.show_message(text)


func mark_registry_type(type_name: String) -> void:
	_shown[type_name] = true
	_refresh_meter()


func missing_registry_types() -> PackedStringArray:
	var missing := PackedStringArray()
	for type_name in _Registry.type_names():
		if not _shown.has(String(type_name)):
			missing.append(String(type_name))
	return missing


func get_toast_host() -> TaToastHost:
	return _toast_host


func get_look() -> TaTokens:
	return _live


func filter_gallery(query: String) -> void:
	_UI.apply_filter(_showcase, query)
	_UI.apply_filter(_kit, query)
	_UI.apply_filter(_stock, query)
	_UI.apply_filter(_composites, query)
	_UI.apply_filter(_coverage, query)
	_UI.apply_filter(_hud, query)
	_UI.apply_filter(_recipes, query)
	_UI.apply_filter(_fanfare, query)


func visible_cell_count() -> int:
	return (
			_UI.count_visible_cells(_kit)
			+ _UI.count_visible_cells(_stock)
			+ _UI.count_visible_cells(_composites)
			+ _UI.count_visible_cells(_coverage)
			+ _UI.count_visible_cells(_hud)
	)


func copy_recipe(text: String) -> void:
	if text.is_empty():
		return
	DisplayServer.clipboard_set(text)
	if is_instance_valid(_toast_host):
		_toast_host.show_message("Copied recipe")


func copy_snippet(text: String) -> void:
	if text.is_empty():
		return
	var blob := text
	if _live != null:
		blob += "\n# look.color_accent = Color(%s, %s, %s)" % [
			_live.color_accent.r, _live.color_accent.g, _live.color_accent.b
		]
		blob += "\n# Save in the playground, or: TaThemeBuilder.apply_to(self, look)"
	DisplayServer.clipboard_set(blob)
	if is_instance_valid(_toast_host):
		_toast_host.show_message("Copied snippet")


func show_sfx_toast(sfx_name: String) -> void:
	if is_instance_valid(_toast_host):
		_toast_host.show_message("SFX: %s" % sfx_name)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	var root := HBoxContainer.new()
	# A page margin: the preset bar and token panel sat on the window edge.
	root.name = "Page"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(main)
	# The playground's own controls wear Flat in every look, sized for this display; refit
	# rebuilds them with the rest when the window crosses a scale step.
	var tool_look := TaTokens.new()
	_tool_theme = TaThemeBuilder.make(tool_look)
	var bar := PanelContainer.new()
	bar.name = "ToolBar"
	bar.theme = _tool_theme
	TaLook.track_paint(bar, tool_look)
	bar.add_child(_preset_bar())
	main.add_child(bar)
	_tabs = TabContainer.new()
	_tabs.name = "PlaygroundTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(_tabs)
	_showcase = _Showcase.new()
	_showcase.name = "Showcase"
	if _showcase.has_method("setup"):
		_showcase.setup(self)
	_add_tab("Showcase", _showcase)
	_kit = _Kit.new()
	_kit.name = "Kit"
	if _kit.has_method("setup"):
		_kit.setup(self)
	_add_tab("Kit", _kit)
	_stock = _Stock.new()
	_stock.name = "Stock"
	_add_tab("Stock", _stock)
	_composites = _Composites.new()
	_composites.name = "Composites"
	if _composites.has_method("setup"):
		_composites.setup(self)
	_add_tab("Composites", _composites)
	_coverage = _Coverage.new()
	_coverage.name = "Coverage"
	if _coverage.has_method("setup"):
		_coverage.setup(self)
	_add_tab("Coverage", _coverage)
	_hud = _Hud.new()
	_hud.name = "Hud"
	if _hud.has_method("setup"):
		_hud.setup(self)
	_add_tab("HUD", _hud)
	_recipes = _Recipes.new()
	_recipes.name = "Recipes"
	if _recipes.has_method("setup"):
		_recipes.setup(self)
	_add_tab("Recipes", _recipes)
	_score = Label.new()
	_score.name = "FanfareScore"
	_score.text = "0"
	_score.theme_type_variation = "TaTitle"
	_fanfare = _Fanfare.new()
	_fanfare.name = "Fanfare"
	_fanfare.set_meta("ta_cell", true)
	_fanfare.set_meta("ta_filter", "fanfare juice sfx transition punch shake")
	if _fanfare.has_method("setup"):
		_fanfare.setup(self, _score)
	_add_tab("Fanfare", _fanfare)
	_tokens = _TokensPanel.new()
	_tokens.name = "Tokens"
	if _tokens.has_method("bind"):
		_tokens.bind(_live)
	if _tokens.has_signal("tokens_changed"):
		_tokens.tokens_changed.connect(_on_tokens_changed)
	var side := PanelContainer.new()
	side.name = "ToolPanel"
	side.theme = _tool_theme
	TaLook.track_paint(side, tool_look)
	side.add_child(_tokens)
	root.add_child(side)
	_mount_overlays()
	_refresh_meter()
	_mark_dirty(false)
	_tabs.tab_changed.connect(_on_tab_changed)
	if DisplayServer.get_name() == "headless" and is_instance_valid(_hud):
		if _hud.has_method("run_demo"):
			_hud.run_demo()


## The page margin on this display (TaLook.refresh_tree calls this after a refit).
func refresh_metrics() -> void:
	var page := get_node_or_null("Page") as Control
	if page == null:
		return
	var m := _UI.ui(TaDefaults.SEPARATION)
	page.offset_left = m
	page.offset_top = m
	page.offset_right = -m
	page.offset_bottom = -m
	if is_instance_valid(_accent):
		_accent.custom_minimum_size = Vector2(_UI.ui(48), _UI.ui(24))
	if is_instance_valid(_tabs):
		_sync_min_heights(_tabs)


func _preset_bar() -> VBoxContainer:
	var col := VBoxContainer.new()
	var line := Label.new()
	line.text = (
			"Pick a preset, tune it on the right, Save. "
			+ "Every kit component in your project wears it."
	)
	line.theme_type_variation = "TaCaption"
	col.add_child(line)
	var row := HBoxContainer.new()
	col.add_child(row)
	var title := Label.new()
	title.text = "Preset"
	title.theme_type_variation = "TaTitle"
	row.add_child(title)
	for id in TaDefaults.PRESETS:
		var button := Button.new()
		button.name = "Preset%s" % String(id).capitalize()
		button.text = String(id).capitalize()
		var look_id := String(id)
		button.pressed.connect(func() -> void: _switch_preset(look_id))
		row.add_child(button)
	var save := Button.new()
	save.name = "SaveLook"
	save.text = "Save"
	save.theme_type_variation = "TaPrimary"
	save.tooltip_text = "Write this look and its Theme to %s" % TaLook.save_dir
	save.pressed.connect(func() -> void: save_look())
	row.add_child(save)
	var revert := Button.new()
	revert.name = "RevertLook"
	revert.text = "Revert"
	revert.tooltip_text = "Back to the saved look"
	revert.pressed.connect(func() -> void: revert_look())
	row.add_child(revert)
	_status = Label.new()
	_status.name = "SaveStatus"
	_status.theme_type_variation = "TaCaption"
	row.add_child(_status)
	var accent_l := Label.new()
	accent_l.text = "Accent"
	row.add_child(accent_l)
	_accent = ColorPickerButton.new()
	_accent.name = "AccentPicker"
	_accent.custom_minimum_size = Vector2(_UI.ui(48), _UI.ui(24))
	_accent.color_changed.connect(_on_accent)
	row.add_child(_accent)
	var motion := CheckBox.new()
	motion.name = "ReduceMotion"
	motion.text = "Reduce motion"
	motion.toggled.connect(_on_motion)
	row.add_child(motion)
	_meter = Label.new()
	_meter.name = "CoverageMeter"
	_meter.theme_type_variation = "TaCaption"
	row.add_child(_meter)
	var search := LineEdit.new()
	search.name = "PlaygroundFilter"
	search.placeholder_text = "Filter controls…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(filter_gallery)
	row.add_child(search)
	return col


func _on_tab_changed(idx: int) -> void:
	if _tabs.get_tab_title(idx) == "HUD" and is_instance_valid(_hud):
		if _hud.has_method("run_demo"):
			_hud.run_demo()


func _add_tab(title: String, inner: Control) -> void:
	var scroll := _scroll(inner)
	scroll.name = "%sTab" % title
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)


func _scroll(inner: Control) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	return scroll


func _mount_overlays() -> void:
	# Esc goes to the top open overlay, then the pause drop-in (router fallback).
	var router := TaCancelRouter.new()
	router.name = "TaCancelRouter"
	add_child(router)
	mark_registry_type("TaCancelRouter")
	_toast_host = TaToastHost.new()
	_toast_host.name = "TaToastHost"
	add_child(_toast_host)
	mark_registry_type("TaToastHost")
	_dialog = TaDialog.new()
	_dialog.name = "TaDialog"
	_dialog.title = "Apply this look?"
	_dialog.body = "Theme Assist will retint this playground. Confirm or cancel."
	add_child(_dialog)
	mark_registry_type("TaDialog")
	var modal := TaModal.new()
	modal.name = "TaModal"
	modal.title = "Day complete"
	modal.body = "The grove is quiet."
	add_child(modal)
	mark_registry_type("TaModal")
	_info = TaInfoPopup.new()
	_info.name = "TaInfoPopup"
	add_child(_info)
	mark_registry_type("TaInfoPopup")
	var wipe := TaTransition.on(self)
	if wipe != null:
		mark_registry_type("TaTransition")
	var packed := load(_PAUSE) as PackedScene
	if packed != null:
		_pause = packed.instantiate() as Control
		_pause.name = "PauseOverlay"
		_pause.visible = false
		_pause.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pause)
		if _pause.has_signal("resume_pressed"):
			_pause.resume_pressed.connect(_on_resume)
		if _pause.has_signal("quit_pressed"):
			_pause.quit_pressed.connect(_on_quit)


func _switch_preset(id: String) -> void:
	var wipe := TaTransition.on(self)
	if wipe != null:
		wipe.fade_through(func() -> void: apply_preset(id))
	else:
		apply_preset(id)


func _apply_live() -> void:
	if _live == null:
		return
	TaThemeBuilder.apply_to(self, _live, false)
	if is_instance_valid(_bg):
		_bg.color = _live.color_bg
	if is_instance_valid(_accent):
		_accent.color = _live.color_accent
	_sync_min_heights(_tabs)


func _sync_min_heights(node: Node) -> void:
	# Slots and info icons keep their square; a tag's dismiss glyph stays as tall as its text.
	var button := node as Button
	var sized := button is TaSlot or button is TaInfoIcon
	if button != null and not sized and button.theme_type_variation != &"TaTagClose":
		button.custom_minimum_size.y = TaLook.button_height()
	for child in node.get_children():
		_sync_min_heights(child)


func _on_accent(color: Color) -> void:
	if _live == null:
		return
	_live.color_accent = color
	if is_instance_valid(_tokens) and _tokens.has_method("bind"):
		_tokens.bind(_live)
	_apply_live()
	_refresh_dirty()


func _on_tokens_changed() -> void:
	_apply_live()
	_refresh_dirty()


func _on_motion(pressed: bool) -> void:
	TaJuice.reduced_motion = pressed
	TaJuice.snap_tree(self)
	if _live != null:
		TaCrtOverlay.sync_on(self, _live.crt_intensity > 0.0, _live.crt_intensity)
	if is_instance_valid(_toast_host):
		var msg := "Reduced motion: juice and SFX skipped" if pressed else "Motion on"
		_toast_host.show_message(msg)


func _refresh_meter() -> void:
	if not is_instance_valid(_meter):
		return
	var names := _Registry.type_names()
	var seen := 0
	for type_name in names:
		if _shown.has(String(type_name)):
			seen += 1
	_meter.text = "%d/%d types" % [seen, names.size()]


func show_dialog() -> void:
	if is_instance_valid(_dialog):
		_dialog.show_dialog()


func show_info(anchor: Control) -> void:
	if is_instance_valid(_info):
		_info.popup_message("Hover and click are juiced. This is an info bubble.", anchor)


func show_pause_overlay() -> void:
	if is_instance_valid(_pause) and _pause.has_method("show_pause"):
		_pause.show_pause()


func show_options_overlay() -> void:
	show_pause_overlay()
	if is_instance_valid(_pause) and _pause.has_method("open_options"):
		_pause.open_options()


func _on_resume() -> void:
	if is_instance_valid(_toast_host):
		_toast_host.show_message("Resumed", -1.0, TaBadge.Tone.ACCENT)


func _on_quit() -> void:
	if is_instance_valid(_toast_host):
		_toast_host.show_message("Quit is a signal — playground stays open")


func _print_smoke_if_headless() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var missing := missing_registry_types()
	if missing.is_empty():
		print("PLAYGROUND_MISSING none")
	else:
		print("PLAYGROUND_MISSING %s" % ",".join(missing))
	print("PLAYGROUND_OK")
	var tree := get_tree()
	if tree != null and tree.current_scene == self:
		tree.quit(0 if missing.is_empty() else 1)
