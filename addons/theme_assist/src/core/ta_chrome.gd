class_name TaChrome
extends Object

# AGENT: Every box the Theme draws, by role, for both families. Called by the builder,
# TaThemeStock, and TaThemeTones. Component layer never calls it.
# INVARIANT: `look` is the on-screen look (TaThemeBuilder.screen): VECTOR metrics are px;
# PIXEL metrics are art px times look.art_scale(), divided back here and drawn as integer
# blocks. A control box keeps its outer size in every state: a press only moves its face
# down into the lip. PIXEL boxes never antialias.
# DO NOT: Tint a bundled sheet. Read TaLook here (the look is passed in).

enum Role {
	## Panels, windows, popups, tooltips: frame, inset, panel fill.
	FRAME,
	## Buttons, tabs: a face on a lip.
	CONTROL,
	## Fields, tracks, list panels: a sunken page-colored well.
	WELL,
	## Bar and slider fills.
	FILL,
	## Badges, tags, selected rows.
	CHIP,
	## Item slots: a framed well.
	SLOT,
	## Header bars and window titles: a fill with an accent stripe under it.
	HEADER,
	## Thin wells: slider, scroll, and progress tracks. Small corners, no frame band.
	TRACK,
	## Tabs: a face with no lip, rounded on top.
	TAB,
	## HUD atoms and cards inside a panel (chip, bar, dial, shop card): a fill with the
	## control border on VECTOR looks, a frame on PIXEL looks.
	CARD,
	## Toasts and callouts: a chip's shape at panel size on VECTOR looks (Modern's slant,
	## lip, and cut corners, like its buttons), a frame on PIXEL looks.
	NOTE,
}

enum State { NORMAL, HOVER, PRESSED, DISABLED }

## Alpha of a PIXEL drop shadow (solid, like a card on a table).
const _PIXEL_SHADOW_ALPHA := 0.6
## A ribbon tag's notch depth and a selection bracket's arm, in art px.
const _RIBBON_NOTCH := 3
const _BRACKET_ARM := 3
## Largest corner a PIXEL tag or badge takes (a slab, not a pill).
const _CHIP_RADIUS_MAX := 3
## How much lighter a bevel row is, and how much darker a lip or a well's top row.
const _BEVEL_LIFT := 0.16
const _LIP_SHADE := 0.62
const _WELL_SHADE := 0.55
## A bevelled frame is wood: the line colour in shade under a lit edge (the reference wood frame's
## window: #94704a lit, #6e5034 band, #4a3421 foot). 2.2 drew the line colour itself and
## read as bright brass.
const _WOOD_LIT := 0.88
const _WOOD := 0.65
const _WOOD_FOOT := 0.44
## The surface's own edge inside a bevelled frame: barely lit on top and left, shaded
## at the foot and right.
const _INNER_LIFT := 0.05
const _INNER_SHADE := 0.75

static var _cache: Dictionary = {}


## A StyleBox for `role`: filled with `fill`, lined with `line`, `margin` screen px of
## content padding (before the lip).
static func box(
		look: TaTokens,
		role: Role,
		fill: Color,
		line: Color,
		margin: int,
		state: State = State.NORMAL
	) -> StyleBox:
	if look.is_pixel():
		return _pixel_box(look, role, fill, line, margin, state)
	return _vector_box(look, role, fill, line, margin, state)


## Outline-only focus box. Godot draws focus over the control, so it never fills.
## `slanted` follows the look's skew (buttons, tabs); fields stay square.
static func ring(look: TaTokens, slanted: bool = false) -> StyleBox:
	if look.is_pixel():
		return _pixel_ring(look)
	var r := StyleBoxFlat.new()
	r.draw_center = false
	r.border_color = look.color_accent
	r.set_border_width_all(maxi(1, look.focus_width))
	r.set_expand_margin_all(look.px(TaDefaults.FOCUS_RING_GAP))
	r.set_corner_radius_all(look.radius + look.px(TaDefaults.FOCUS_RING_GAP))
	r.corner_detail = 1 if look.chamfer else 8
	if slanted:
		r.skew = Vector2(look.skew, 0)
	r.anti_aliasing = true
	return r


