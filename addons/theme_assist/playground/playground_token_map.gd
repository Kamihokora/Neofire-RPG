extends Object

# AGENT: Token → widget copy for the playground lab.
# INVARIANT: affects(key) is non-empty for every TaTokens knob the lab exposes.
# DO NOT: Per-control Theme overrides. This is discoverability, not a DSL.

const AFFECTS := {
	"color_bg": "Page: backdrops, fields, tracks, list wells, idle tabs",
	"ui_scale": "Size of the whole UI in every preset; the kit multiplies it by the display",
	"color_panel": "Panels, windows, popovers, tooltips",
	"color_card": "Cards inside panels: chips, bars, dials, shop cards, toasts (Framed: cream)",
	"color_rarity": "Rare items and the Rarity tone of badges and tags",
	"color_surface": "Buttons, option buttons, default badges and tags",
	"color_text": "Ink: labels and body text; button text is picked to read",
	"color_accent": "Focus, selection, fills, sliders, TaPrimary buttons, hover lines",
	"color_border": "Outlines, frames (the brass band in Framed), separators",
	"color_shadow": "Pixel edges, inset lines, drop shadows, text shadow",
	"color_muted": "TaCaption, muted badges, hints",
	"color_danger": "TaDanger buttons, labels, chips",
	"color_success": "TaSuccess buttons, labels, chips",
	"color_warning": "TaWarning buttons, labels, chips",
	"color_surface_hover": "Hovered buttons, selected rows",
	"color_surface_pressed": "Pressed buttons",
	"color_disabled_bg": "Disabled button fill",
	"color_disabled_text": "Disabled button text",
	"face": "Body face. Pixel faces stay crisp at whole multiples of their size",
	"face_title": "TaTitle, window and dialog titles",
	"face_bold": "TaBold and [b] in rich text (none: derived from the face)",
	"face_caption": "TaCaption, badges, tags (Grain Small is Framed's small caps)",
	"font_size_title": "TaTitle",
	"font_size": "Body labels and buttons",
	"font_size_caption": "TaCaption, badges, cell titles",
	"title_tracking": "Extra space between title letters",
	"text_shadow": "Shadow under light label text (px; Pixel uses it)",
	"outline_size": "Label font outline",
	"family": "Vector draws smooth boxes; Pixel draws generated integer chrome",
	"pixel_scale": "Pixel family: screen px per art px at 1080; rounded with the display",
	"radius": "Corner rounding (Pixel: rounded pixel steps)",
	"chamfer": "Cut corners instead of round ones (Vector)",
	"border_width": "Frames: panels, windows, dialogs (the band on Pixel frames)",
	"control_border": "Border of what sits in a frame: buttons, fields, slots, tags (0: fill only)",
	"chip_ribbon": "Tags and badges end in a notched ribbon (Pixel family)",
	"select_brackets": "Selection and focus as corner brackets (Pixel family)",
	"title_mark": "A small framed mark before window and header titles",
	"edge": "Dark outline around Pixel frames and buttons",
	"inset": "Dark line inside Pixel frames",
	"lip": "Pressable depth under buttons; a press drops into it",
	"shadow_size": "Drop shadow under panels and buttons (0 = off)",
	"skew": "Slant of buttons and tabs (Vector)",
	"accent_bar": "Accent stripe under header bars and window titles",
	"content_margin": "Inner padding on buttons, fields, chips",
	"panel_margin": "Inner padding on panels, windows, dialogs",
	"button_min_height": "Button and bar height",
	"focus_width": "Focus ring thickness",
	"motion_hover_scale": "Hover lift",
	"motion_press_scale": "Press squash",
	"motion_hover_tilt": "Hover lean in degrees (the Pixel wobble)",
	"fanfare": "Punch and shake strength",
	"motion_hover_seconds": "Hover tween time",
	"motion_press_seconds": "Press / punch time",
	"motion_open_seconds": "Open / fade / wipe cover time",
	"motion_roll_seconds": "Number roll time",
	"toast_seconds": "TaToast hold",
	"dimmer_alpha": "Pause / dialog veil",
	"dimmer_blur": "Backdrop blur behind pause / modal veils (0 = off)",
	"crt_intensity": "Scanline overlay (an effect; off in every preset)",
}


static func affects(key: String) -> String:
	if AFFECTS.has(key):
		return "Affects: %s" % String(AFFECTS[key])
	return "Affects: the whole Theme"
