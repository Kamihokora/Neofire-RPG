class_name TaContrast
extends Object

# AGENT: WCAG colour maths for the builder, its seams, and your own looks.
# INVARIANT: Linearised sRGB luminance (WCAG 2.x). A translucent fill is judged
# composited over a backdrop: over a scene you cannot see, both white and black.
# DO NOT: Guess one backdrop for glass. Do not edit Theme resources here.

## Contrast checks for your look. ratio(), ink_on(), and panel_fill() are what the
## Theme builder uses; check(look) tests a whole generated Theme, the way the kit's
## own looks are held to 4.5:1 text (D39). It needs no nodes and runs anywhere.

const WHITE := Color(1, 1, 1)
const BLACK := Color(0, 0, 0)
## On a settled look: the surface as you set it, so panels start from your alpha.
const _GLASS_META := &"_ta_glass_surface"
const _SURFACES := ["color_surface", "color_surface_hover", "color_surface_pressed"]

## [class, font colour item, stylebox it sits on ("" = page panel)]. A name that is
## not a class is a Label variation. "@Type.box" reads that PanelContainer variation.
const CASES := [
	["Button", "font_color", "normal"], ["Button", "font_hover_color", "hover"],
	["Button", "font_pressed_color", "pressed"], ["Button", "font_focus_color", "normal"],
	["Button", "font_hover_pressed_color", "hover_pressed"],
	["CheckBox", "font_color", "normal"], ["CheckBox", "font_hover_color", "hover"],
	["CheckBox", "font_pressed_color", "pressed"], ["CheckBox", "font_focus_color", "normal"],
	["CheckBox", "font_hover_pressed_color", "hover_pressed"],
	["CheckButton", "font_color", "normal"], ["CheckButton", "font_focus_color", "normal"],
	["CheckButton", "font_hover_pressed_color", "hover_pressed"],
	["LinkButton", "font_color", ""], ["LinkButton", "font_focus_color", ""],
	["LinkButton", "font_hover_color", ""],
	["OptionButton", "font_color", "normal"], ["MenuButton", "font_color", "normal"],
	# MenuButton is flat by default: its label sits on the page.
	["MenuButton", "font_color", ""], ["MenuButton", "font_hover_color", ""],
	["Label", "font_color", ""],
	["LineEdit", "font_color", "normal"], ["LineEdit", "font_placeholder_color", "normal"],
	["LineEdit", "font_selected_color", "normal"],
	["TextEdit", "font_color", "normal"], ["TextEdit", "font_placeholder_color", "normal"],
	["ItemList", "font_color", "panel"], ["ItemList", "font_selected_color", "selected"],
	["ItemList", "font_hovered_color", "hovered"],
	["ItemList", "font_hovered_selected_color", "hovered_selected"],
	["Tree", "font_color", "panel"], ["Tree", "font_selected_color", "selected"],
	["Tree", "title_button_color", "title_button_normal"],
	["Tree", "font_hovered_color", "panel"],
	["TabBar", "font_selected_color", "tab_selected"],
	["TabBar", "font_unselected_color", "tab_unselected"],
	["TabBar", "font_hovered_color", "tab_hovered"],
	["TabContainer", "font_selected_color", "tab_selected"],
	["TabContainer", "font_unselected_color", "tab_unselected"],
	["TabContainer", "font_hovered_color", "tab_hovered"],
	["PopupMenu", "font_color", "panel"], ["PopupMenu", "font_hover_color", "hover"],
	# The value straddles fill and track: the text colour reads on the fill, and its
	# outline (the text colour of the page) carries it over the empty track.
	["ProgressBar", "font_color", "fill"], ["ProgressBar", "font_outline_color", "background"],
	["TooltipLabel", "font_color", "@TooltipPanel.panel"],
	["Label", "font_color", "@PanelContainer.panel"],
	["Label", "font_color", "@TaModal.panel"],
	["Label", "font_color", "@TaWindow.panel"],
	["Label", "font_color", "@TaItemTooltip.panel"],
	["Label", "font_color", "@TaPopover.panel"],
	["Label", "font_color", "@TaHeaderPanel.panel"],
	# Cards (color_card: Framed's cream) carry TaCardText and TaCardCaption.
	["TaCardText", "font_color", "@TaShopCard.panel"],
	["Label", "font_color", "@TaSpeechBubble.panel"],
	["Label", "font_color", "@TaQuestTracker.panel"],
	["TaCardText", "font_color", "@TaChip.panel"],
	["TaCardCaption", "font_color", "@TaChip.panel"],
	["TaCardText", "font_color", "@TaBar.panel"],
	["TaCardText", "font_color", "@TaRadial.panel"],
	["TaCardText", "font_color", "@TaPartyFrame.panel"],
	["TaCaption", "font_color", "@TaModal.panel"],
	["TaCaption", "font_color", "@PanelContainer.panel"],
	["TaSuccessLabel", "font_color", "@TaQuestTracker.panel"],
	["TaDangerLabel", "font_color", "@PanelContainer.panel"],
	["TaWarningLabel", "font_color", "@PanelContainer.panel"],
]


