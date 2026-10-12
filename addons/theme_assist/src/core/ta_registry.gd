class_name TaRegistry
extends Object

# AGENT: Shipped custom types + editor icons. plugin.gd iterates this.
# INVARIANT: Unique type_name. Helper overlays spawned
# via ClassName.on(host) (TaDimmer, TaTransition) are not listed.
# DO NOT: Name types in plugin.gd.

const _BADGE := preload("res://addons/theme_assist/src/components/badge/ta_badge.gd")
const _TOAST_HOST := preload("res://addons/theme_assist/src/components/toast/ta_toast_host.gd")
const _TOAST := preload("res://addons/theme_assist/src/components/toast/ta_toast.gd")
const _DIALOG := preload("res://addons/theme_assist/src/components/dialog/ta_dialog.gd")
const _MODAL := preload("res://addons/theme_assist/src/components/dialog/ta_modal.gd")
const _TOOLTIP := preload("res://addons/theme_assist/src/components/tooltip/ta_item_tooltip.gd")
const _SLOT := preload("res://addons/theme_assist/src/components/slot/ta_slot.gd")
const _WINDOW := preload("res://addons/theme_assist/src/components/window/ta_window.gd")
const _GRID := preload("res://addons/theme_assist/src/components/grid/ta_slot_grid.gd")
const _INSPECTOR := preload("res://addons/theme_assist/src/components/inspector/ta_inspector.gd")
const _INFO := preload("res://addons/theme_assist/src/components/popup/ta_info_popup.gd")
const _TABS := preload("res://addons/theme_assist/src/components/window/ta_tab_window.gd")
const _HINT := preload("res://addons/theme_assist/src/components/hint/ta_prompt_hint.gd")
const _REBIND := preload("res://addons/theme_assist/src/components/rebind/ta_rebind_row.gd")
const _CHIP := preload("res://addons/theme_assist/src/components/chip/ta_chip.gd")
const _BAR := preload("res://addons/theme_assist/src/components/bar/ta_bar.gd")
const _INFO_ICON := preload("res://addons/theme_assist/src/components/info_icon/ta_info_icon.gd")
const _TAG := preload("res://addons/theme_assist/src/components/tag/ta_tag.gd")
const _HEADER := preload("res://addons/theme_assist/src/components/header/ta_header_panel.gd")
const _BTN_ROW := preload("res://addons/theme_assist/src/components/buttons/ta_button_row.gd")
const _BTN_COL := preload("res://addons/theme_assist/src/components/buttons/ta_button_col.gd")
const _PLATE := preload("res://addons/theme_assist/src/components/buttons/ta_plate_button.gd")
const _TOGGLE := preload("res://addons/theme_assist/src/components/toggle/ta_toggle_group.gd")
const _VBAR := preload("res://addons/theme_assist/src/components/bar/ta_vbar.gd")
const _RADIAL := preload("res://addons/theme_assist/src/components/radial/ta_radial.gd")
const _SORT := preload("res://addons/theme_assist/src/components/list/ta_sort_list.gd")
const _REORDER := preload("res://addons/theme_assist/src/components/list/ta_reorder_list.gd")
const _ICONS := preload("res://addons/theme_assist/src/components/grid/ta_icon_grid.gd")
const _FIELD := preload("res://addons/theme_assist/src/components/field/ta_field_row.gd")
const _INTERACT := preload("res://addons/theme_assist/src/components/hint/ta_interact_hint.gd")
const _FEED := preload("res://addons/theme_assist/src/components/feed/ta_kill_feed.gd")
const _RETICLE := preload("res://addons/theme_assist/src/components/hud/ta_reticle.gd")
const _VIGNETTE := preload("res://addons/theme_assist/src/components/hud/ta_vignette.gd")
const _HOTBAR := preload("res://addons/theme_assist/src/components/hud/ta_hotbar.gd")
const _MINIMAP := preload("res://addons/theme_assist/src/components/hud/ta_minimap.gd")
const _PARTY := preload("res://addons/theme_assist/src/components/hud/ta_party_frame.gd")
const _SPEECH := preload("res://addons/theme_assist/src/components/hud/ta_speech_bubble.gd")
const _SHOP := preload("res://addons/theme_assist/src/components/hud/ta_shop_card.gd")
const _STAT := preload("res://addons/theme_assist/src/components/hud/ta_stat_row.gd")
const _CHOICE := preload("res://addons/theme_assist/src/components/hud/ta_choice_picker.gd")
const _SPLASH := preload("res://addons/theme_assist/src/components/hud/ta_win_splash.gd")
const _BANNER := preload("res://addons/theme_assist/src/components/hud/ta_banner.gd")
const _BUFFS := preload("res://addons/theme_assist/src/components/hud/ta_buff_strip.gd")
const _STEPPER := preload("res://addons/theme_assist/src/components/hud/ta_stepper.gd")
const _QUEST := preload("res://addons/theme_assist/src/components/hud/ta_quest_tracker.gd")
const _COMPASS := preload("res://addons/theme_assist/src/components/hud/ta_compass.gd")
const _BOARD := preload("res://addons/theme_assist/src/components/hud/ta_scoreboard.gd")
const _FLOATER := preload("res://addons/theme_assist/src/components/hud/ta_floater.gd")
const _HIGHLIGHT := preload("res://addons/theme_assist/src/components/hud/ta_highlight_cell.gd")
const _OVERLAY := preload("res://addons/theme_assist/src/components/overlay/ta_overlay.gd")
const _ROUTER := preload("res://addons/theme_assist/src/components/overlay/ta_cancel_router.gd")
const _POPOVER := preload("res://addons/theme_assist/src/components/popover/ta_popover.gd")
const _BUTTON := preload("res://addons/theme_assist/src/components/buttons/ta_button.gd")
const _WORLD := preload("res://addons/theme_assist/src/components/world/ta_world_attach.gd")


