# Changelog (shipped with the addon)

## 2.3.0

Godot 4.4 or newer. Developed and tested on 4.7.2. **Breaking release** (the kit is in beta). Everything new or changed since 1.12.3; every break is listed under Breaking changes.

### Design once, and the whole project wears it

- Playground **Save** writes `res://theme_assist/look.tres` (the tokens) and `res://theme_assist/theme.res` (the Theme built from them), and sets Project Settings → GUI → Theme → Custom to that Theme when the setting is empty. Every Control in the project then wears the look with no code, in the editor and in the game. A project theme you set yourself is never replaced. **Revert** reloads the saved look
- The editor dock lists the four presets and has **Save to project** too. The save status names what the project wears ("Not saved (project: Flat)")
- `TaLook.save(look)`, `load_saved()`, `has_saved()`, `apply_saved(control)`, and `current()` (the bound look, else the saved one, else Flat). Kit components size themselves from `current()`
- `TaBar` and `TaBadge` are tool scripts, so the editor preview matches the game

### Four presets, one kit

- **Flat**, the factory default (`TaTokens.new()` equals `TaTokens.flat()`): neutral charcoal, one warm accent, a single 1 px border on frames only, plain fills everywhere else, radius 2, no shadow, hover and press as a colour change. Barlow Semi Condensed faces (bundled)
- **Modern** (new): Flat's frame and layout with a committed style. Cut corners drawn in hard steps; a press lip and a slant on buttons, tabs, badges, tags, and toasts; an accent rule under panel headers and dialog titles; tracked titles; louder fanfare. Light by default. Barlow faces
- **Framed** (new): generated pixel frames. Windows are framed cards: a dark outline, a lit edge, a three-pixel wood band shaded at the foot and right, and a dark inset line. Cards, slots, and tags keep a brass line. Cream cards under chips, bars, and dials; ribbon tags; corner brackets on the selected slot and on focus; a filled active tab; a framed gem before titles; the mixed-case Grain face with a small-caps caption
- **Pixel** (rebuilt): the chunky game end. Filled slabs with a drop shadow and no outlines, a large stepped corner cut, a tall narrow face, grey neutrals with the accent on the selected tab, saturated fills, tilt on hover, the most fanfare. No CRT
- Switching a preset never swaps a widget or a scene. `TaTokens.preset(id)`, `modern()`, `framed()`; `TaLook.IDS`
- Framed and Pixel chrome is generated from the tokens, with no image files: nearest-neighbour at a whole number of screen pixels per art pixel, so it follows every retint and stays crisp on an HD game. What a framed box holds starts an art pixel inside its frame
- Four original bitmap faces drawn for the addon: Grain (mixed case), Grain Small (small caps), Chunk (bold), and Tall. `TaPixelFont.face(id)`, `at_size()`. Every look has a real type scale: title, body, and caption
- New tokens, all in the Playground: `look_id`, `ui_scale`, `pixel_scale`, `color_panel`, `color_card`, `color_rarity`, `color_shadow`, `face_title`, `face_caption`, `title_tracking`, `text_shadow`, `chamfer`, `skew`, `lip`, `edge`, `inset`, `accent_bar`, `panel_margin`, `control_border`, `chip_ribbon`, `select_brackets`, `title_mark`, `motion_hover_tilt`, `fanfare`
- `TaPrimary` Button variation: the accent-filled main action

### Every display

- One look fits a Steam Deck (1280×800 and 720p), 1080p, 1440p, and native 4K with no font-size edits. Every look is drawn for a 1080 px tall canvas and scaled to yours: vector looks by canvas height ÷ 1080 in 1/8 steps, pixel looks by a whole number of screen pixels per art pixel. Type, margins, buttons, slots, bars, badges, and world attaches follow
- Text never draws below 9 px capitals on screen
- `ui_scale` is the density knob: 1.2 makes the whole UI 20% bigger on every display
- When the window crosses a scale step, `TaLook.refit()` rebuilds the project theme and every Theme `apply_to` painted, and kit widgets resize
- New API: `TaDisplay.vector_scale(look)`, `art_scale(look)`, `fit_key(look)`, `watch()`, and `factor_override` (tests and capture scripts); `TaLook.ui_scale()`, `scale()`, `gap()`, `metric()`, `refit()`, `track_paint()`; `TaTokens.px(hd)`
- The Playground's Showcase fills one screen with no scrolling at 1280×800, 1920×1080, and 3840×2160 in all four looks

### HUD in the world

