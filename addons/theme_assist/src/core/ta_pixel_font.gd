class_name TaPixelFont
extends Object

# AGENT: Builds the kit's bitmap faces from TaPixelGlyphs, pre-scaled per screen scale.
# INVARIANT: face(id, s) draws one art pixel as an s x s block, so text sits 1:1 on the
# screen at fixed_size = base_size(id) * s (crisp at rest, smooth under juice scale).
# Faces carry meta "ta_face" so the builder can rebuild them at another scale.
# DO NOT: Antialias. Load an outside font file here. Bitmap-scale a face at draw time.

const GRAIN := "grain"
const GRAIN_SMALL := "grain_small"
## GRAIN thickened to two-pixel stems: the bold pixel face. Small caps stay thin:
## thickening a 3 px capital closes its counters.
const CHUNK := "chunk"
## GRAIN drawn tall and narrow: cap 9, stems still one pixel wide, so a word is a column of
## slim upright letters. The Pixel look's face; with Pixel's text shadow it reads
## bold at card scale without the width of CHUNK.
const TALL := "tall"
const FACES := [GRAIN, GRAIN_SMALL, CHUNK, TALL]
const META_FACE := &"ta_face"
const META_SCALE := &"ta_scale"

## Rows above the baseline (cap height plus air) and below it, per table.
const _GRAIN_ASCENT := 9
const _GRAIN_DESCENT := 2
const _SMALL_ASCENT := 6
const _SMALL_DESCENT := 1
const _GRAIN_CAP := 7
const _SMALL_CAP := 5
const _TALL_ASCENT := 11
const _TALL_CAP := 9
## Cap rows a TALL glyph repeats: one in the upper half, one in the lower (GRAIN row ids).
const _TALL_UPPER := [1, 2]
const _TALL_LOWER := [4, 5]
const _GRAIN_SPACE := 3
const _SMALL_SPACE := 2

static var _cache: Dictionary = {}


## The face `id` with each art pixel drawn as `scale` screen pixels. Cached.
static func face(id: String, scale: int = 1) -> FontFile:
	var s := maxi(1, scale)
	var key := "%s@%d" % [id, s]
	if _cache.has(key) and is_instance_valid(_cache[key]):
		return _cache[key]
	var made := _build(id, s)
	if made != null:
		_cache[key] = made
	return made


## Line height of `id` in art pixels: 11 for the body faces, 13 for TALL, 7 for the
## small one.
static func base_size(id: String) -> int:
	if id == GRAIN_SMALL:
		return _SMALL_ASCENT + _SMALL_DESCENT
	if id == TALL:
		return _TALL_ASCENT + _GRAIN_DESCENT
	return _GRAIN_ASCENT + _GRAIN_DESCENT


## The kit face id of `font`, or "" for any other font.
static func kit_id(font: Font) -> String:
	if font == null or not font.has_meta(META_FACE):
		return ""
	return String(font.get_meta(META_FACE))


## Cap height of a kit face in art px (TaDisplay keeps it 9 px tall on screen); 0 for any
## other font.
static func cap_height(font: Font) -> int:
	match kit_id(font):
		"":
			return 0
		GRAIN_SMALL:
			return _SMALL_CAP
		TALL:
			return _TALL_CAP
		_:
			return _GRAIN_CAP


## `font` ready to draw at `size` screen pixels. A kit face is rebuilt so its pixels
## land 1:1 (size snaps to a whole multiple of the face); other fonts come back as is.
static func at_size(font: Font, size: int) -> Font:
	var id := kit_id(font)
	if id.is_empty():
		return font
	return face(id, snap(id, size) / base_size(id))


## `size` snapped to a whole multiple of the face's line height (at least one).
static func snap(id: String, size: int) -> int:
	var base := base_size(id)
	return maxi(1, roundi(float(size) / float(base))) * base


## The bold sibling of a kit face (GRAIN -> CHUNK), or "" when there is none.
static func bold_of(id: String) -> String:
	return CHUNK if id == GRAIN else ""


