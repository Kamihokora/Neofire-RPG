@tool
extends PanelContainer

# AGENT: Store-prefab pause slice. Lives in the addon zip, not demo/.
# INVARIANT: apply_to paint-only. No display policy. No autoload.
# DO NOT: Load res://demo.

## Small pause panel for the editor gallery and drop-in scenes.


func _ready() -> void:
	if get_child_count() > 0:
		return
	TaThemeBuilder.apply_to(self, TaLook.current(), false)
	var col := VBoxContainer.new()
	add_child(col)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var buttons: Array[Control] = []
	for caption in ["Resume", "Options", "Quit"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = TaDefaults.BUTTON_MIN_HEIGHT
		col.add_child(button)
		buttons.append(button)
	var bar := ProgressBar.new()
	bar.value = 62
	bar.show_percentage = true
	col.add_child(bar)
	var hint := TaPromptHint.new()
	col.add_child(hint)
	TaJuice.bind_tree(self)
	TaFocus.chain(buttons, TaFocus.Axis.VERTICAL)