- `TaWorldAttach` puts any kit Control into a 3D scene wearing the active look. `BILLBOARD` draws it on a camera-facing quad; `SCREEN` pins it to the canvas over the 3D point. Far billboards keep caption capitals at 9 screen pixels (`TaWorldAttach.least_scale(look)`)
- `TaFloater.pop_world(node3d, text)`: a number rising over a 3D object
- `TaBar` keeps room for its widest value, and the number sits wholly in the fill or wholly in the empty track
- Example: `examples/world_hud/world_hud.tscn`: named bars over 3D crates, a loot chip pinned to the canvas, and the canvas HUD strip; keys 1–4 switch the look

### Feel on every component

- `TaButton`: the kit's Button, with hover, press, focus, and the press sound wired by the button itself. Every button the kit builds is one, and `TaSlot` and `TaInfoIcon` extend it. Subclasses keep the wiring even when they override `_init` or `_ready`. `press_sound` picks the sound
- Keyboard and gamepad focus give the same lift and tick as a mouse hover; `ui_accept` plays the press. Everything goes through Godot's `ui_*` actions
- `TaFocus.wrap(controls, axis)`: button rows, button columns, toggle groups, and hotbars wrap focus at their ends
- `TaOverlay` and `TaPopover` play open and close sounds (`sounds = false` turns them off), `TaDialog` plays open, and `TaToast` plays notify (`notify_sound = false`)
- Fixed: reduced motion silenced hover and press ticks. It now drops only the motion; `TaSfx.muted` is the sound switch

### Slots, badges, and text that reads

- A slot's count sits in the slot's top-right corner, inside its width, on its top frame, clear of the icon, on a compact plate of the look's ink (`TaBadge.Tone.COUNT`). `TaSlotGrid` keeps room between rows for it; in a grid of your own, set the row gap to at least `TaSlot.count_room(grid)`
- Rarity has its own colour (`color_rarity`), not the warning amber
- Tones are fill colours. Text in a tone (`TaDangerLabel`, `TaSuccessLabel`, `TaWarningLabel`, a quiet danger button) is the tone moved toward black or white until it reads at 4.5:1 on its panel (`TaContrast.tone_ink`), so it keeps its hue
- Text drawn straight onto a scene (`TaInteractHint`, `TaFloater`) is light ink with a dark halo in every look (`TaSceneText`, `TaSceneSuccess`). `TaInteractHint.on_scene = false` gives a hint inside a panel plain ink
- Chips, bars, dials, shop cards, and party frames sit on cards (`color_card`), with their text in `TaCardText` and `TaCardCaption`
- One frame line per window: a tab page is one surface with its window on Flat and Modern, and a well of the page colour on Framed and Pixel
- A toast that opens over a dialog or modal draws above its dim
- `TaPartyFrame` shows the member's initial on a tone picked from the name. `ColorPickerButton` shows its colour as a full swatch

### Playground, recipes, and fixes

- The Playground opens on a **Showcase** tab: one composed game screen that fills the tab in every preset before any knob is touched. The HUD tab leads with the world attach
- Fixed: the Shop / wave Copy recipe put its banner, card, picker, and buffs on top of each other at the top-left corner, and the casino shell stacked its chip on its plate. Every recipe (and `examples/fps_hud`) pins its widgets to screen edges with anchors
- Fixed: a `TaQuestTracker` pinned to a corner came out about 800 px tall
- `TaVignette` fades in from the edges (smooth on vector looks, three flat steps on pixel looks); it was four flat bands
- `TaRadial` is a ring by default

### Breaking changes