## WCAG relative luminance (linearised sRGB). Plain weighted sRGB overrates
## mid-tone fills and let 1.78:1 panels pass as readable.
static func luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## WCAG contrast ratio, 1 to 21, of two opaque colours (composite glass with over()).
static func ratio(a: Color, b: Color) -> float:
	var l1 := luminance(a) + 0.05
	var l2 := luminance(b) + 0.05
	return maxf(l1, l2) / minf(l1, l2)


## `top` painted over `below` (source-over). Opaque when `below` is; glass over
## glass stays translucent, so worst() can still judge it against the scene.
static func over(top: Color, below: Color) -> Color:
	var a := clampf(top.a, 0.0, 1.0)
	var b := clampf(below.a, 0.0, 1.0) * (1.0 - a)
	var out := a + b
	if out <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
			(top.r * a + below.r * b) / out,
			(top.g * a + below.g * b) / out,
			(top.b * a + below.b * b) / out,
			out
	)


## Contrast of `ink` on `fill` where you cannot see what is behind a translucent
## fill: the worse of the fill over white and over black. Opaque fills are exact.
## A translucent ink is judged as drawn: the fill shows through it.
static func worst(ink: Color, fill: Color) -> float:
	if fill.a >= 1.0:
		return _seen(ink, fill)
	return minf(_seen(ink, over(fill, WHITE)), _seen(ink, over(fill, BLACK)))


## Text or page colour, whichever reads on `fill`. On a light page (Modern) the
## old "light button -> page colour" rule painted cream on cream. Glass is judged
## by its own colour: settle_glass() makes it opaque enough for that ink.
static func ink_on(look: TaTokens, fill: Color) -> Color:
	return ink_between(look.color_text, look.color_bg, fill)


## The one of `first` and `second` that reads better on `fill`, always opaque and
## always 4.5:1: when neither reaches it (a mid-grey tone), it moves toward black or
## white until it does. A translucent page colour must not become faint text.
static func ink_between(first: Color, second: Color, fill: Color) -> Color:
	var shown := Color(fill.r, fill.g, fill.b, 1.0)
	var a := Color(first.r, first.g, first.b, 1.0)
	var b := Color(second.r, second.g, second.b, 1.0)
	var ink := a if ratio(a, shown) >= ratio(b, shown) else b
	if ratio(ink, shown) >= TaDefaults.MIN_TEXT_CONTRAST:
		return ink
	var dark := luminance(ink) <= luminance(shown)
	var end := BLACK if dark else WHITE
	if ratio(end, shown) < TaDefaults.MIN_TEXT_CONTRAST:
		end = WHITE if dark else BLACK
	var t := TaDefaults.INK_PUSH_STEP
	while t < 1.0:
		var pushed := ink.lerp(end, t)
		if ratio(pushed, shown) >= TaDefaults.MIN_TEXT_CONTRAST:
			return pushed
		t += TaDefaults.INK_PUSH_STEP
	return end


## `tone` as text on `fill`: the tone itself when it reads at 4.5:1, else moved toward
## black or white (whichever reads on `fill`) until it does. A tone is a fill colour (a
## Modern warning badge is amber); text in a tone keeps its hue and stays readable.
## Glass is judged like body text: over white and over black (worst()).
static func tone_ink(tone: Color, fill: Color) -> Color:
	var ink := Color(tone.r, tone.g, tone.b, 1.0)
	if worst(ink, fill) >= TaDefaults.MIN_TEXT_CONTRAST:
		return ink
	var end := BLACK if luminance(Color(fill.r, fill.g, fill.b, 1.0)) > 0.18 else WHITE
	var t := TaDefaults.INK_PUSH_STEP
	while t < 1.0:
		var pushed := ink.lerp(end, t)
		if worst(pushed, fill) >= TaDefaults.MIN_TEXT_CONTRAST:
			return pushed
		t += TaDefaults.INK_PUSH_STEP
	return end


