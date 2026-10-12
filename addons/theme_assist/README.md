# Theme Assist

Skip the UI grind. Theme Assist is a **Godot 4 UI component kit**. Open the Playground, design how the UI looks, press **Save**, and every kit component in the project wears that theme. Windows, panels, buttons, slots, bars, toasts, dialogs, pause, HUD: built, themed, and wired for hover, press, focus, gamepad, and sound.

**Flat, Modern, Framed, and Pixel** are four presets of one kit. They are a ladder from a clean default to a chunky pixel game: the same components, different token sets. Start from one, change the knobs, save your own.

**Free** on the Godot Asset Store. **itch** is optional support: **$9.99**, or pay what you want with $9.99 suggested. It is the **same MIT zip and the same 2.3.0**; paying does not unlock extra files. GDScript, no autoloads, no GDExtension. Godot **4.7** (min **4.4**).

**Who it's for:** beginners (and the AI agents they point at it) who want a working UI with no styling work, and experts who want to prototype on a kit and later extend it. Every component is a normal `class_name` script: subclass it, and the click, focus, and sound wiring is already there.

**Who it isn't for:** people who want Maaack (saves, a scene router), a 1,000-PNG art pack, ThemeGen, UIFlow, or an inventory backend.

**Sixty seconds:** enable the plugin → F6 [`playground/playground.tscn`](playground/playground.tscn) → switch **Flat / Modern / Framed / Pixel**, change Accent → **Save**. Cookbook: [`COOKBOOK.md`](COOKBOOK.md). Examples: [`examples/`](examples/README.md).

## First run

Copy `addons/theme_assist/` into your project and enable the plugin (Project → Project Settings → Plugins). Then F6 `playground/playground.tscn`, or use the Theme Assist dock → **Open playground**. It opens on the **Showcase** tab in Flat, the factory default.

## Design, Save, done

1. In the Playground, pick a preset from the top bar, then edit the knobs in the **Tokens** panel on the right (colors, type, chrome, motion, feedback). Every tab updates live.
2. Press **Save**. It writes two files into your project:
   - `res://theme_assist/look.tres`: the tokens (a `TaTokens` resource; small, readable, and editable in the Inspector).
   - `res://theme_assist/theme.res`: the `Theme` built from those tokens.
3. The editor plugin sets **Project Settings → GUI → Theme → Custom** to `theme.res` when that setting is empty. Every Control in the project, kit or stock, now wears the look. A project theme you set yourself is never replaced: the plugin prints how to switch instead.

**Revert** reloads the saved look. The dock has the same **Save to project** for a preset or accent picked there.

In code, a scene can wear the saved look explicitly (handy when the project theme belongs to someone else, or for a HUD in a sub-viewport):

```
func _ready() -> void:
	TaLook.apply_saved(self)  # the saved look; Flat if nothing is saved yet
```

`TaLook.current()` is the bound look (the saved one if there is one, else Flat). Kit components read their metrics from it, so a component created after load matches.

## Five minutes (pause + HUD)

1. Instance `addons/theme_assist/scenes/pause.tscn` on your UI root, or use the dock's **Instance pause**.
2. Instance `scenes/hud.tscn` (HUD strip + toast host), or use the dock's **Instance HUD**.
3. Connect the signals. Quit is a signal so it does not kill the editor:

```
pause.resume_pressed.connect(func() -> void:
	hud.get_toast_host().show_message("Resumed")
)
pause.quit_pressed.connect(func() -> void:
	get_tree().quit()
)
```

Esc from play opens the pause; Esc while it is open resumes. `show_pause()` sets `get_tree().paused = true` (the overlay processes Always). Put the HUD and pause on a CanvasLayer if a 2D or 3D world can draw over Controls. A drop-in with no Theme above it paints itself with the saved look at the end of its first frame; `apply_to` and the project theme both win over that.

**Esc with several overlays:** add a `TaCancelRouter` to your UI. Esc then closes the top open overlay (`TaModal`, `TaDialog`, `TaOverlay`, `TaPopover`, or anything you `push`), and only when nothing is open does it toggle the pause. See COOKBOOK → Keyboard, Esc, and overlays.

