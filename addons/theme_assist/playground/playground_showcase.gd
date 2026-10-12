extends VBoxContainer

# AGENT: First playground tab. One composed game screen built only from kit components,
# so the first open looks like a finished UI in whatever look is live.
# INVARIANT: Only Ta* components and stock Controls; no per-node colors (the Theme does
# all of it). Icons and the map are original art, drawn on whole pixels. The screen fills
# the tab: a status bar on top, the panels across the middle, the hotbar on the bottom
# edge. Each panel shows its optional blocks, in order, while they fit (a bigger screen
# shows more, so the panels are full, not stretched around empty space). Narrow tabs wrap
# the panels (HFlowContainer) instead of clipping them. Widths follow the display.
# DO NOT: Grow game logic here. Add a recipe (the Recipes tab is the copyable shells).

const _UI := preload("res://addons/theme_assist/playground/playground_ui.gd")
const _ICONS := {
	"blade": [
		".......#", "......##", ".....##.", "#..##...", ".###....", "..#.....", ".#.#....",
		"#.......",
	],
	"flask": [
		"..###...", "...#....", "...#....", "..###...", ".#####..", "#######.", "#######.",
		".#####..",
	],
	"gem": [
		"........", "..####..", ".######.", "########", ".######.", "..####..", "...##...",
		"........",
	],
	"coin": [
		"..####..", ".######.", "###..###", "##.##.##", "##.##.##", "###..###", ".######.",
		"..####..",
	],
	"key": [
		".###....", "#...#...", "#...#...", ".###....", "..#.....", "..###...", "..#.....",
		"..##....",
	],
	"leaf": [
		"......##", "....####", "..######", ".######.", ".#####..", "####....", "##......",
		"#.......",
	],
}

var _host: Control
var _status: Control
var _stage: HFlowContainer
var _hotbar: Control
var _hero_panel: Control
var _pack_panel: Control
var _side_panel: Control
var _fit_queued: bool = false
## Optional blocks per panel ([hero, pack, side]), each an Array of Controls shown
## together, in the order they show as room allows. Always instanced, so every preset has
## the same nodes.
var _extras: Array = [[], [], []]


func setup(host: Control) -> void:
	_host = host


func _ready() -> void:
	if get_child_count() > 0:
		return
	name = "Showcase"
	# Fill the tab (the playground's ScrollContainer stretches an EXPAND child).
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	set_meta("ta_cell", true)
	set_meta("ta_filter", "showcase screen menu inventory hud quest hotbar")
	_status = _status_bar()
	add_child(_status)
	_stage = HFlowContainer.new()
	_stage.name = "Stage"
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_stage)
	_hero_panel = _hero()
	_stage.add_child(_hero_panel)
	_pack_panel = _pack()
	_stage.add_child(_pack_panel)
	_side_panel = _side()
	_stage.add_child(_side_panel)
	_hotbar = _hotbar_row()
	add_child(_hotbar)
	refresh_metrics()
	var scroll := get_parent() as Control
	if scroll != null:
		scroll.resized.connect(_queue_fit)
	# The bars resize after a look change, a frame after the theme; refit then too.
	_status.minimum_size_changed.connect(_queue_fit)
	_hotbar.minimum_size_changed.connect(_queue_fit)


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_queue_fit()


## TaLook.refresh_tree calls this after a look or display change. The panel sizes are
## set in _fit_stage, deferred: the Pack window's own refresh_metrics runs after this one
## and would overwrite a width set here.
func refresh_metrics() -> void:
	_queue_fit()


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit_stage.call_deferred()


## The three panels share one row between the status bar and the hotbar. Each panel
## then shows its optional blocks in order while the row still fits, and the panels take
## the room's height, so the screen is full of content at any size (2.0 left 40% of the
## tab empty; stretching alone moved that space inside the panels). Measured from the
## tab, not the stage, so a smaller window can always shrink them back. Design widths
## first, then each panel only as wide as its content (a Steam Deck in a look whose
## captions keep it at 1080 size). Nothing fits: the bare screen wraps and the tab scrolls.
func _fit_stage() -> void:
	_fit_queued = false
	var scroll := get_parent() as Control
	if scroll == null or not is_instance_valid(_stage):
		return
	var panels: Array[Control] = [_hero_panel, _pack_panel, _side_panel]
	var design: Array[int] = [
		TaLook.metric(340, 110), TaLook.metric(380, 130), TaLook.metric(300, 100)
	]
	var gap := float(get_theme_constant("separation"))
	var room := scroll.size.y - _status.get_combined_minimum_size().y
	room -= _hotbar.get_combined_minimum_size().y + gap * 2.0
	for designed in [true, false]:
		for i in panels.size():
			panels[i].custom_minimum_size = Vector2(design[i] if designed else 0, 0)
		for blocks in _extras:
			for block in blocks:
				_show(block, false)
		if not _row_fits(panels, room, scroll.size.x):
			continue
		for blocks in _extras:
			for block in blocks:
				_show(block, true)
				if not _row_fits(panels, room, scroll.size.x):
					_show(block, false)
					break
		for panel in panels:
			panel.custom_minimum_size.y = floorf(room)
		return