## Fill for kit panels, popups, and tooltips that hold plain Labels. color_panel when
## body text, captions, and semantic labels all read on it; else the page moved toward
## the panel color until they do.
## Glass: a translucent panel keeps its alpha when that text reads over any scene
## (white and black behind it); else the alpha rises only as far as it must.
static func panel_fill(look: TaTokens) -> Color:
	var s: Color = look.get_meta(_GLASS_META, look.color_panel)
	var solid := _solid_fill(look, Color(s.r, s.g, s.b, 1.0))
	if s.a >= 1.0:
		return solid
	var a := clampf(s.a, 0.0, 1.0)
	while a < 1.0:
		var glass := Color(solid.r, solid.g, solid.b, a)
		if _reads_over(look, glass, WHITE) and _reads_over(look, glass, BLACK):
			return glass
		a += TaDefaults.GLASS_ALPHA_STEP
	return solid


## The look the builder paints with. Opaque looks come back as they are. A glass look
## (translucent surfaces) comes back as a copy whose button and tab fills are only as
## clear as their text allows over any scene; panels settle separately (panel_fill).
static func settle_glass(look: TaTokens) -> TaTokens:
	var glass := look.color_panel.a < 1.0
	for key in _SURFACES:
		glass = glass or (look.get(key) as Color).a < 1.0
	if not glass:
		return look
	var shown := look.duplicate() as TaTokens
	shown.set_meta(_GLASS_META, look.color_panel)
	for key in _SURFACES:
		var fill: Color = shown.get(key)
		if fill.a < 1.0:
			shown.set(key, _clear_as_text_allows(shown, fill))
	return shown


## Every text pair of your look's Theme at 4.5:1. One line per pair that fails; empty
## means the look passes. Glass is judged over white and black. No nodes and no tree:
## items resolve the way Godot resolves them (variation, its bases, the class and its
## parents; then the project theme, then the default theme), so it runs anywhere,
## including a SceneTree script's _init, a tool script, or CI.
## Edited the Theme after apply_to (a skin that restyles TaToast)? Pass it as `theme`
## (your root's) and that is judged instead; the look still gives the page colour and
## the named tones. Pairs your own types add are yours to check (see worst()).
static func check(look: TaTokens, theme: Theme = null) -> PackedStringArray:
	var out := PackedStringArray()
	var judged := theme if theme != null else TaThemeBuilder.make(look)
	var themes: Array[Theme] = [judged]
	if ThemeDB.get_project_theme() != null:
		themes.append(ThemeDB.get_project_theme())
	themes.append(ThemeDB.get_default_theme())
	var page := box_fill(_stylebox(themes, "panel", "PanelContainer", ""), look.color_bg)
	for c in CASES:
		var cls: String = c[0]
		var item: String = c[1]
		var on: String = c[2]
		# TabBar starts with "Ta" too; only non-classes are Label variations.
		var variation := "" if ClassDB.class_exists(cls) else cls
		var base := "Label" if not variation.is_empty() else cls
		var ink := _color(themes, item, base, variation)
		var fill := page
		if on.begins_with("@"):
			var parts := on.substr(1).split(".")
			fill = box_fill(_stylebox(themes, parts[1], "PanelContainer", parts[0]), page)
		elif not on.is_empty():
			fill = box_fill(_stylebox(themes, on, base, variation), page)
			# A state box (hover, selected) is drawn over the control's own panel.
			var panel := _stylebox(themes, "panel", base, variation)
			if fill.a < 1.0 and on != "panel" and panel != null:
				fill = over(fill, box_fill(panel, page))
		_judge(out, "%s.%s on %s" % [cls, item, on if not on.is_empty() else "page"], ink, fill)
	# Kit chips and cards carry their own ink for their own panel (TaBadgeWarning's
	# font_color on TaBadgeWarning's panel), in every tone and every named look tone.
	for type_name in _kit_inks(look):
		var ink := _color(themes, "font_color", "Label", type_name)
		var fill := box_fill(_stylebox(themes, "panel", "PanelContainer", type_name), page)
		_judge(out, "%s.font_color on panel" % type_name, ink, fill)
	return out


## 1.12.0 name for check(). `host` is no longer needed (pass any node or null); it
## was a live-Control audit that also skipped PopupMenu, which is a Window.
static func audit(_host: Node, look: TaTokens) -> PackedStringArray:
	return check(look)


