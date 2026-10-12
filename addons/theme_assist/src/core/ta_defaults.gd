class_name TaDefaults
extends Object

# AGENT: Sole factory knobs. Theme builder and juice read these.
# INVARIANT: FLAT is what TaTokens.new() holds. Every preset dict has every look key.
# DO NOT: Copy a Color or duration into a widget or demo beyond this class.

const PLUGIN_ID := "theme_assist"
## Line we develop on (latest stable at scaffold).
const DEV_GODOT := "4.7"
## Oldest Godot we claim without a 4.7-only API in the builder.
const MIN_GODOT := "4.4"

# The four presets (2.0). Each is a whole token set: TaTokens.preset(id) copies one onto
# TaTokens.new(), whose export defaults are FLAT. Metrics of the PIXEL family (Framed,
# Pixel) are in art pixels; pixel_scale turns one art pixel into that many screen pixels.
# Fonts are not here: they are objects, so the factories in TaTokens set them.

## Flat: the factory default, a game panel nobody has decorated yet. One border, on the
## panel only: what sits inside it (buttons, fields, tracks, slots, tags) is told apart by
## fill. No shadow, slant, lip, or accent bar; near-square corners; neutral charcoal and a
## signal-yellow accent. Hover and press are a colour change, not a bounce. Two type
## levels: a SemiBold title and a Medium body (captions are body size, muted).
const FLAT := {
	"look_id": "flat",
	"ui_scale": 1.0,
	"family": 0,
	"color_bg": Color("#121417"),
	"color_panel": Color("#1b1f24"),
	"color_card": Color("#1b1f24"),
	"color_surface": Color("#23282e"),
	"color_surface_hover": Color("#2d333b"),
	"color_surface_pressed": Color("#191c21"),
	"color_text": Color("#e8eaed"),
	"color_muted": Color("#9ba3ad"),
	"color_accent": Color("#f2c14e"),
	"color_border": Color("#58616d"),
	"color_shadow": Color("#000000"),
	"color_danger": Color("#ef5b5b"),
	"color_success": Color("#46c08a"),
	"color_warning": Color("#f29e4c"),
	"color_rarity": Color("#a07ae6"),
	"color_disabled_bg": Color("#1a1d21"),
	"color_disabled_text": Color("#5f6670"),
	"radius": 2,
	"chamfer": false,
	"border_width": 1,
	"control_border": 0,
	"edge": 0,
	"inset": 0,
	"lip": 0,
	"shadow_size": 0,
	"skew": 0.0,
	"accent_bar": 0,
	"chip_ribbon": false,
	"select_brackets": false,
	"title_mark": false,
	"content_margin": 10,
	"panel_margin": 14,
	"button_min_height": 36,
	"focus_width": 2,
	"outline_size": 0,
	"text_shadow": 0,
	"font_size": 16,
	"font_size_title": 24,
	"font_size_caption": 16,
	"title_tracking": 0,
	"pixel_scale": 1,
	"motion_hover_scale": 1.0,
	"motion_press_scale": 1.0,
	"motion_hover_tilt": 0.0,
	"fanfare": 0.6,
}