func _row_fits(panels: Array[Control], room: float, width: float) -> bool:
	var row := float(_stage.get_theme_constant("h_separation")) * (panels.size() - 1)
	for panel in panels:
		var want := panel.get_combined_minimum_size()
		row += want.x
		if want.y > room:
			return false
	return row <= width


func _show(block: Array, on: bool) -> void:
	for node in block:
		(node as Control).visible = on


## Top edge of the screen: what the player carries on the left, how they are on the right.
func _status_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.name = "StatusBar"
	for spec in [["Gold", "1,250"], ["Day", "4 · Dusk"], ["Arrows", "12 / 30"]]:
		var chip := TaChip.new()
		chip.set_caption(String(spec[0]))
		chip.set_text(String(spec[1]))
		bar.add_child(chip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	for spec in [["Rested", TaBadge.Tone.SUCCESS], ["Hungry", TaBadge.Tone.WARNING],
			["Bleeding", TaBadge.Tone.DANGER]]:
		var tag := TaTag.new()
		tag.text = String(spec[0])
		tag.tone = int(spec[1]) as TaTag.Tone
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(tag)
	return bar


func _hero() -> Control:
	var panel := PanelContainer.new()
	panel.name = "Hero"
	var col := VBoxContainer.new()
	panel.add_child(col)
	var name_label := Label.new()
	name_label.text = "Rowan"
	name_label.theme_type_variation = "TaTitle"
	col.add_child(name_label)
	var role := Label.new()
	role.text = "Ranger · Level 7"
	role.theme_type_variation = "TaCaption"
	col.add_child(role)
	var hp := TaBar.new()
	hp.set_caption("HP")
	hp.set_range(72, 100)
	col.add_child(hp)
	var xp := TaBar.new()
	xp.set_caption("XP")
	xp.set_value(40)
	col.add_child(xp)
	# Two stats: a gain and a loss show both value inks; a third pushed Pixel off 1080.
	for spec in [["Damage", 8.0], ["Speed", -3.0]]:
		var stat := TaStatRow.new()
		stat.set_stat(String(spec[0]), float(spec[1]))
		col.add_child(stat)
	var more: Array = []
	for spec in [["Armor", 5.0], ["Stealth", 2.0]]:
		var stat := TaStatRow.new()
		stat.set_stat(String(spec[0]), float(spec[1]))
		col.add_child(stat)
		more.append(stat)
	var equipped := VBoxContainer.new()
	equipped.name = "Equipped"
	var worn := Label.new()
	worn.text = "Equipped"
	worn.theme_type_variation = "TaCaption"
	equipped.add_child(worn)
	var gear := TaSlotGrid.new()
	gear.grid_columns = 4
	gear.slot_count = 4
	equipped.add_child(gear)
	var on_body := ["blade", "gem", "key", "leaf"]
	for i in on_body.size():
		var slot := gear.get_slot(i)
		if slot != null:
			slot.icon = _icon(String(on_body[i]), i + 1)
	col.add_child(equipped)
	var skills := _slot_row("Skills", ["flask", "leaf", "coin"], 3)
	col.add_child(skills)
	var buffs := TaBuffStrip.new()
	buffs.buff_count = 3
	buffs.set_buff(0, "Haste", TaBadge.Tone.SUCCESS)
	buffs.set_buff(1, "Warded", TaBadge.Tone.ACCENT)
	buffs.set_buff(2, "Poisoned", TaBadge.Tone.DANGER)
	col.add_child(buffs)
	_extras[0].append_array([[equipped], more, [skills], [buffs]])
	# The menu sits at the card's foot when the stage stretches the card.
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(push)
	col.add_child(HSeparator.new())
	var menu := TaButtonCol.new()
	menu.name = "Menu"
	# Three rows: at Pixel scale 3 a fourth pushed the hotbar off a 1080p screen.
	for caption in ["Continue", "Inventory", "Quit"]:
		menu.add_button(caption)
	var buttons := menu.get_buttons()
	buttons[0].theme_type_variation = "TaPrimary"
	buttons[2].theme_type_variation = "TaDangerQuiet"
	col.add_child(menu)
	return panel


func _pack() -> Control:
	var window := TaWindow.new()
	window.name = "Pack"
	window.title = "Pack"
	# Takes the middle's spare width; the stage gives it the row's height.
	window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.get_content().add_child(tabs)
	var gear := VBoxContainer.new()
	gear.name = "Gear"
	tabs.add_child(gear)
	var grid := TaSlotGrid.new()
	# Six columns fit beside the hero and the quest at Pixel scale 3; wider looks centre it.
	grid.grid_columns = 6
	grid.slot_count = 48
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gear.add_child(grid)
	var kinds := ["blade", "flask", "gem", "coin", "key", "leaf", "flask", "gem", "coin", "leaf"]
	var counts := ["", "3", "", "48", "", "12", "1", "2", "", "5"]
	for i in kinds.size():
		var slot := grid.get_slot(i)
		if slot != null:
			slot.icon = _icon(String(kinds[i]), i)
			slot.set_center_text("")
			slot.badge_text = String(counts[i])
	var first := grid.get_slot(0)
	if first != null:
		first.selected = true
	# Rows three to eight show as the stage has room (an inventory with free space).
	var rows: Array = []
	var spare_icons := {12: "coin", 13: "flask", 19: "key"}
	for first_slot in [12, 18, 24, 30, 36, 42]:
		var row: Array = []
		for i in range(first_slot, first_slot + 6):
			var spare := grid.get_slot(i)
			if spare != null:
				if spare_icons.has(i):
					spare.icon = _icon(String(spare_icons[i]), i)
				row.append(spare)
		rows.append(row)
	# Details sit at the foot of the pack, under the grid, as in most inventories.
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear.add_child(gap)
	gear.add_child(HSeparator.new())
	var detail := HBoxContainer.new()
	gear.add_child(detail)
	var item := Label.new()
	item.text = "Ash longbow"
	detail.add_child(item)
	for spec in [["Rare", TaBadge.Tone.RARITY], ["+8 Dmg", TaBadge.Tone.SUCCESS]]:
		var badge := TaBadge.new()
		badge.text = String(spec[0])
		badge.tone = int(spec[1]) as TaBadge.Tone
		detail.add_child(badge)
	var about := Label.new()
	about.text = "Ash, horn, and gut string. Draws fast and quiet; ignores light armor."
	about.theme_type_variation = "TaCaption"
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear.add_child(about)
	var traits: Array = []
	for spec in [["Range", 12.0], ["Weight", -1.0]]:
		var stat := TaStatRow.new()
		stat.set_stat(String(spec[0]), float(spec[1]))
		gear.add_child(stat)
		traits.append(stat)
	_extras[1].append_array([rows[0], traits])
	_extras[1].append_array(rows.slice(1))
	var items := ItemList.new()
	items.name = "Items"
	items.custom_minimum_size.y = _UI.ui(120)
	for line in ["Rope", "Torch x3", "Map of the Weald"]:
		items.add_item(line)
	items.select(0)
	tabs.add_child(items)
	var notes := Label.new()
	notes.name = "Notes"
	notes.text = "The bridge is out. Try the ford at dawn."
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tabs.add_child(notes)
	return window


func _side() -> Control:
	var col := VBoxContainer.new()
	col.name = "Side"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quest := TaQuestTracker.new()
	quest.set_title("The Weald")
	quest.set_objectives(
			PackedStringArray(["Find the ranger's cache", "Cross the river", "Light the beacon"]),
			[true, false, false]
	)
	quest.set_progress(33)
	col.add_child(quest)
	var dials := HBoxContainer.new()
	col.add_child(dials)
	for spec in [["Stamina", 64], ["Focus", 30]]:
		var dial := TaRadial.new()
		dial.set_caption(String(spec[0]))
		dial.set_value(int(spec[1]))
		dials.add_child(dial)
	var party := HFlowContainer.new()
	party.name = "Party"
	col.add_child(party)
	var mates: Array = []
	for spec in [["Bram", 86], ["Isel", 41], ["Wren", 63]]:
		var mate := TaPartyFrame.new()
		mate.set_member_name(String(spec[0]))
		mate.set_health(float(spec[1]))
		mate.size_flags_horizontal = Control.SIZE_FILL
		party.add_child(mate)
		mates.append(mate)
	var log := VBoxContainer.new()
	log.name = "Log"
	var later: Array = []
	for line in [
		"Bram picked up 3 arrows.", "Isel is bleeding.", "A wolf howls to the north.",
		"The ford is shallow at dawn.", "Wren joined the party.",
	]:
		var entry := Label.new()
		entry.text = line
		entry.theme_type_variation = "TaCaption"
		log.add_child(entry)
		if log.get_child_count() > 3:
			later.append(entry)
	col.add_child(log)
	var map := TaMinimap.new()
	map.name = "Map"
	# Takes the column's spare height: the screen ends in map, not in empty panel.
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art := _MapArt.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.get_content().add_child(art)
	col.add_child(map)
	_extras[2].append_array([[log], [map], [mates[2]], later])
	return col


## A caption over a row of slots with icons (equipped gear, skills).
func _slot_row(caption: String, kinds: Array, count: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = caption
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = "TaCaption"
	box.add_child(label)
	var grid := TaSlotGrid.new()
	grid.grid_columns = count
	grid.slot_count = count
	box.add_child(grid)
	for i in kinds.size():
		var slot := grid.get_slot(i)
		if slot != null:
			slot.icon = _icon(String(kinds[i]), i + 2)
	return box


func _hotbar_row() -> Control:
	var row := HFlowContainer.new()
	row.name = "HotbarRow"
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	# The pickup notice sits by the hotbar, where the eye already is (a toast is a pixel
	# look's widest atom, so it does not fit the side column at scale 3).
	var toast := TaToast.new()
	toast.text = "Found 12 arrows"
	toast.tone = TaBadge.Tone.ACCENT
	toast.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(toast)
	var bar := TaHotbar.new()
	bar.slot_count = 6
	row.add_child(bar)
	var kinds := ["blade", "flask", "key", "leaf", "gem", "coin"]
	for i in kinds.size():
		var slot := bar.get_slot(i)
		if slot != null:
			slot.icon = _icon(String(kinds[i]), i)
	var hint := TaInteractHint.new()
	hint.set_prompt("E", "Open the cache")
	# On the page, not over a scene: plain ink like the rest of the screen.
	hint.on_scene = false
	row.add_child(hint)
	return row


## The map in the Map frame: original art in look colours, cell by cell, each cell a
## whole number of art pixels, so it stays crisp in every look. It covers the whole frame
## (the frame takes the column's spare height). Redrawn on a look or size change.
class _MapArt extends Control:
	## Cells across the frame's shorter side.
	const CELLS := 24

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var look := TaLook.current()
		var art := TaLook.scale()
		var cell := maxi(1, floori(minf(size.x, size.y) / CELLS / art)) * art
		var cols := floori(size.x / cell)
		var rows := floori(size.y / cell)
		var area := Vector2(cols * cell, rows * cell)
		var origin := ((size - area) / 2.0).floor()
		draw_rect(Rect2(origin, area), look.color_bg)
		for y in rows:
			for x in cols:
				var ink := _ink(x, y, cols, rows, look)
				if ink.a > 0.0:
					draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), ink)

	## Woods in three corners, a river, a path from the player to the cache.
	func _ink(x: int, y: int, cols: int, rows: int, look: TaTokens) -> Color:
		var u := (x + 0.5) / cols
		var v := (y + 0.5) / rows
		var px := floori(cols * 0.64)
		var py := floori(rows * 0.78)
		var ox := floori(cols * 0.48)
		var oy := floori(rows * 0.2)
		if x >= px and x <= px + 1 and y >= py and y <= py + 1:
			return look.color_accent
		if absi(x - ox) == absi(y - oy) and absi(x - ox) <= 1:
			return look.color_danger
		if absf(x - (cols * 0.16 + y * cols * 0.45 / rows)) < 0.8:
			return look.color_muted
		if (x == px and y > oy and y < py) or (y == oy + 1 and x > ox and x <= px):
			return look.color_border
		var woods := (u < 0.24 and v > 0.62) or (u > 0.76 and v < 0.34) or (u > 0.84 and v > 0.66)
		if woods and (x * 7 + y * 5) % 4 != 0:
			return look.color_success.darkened(0.25)
		return Color(0, 0, 0, 0)


## An 8 x 8 icon in a look color, scaled by whole pixels to slot size.
func _icon(kind: String, index: int) -> Texture2D:
	var rows: Array = _ICONS.get(kind, _ICONS["gem"])
	var look := TaLook.current()
	var tints := [look.color_accent, look.color_success, look.color_warning, look.color_danger]
	var ink: Color = tints[index % tints.size()]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 8:
		var line := String(rows[y])
		for x in 8:
			if line[x] == "#":
				img.set_pixel(x, y, ink)
	var scale := maxi(2, TaLook.metric(TaDefaults.SLOT_SIZE, TaDefaults.PIXEL_SLOT_SIZE) / 16)
	img.resize(8 * scale, 8 * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
