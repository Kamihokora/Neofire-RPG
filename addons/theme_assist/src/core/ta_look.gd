@tool
class_name TaLook
extends Object

# AGENT: Session look, the saved look, and sizes kit widgets read from it.
# INVARIANT: current() is the bound look, else the look the Playground saved, else
# Flat. save() writes tokens and the Theme made from them; load_saved() reads tokens.
# Widget sizes go through metric() so they follow the display (TaDisplay) and, on pixel
# looks, the art scale. refit() rebuilds every kit Theme made for another display fit.
# DO NOT: Autoload. Do not split pause vs playground looks. Write project.godot here
# (the editor plugin points the project theme at the saved Theme).

const FLAT := "flat"
const MODERN := "modern"
const FRAMED := "framed"
const PIXEL := "pixel"
const IDS := [FLAT, MODERN, FRAMED, PIXEL]

static var id: String = FLAT
## Last look passed through apply / apply_to / bind. Juice, dimmer, toast, CRT read this.
static var active: TaTokens = null
## Where save() writes and current() / load_saved() read. A game may point it elsewhere
## (the editor plugin only watches TaDefaults.SAVE_DIR).
static var save_dir: String = TaDefaults.SAVE_DIR

const _FACE_KEYS := ["face", "face_title", "face_caption", "face_bold", "face_italic"]
const _KIT_FACES := &"ta_kit_faces"
## Face keys a look leaves empty (Godot's default font). A null property is not written,
## so without this the export default (Barlow) came back on load.
const _NO_FACES := &"ta_no_faces"

## Roots apply_to painted, by instance id: [weakref(control), look]. refit() repaints them.
static var _painted: Dictionary = {}


## The preset for the session id.
static func tokens() -> TaTokens:
	return TaTokens.preset(id)


## The bound look; else the saved look; else Flat. Binds what it finds.
static func current() -> TaTokens:
	if active == null:
		var saved := load_saved()
		bind(saved if saved != null else TaTokens.new())
		TaDisplay.watch()
	return active


## Apply Theme. sync_display true switches the Window (pixel games) and full-rects the
## target only when it is the scene root.
static func apply(
		control: Control,
		look: TaTokens = null,
		sync_display: bool = true
	) -> Theme:
	var resolved := look if look != null else current()
	bind(resolved)
	return TaThemeBuilder.apply_to(control, resolved, sync_display)


static func uses_pixel() -> bool:
	if active != null:
		return active.is_pixel()
	return TaDisplay.is_pixel()


## Screen pixels per art pixel for the bound look on this display. 1 for VECTOR looks,
## and 1 inside a pixel framebuffer (TaDisplay), where the window does the scaling.
static func scale() -> int:
	var look := current()
	if look == null or not look.is_pixel():
		return 1
	return TaDisplay.art_scale(look)


## The px multiplier of the bound VECTOR look on this display (1 at 1080 px tall).
static func ui_scale() -> float:
	var look := current()
	return TaDisplay.vector_scale(look) if look != null and not look.is_pixel() else 1.0


## A widget size on this display: `hd` px times ui_scale() on VECTOR looks, `pixel_art`
## art px times scale() on PIXEL looks.
static func metric(hd: int, pixel_art: int) -> int:
	if uses_pixel():
		return pixel_art * scale()
	return roundi(hd * ui_scale())


## metric() for a given on-screen look (the builder passes the look it is building).
static func metric_for(look: TaTokens, hd: int, pixel_art: int) -> int:
	return pixel_art * look.art_scale() if look.is_pixel() else look.px(hd)


## The kit gap (box separations, icon-to-text) for the bound look on this display.
static func gap() -> int:
	return metric(TaDefaults.SEPARATION, TaDefaults.PIXEL_SEPARATION)


## Button height on screen for the bound look.
static func button_height() -> int:
	var look := current()
	if look.is_pixel():
		return look.button_min_height * scale()
	return roundi(look.button_min_height * ui_scale())


## Push look knobs into juice (and remember the look for dimmer/toast/CRT).
static func bind(look: TaTokens) -> void:
	if look == null:
		return
	active = look
	TaJuice.apply_look(look)
	# In-world HUD (TaWorldAttach) follows the bound look. Deferred: a refresh may bind.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		tree.call_group_flags(
				SceneTree.GROUP_CALL_DEFERRED | SceneTree.GROUP_CALL_UNIQUE,
				&"ta_world_attach", "refresh_look"
		)


## Remember that apply_to painted `control` with `look`, so refit() can repaint it.
static func track_paint(control: Control, look: TaTokens) -> void:
	_painted[control.get_instance_id()] = [weakref(control), look]