static func _vector_box(
		look: TaTokens,
		role: Role,
		fill: Color,
		line: Color,
		margin: int,
		state: State
	) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = line
	b.anti_aliasing = true
	b.corner_detail = 1 if look.chamfer else 8
	b.set_content_margin_all(margin)
	var w := look.border_width
	# Inside a frame: the control border (0 on Flat and Modern, so lines never nest). A
	# hovered, pressed, or selected well or slot shows its state as a line of focus width.
	var cw := look.control_border
	var hot := state == State.HOVER or state == State.PRESSED
	var r := look.radius
	match role:
		Role.FRAME:
			b.set_border_width_all(w)
			# A cut the size of a button's reads as a rounded corner on a whole panel.
			b.set_corner_radius_all(r * 2 if look.chamfer else r)
		Role.CARD:
			b.set_border_width_all(cw)
			b.set_corner_radius_all(r)
		Role.CONTROL:
			b.set_border_width_all(cw)
			b.set_corner_radius_all(r)
			b.skew = Vector2(look.skew, 0)
			_vector_lip(b, look, state, fill)
		Role.WELL, Role.SLOT, Role.TRACK:
			var edge := maxi(cw, look.focus_width) if hot and role != Role.TRACK else cw
			b.set_border_width_all(edge)
			b.set_corner_radius_all(mini(r, look.px(2)) if role == Role.TRACK else r)
		Role.TAB:
			b.set_border_width_all(cw)
			b.corner_radius_top_left = r
			b.corner_radius_top_right = r
			b.skew = Vector2(look.skew, 0)
		Role.FILL:
			b.set_border_width_all(0)
			b.set_corner_radius_all(mini(r, look.px(2)))
		Role.CHIP:
			# A tag or badge is a small button: the look's corners (never a pill), and on
			# Modern the same slant and lip. Cut corners scale down with the chip, so a
			# chamfer never turns a badge into a hexagon.
			b.set_border_width_all(cw)
			var cut := mini(r, look.px(TaDefaults.CHIP_RADIUS_MIN)) if look.chamfer else r
			b.set_corner_radius_all(cut)
			b.skew = Vector2(look.skew, 0)
			_vector_lip(b, look, state, fill)
			if look.lip > 0 and cw <= 0:
				# A lip alone did not separate a badge from a slot of its own colour: the
				# lip's shade runs round the whole chip, the lip stays deeper at the foot.
				var rim := maxi(1, look.px(1))
				b.border_width_left = rim
				b.border_width_top = rim
				b.border_width_right = rim
			var ends := ceili(look.skew * (margin * 2 + look.font_size_caption))
			b.content_margin_left += ends
			b.content_margin_right += ends
		Role.NOTE:
			b.set_border_width_all(cw)
			b.set_corner_radius_all(r)
			b.skew = Vector2(look.skew, 0)
			_vector_lip(b, look, state, fill)
			var slant := ceili(look.skew * (margin * 2 + look.font_size))
			b.content_margin_left += slant
			b.content_margin_right += slant
		Role.HEADER:
			b.set_border_width_all(0)
			b.border_width_bottom = look.accent_bar
			b.corner_radius_top_left = r
			b.corner_radius_top_right = r
	# A cut corner on a box that does not slant draws in hard steps: antialiased, a frame's
	# 1 px diagonal went grey and read as a soft round corner at 1080.
	if look.chamfer and is_zero_approx(b.skew.x):
		b.anti_aliasing = false
	if look.shadow_size > 0 and (role == Role.FRAME or role == Role.CONTROL):
		b.shadow_color = Color(look.color_shadow, TaDefaults.SHADOW_ALPHA)
		b.shadow_size = look.shadow_size
		b.shadow_offset = TaDefaults.SHADOW_OFFSET * look.display_px
	return b


## The lip is extra border at the bottom, a deep shade of the face (the face's own edge,
## like a key). A press collapses it and moves the face down by the same amount, so the
## outer size never changes.
static func _vector_lip(b: StyleBoxFlat, look: TaTokens, state: State, fill: Color) -> void:
	var lip := look.lip
	if lip <= 0:
		return
	if look.control_border <= 0:
		b.border_color = _shade(fill, _LIP_SHADE)
	if state == State.PRESSED:
		b.expand_margin_top = -lip
		b.content_margin_top += lip
	else:
		b.border_width_bottom = look.control_border + lip
		b.content_margin_bottom += lip