**A card beside a control:** `TaPopover.open(anchor)` places a card on the side with room, off your HUD rows (`safe_insets`), and follows the anchor.

## Presets

| Preset | Family | Reads as |
|---|---|---|
| `TaTokens.flat()` | Vector | The default, undecorated. Charcoal page, one warm accent. One 1 px border, on frames only: buttons, fields, slots, and tags are fills, not outlines. No shadow, slant, lip, or accent bar; hover and press are a colour change. Title and body are the only type levels. |
| `TaTokens.modern()` | Vector | Flat after a style was committed to. The same border weight and layout, then cut corners, a press lip, and a slant on buttons, tabs, badges, tags, and toasts; an accent rule under headers; tracked titles; louder fanfare. Light, so it reads over a 3D scene. |
| `TaTokens.framed()` | Pixel | The hybrid, with its own frame language. Windows framed like a wooden card (a dark outline, a beveled dark-wood band, a dark inset line, the surface's own edge), cream cards inside, ribbon tags, corner brackets on the selected slot, a filled active tab, a small gem before titles. A mixed-case pixel face (Grain) with a small-caps caption. |
| `TaTokens.pixel()` | Pixel | The chunky game end. Filled slabs with a drop shadow, a tall, narrow pixel face (Tall), grey neutral buttons and tabs with the accent on the selected one, a stepped corner cut, saturated fills, tilt on hover, the most fanfare. No CRT. |

`TaTokens.new()` is Flat, value for value. Switching preset changes tokens only: the same scenes and the same components stay instanced.

**Faces:** Flat uses Barlow Semi Condensed (Medium for body, SemiBold for titles). Modern uses Barlow (Medium and Bold), a wider cut of the same family, so the ladder reads as one kit. Both ship in `fonts/` under the SIL Open Font License. Framed uses the kit's bitmap faces (Grain, Grain Small, Chunk), and Pixel the tall, narrow Tall face, all drawn for this addon. The pixel faces cover Latin text, digits, and common punctuation; `fallback_fonts` covers the rest. Set `face` and `face_title` to your own font, or to null for Godot's default.

## Every display

One look fits a Steam Deck (1280×800, and its 720p mode), 1080p, 1440p, and native 4K, with no font-size edits. Every look is drawn for a 1080 px tall canvas, and the kit scales it to yours (`TaDisplay`):

- **Vector looks** (Flat, Modern): type, margins, button height, slot size, bar thickness, badge size, and world-attach size are multiplied by your canvas height ÷ 1080 × `ui_scale`, in steps of 1/8, so 4K is exactly twice 1080. On a small screen the scale stops where caption capitals are still 9 screen pixels tall: a Deck draws Flat at 0.875 and Modern at 1.
- **Pixel looks** (Framed, Pixel): `pixel_scale` is screen pixels per art pixel at 1080. On another canvas it is rounded to a whole number (Pixel: 2 on a Deck, 3 at 1080, 6 at 4K; Framed: 2, 2, 4), so chrome and type stay on whole art pixels.
- `ui_scale` is the density knob for every preset: 1.2 makes the whole UI 20% bigger on every display.
- The scale reads your project canvas (Project Settings → Display → Window: viewport size and stretch mode) and the window. When the window crosses a scale step, `TaLook.refit()` rebuilds the project theme and every Theme `apply_to` painted, and kit widgets resize. In the editor, Themes are built at the 1080 reference; a running game refits them to its window.

`TaLook.metric(hd, pixel_art)` puts your own widgets on the same scale: `hd` px on vector looks, `pixel_art` art pixels on pixel looks.

## Pixel family: paint vs framebuffer

A Pixel-family look (Framed, Pixel) draws chrome and type at a whole number of screen pixels per art pixel (`pixel_scale` at 1080, rounded for your display), nearest-neighbour, with no anti-aliasing. There are two ways to use it:

| Call | Theme | Window |
|---|---|---|
| `TaThemeBuilder.apply_to(node, look)` | yes, at the art scale | **unchanged** (default `sync_display = false`) |
| `TaThemeBuilder.apply_to(node, look, true)` | yes, at scale 1 | framebuffer of your project canvas ÷ the art scale, integer stretch |
| `TaLook.apply(node, look)` | yes, at scale 1 | as above for Pixel looks; a Vector look restores the window |

Paint (`sync_display = false`) is the usual choice: pixel chrome on an HD game, and juice tilts and scales stay smooth. The framebuffer (`sync_display = true`) makes the whole game a low-resolution canvas (on 1920×1080: Pixel 640×360, Framed 960×540). Only the scene root is stretched to it, and a dense HD layout will not fit, so design for it. `crt_intensity` adds a scanline overlay to any look; it is an effect you turn on, not part of a preset.

## Retint in code

```
var look := TaTokens.modern()
look.color_accent = Color(0.1, 0.55, 0.45)
look.radius = 4
look.font_size = 18
look.focus_width = 3
look.motion_open_seconds = 0.25
look.toast_seconds = 3.0
look.dimmer_alpha = 0.7
TaThemeBuilder.apply_to(self, look)
TaLook.save(look)  # what the Playground's Save does
```

`apply_to` also refreshes the min sizes of kit widgets already in the tree. Call `TaLook.refresh_tree(root)` if you switch between a Vector and a Pixel look after building a dense tree yourself.

## Look knobs (`TaTokens`)

| Knob | Affects |
|---|---|
| `color_bg` / `color_panel` / `color_card` / `color_surface` (+ hover, pressed) | Page, panel, card (chips, bars, dials, and toasts inside a panel), and control fills. A translucent `color_surface` or `color_panel` is glass: kept as clear as its text allows. Check a look with `TaContrast.check(look)` |
| `color_text` / `color_muted` / `color_accent` / `color_border` / `color_shadow` | Ink, captions, the accent, frames, drop shadows |
| `color_danger` / `color_success` / `color_warning` / `color_rarity` | Tones for buttons, badges, tags, toasts, bars. Rarity is the Rare badge and tag. A tone is a fill colour; text in a tone is derived from it to read at 4.5:1 (`TaContrast.tone_ink`) |
| `tones` | Extra named tones (`tone_name` on `TaTag` / `TaBadge` / `TaToast`) |
| `face` / `face_title` / `face_caption` / `face_bold` / `face_italic` | Body, titles, caption, bold, italic. Null bold emboldens `face`; **null italic stays upright** |
| `fallback_fonts` | Fonts tried for glyphs the face lacks (emoji on web exports) |
| `font_size` / `font_size_title` / `font_size_caption` / `title_tracking` | The type scale |
| `outline_size` / `text_shadow` | Ink outline; a 1-art-pixel text shadow under light ink |
| `family` | Vector (StyleBoxFlat) or Pixel (generated textures) |
| `radius` / `chamfer` / `border_width` / `control_border` / `edge` / `inset` | Corners, cut corners, the border of frames (panels, windows, dialogs), the border of what sits in a frame (buttons, fields, slots, tags; 0 is fill only), the pixel edge band and its inset line |
| `chip_ribbon` / `select_brackets` / `title_mark` | Pixel-family details: tags and badges end in a notched ribbon, selection and focus as corner brackets, a small framed mark before window and header titles (Framed) |
| `lip` / `shadow_size` / `skew` / `accent_bar` | Press depth, drop shadow, slant (Vector), header accent stripe |
| `content_margin` / `panel_margin` / `button_min_height` / `focus_width` | Density and the focus ring |
| `ui_scale` | Size of the whole UI in every preset. The kit multiplies it by the display scale (see Every display) |
| `pixel_scale` | Pixel-family looks: screen pixels per art pixel on a 1080 px canvas, rounded to a whole number for yours |
| `motion_hover_scale` / `motion_press_scale` / `motion_hover_tilt` / `motion_*_seconds` | `TaJuice` hover, press, open, roll |
| `fanfare` | How big celebrations and denials play (0 = calm) |
| `toast_seconds` | `TaToast` hold |
| `dimmer_alpha` / `dimmer_blur` | `TaDimmer` veil behind modals (`TaOverlay.dim_alpha` overrides one layer) |
| `crt_intensity` | Optional scanline overlay (0 = off) |

## Feel: hover, press, focus, sound, gamepad

Every interactive kit component wires itself: a hover lift and tick, a press squash and sound, the same lift when focus arrives from keys or a gamepad, and the generated sounds for open, close, confirm, notify. Gamepads and keys go through Godot's `ui_*` actions (`ui_accept`, `ui_cancel`, the `ui_up`/`ui_down`/`ui_left`/`ui_right` focus moves); there is no second input path. Button rows, columns, toggle groups, and hotbars wrap focus at their ends.

`TaButton` is the kit's Button. Subclass it (or `TaSlot`, which extends it) and override `_init` or `_ready` freely: the wiring is in `_notification`, so it survives. `press_sound` picks the press sound (`&"press"`, `&"confirm"`, `&"close"`, or `&""` for none).

```
TaFanfare.celebrate(score)
TaFanfare.deny(panel)
TaSfx.play_on(self, TaSfx.confirm())
```

`TaJuice.reduced_motion = true` drops the motion and keeps the sounds. `TaSfx.muted = true` silences every kit sound (Options → UI sounds). Preview every preset on the Playground's Fanfare tab.

## HUD: canvas and world

The HUD is a use of the kit, not a preset. `scenes/hud.tscn` is the canvas strip. `TaWorldAttach` puts the same components into a 3D scene, wearing the active look:

```
var attach := TaWorldAttach.new()      # BILLBOARD: a camera-facing quad
attach.position = Vector3(0, 2.2, 0)
enemy.add_child(attach)
var bar := TaBar.new()
attach.add_content(bar)                # the same TaBar the canvas strip uses
```

Nameplates follow the display: on a 4K canvas the content has twice the pixels and the quad keeps its size. Far from the camera a `BILLBOARD` grows so its caption capitals stay at 9 screen pixels on vector looks, and at whole pixels on pixel looks (whose faces break up when shrunk). A `TaBar` keeps room for its widest value, so its number sits wholly in the fill or the track at any value. For a row of nameplates, put the name over the bar (a `TaTag`, then the bar, both through `add_content`), so plates are as narrow as their bars; the tag gives the name a surface, so it reads on any sky. `mode = SCREEN` pins the content to the canvas over the 3D point instead (same size at any distance). `TaFloater.pop_world(enemy, "-12")` pops a damage number over a 3D object. See [`examples/world_hud/world_hud.tscn`](examples/world_hud/world_hud.tscn).

## Playground

The Playground follows the display like the kit: its Showcase fills one screen with no scrolling on a Steam Deck (1280×800), at 1080, and at native 4K. In a new project (a 1152×648 window, stretch mode off) maximize it; below about 1280×720 the panels wrap and scroll.

The source of truth ships **inside this addon**. Tabs: Showcase (a finished screen), Kit (every Ta* component), Stock (every Godot Control), Composites, Coverage, HUD (canvas and world), Recipes (copyable genre shells), Fanfare. Filter the galleries; **Copy** on a cell puts a snippet on the clipboard.

Headless:

```
godot --headless --path . res://addons/theme_assist/playground/playground.tscn
```

Prints `PLAYGROUND_OK` (and `PLAYGROUND_MISSING …` if a registry type is absent).

## Editor dock

Theme Assist dock: Flat / Modern / Framed / Pixel, live accent and radius, **Save to project**, **Open playground**, **Instance pause**, and **Instance HUD** into the edited scene.

## Not this pack

| Want | Use |
|---|---|
| Main menu, save games, scene router, persistent settings | Maaack (or your own) |
| Loot DB, stacking, drag-drop inventory rules | not Theme Assist (`TaSlotGrid` is layout and display) |
| Theme DSL / generator | ThemeGen |
| Full input mapper | `TaRebindRow` takes the first keyboard event only |

## License

- Addon code: MIT (`LICENSE`). Games may be proprietary. Fork and redistribute it as long as the copyright notice stays. The itch price is support, not a different license.
- Pixel faces, chrome, editor icons, and sounds: original to this addon, generated or drawn in code, MIT.
- Barlow and Barlow Semi Condensed (`fonts/`): SIL Open Font License 1.1, © 2017 The Barlow Project Authors (`fonts/OFL.txt`). They may ship in your game, commercial or not; keep `OFL.txt` with the font files.

See `NOTICE` and `CHANGELOG.md`.