static func _build(id: String, s: int) -> FontFile:
	var small := id == GRAIN_SMALL
	var bold := id == CHUNK
	var stretched := id == TALL
	if not FACES.has(id):
		return null
	var table: Dictionary = TaPixelGlyphs.SMALL if small else TaPixelGlyphs.GRAIN
	var ascent := _SMALL_ASCENT if small else (_TALL_ASCENT if stretched else _GRAIN_ASCENT)
	var descent := _SMALL_DESCENT if small else _GRAIN_DESCENT
	var cap := _SMALL_CAP if small else (_TALL_CAP if stretched else _GRAIN_CAP)
	var space := _SMALL_SPACE if small else _GRAIN_SPACE
	var glyphs := {}
	for ch in table:
		var rows: Array = table[ch]
		if bold:
			rows = _bold(String(ch), rows)
		elif stretched:
			rows = _stretch(String(ch), rows)
		glyphs[String(ch)] = rows
	if small:
		for ch in table:
			var lower := String(ch).to_lower()
			if lower != String(ch) and not glyphs.has(lower):
				glyphs[lower] = glyphs[String(ch)]
	var line := ascent + descent
	var size := line * s
	var font := FontFile.new()
	font.fixed_size = size
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.multichannel_signed_distance_field = false
	font.generate_mipmaps = false
	font.allow_system_fallback = true
	var cell := Vector2i(size, 0)
	font.set_cache_ascent(0, size, ascent * s)
	font.set_cache_descent(0, size, descent * s)
	var keys := glyphs.keys()
	var width := 1
	for ch in keys:
		width += (String((glyphs[ch] as Array)[0]).length() + 1) * s
	var tall := 0
	for ch in keys:
		tall = maxi(tall, (glyphs[ch] as Array).size())
	var img := Image.create(width, maxi(1, tall * s), false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var x := 1
	for ch in keys:
		var rows: Array = glyphs[ch]
		var w := String(rows[0]).length()
		var h := rows.size()
		for row in h:
			var line_text := String(rows[row])
			for col in w:
				if line_text[col] == "#":
					img.fill_rect(Rect2i(x + col * s, row * s, s, s), Color(1, 1, 1, 1))
		var code := String(ch).unicode_at(0)
		font.set_glyph_advance(0, size, code, Vector2((w + 1) * s, 0))
		font.set_glyph_offset(0, cell, code, Vector2(0, -cap * s))
		font.set_glyph_size(0, cell, code, Vector2(w * s, h * s))
		font.set_glyph_uv_rect(0, cell, code, Rect2(x, 0, w * s, h * s))
		font.set_glyph_texture_idx(0, cell, code, 0)
		x += (w + 1) * s
	var blank := " ".unicode_at(0)
	font.set_glyph_advance(0, size, blank, Vector2((space + 1) * s, 0))
	font.set_glyph_size(0, cell, blank, Vector2.ZERO)
	font.set_glyph_texture_idx(0, cell, blank, -1)
	font.set_texture_image(0, cell, 0, img)
	font.set_meta(META_FACE, id)
	font.set_meta(META_SCALE, s)
	return font


## A GRAIN glyph two rows taller: it repeats one cap row in the upper half and one in
## the lower, preferring a row that continues a straight stroke, so bowls and crossbars
## keep their place. Lowercase repeats row 1 (blank or ascender), so the x-height grows
## by one. Descender rows are untouched.
static func _stretch(ch: String, rows: Array) -> Array:
	var cap := mini(rows.size(), _GRAIN_CAP)
	if cap < _GRAIN_CAP:
		# Short marks (quotes, a centred dot) keep their shape and sit as drawn.
		return rows
	var lower_case := ch.to_lower() == ch and ch.to_upper() != ch
	var up: int = _TALL_UPPER[0] if lower_case else _straight(rows, _TALL_UPPER)
	var down: int = _straight(rows, _TALL_LOWER)
	var out: Array = []
	for i in rows.size():
		out.append(rows[i])
		if i == up or i == down:
			out.append(rows[i])
	return out


## The first candidate row that repeats a neighbour (a straight stroke), else the first.
static func _straight(rows: Array, candidates: Array) -> int:
	for i in candidates:
		if (i > 0 and rows[i] == rows[i - 1]) or (i + 1 < rows.size() and rows[i] == rows[i + 1]):
			return i
	return candidates[0]


## Thicken a GRAIN glyph by one column, or take its hand-drawn bold form.
static func _bold(ch: String, rows: Array) -> Array:
	if TaPixelGlyphs.CHUNK_FIX.has(ch):
		return TaPixelGlyphs.CHUNK_FIX[ch]
	var out: Array = []
	for row in rows:
		var text := String(row)
		var thick := ""
		for x in text.length() + 1:
			var here := x < text.length() and text[x] == "#"
			var left := x > 0 and text[x - 1] == "#"
			thick += "#" if here or left else "."
		out.append(thick)
	return out