- **Presets** are Flat, Modern, Framed, and Pixel. **Dawn is removed** (`TaTokens.dawn()`, `TaThemeBuilder.make_dawn()`, `TaLook.DAWN`, the `DAWN_*` constants): use `TaTokens.modern()` (light) or retint Flat. **The HUD look is removed** (`TaTokens.flat_hud()`, `with_hud_density()`, `TaLook.HUD`, the `HUD_*` constants): a dense HUD is any look with `content_margin` and `button_min_height` turned down
- **Flat changed**: the 1.x Flat (plum page, gold surfaces, radius 8, border 2, shadow 4) is gone, and the `TaTokens` export defaults match the new Flat. A saved 1.x `TaTokens` resource keeps its own values, and the new tokens take Flat's. Flat's faces are Barlow Semi Condensed; set `face`, `face_title`, and `face_bold` to null for Godot's default
- **Pixel changed**: new tokens, face, and chrome. Press Start 2P, the 9-slice PNGs (`chrome/`), `TaChromePack`, `TaPixelPack`, and `TaTokens.chrome_pack` are removed: chrome is generated. For your own art, set StyleBoxTextures on the Theme from `TaThemeBuilder.make(look)` (COOKBOOK → Pixel chrome knobs)
- **CRT is opt-in**: no preset turns it on. Set `crt_intensity` above 0 for scanlines on any look
- **Removed**: `TaThemeBuilder.make_pixel()` (use `make(TaTokens.pixel())`), `TaPixelFont.get_font()` and `snap_size()` (use `face()` and `at_size()`), `TaThemeTones.panel()`, `TaDefaults.playfield_color()`, `COLOR_TABLE`, and the per-look constants (`COLOR_*`, `PIXEL_*`, `RADIUS`, `SHADOW_SIZE`, and the rest: the dictionaries `TaDefaults.FLAT`, `MODERN`, `FRAMED`, and `PIXEL` hold the values). `TaProbe`, an empty test control, is gone
- **Sizes follow the display**: on a canvas that is not 1080 px tall, the Theme and every kit metric differ from the token values (at 4K a Flat `font_size` of 16 draws at 32). Code that read `theme.default_font_size` or a kit widget's minimum size gets the display value. `TaDisplay.factor_override = 1.0` pins the 1080 reference
- **The pixel framebuffer** (`sync_display = true`) is the canvas ÷ the art scale on this display
- **`TaThemeBuilder.apply_to(control)`** with no look, and the drop-ins, use `TaLook.current()` (your saved look) instead of Flat. A drop-in no longer paints itself when the project has a theme
- **Kit buttons are `TaButton`** (still a `Button`), and `TaSlot` and `TaInfoIcon` extend it. Overlays, popovers, dialogs, and toasts make sound; if your game plays its own, turn theirs off (`sounds`, `notify_sound`). Focus wraps at the ends of kit button rows, columns, toggle groups, and hotbars
- **Titles use `face_title`** (null uses `face`). A look that set `face_bold` for its titles must set `face_title`
- **Cards**: chips, bars, dials, shop cards, highlight cells, party frames, and the compass fill with `color_card`. Text inside them uses the Label variations `TaCardText` and `TaCardCaption`, so an override on `Label` no longer reaches it. Toasts have their own chrome role
- **Container gaps come from the Theme**: kit components no longer set a `separation` override on their boxes, and the kit Theme sets `separation` (Box containers) and `h_separation` / `v_separation` (Grid and Flow containers) to the kit gap. Stock containers in a project that wears the kit Theme get that gap too (8 px at 1080; Godot's is 4)
- **Tab pages**: the `TabContainer` panel is the panel fill with no border on vector looks, and a page-colour well on pixel looks
- **Badges** use the look's caption size, and the Rarity tone uses `color_rarity`. `TaBadge.Tone.COUNT` and the variations `TaBadgeCount` and `TaTagCount` are new
- **`TaSlot` count**: inside the slot's width, on its top frame, on a `TaBadgeCount` plate (it was anchored inside the corner). **`TaSlotGrid`** row gap is at least `TaSlot.count_room(grid)`
- **`TaBar`** minimum width holds its widest value, scaled for the display (it was 80 px). Its value text sits wholly in the fill or the track when one holds it
- **`TaRadial`** defaults to a ring that follows the display (`set_ring_width(0)` still draws a full disk)
- **`TaToastHost.z_index`** is 110 (`TaDefaults.TOAST_Z_INDEX`), above modals, overlays, dimmers, and popovers; only `TaTransition` draws over it
- **Scene text**: `TaInteractHint` action text uses `TaSceneText` unless `on_scene` is false, and `TaFloater` uses `TaSceneSuccess` (it was `TaSuccessLabel`)
- **Semantic label colours** (`TaDangerLabel`, `TaSuccessLabel`, `TaWarningLabel`) and the quiet danger button's text are derived from the tone, not the token itself. `TaContrast.panel_fill` no longer lifts a panel so raw tones read as text on it. Code that drew text in a tone token directly should use `TaContrast.tone_ink(tone, fill)`
- **`TaModal` and `TaDialog`** put the title row in a `PanelContainer` with the variation `TaDialogHeader`. A `TaDialog` with no title keeps no empty title line
- **Stock `ColorPickerButton`** gets its own boxes from the kit Theme instead of inheriting Button's padding
- **`TaWindow` and `TaHeaderPanel`** show a theme icon `mark` before the title when the look has `title_mark`
- **`TaVignette`** bands are TextureRects with a gradient (they were ColorRects)
- **Fonts**: `fonts/` holds four Barlow TTFs and `OFL.txt` (SIL Open Font License 1.1); Press Start 2P is gone. See `NOTICE`