## Rebuild every kit Theme made for another display fit: the project theme (the saved
## look, made in the editor at 1080 px) and every root apply_to painted. Then widgets
## refresh their sizes. TaDisplay.watch() calls this on start and when the window
## crosses a scale step.
static func refit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var changed := false
	var project := ThemeDB.get_project_theme()
	if project != null and project.has_meta(TaThemeBuilder.FIT_META):
		var look := current()
		if String(project.get_meta(TaThemeBuilder.FIT_META)) != TaDisplay.fit_key(look):
			var fresh := TaThemeBuilder.make(look)
			project.clear()
			project.merge_with(fresh)
			project.set_meta(TaThemeBuilder.FIT_META, fresh.get_meta(TaThemeBuilder.FIT_META))
			changed = true
	for id in _painted.keys():
		var entry: Array = _painted[id]
		var control := (entry[0] as WeakRef).get_ref() as Control
		if control == null:
			_painted.erase(id)
			continue
		var look: TaTokens = entry[1]
		var theme := control.theme
		if theme == null or not theme.has_meta(TaThemeBuilder.FIT_META):
			continue
		if String(theme.get_meta(TaThemeBuilder.FIT_META)) != TaDisplay.fit_key(look):
			control.theme = TaThemeBuilder.make(look)
			changed = true
	if changed:
		refresh_tree(tree.root)
		tree.call_group(&"ta_world_attach", "refresh_look")


## Walk a tree and call refresh_metrics() on kit widgets after a look change.
static func refresh_tree(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node.has_method("refresh_metrics"):
		node.refresh_metrics()
	for child in node.get_children():
		refresh_tree(child)


## Save `look` (a copy) and the Theme built from it to `dir` (look.tres, theme.res).
## The editor plugin then sets the project theme to theme.res, so every Control in
## the project wears it. Returns the first error, or OK.
static func save(look: TaTokens, dir: String = "") -> Error:
	if look == null:
		return ERR_INVALID_PARAMETER
	dir = _dir(dir)
	var made := DirAccess.make_dir_recursive_absolute(_absolute(dir))
	if made != OK and not DirAccess.dir_exists_absolute(_absolute(dir)):
		return made
	# The Theme embeds everything it draws (generated chrome, kit faces): compressed binary.
	var err := ResourceSaver.save(
			TaThemeBuilder.make(look), theme_path(dir), ResourceSaver.FLAG_COMPRESS
	)
	if err != OK:
		return err
	# The look names kit faces by id instead of embedding them, so look.tres stays small and
	# readable; load_saved() rebuilds them.
	var copy := look.duplicate() as TaTokens
	var kit := {}
	for key in _FACE_KEYS:
		var id := TaPixelFont.kit_id(copy.get(key))
		if not id.is_empty():
			kit[key] = id
			copy.set(key, null)
	if not kit.is_empty():
		copy.set_meta(_KIT_FACES, kit)
	var none := PackedStringArray()
	for key in _FACE_KEYS:
		if look.get(key) == null:
			none.append(key)
	if not none.is_empty():
		copy.set_meta(_NO_FACES, none)
	return ResourceSaver.save(copy, look_path(dir))


## The saved look in `dir`, or null. Always read fresh from disk.
static func load_saved(dir: String = "") -> TaTokens:
	var path := look_path(dir)
	if not ResourceLoader.exists(path):
		return null
	var look := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as TaTokens
	if look != null and look.look_id == "terpene":
		look.look_id = FRAMED  # beta rename: an old save opens as Framed
	if look != null and look.has_meta(_KIT_FACES):
		var kit: Dictionary = look.get_meta(_KIT_FACES)
		for key in kit:
			look.set(key, TaPixelFont.face(String(kit[key])))
		look.remove_meta(_KIT_FACES)
	if look != null and look.has_meta(_NO_FACES):
		for key in look.get_meta(_NO_FACES):
			look.set(String(key), null)
		look.remove_meta(_NO_FACES)
	return look


## True when two looks hold the same knobs (every saved property). The Playground uses it
## so picking the preset you already have is not an unsaved change.
static func same(a: TaTokens, b: TaTokens) -> bool:
	if a == null or b == null:
		return a == b
	for prop in a.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
			continue
		var key := String(prop["name"])
		if key == "resource_path" or key == "resource_name" or key == "script":
			continue
		var x: Variant = a.get(key)
		var y: Variant = b.get(key)
		if typeof(x) != typeof(y):
			return false
		if x is Color:
			if not (x as Color).is_equal_approx(y):
				return false
		elif x is float:
			if not is_equal_approx(x, y):
				return false
		elif x != y:
			return false
	return true


static func has_saved(dir: String = "") -> bool:
	return ResourceLoader.exists(look_path(dir))


## Bind the saved look (Flat if none) and paint `control` with it. Returns the look.
static func apply_saved(control: Control, dir: String = "") -> TaTokens:
	var look := load_saved(dir)
	if look == null:
		look = TaTokens.new()
	TaThemeBuilder.apply_to(control, look, false)
	return look


static func look_path(dir: String = "") -> String:
	return _dir(dir).path_join(TaDefaults.SAVE_LOOK)


static func theme_path(dir: String = "") -> String:
	return _dir(dir).path_join(TaDefaults.SAVE_THEME)


static func _dir(dir: String) -> String:
	if not dir.is_empty():
		return dir
	# A static initializer does not run where this script is not a tool (the editor plugin
	# reads it), so an empty save_dir falls back to the constant.
	return save_dir if not save_dir.is_empty() else TaDefaults.SAVE_DIR


static func _absolute(dir: String) -> String:
	if dir.begins_with("res://") or dir.begins_with("user://"):
		return ProjectSettings.globalize_path(dir)
	return dir
