class_name TaQuestTracker
extends PanelContainer

# AGENT: Quest/objective list. Display only; not a quest DB.
# INVARIANT: set_objectives replaces rows. Optional ProgressBar 0–100.
# DO NOT: Own quests. Do not autoload.

## Header + bullet objectives + optional progress.

var _col: VBoxContainer
var _title: Label
var _list: VBoxContainer
var _bar: ProgressBar
var _lines: PackedStringArray = PackedStringArray()
var _done: Array = []


func _init() -> void:
	theme_type_variation = "TaQuestTracker"
	_col = VBoxContainer.new()
	add_child(_col)
	_title = Label.new()
	_title.text = "Quest"
	_title.theme_type_variation = "TaTitle"
	_col.add_child(_title)
	_list = VBoxContainer.new()
	_col.add_child(_list)
	_bar = ProgressBar.new()
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.value = 0
	_bar.show_percentage = false
	_col.add_child(_bar)
	refresh_metrics()


## Objectives wrap inside a set width. Sized by its content (a HUD corner), the tracker
## was as wide as its title and wrapped "Clear the crypt" onto three lines.
func refresh_metrics() -> void:
	if not is_instance_valid(_list):
		return
	_list.custom_minimum_size.x = TaLook.metric(
			TaDefaults.QUEST_MIN_WIDTH, TaDefaults.PIXEL_QUEST_MIN_WIDTH
	)
	for label in _list.get_children():
		_fit(label as Label)


## An autowrap Label measures its height at its own width, 0 before layout: one word a
## line, and a tracker pinned to a corner kept that 800 px height. Give it the list width.
func _fit(label: Label) -> void:
	if label != null:
		label.custom_minimum_size.x = _list.custom_minimum_size.x


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_paint_marks()


func set_title(text: String) -> void:
	_title.text = text


## `done` is optional and parallel to lines. True marks that row done.
## The words stay yours, including a live count. Existing string calls are unchanged.
func set_objectives(lines: PackedStringArray, done: Array = []) -> void:
	_lines = lines.duplicate()
	_done = done.duplicate()
	for child in _list.get_children():
		_list.remove_child(child)
		child.free()
	for i in lines.size():
		var label := Label.new()
		label.theme_type_variation = "TaSuccessLabel" if _finished(i) else ""
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_fit(label)
		_list.add_child(label)
	_paint_marks()


func _finished(index: int) -> bool:
	return index < _done.size() and bool(_done[index])


## Bullet or tick per line. The tick is "√" in a face without "✓" (the Pixel face has
## none, so done lines showed a missing-glyph box).
func _paint_marks() -> void:
	if not is_instance_valid(_list):
		return
	var face := get_theme_font("font", "Label")
	var tick := TaDefaults.QUEST_DONE
	if face != null and not face.has_char(tick.unicode_at(0)):
		tick = TaDefaults.QUEST_DONE_PLAIN
	for i in mini(_lines.size(), _list.get_child_count()):
		var label := _list.get_child(i) as Label
		if label != null:
			label.text = "%s %s" % [tick if _finished(i) else TaDefaults.QUEST_TODO, _lines[i]]


## False hides the bar (a tracker with no single progress number).
func set_progress_visible(on: bool) -> void:
	_bar.visible = on


func set_progress(amount: float) -> void:
	_bar.value = clampf(amount, 0.0, 100.0)


func get_objective_count() -> int:
	return _list.get_child_count()