static func all() -> Array[Dictionary]:
	return [
		_entry("TaBadge", "PanelContainer", _BADGE, "ta_badge.svg"),
		_entry("TaToastHost", "Control", _TOAST_HOST, "ta_host.svg"),
		_entry("TaToast", "PanelContainer", _TOAST, "ta_toast.svg"),
		_entry("TaDialog", "PopupPanel", _DIALOG, "ta_dialog.svg"),
		_entry("TaModal", "Control", _MODAL, "ta_dialog.svg"),
		_entry("TaItemTooltip", "PanelContainer", _TOOLTIP, "ta_tooltip.svg"),
		_entry("TaSlot", "Button", _SLOT, "ta_slot.svg"),
		_entry("TaWindow", "PanelContainer", _WINDOW, "ta_window.svg"),
		_entry("TaSlotGrid", "GridContainer", _GRID, "ta_grid.svg"),
		_entry("TaInspector", "PanelContainer", _INSPECTOR, "ta_inspector.svg"),
		_entry("TaInfoPopup", "PopupPanel", _INFO, "ta_info.svg"),
		_entry("TaTabWindow", "PanelContainer", _TABS, "ta_tabs.svg"),
		_entry("TaPromptHint", "Label", _HINT, "ta_hint.svg"),
		_entry("TaRebindRow", "HBoxContainer", _REBIND, "ta_rebind.svg"),
		_entry("TaChip", "PanelContainer", _CHIP, "ta_chip.svg"),
		_entry("TaBar", "PanelContainer", _BAR, "ta_bar.svg"),
		_entry("TaInfoIcon", "Button", _INFO_ICON, "ta_info_icon.svg"),
		_entry("TaTag", "PanelContainer", _TAG, "ta_tag.svg"),
		_entry("TaHeaderPanel", "PanelContainer", _HEADER, "ta_header.svg"),
		_entry("TaButtonRow", "HBoxContainer", _BTN_ROW, "ta_buttons.svg"),
		_entry("TaButtonCol", "VBoxContainer", _BTN_COL, "ta_buttons.svg"),
		_entry("TaPlateButton", "TextureButton", _PLATE, "ta_buttons.svg"),
		_entry("TaToggleGroup", "HBoxContainer", _TOGGLE, "ta_toggle.svg"),
		_entry("TaVBar", "PanelContainer", _VBAR, "ta_vbar.svg"),
		_entry("TaRadial", "PanelContainer", _RADIAL, "ta_radial.svg"),
		_entry("TaSortList", "PanelContainer", _SORT, "ta_sort.svg"),
		_entry("TaReorderList", "PanelContainer", _REORDER, "ta_reorder.svg"),
		_entry("TaIconGrid", "GridContainer", _ICONS, "ta_icons.svg"),
		_entry("TaFieldRow", "HBoxContainer", _FIELD, "ta_inspector.svg"),
		_entry("TaInteractHint", "HBoxContainer", _INTERACT, "ta_hint.svg"),
		_entry("TaKillFeed", "VBoxContainer", _FEED, "ta_toast.svg"),
		_entry("TaReticle", "Control", _RETICLE, "ta_info_icon.svg"),
		_entry("TaVignette", "Control", _VIGNETTE, "ta_window.svg"),
		_entry("TaHotbar", "HBoxContainer", _HOTBAR, "ta_grid.svg"),
		_entry("TaMinimap", "PanelContainer", _MINIMAP, "ta_header.svg"),
		_entry("TaPartyFrame", "PanelContainer", _PARTY, "ta_inspector.svg"),
		_entry("TaSpeechBubble", "PanelContainer", _SPEECH, "ta_info.svg"),
		_entry("TaShopCard", "PanelContainer", _SHOP, "ta_header.svg"),
		_entry("TaStatRow", "HBoxContainer", _STAT, "ta_chip.svg"),
		_entry("TaChoicePicker", "PanelContainer", _CHOICE, "ta_buttons.svg"),
		_entry("TaWinSplash", "PanelContainer", _SPLASH, "ta_badge.svg"),
		_entry("TaBanner", "PanelContainer", _BANNER, "ta_header.svg"),
		_entry("TaBuffStrip", "HBoxContainer", _BUFFS, "ta_badge.svg"),
		_entry("TaStepper", "HBoxContainer", _STEPPER, "ta_chip.svg"),
		_entry("TaQuestTracker", "PanelContainer", _QUEST, "ta_inspector.svg"),
		_entry("TaCompass", "PanelContainer", _COMPASS, "ta_radial.svg"),
		_entry("TaScoreboard", "PanelContainer", _BOARD, "ta_sort.svg"),
		_entry("TaFloater", "Label", _FLOATER, "ta_chip.svg"),
		_entry("TaHighlightCell", "PanelContainer", _HIGHLIGHT, "ta_slot.svg"),
		_entry("TaOverlay", "Control", _OVERLAY, "ta_dialog.svg"),
		_entry("TaCancelRouter", "Node", _ROUTER, "ta_hint.svg"),
		_entry("TaPopover", "PanelContainer", _POPOVER, "ta_tooltip.svg"),
		_entry("TaWorldAttach", "Node3D", _WORLD, "ta_world.svg"),
		_entry("TaButton", "Button", _BUTTON, "ta_buttons.svg"),
	]


