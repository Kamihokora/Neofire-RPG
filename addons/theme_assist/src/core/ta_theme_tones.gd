class_name TaThemeTones
extends Object

# AGENT: Toned boxes (accent/danger/success/warning/rarity chips and toasts, selected
# cards, look.tones) and the semantic buttons and labels (TaDanger, TaDangerQuiet,
# TaSuccessLabel...) for the generated Theme. Called from TaThemeBuilder.
# INVARIANT: A toned box is filled with its tone in every look, so ink picked against
# the tone is ink on the tone. Chips use the CHIP role, toasts and cards FRAME.
# DO NOT: Modulate a texture. No DSL.

## Count: a number pinned to a slot, on a plate of the look's ink, so it reads on any slot.
const BADGE_TONES := ["Accent", "Danger", "Success", "Warning", "Rarity", "Count"]
const TOAST_TONES := ["Accent", "Danger", "Success", "Warning"]


## Semantic buttons (filled TaDanger / TaSuccess / TaWarning, quiet TaDangerQuiet),
## the matching *Label colours, then look.tones.
static func apply_semantic(theme: Theme, look: TaTokens) -> void:
	_tone_button(theme, "TaDanger", look, look.color_danger)
	_quiet_button(theme, "TaDangerQuiet", look, look.color_danger)
	_tone_button(theme, "TaSuccess", look, look.color_success)
	_tone_button(theme, "TaWarning", look, look.color_warning)
	# Tones are fill colours; text in a tone is that tone pushed until it reads on the panel.
	var panel := TaThemeBuilder.panel_fill(look)
	theme.set_type_variation("TaDangerLabel", "Label")
	theme.set_color("font_color", "TaDangerLabel", TaContrast.tone_ink(look.color_danger, panel))
	theme.set_type_variation("TaSuccessLabel", "Label")
	theme.set_color(
			"font_color", "TaSuccessLabel", TaContrast.tone_ink(look.color_success, panel)
	)
	theme.set_type_variation("TaWarningLabel", "Label")
	theme.set_color(
			"font_color", "TaWarningLabel", TaContrast.tone_ink(look.color_warning, panel)
	)
	apply_named(theme, look)


## Built-in toned variations. Ink colours stay in TaThemeBuilder.
static func apply_builtin(theme: Theme, look: TaTokens) -> void:
	var bm := TaThemeBuilder.badge_margin(look)
	var p := look.panel_margin
	for tone_name in BADGE_TONES:
		var fill := _fill(look, tone_name)
		var border := fill.darkened(0.3)
		chip(theme, "TaBadge" + tone_name, look, fill, border, bm)
		chip(theme, "TaTag" + tone_name, look, fill, border, bm)
	_count_plate(theme, look)
	for tone_name in TOAST_TONES:
		var fill := _fill(look, tone_name)
		card(theme, "TaToast" + tone_name, look, fill, fill.darkened(0.3), p, TaChrome.Role.NOTE)
	card(theme, "TaShopCardOn", look, look.color_accent, look.color_accent.darkened(0.3), p)
	card(theme, "TaHighlightCellOn", look, look.color_warning, look.color_accent, p)


## look.tones {name: Color} -> TaTag / TaBadge / TaToast variations with readable ink.
static func apply_named(theme: Theme, look: TaTokens) -> void:
	var bm := TaThemeBuilder.badge_margin(look)
	var p := look.panel_margin
	var badge_fs := look.font_size_caption
	var badge_face := TaThemeBuilder.face_at(
			look.face_caption if look.face_caption != null else look.face, badge_fs
	)
	for key in look.tones:
		var value: Variant = look.tones[key]
		if not value is Color or String(key).is_empty():
			continue
		var tone: Color = value
		var ink := TaThemeBuilder.ink_on(look, tone)
		for prefix in ["TaTag", "TaBadge"]:
			var type_name := TaThemeBuilder.tone_type(prefix, String(key))
			chip(theme, type_name, look, tone, tone.darkened(0.3), bm)
			theme.set_color("font_color", type_name, ink)
			theme.set_color("font_shadow_color", type_name, TaThemeBuilder.shadow_for(look, ink))
			theme.set_font_size("font_size", type_name, badge_fs)
			if badge_face != null:
				theme.set_font("font", type_name, badge_face)
		var toast := TaThemeBuilder.tone_type("TaToast", String(key))
		card(theme, toast, look, tone, tone.darkened(0.3), p, TaChrome.Role.NOTE)
		theme.set_color("font_color", toast, ink)
		theme.set_color("font_shadow_color", toast, TaThemeBuilder.shadow_for(look, ink))