static func _pixel_box(
		look: TaTokens,
		role: Role,
		fill: Color,
		line: Color,
		margin: int,
		state: State
	) -> StyleBoxTexture:
	var s := look.art_scale()
	var art := _art(look, role, state)
	var key := "%s|%d|%s|%s|%s|%s|%d" % [
		role, state, fill.to_html(), line.to_html(), look.color_shadow.to_html(), art, s,
	]
	var tex: Texture2D = _cache.get(key)
	if tex == null or not is_instance_valid(tex):
		tex = _paint(art, fill, line, look.color_shadow, role, state, s)
		_cache[key] = tex
	var box := StyleBoxTexture.new()
	box.texture = tex
	var corner: int = art["corner"]
	box.texture_margin_left = corner * s
	box.texture_margin_right = (corner + art["notch"]) * s
	box.texture_margin_top = (corner + art["top"]) * s
	box.texture_margin_bottom = (corner + art["lip"] + art["shadow"]) * s
	box.expand_margin_bottom = art["shadow"] * s
	box.expand_margin_top = 0
	# What a box holds starts inside its frame with an art pixel of air: a Framed bar's
	# "HP" sat on the frame's dark inset line when the band grew past the card's margin.
	var frame: int = art["edge"] + art["band"] + art["inset"] + (1 if art["bevel"] else 0)
	if frame > 0 and margin > 0 and role != Role.TRACK and role != Role.FILL:
		margin = maxi(margin, (frame + 1) * s)
	box.set_content_margin_all(margin)
	box.content_margin_top += art["top"] * s
	box.content_margin_bottom += art["lip"] * s
	box.content_margin_right += art["notch"] * s
	box.draw_center = true
	return box


## Art-pixel geometry for a role and state.
static func _art(look: TaTokens, role: Role, state: State) -> Dictionary:
	var s := look.art_scale()
	var radius := look.radius / s
	var edge := look.edge / s
	var band := look.border_width / s
	var inset := look.inset / s
	var lip := look.lip / s
	var shadow := look.shadow_size / s
	var notch := 0
	var brackets := false
	# Pixel-family windows read as framed cards: a wooden band with a lit edge on top and
	# left and a shaded one at the foot and right, then the dark inset and the surface's
	# own edge (the old wood-framed windows).
	var bevel := false
	match role:
		Role.CONTROL:
			band = 0
			inset = 0
		Role.CHIP:
			band = 0
			inset = 0
			lip = 0
			shadow = 0
			radius = mini(radius, _CHIP_RADIUS_MAX)
			if look.chip_ribbon:
				radius = 0
				notch = _RIBBON_NOTCH
		Role.TAB:
			band = 0
			inset = 0
			lip = 0
			shadow = 0
		Role.CARD, Role.NOTE:
			lip = 0
		Role.WELL:
			band = 0
			inset = 0
			lip = 0
			shadow = 0
		Role.SLOT:
			band = maxi(1, mini(band, 1))
			inset = 0
			lip = 0
			shadow = 0
			# Selected or hovered: gold corner brackets over the usual band.
			brackets = look.select_brackets and state != State.NORMAL and state != State.DISABLED
		Role.TRACK:
			band = 0
			inset = 0
			lip = 0
			shadow = 0
			radius = mini(radius, 1)
		Role.FILL:
			edge = 0
			band = 0
			inset = 0
			lip = 0
			shadow = 0
			radius = mini(radius, 1)
		Role.HEADER:
			edge = 0
			band = 0
			inset = 0
			lip = 0
			shadow = 0
			radius = 0
		Role.FRAME:
			lip = 0
			bevel = band > 0
			if bevel:
				# The bevel row sits outside the band: 1 lit row + a 3-row band.
				band += 1
	var top := 0
	if state == State.PRESSED and lip > 0:
		top = lip
		lip = 0
	var thin := role == Role.TRACK or role == Role.FILL
	var corner := maxi(radius, edge + band + inset) + (1 if thin else 2)
	return {
		"radius": radius, "edge": edge, "band": band, "inset": inset, "lip": lip,
		"shadow": shadow, "top": top, "corner": corner,
		"accent_bar": (look.accent_bar / s) if role == Role.HEADER else 0,
		"notch": notch, "brackets": brackets, "bevel": bevel,
		"bracket": look.color_accent.to_html(),
	}