## Modern: Flat after someone committed to a style. The same border weight and layout,
## light, then cut corners, a press lip and a slant on buttons, tabs, and badges, an
## accent rule under headers, tracked titles, louder fanfare. Shadow, glass, and blur
## stay off (tokens turn them on).
const MODERN := {
	"look_id": "modern",
	"ui_scale": 1.0,
	"family": 0,
	"color_bg": Color("#e9e6df"),
	"color_panel": Color("#faf8f4"),
	"color_card": Color("#faf8f4"),
	"color_surface": Color("#e4ded3"),
	"color_surface_hover": Color("#f1d5ca"),
	"color_surface_pressed": Color("#d5cec1"),
	"color_text": Color("#1d1f23"),
	"color_muted": Color("#575c64"),
	"color_accent": Color("#cf3a20"),
	"color_border": Color("#1d1f23"),
	"color_shadow": Color("#1d1f23"),
	"color_danger": Color("#d22b3e"),
	"color_success": Color("#2f9d5b"),
	"color_warning": Color("#f0a81c"),
	"color_rarity": Color("#6a3db8"),
	"color_disabled_bg": Color("#e1ddd5"),
	"color_disabled_text": Color("#8d8981"),
	"radius": 7,
	"chamfer": true,
	"border_width": 1,
	"control_border": 0,
	"edge": 0,
	"inset": 0,
	"lip": 3,
	"shadow_size": 0,
	"skew": 0.18,
	"accent_bar": 4,
	"chip_ribbon": false,
	"select_brackets": false,
	"title_mark": false,
	"content_margin": 12,
	"panel_margin": 18,
	"button_min_height": 42,
	"focus_width": 3,
	"outline_size": 0,
	"text_shadow": 0,
	"font_size": 17,
	"font_size_title": 28,
	"font_size_caption": 13,
	"title_tracking": 3,
	"pixel_scale": 1,
	"motion_hover_scale": 1.04,
	"motion_press_scale": 0.95,
	"motion_hover_tilt": 0.0,
	"fanfare": 1.2,
}

## Framed: the hybrid, between Pixel and Modern. Thick wood frame, inset, framed slots. Its own
## frame language: windows are framed cards (a dark outline, a beveled dark-wood band, a
## dark inset line, the surface's own edge, a warm dark surface), cream cards inside them,
## ribbon tags, gold corner brackets on what is selected or focused, a framed mark before
## titles, a thin mixed-case pixel face with small-caps captions.
const FRAMED := {
	"look_id": "framed",
	"ui_scale": 1.0,
	"family": 1,
	"color_bg": Color("#17130f"),
	"color_panel": Color("#2e261d"),
	"color_card": Color("#e6d9bb"),
	"color_surface": Color("#3d3329"),
	"color_surface_hover": Color("#4e4234"),
	"color_surface_pressed": Color("#2f271f"),
	"color_text": Color("#efe3c6"),
	"color_muted": Color("#b4a27e"),
	"color_accent": Color("#dba642"),
	"color_border": Color("#a98149"),
	"color_shadow": Color("#0d0a08"),
	"color_danger": Color("#de6b5e"),
	"color_success": Color("#86bd5c"),
	"color_warning": Color("#e7c661"),
	"color_rarity": Color("#a385d6"),
	"color_disabled_bg": Color("#2a241e"),
	"color_disabled_text": Color("#776a57"),
	"radius": 1,
	"chamfer": false,
	"border_width": 3,
	"control_border": 1,
	"edge": 1,
	"inset": 1,
	"lip": 1,
	"shadow_size": 0,
	"skew": 0.0,
	"accent_bar": 0,
	"chip_ribbon": true,
	"select_brackets": true,
	"title_mark": true,
	"content_margin": 4,
	"panel_margin": 7,
	"button_min_height": 20,
	"focus_width": 1,
	"outline_size": 0,
	"text_shadow": 0,
	"font_size": 11,
	"font_size_title": 22,
	"font_size_caption": 7,
	"title_tracking": 0,
	"pixel_scale": 2,
	"motion_hover_scale": 1.0,
	"motion_press_scale": 1.0,
	"motion_hover_tilt": 0.0,
	"fanfare": 0.8,
}

