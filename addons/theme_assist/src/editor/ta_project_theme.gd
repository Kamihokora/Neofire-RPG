@tool
extends Object

# AGENT: Editor side of the playground Save: point the project theme at the saved Theme.
# INVARIANT: Sets gui/theme/custom only when it is empty (or already ours) and the saved
# theme exists, then saves project.godot. A project theme of your own is never replaced.
# DO NOT: Run in a game (editor only). Write the theme here (TaLook.save does).

const SETTING := "gui/theme/custom"


## Point the project theme at the saved Theme. Returns true when it changed.
static func sync() -> bool:
	if not Engine.is_editor_hint():
		return false
	var path := TaLook.theme_path()
	if not FileAccess.file_exists(path):
		return false
	var current := String(ProjectSettings.get_setting(SETTING, ""))
	if current == path:
		return false
	if not current.is_empty():
		# The project already names a theme of its own: leave it, say how to switch.
		var note := "[color=yellow]Theme Assist:[/color] saved look is %s; your project "
		note += "theme (%s) stays. Set %s to use it."
		print_rich(note % [path, current, SETTING])
		return false
	ProjectSettings.set_setting(SETTING, path)
	ProjectSettings.save()
	print("Theme Assist: project theme set to %s" % path)
	return true