static func _judge(out: PackedStringArray, what: String, ink: Color, fill: Color) -> void:
	var seen := worst(ink, fill)
	if seen < TaDefaults.MIN_TEXT_CONTRAST:
		out.append("%s: %.2f < %.1f" % [what, seen, TaDefaults.MIN_TEXT_CONTRAST])


## Ink over an opaque `below`: a translucent ink lets `below` through.
static func _seen(ink: Color, below: Color) -> float:
	return ratio(over(ink, below) if ink.a < 1.0 else ink, below)


## Variations that set their own font_color for their own panel.
static func _kit_inks(look: TaTokens) -> PackedStringArray:
	var out := PackedStringArray(["TaShopCardOn"])
	for prefix in ["TaBadge", "TaTag"]:
		for tone in ["", "Muted"] + TaThemeTones.BADGE_TONES:
			out.append(prefix + tone)
	for tone in ["", "Muted"] + TaThemeTones.TOAST_TONES:
		out.append("TaToast" + tone)
	for key in look.tones:
		if look.tones[key] is Color and not String(key).is_empty():
			for prefix in ["TaTag", "TaBadge", "TaToast"]:
				out.append(TaThemeBuilder.tone_type(prefix, String(key)))
	return out


## The types Godot searches for an item: the variation and its bases, then the class
## and its parents.
static func _types(theme: Theme, cls: String, variation: String) -> PackedStringArray:
	var out := PackedStringArray()
	var v := variation
	while not v.is_empty() and not out.has(v):
		out.append(v)
		v = String(theme.get_type_variation_base(v))
	var c := cls
	while not c.is_empty():
		out.append(c)
		c = String(ClassDB.get_parent_class(c))
	return out


static func _color(themes: Array[Theme], item: String, cls: String, variation: String) -> Color:
	var types := _types(themes[0], cls, variation)
	for t in themes:
		for type_name in types:
			if t.has_color(item, type_name):
				return t.get_color(item, type_name)
	return Color.BLACK


static func _stylebox(
		themes: Array[Theme], item: String, cls: String, variation: String
	) -> StyleBox:
	var types := _types(themes[0], cls, variation)
	for t in themes:
		for type_name in types:
			if t.has_stylebox(item, type_name):
				return t.get_stylebox(item, type_name)
	return null


static func _solid_fill(look: TaTokens, s: Color) -> Color:
	if _reads(look, s):
		return s
	var t := TaDefaults.PANEL_LIFT_MAX
	while t > 0.0:
		var fill := look.color_bg.lerp(s, t)
		if _reads(look, fill):
			return Color(fill.r, fill.g, fill.b, 1.0)
		t -= TaDefaults.PANEL_LIFT_STEP
	return Color(look.color_bg.r, look.color_bg.g, look.color_bg.b, 1.0)


## Body text and captions read on `fill`. Tone text is not asked: it is tone_ink, which
## reaches 4.5:1 on its fill by construction.
static func _reads(look: TaTokens, fill: Color) -> bool:
	for ink in [look.color_text, look.color_muted]:
		if ratio(ink, fill) < TaDefaults.MIN_TEXT_CONTRAST:
			return false
	return true


static func _clear_as_text_allows(look: TaTokens, fill: Color) -> Color:
	var ink := ink_on(look, fill)
	var a := clampf(fill.a, 0.0, 1.0)
	while a < 1.0:
		var glass := Color(fill.r, fill.g, fill.b, a)
		if worst(ink, glass) >= TaDefaults.MIN_TEXT_CONTRAST:
			return glass
		a += TaDefaults.GLASS_ALPHA_STEP
	return Color(fill.r, fill.g, fill.b, 1.0)


static func _reads_over(look: TaTokens, glass: Color, below: Color) -> bool:
	return _reads(look, over(glass, below))


## The colour a box shows: a StyleBoxFlat's fill (alpha kept, for glass), a texture's
## centre pixel, else the colour behind it (null, empty, or unreadable boxes).
static func box_fill(box: StyleBox, behind: Color) -> Color:
	if box is StyleBoxFlat and (box as StyleBoxFlat).draw_center:
		var flat := (box as StyleBoxFlat).bg_color
		if flat.a > 0.05:
			return flat
	if box is StyleBoxTexture and (box as StyleBoxTexture).texture != null:
		var img := (box as StyleBoxTexture).texture.get_image()
		if img != null and not img.is_empty():
			var c := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
			if c.a > 0.05:
				return c
	return behind


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