## One chip variation (badge, tag) filled with `tone`.
static func chip(
		theme: Theme, type_name: String, look: TaTokens, tone: Color, border: Color, margin: int
	) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox(
			"panel", type_name, TaChrome.box(look, TaChrome.Role.CHIP, tone, border, margin)
	)


## A slot count's plate (TaBadgeCount): the look's ink with COUNT_MARGIN round its
## figures (TaThemeBuilder.figure_face), so it is short enough to sit on the slot's top
## frame. On PIXEL looks a one-pixel corner, no outline, no ribbon notch: a number, not a
## tag (Framed's chip outline took the whole margin and the digits filled the plate).
static func _count_plate(theme: Theme, look: TaTokens) -> void:
	var plate := look
	var m := look.px(TaDefaults.COUNT_MARGIN)
	if look.is_pixel():
		m = TaDefaults.PIXEL_COUNT_MARGIN * look.art_scale()
		plate = look.duplicate() as TaTokens
		plate.radius = mini(look.radius, look.art_scale())
		plate.edge = 0
		plate.chip_ribbon = false
	var ink := look.color_text
	chip(theme, "TaBadgeCount", plate, ink, ink.darkened(0.3), m)


## One card variation (a selected card, or a toast with role NOTE) filled with `tone`.
static func card(
		theme: Theme,
		type_name: String,
		look: TaTokens,
		tone: Color,
		border: Color,
		margin: int,
		role: TaChrome.Role = TaChrome.Role.CARD
	) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, TaChrome.box(look, role, tone, border, margin))


static func _fill(look: TaTokens, tone_name: String) -> Color:
	match tone_name:
		"Accent":
			return look.color_accent
		"Danger":
			return look.color_danger
		"Success":
			return look.color_success
		"Rarity":
			return look.color_rarity
		"Count":
			return look.color_text
		_:
			return look.color_warning


## A filled tone button (TaDanger, TaSuccess, TaWarning): the button shape in the tone.
static func _tone_button(theme: Theme, type_name: String, look: TaTokens, tone: Color) -> void:
	theme.set_type_variation(type_name, "Button")
	TaThemeBuilder.button_boxes(
			theme, type_name, look, [tone, tone.lightened(0.12), tone.darkened(0.18)],
			tone.darkened(0.45)
	)


## Surface button with a tone border and tone text. Same height as its siblings.
## For a destructive row in a menu (New game, Abandon run) that should not shout.
static func _quiet_button(theme: Theme, type_name: String, look: TaTokens, tone: Color) -> void:
	theme.set_type_variation(type_name, "Button")
	if look.is_pixel():
		# Pixel buttons carry no border line, so the quiet form is a deep tone fill.
		var deep := tone.darkened(0.45)
		TaThemeBuilder.button_boxes(
				theme, type_name, look, [deep, deep.lightened(0.1), deep.darkened(0.2)],
				tone.darkened(0.7)
		)
		return
	TaThemeBuilder.button_boxes(
			theme, type_name, look,
			[look.color_surface, look.color_surface_hover, look.color_surface_pressed], tone
	)
	var ink := TaContrast.tone_ink(tone, look.color_surface)
	theme.set_color("font_color", type_name, ink)
	theme.set_color("font_hover_color", type_name, ink)
	theme.set_color("font_focus_color", type_name, ink)