## Pixel: the chunky game end. Filled slabs with a stepped corner cut on a slate table with a
## solid drop shadow and no outline; grey neutral buttons and colored calls to action on a
## deep lip; the selected tab is the coloured one; a tall narrow face with a text shadow at
## card scale; hover wobble and punchy presses.
const PIXEL := {
	"look_id": "pixel",
	"ui_scale": 1.0,
	"family": 1,
	"color_bg": Color("#1f2c2f"),
	"color_panel": Color("#34474c"),
	"color_card": Color("#26363c"),
	"color_surface": Color("#4b5d64"),
	"color_surface_hover": Color("#5b6f77"),
	"color_surface_pressed": Color("#3d4c52"),
	"color_text": Color("#ffffff"),
	"color_muted": Color("#b3c3c6"),
	"color_accent": Color("#fda200"),
	"color_border": Color("#58737a"),
	"color_shadow": Color("#0b1213"),
	"color_danger": Color("#ff6a5c"),
	"color_success": Color("#4bc292"),
	"color_warning": Color("#eac058"),
	"color_rarity": Color("#a782d1"),
	"color_disabled_bg": Color("#2a3a3e"),
	"color_disabled_text": Color("#6f8589"),
	"radius": 4,
	"chamfer": false,
	"border_width": 0,
	"control_border": 0,
	"edge": 0,
	"inset": 0,
	"lip": 2,
	"shadow_size": 2,
	"skew": 0.0,
	"accent_bar": 0,
	"chip_ribbon": false,
	"select_brackets": false,
	"title_mark": false,
	"content_margin": 4,
	"panel_margin": 5,
	"button_min_height": 23,
	"focus_width": 1,
	"outline_size": 0,
	"text_shadow": 1,
	"font_size": 13,
	"font_size_title": 26,
	"font_size_caption": 7,
	"title_tracking": 0,
	"pixel_scale": 3,
	"motion_hover_scale": 1.06,
	"motion_press_scale": 0.94,
	"motion_hover_tilt": 2.5,
	"fanfare": 1.5,
}

## Preset ids in ladder order: clean to chunky.
const PRESETS := ["flat", "modern", "framed", "pixel"]

## Where the Playground saves your look (tokens) and the Theme made from it. The editor
## plugin points the project theme (gui/theme/custom) at THEME_PATH, so every Control in
## the project wears it with no code.
const SAVE_DIR := "res://theme_assist/"
const SAVE_LOOK := "look.tres"
const SAVE_THEME := "theme.res"

## HD fallbacks for code that has no look yet.
const FONT_SIZE := 16
const FONT_SIZE_TITLE := 24
const FONT_SIZE_CAPTION := 13
const BORDER_WIDTH := 1
const FOCUS_BORDER_WIDTH := 2
const CONTENT_MARGIN := 10
const PANEL_MARGIN := 14
const BUTTON_MIN_HEIGHT := 36
const SLIDER_TRACK_HEIGHT := 6
## Slider thumb diameter: larger than the track, so there is something to grab.
const SLIDER_KNOB := 20
const OUTLINE_SIZE := 0
## VECTOR chips (badges, tags) round to twice the larger of the look radius and this.
const CHIP_RADIUS_MIN := 4
## Vector shadow (when a look turns shadow_size on): offset and alpha.
const SHADOW_OFFSET := Vector2(0, 3)
const SHADOW_ALPHA := 0.35

# PIXEL family sizes for kit widgets, in art pixels (times pixel_scale on screen).
const PIXEL_SLIDER_TRACK_HEIGHT := 4
const PIXEL_SLIDER_KNOB := 10
const PIXEL_CONTENT_MARGIN := 4
const PIXEL_PANEL_MARGIN := 6
## Art size of a caption in a kit widget (slot count, icon-grid caption): the small face.
const PIXEL_FONT_SIZE_CAPTION := 7
## A bare pixel button: 4 + 4 px margin, a 1 to 2 px lip, the 11 px Grain line.
const PIXEL_BUTTON_MIN_HEIGHT := 20
const PIXEL_SLOT_SIZE := 22
## Display fit (TaDisplay): every size in a look is drawn for a canvas this many px tall;
## the kit scales the look with the real canvas height (and look.ui_scale).
const REFERENCE_HEIGHT := 1080.0
## Smallest glyph the kit draws, in screen px (Steam Deck guidance: no character under
## 9 px tall at 1280x800). Caps the downscale on small displays.
const MIN_GLYPH_PX := 9.0
## Cap height of a vector face as a share of its font size (Barlow, most UI sans).
const CAP_HEIGHT := 0.7
## VECTOR scales move in steps of this, so a window drag rebuilds a few times, not per px.
const SCALE_STEP := 0.125
## Largest art scale a PIXEL look reaches on a big display.
const ART_SCALE_MAX := 12
const PIXEL_SEPARATION := 3
## Mark (check box, arrow) art size, and its HD size in screen pixels.
const PIXEL_MARK := 8
const MARK := 14
const ARROW := 12
const CRT_INTENSITY := 0.12
const CRT_LINE_COUNT := 360.0