static func _paint(
		art: Dictionary,
		fill: Color,
		line: Color,
		shadow_color: Color,
		role: Role,
		state: State,
		s: int
	) -> ImageTexture:
	var corner: int = art["corner"]
	var lip: int = art["lip"]
	var top: int = art["top"]
	var shadow: int = art["shadow"]
	var notch: int = art["notch"]
	var w := corner * 2 + 2 + notch
	var face_h := corner * 2 + 2 + lip
	var h := top + face_h + shadow
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mask := _rounded(w, face_h, art["radius"])
	if notch > 0:
		_notch(mask, w, face_h, notch)
	if shadow > 0:
		var shade := Color(shadow_color, _PIXEL_SHADOW_ALPHA)
		for y in face_h:
			for x in w:
				if mask[y * w + x]:
					img.set_pixel(x, top + y + shadow, shade)
	var depth := _depths(mask, w, face_h)
	var edge: int = art["edge"]
	var band: int = art["band"]
	var inset: int = art["inset"]
	var inner := edge + band + inset
	var dark := Color(shadow_color, 1.0)
	var hi := _lift(fill)
	var lip_color := _shade(fill, _LIP_SHADE)
	var band_hi := _lift(line)
	var wood := _shade(line, _WOOD)
	var wood_lit := _shade(line, _WOOD_LIT)
	var wood_foot := _shade(line, _WOOD_FOOT)
	var bevel: bool = art["bevel"]
	var bar: int = art["accent_bar"]
	for y in face_h:
		for x in w:
			var d: int = depth[y * w + x]
			if d < 0:
				continue
			var c := fill
			# Nearest side: top or left lights, bottom or right shades.
			var lit := mini(x, y) <= mini(w - 1 - x, face_h - 1 - y)
			if d < edge:
				c = dark
			elif d < edge + band:
				if bevel:
					# Lit edge, wood, wood; at the foot and right a shaded row each side.
					var k := d - edge
					c = wood
					if lit and k == 0:
						c = wood_lit
					elif not lit and (k == 0 or k == band - 1):
						c = wood_foot
				else:
					c = band_hi if (y == edge and band > 1) else line
			elif d < inner:
				c = dark.lerp(fill, 0.25)
			elif bevel and d == inner:
				c = _lift(fill, _INNER_LIFT) if lit else _shade(fill, _INNER_SHADE)
			elif y >= face_h - edge - lip:
				c = lip_color
			elif role == Role.WELL or role == Role.SLOT or role == Role.TRACK:
				c = _shade(fill, _WELL_SHADE) if y == inner else fill
			elif role == Role.HEADER:
				c = line if y >= face_h - bar else fill
			elif role == Role.TAB and state == State.HOVER and y == inner:
				# The selected tab: an accent row along its top.
				c = line
			elif y == inner and state != State.DISABLED:
				c = hi
			elif role == Role.FILL and y == face_h - 1:
				c = lip_color
			img.set_pixel(x, top + y, c)
	if art["brackets"]:
		_brackets(img, Rect2i(0, top, w, face_h), Color(String(art["bracket"])), 1)
	if s > 1:
		img.resize(w * s, h * s, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Cut a swallowtail into the right end of `mask`: a ribbon tag.
static func _notch(mask: PackedByteArray, w: int, h: int, depth: int) -> void:
	var mid := (h - 1) / 2.0
	for y in h:
		var cut := maxi(0, depth - int(absf(y - mid)))
		for x in range(w - cut, w):
			mask[y * w + x] = 0


## Gold corner brackets (an L at each corner of `rect`, `thick` art px).
static func _brackets(img: Image, rect: Rect2i, color: Color, thick: int) -> void:
	var arm := mini(_BRACKET_ARM, mini(rect.size.x, rect.size.y) / 2)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x - thick
	var y1 := rect.end.y - thick
	for t in thick:
		for i in arm:
			for p in [
				Vector2i(x0 + i, y0 + t), Vector2i(x0 + t, y0 + i),
				Vector2i(x1 - i + thick - 1, y0 + t), Vector2i(x1 + t, y0 + i),
				Vector2i(x0 + i, y1 + t), Vector2i(x0 + t, y1 - i + thick - 1),
				Vector2i(x1 - i + thick - 1, y1 + t), Vector2i(x1 + t, y1 - i + thick - 1),
			]:
				img.set_pixelv(p, color)


## Inside mask of a w x h rectangle with pixel-rounded corners of `radius`.
static func _rounded(w: int, h: int, radius: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in h:
		for x in w:
			mask[y * w + x] = 1 if _inside(x, y, w, h, radius) else 0
	return mask


## Outside the corner cut: the edge row cuts `r` art px and each row in cuts half the
## row before it, so radius 4 cuts 4, 2, 1 (12, 6, 3 screen px at art scale 3), radius 1
## a notch. A stepped cut, not a quarter circle: a circle (4, 2, 1, 1 at radius 5) reads as
## an app button.
static func _inside(x: int, y: int, w: int, h: int, r: int) -> bool:
	if r <= 0:
		return true
	var row := mini(y, h - 1 - y)
	var col := mini(x, w - 1 - x)
	return col >= (r >> mini(row, 30))


## Depth of each inside pixel from the shape's edge (4-neighbour erosion); -1 outside.
static func _depths(mask: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var depth := PackedInt32Array()
	depth.resize(w * h)
	var live := mask.duplicate()
	for i in w * h:
		depth[i] = -1 if mask[i] == 0 else 0
	var level := 0
	while true:
		var next := live.duplicate()
		var any := false
		for y in h:
			for x in w:
				var i := y * w + x
				if live[i] == 0:
					continue
				var keep := (
						x > 0 and x < w - 1 and y > 0 and y < h - 1
						and live[i - 1] == 1 and live[i + 1] == 1
						and live[i - w] == 1 and live[i + w] == 1
				)
				if keep:
					any = true
					depth[i] = level + 1
				else:
					next[i] = 0
		live = next
		level += 1
		if not any or level > maxi(w, h):
			break
	return depth


static func _pixel_ring(look: TaTokens) -> StyleBoxTexture:
	var s := look.art_scale()
	var fw := maxi(1, look.focus_width / s)
	var gap := 1
	var radius := look.radius / s + fw + gap
	var brackets := look.select_brackets
	var key := "ring|%s|%d|%d|%d|%s" % [look.color_accent.to_html(), fw, radius, s, brackets]
	var tex: Texture2D = _cache.get(key)
	if tex == null or not is_instance_valid(tex):
		var corner := radius + fw + 1
		var w := corner * 2 + 2
		var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		if brackets:
			# Framed focus: gold corner brackets, as on its focused buttons.
			_brackets(img, Rect2i(0, 0, w, w), look.color_accent, fw)
		else:
			var mask := _rounded(w, w, radius)
			var depth := _depths(mask, w, w)
			for i in w * w:
				var d: int = depth[i]
				if d >= 0 and d < fw:
					img.set_pixel(i % w, i / w, look.color_accent)
		if s > 1:
			img.resize(w * s, w * s, Image.INTERPOLATE_NEAREST)
		tex = ImageTexture.create_from_image(img)
		_cache[key] = tex
	var box := StyleBoxTexture.new()
	box.texture = tex
	var c := (radius + fw + 1) * s
	box.texture_margin_left = c
	box.texture_margin_right = c
	box.texture_margin_top = c
	box.texture_margin_bottom = c
	box.set_expand_margin_all((fw + gap) * s)
	box.draw_center = false
	return box


static func _lift(c: Color, k: float = _BEVEL_LIFT) -> Color:
	return Color(minf(c.r + k, 1.0), minf(c.g + k, 1.0), minf(c.b + k * 0.8, 1.0), c.a)


static func _shade(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)