static func type_names() -> PackedStringArray:
	var names := PackedStringArray()
	for entry in all():
		names.append(String(entry["type_name"]))
	return names


static func _entry(
		type_name: String,
		base_class: String,
		script: Script,
		icon_file: String
	) -> Dictionary:
	var path := "res://addons/theme_assist/icons/%s" % icon_file
	return {
		"type_name": type_name,
		"base_class": base_class,
		"script": script,
		"icon": load_texture(path),
	}


## Load addon SVG/PNG from file bytes. Never ResourceLoader.load (no .import/.ctex).
static func load_texture(path: String) -> Texture2D:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if path.ends_with(".svg"):
		var svg := FileAccess.get_file_as_string(path)
		if svg.is_empty() or img.load_svg_from_string(svg) != OK:
			return null
	elif path.ends_with(".png"):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty() or img.load_png_from_buffer(bytes) != OK:
			return null
	else:
		return null
	return ImageTexture.create_from_image(img)


## Use imported Texture2D when .ctex exists so Pixel sheet paths stay; else bytes.
static func load_imported_or_bytes(path: String) -> Texture2D:
	if _ctex_ready(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	return load_texture(path)


static func _ctex_ready(path: String) -> bool:
	var sidecar := path + ".import"
	if not FileAccess.file_exists(sidecar):
		return false
	var text := FileAccess.get_file_as_string(sidecar)
	var from := text.find("res://.godot/imported/")
	if from < 0:
		return false
	var to := text.find(".ctex", from)
	if to < 0:
		return false
	var dest := text.substr(from, to + 5 - from)
	return FileAccess.file_exists(dest)
