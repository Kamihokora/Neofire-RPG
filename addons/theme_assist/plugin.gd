@tool
extends EditorPlugin

# AGENT: Editor lifecycle only. Loops TaRegistry. Adds the gallery dock. Keeps the
# project theme on the playground's saved look (src/editor/ta_project_theme.gd).
# INVARIANT: _exit_tree undoes every add_custom_type, the dock, and the signal from
# _enter_tree.
# DO NOT: Name widgets, colors, or Theme items here. Dock UI lives in src/editor.

const _Registry := preload("res://addons/theme_assist/src/core/ta_registry.gd")
const _Dock := preload("res://addons/theme_assist/src/editor/ta_gallery_dock.gd")
const _ProjectTheme := preload("res://addons/theme_assist/src/editor/ta_project_theme.gd")

var _dock: Control


func _enter_tree() -> void:
	for entry in _Registry.all():
		add_custom_type(
			entry["type_name"],
			entry["base_class"],
			entry["script"],
			entry["icon"]
		)
	_dock = _Dock.new()
	_dock.name = "Theme Assist"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	_ProjectTheme.sync()
	var files := EditorInterface.get_resource_filesystem()
	if not files.filesystem_changed.is_connected(_on_files_changed):
		files.filesystem_changed.connect(_on_files_changed)


func _exit_tree() -> void:
	var files := EditorInterface.get_resource_filesystem()
	if files.filesystem_changed.is_connected(_on_files_changed):
		files.filesystem_changed.disconnect(_on_files_changed)
	if is_instance_valid(_dock):
		remove_control_from_docks(_dock)
		_dock.free()
	_dock = null
	for entry in _Registry.all():
		remove_custom_type(entry["type_name"])


## A playground Save (from F6) lands while the editor is in the background; the
## rescan when you come back is our cue.
func _on_files_changed() -> void:
	_ProjectTheme.sync()