# Motion (seconds).
const MOTION_HOVER_SECONDS := 0.12
const MOTION_PRESS_SECONDS := 0.08
const MOTION_OPEN_SECONDS := 0.18
const MOTION_HOVER_SCALE := 1.0
const MOTION_PRESS_SCALE := 0.98
const MOTION_OPEN_SCALE := 0.92
const MOTION_LIFT_PIXELS := 2
const MOTION_SLIDE_PIXELS := 16
const CRT_TINT := Color(0.02, 0.04, 0.03, 1.0)
const MOTION_PUNCH_PIXELS := 4
const MOTION_SHAKE_PIXELS := 6
const MOTION_ROLL_SECONDS := 0.4
const MOTION_SHAKE_SECONDS := 0.16
const REDUCED_MOTION := false

# Generated UI ticks. Original PCM; no third-party samples.
const SFX_RATE := 22050
const SFX_HOVER_HZ := 1860.0
const SFX_HOVER_SECONDS := 0.028
const SFX_HOVER_VOLUME := 0.18
const SFX_PRESS_HZ := 880.0
const SFX_PRESS_SECONDS := 0.045
const SFX_PRESS_VOLUME := 0.28
const SFX_CONFIRM_HZ := 1320.0
const SFX_DENY_HZ := 196.0
const SFX_OPEN_HZ := 523.0
const SFX_CLOSE_HZ := 392.0
const SFX_NOTIFY_HZ := 1174.0
const SFX_NOTIFY_HZ_B := 1568.0
const SFX_CELEBRATE_HZ_1 := 523.0
const SFX_CELEBRATE_HZ_2 := 659.0
const SFX_CELEBRATE_HZ_3 := 784.0
const SFX_LEVEL_HZ_1 := 392.0
const SFX_LEVEL_HZ_2 := 523.0
const SFX_LEVEL_HZ_3 := 659.0
const SFX_LEVEL_HZ_4 := 784.0
const SFX_BLIP_SECONDS := 0.055
const SFX_BLIP_VOLUME := 0.26
const SFX_SWEEP_SECONDS := 0.09
const SFX_DENY_SECONDS := 0.1
const FANFARE_CELEBRATE_PUNCH := 1.35
const FANFARE_DENY_SHAKE := 1.25
const FANFARE_LEVEL_PUNCH := 1.5
const FANFARE_CONFIRM_PUNCH := 0.85
const FANFARE_NOTIFY_PUNCH := 0.55
const KEYCAP_MIN := 28
const PIXEL_KEYCAP_MIN := 16
const KILLFEED_MAX := 5
const KILLFEED_HOLD_SECONDS := 2.4
const RETICLE_SIZE := 22
const PIXEL_RETICLE_SIZE := 12
const VIGNETTE_EDGE := 56
const PIXEL_VIGNETTE_EDGE := 28
const VIGNETTE_ALPHA := 0.55
## TaVignette band ramps: [offset, edge alpha] from the outer edge in. Vector looks fade
## smoothly; pixel looks hold three flat steps.
const VIGNETTE_RAMP := [[0.0, 1.0], [0.45, 0.4], [1.0, 0.0]]
const PIXEL_VIGNETTE_RAMP := [[0.0, 1.0], [0.34, 0.5], [0.67, 0.2]]
## Texels along each ramp texture (the band stretches it).
const VIGNETTE_RAMP_TEXELS := 64
const HOTBAR_SLOTS := 8
const MINIMAP_SIZE := 128
const PIXEL_MINIMAP_SIZE := 72
const PARTY_PORTRAIT := 36
const PIXEL_PARTY_PORTRAIT := 20
## TaPartyFrame health bar width: a readable gauge, not a stub.
const PARTY_BAR_WIDTH := 96
const PIXEL_PARTY_BAR_WIDTH := 32
const CHOICE_COUNT := 3
const CHOICE_MIN := 2
const CHOICE_MAX := 4
const STEPPER_MIN := 0
const STEPPER_MAX := 99
const BUFF_COUNT := 6
const SPLASH_MIN_WIDTH := 280
const PIXEL_SPLASH_MIN_WIDTH := 160
const COMPASS_SIZE := 88
const PIXEL_COMPASS_SIZE := 56
const FLOATER_RISE := 36.0
## TaWorldAttach billboard: world units per content pixel (200 px per meter).
const WORLD_PIXEL_SIZE := 0.005
## A far nameplate (BILLBOARD) never draws its texture smaller than this on screen: 0.75
## for vector looks, 1:1 for pixel looks (pixel text broke up when minified).
const WORLD_MIN_TEXT_SCALE := 0.75
## TaFloater.pop_world rise, in meters.
const FLOATER_WORLD_RISE := 0.6
const SWATCH_SIZE := 16

const PROBE_MIN_SIZE := Vector2(8, 8)

const SEPARATION := 8

# Widget timing / layout (not look knobs).
const TOAST_DURATION_SECONDS := 2.5
const TOAST_MAX_VISIBLE := 3
const TOAST_MARGIN := 16
const TOAST_SEPARATION := 8
const TOAST_MAX_WIDTH := 320
const TOOLTIP_DELAY_SECONDS := 0.35
const TOOLTIP_OFFSET := 16
const TOOLTIP_MAX_WIDTH := 280
const TOOLTIP_Z_INDEX := 100
## TaPopover: px between the card and its anchor, the notch size, and the draw layer
## (above HUD, under tooltips).
const POPOVER_GAP := 8
const PIXEL_POPOVER_GAP := 4
const POPOVER_NOTCH := 8
const PIXEL_POPOVER_NOTCH := 4
const POPOVER_Z_INDEX := 90
## Toasts draw above dimmers (8), popovers, and tooltips: a notice that arrives while a
## dialog is up shows over its veil.
const TOAST_Z_INDEX := 110
const POPOVER_SAFE_INSET := 8
const WINDOW_TITLE_HEIGHT := 32
const PIXEL_WINDOW_TITLE_HEIGHT := 18
const WINDOW_MIN_WIDTH := 240
## ≥ 36% of 1280 HD. Still fits Pixel 640×360.
const PAUSE_PANEL_MIN_WIDTH := 480
## Veil over HUD. RGB stays off COLOR_BG so the dimmer reads as a modal.
const DIMMER_COLOR := Color(0.0, 0.0, 0.0, 0.65)
const WINDOW_MIN_HEIGHT := 120
const PIXEL_WINDOW_MIN_HEIGHT := 40
const PIXEL_TOOLTIP_MAX_WIDTH := 160
const REBIND_LISTEN_SECONDS := 3.0
const BADGE_FONT_SIZE := 12
## Badge and tag text: the small face in the PIXEL family (art px).
const PIXEL_BADGE_FONT_SIZE := 7
const PIXEL_TOAST_MAX_WIDTH := 200
const PIXEL_DIALOG_MIN_WIDTH := 280
const PIXEL_WINDOW_MIN_WIDTH := 180
const INSPECTOR_CAPTION_WIDTH := 120
const PIXEL_INSPECTOR_CAPTION_WIDTH := 56
const BADGE_MARGIN := 6
const PIXEL_BADGE_MARGIN := 2
## A slot count's plate: its figures and this much around them (px, art px). The plate
## sits on the slot's top frame, so it stays short enough not to reach the row above.
const COUNT_MARGIN := 2
const PIXEL_COUNT_MARGIN := 1
const BADGE_RADIUS := 32
const SLOT_SIZE := 48
const SLOT_NATIVE_ICON_MAX_WIDTH := 0
const SLOT_GRID_COLUMNS := 5
const SLOT_GRID_COUNT := 10
const DIALOG_RATIO := 0.4
const DIALOG_MIN_WIDTH := 360
const COLOR_TRANSPARENT := Color(0, 0, 0, 0)
const INFO_ICON_SIZE := 24
const PIXEL_INFO_ICON_SIZE := 16
const RADIAL_SIZE := 64
const PIXEL_RADIAL_SIZE := 40
## TaRadial ring stroke (a ring, not a pie chart).
const RADIAL_RING := 8
const PIXEL_RADIAL_RING := 4
## TaBar track: wide enough to carry its value ("100/100") at the look's body size.
const BAR_MIN_WIDTH := 120
const PIXEL_BAR_MIN_WIDTH := 44
const VBAR_MIN_HEIGHT := 80
const PIXEL_VBAR_MIN_HEIGHT := 48
const LIST_MIN_HEIGHT := 88
const PIXEL_LIST_MIN_HEIGHT := 48
## TextureProgressBar degrees clockwise from 12 o'clock. 0 starts at the top (270 started
## the fill at 9 o'clock, which read as a clock a quarter turn off).
const RADIAL_INITIAL_ANGLE := 0.0
## TaRadial empty track: how far toward the text colour the panel is lifted, and the
## contrast the track keeps against the fill so the value boundary reads.
const RADIAL_TRACK_LIFTS := [0.2, 0.3]
const RADIAL_TRACK_MIN_CONTRAST := 3.0
const ICON_GRID_COLUMNS := 4
const ICON_GRID_COUNT := 8
## Close glyphs: the multiplication sign, in the default and Pixel faces (the letter X
## sat on the text baseline and read as a word).
const TAG_DISMISS := "×"
## Text arrows for TaReorderList when no kit Theme supplies the drawn ones.
const REORDER_UP := "^"
const REORDER_DOWN := "v"
## Drop-in options: a CheckBox says what state it is in.
const TOGGLE_ON := "On"
const TOGGLE_OFF := "Off"
## TaQuestTracker: objectives wrap inside this width; done and pending marks. The plain
## tick stands in when the face has no "✓" (the Pixel face).
const QUEST_MIN_WIDTH := 240
const PIXEL_QUEST_MIN_WIDTH := 140
const QUEST_DONE := "✓"
const QUEST_DONE_PLAIN := "√"
const QUEST_TODO := "•"
## Share of the viewport a TaModal body may fill before it scrolls.
const MODAL_MAX_HEIGHT_RATIO := 0.8
const MODAL_CLOSE := "×"
## Backdrop blur radius in px behind TaDimmer. 0 is a plain veil.
const DIMMER_BLUR := 0.0
## Full attention loop for TaJuice.pulse (up and back).
const PULSE_SECONDS := 1.6
const PULSE_BRIGHTNESS := 1.35
## HD focus ring sits this many px outside the button so it never covers the fill.
const FOCUS_RING_GAP := 2
## WCAG AA for body text. Panels, popups, and tooltips must reach it for text and captions.
const MIN_TEXT_CONTRAST := 4.5
## panel_fill lerps page -> surface starting here and stepping down until text reads.
const PANEL_LIFT_MAX := 0.5
const PANEL_LIFT_STEP := 0.05
## Glass panels: opacity rises in these steps until their text reads over any scene.
const GLASS_ALPHA_STEP := 0.05
## Ink that misses 4.5:1 on its fill moves toward black or white in these steps.
const INK_PUSH_STEP := 0.05
## Default TaVignette.hold strength (0-1 of VIGNETTE_ALPHA).
const VIGNETTE_HOLD := 0.45
## Stick tilt that counts as "the player picked up the gamepad" for TaPromptHint.
const PROMPT_STICK_DEADZONE := 0.5
## TaPlateButton dim when disabled and no disabled art was given.
const PLATE_DISABLED_ALPHA := 0.45
