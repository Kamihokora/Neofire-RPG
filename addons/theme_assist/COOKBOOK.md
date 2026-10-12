# Theme Assist cookbook

Recipes for the kit. Copy `addons/theme_assist/`, enable the plugin, then pick a path.

Playground: `addons/theme_assist/playground/playground.tscn` (F6) or dock **Open playground**. Filter the galleries; **Copy** on a cell puts the snippet on the clipboard.

Headless: `godot --headless --path . res://addons/theme_assist/playground/playground.tscn` prints `PLAYGROUND_OK`.

## Design, Save, wear it

Open the playground, pick **Flat / Modern / Framed / Pixel**, edit the knobs in the Tokens panel, press **Save**. That writes `res://theme_assist/look.tres` (the tokens) and `res://theme_assist/theme.res` (the Theme), and the editor plugin makes `theme.res` the project theme (Project Settings → GUI → Theme → Custom) when that setting is empty. From then on every Control in the project wears it, with no code. **Revert** reloads the saved look; the dock has **Save to project** too.

The same from code (a tool script, a settings screen, CI):

```
var look := TaTokens.modern()
look.color_accent = Color(0.1, 0.55, 0.45)
TaLook.save(look)                 # look.tres + theme.res in res://theme_assist/
var again := TaLook.load_saved()  # null when nothing is saved
TaLook.apply_saved(hud)           # paint one tree with the saved look (Flat if none)
```

`TaLook.current()` is the look kit components size themselves from: the bound one, else the saved one, else Flat. `TaTokens.new()` is Flat, value for value. Switching presets changes tokens only, never which scenes or components are instanced.

## Pause + HUD in five minutes

```
TaLook.apply_saved(self)  # or skip it: the saved theme is already the project theme
var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
var hud := preload("res://addons/theme_assist/scenes/hud.tscn").instantiate()
add_child(hud)
add_child(pause)
pause.resume_pressed.connect(func() -> void:
	hud.get_toast_host().show_message("Resumed")
)
pause.quit_pressed.connect(func() -> void: get_tree().quit())
```

Esc from play opens pause. Esc while pause is open resumes. Options has **Back**. `TaDialog` is a small Window popup (add it to the tree, then `show_dialog()`). `TaModal` is the layout-tree sheet when you need `z_index`. Paint the root in `_ready` or later, in any order: a drop-in paints itself (with the saved look) only if the tree still has no Theme and the project has no theme at the end of that frame, and `apply_to` replaces its paint.

## Management shell

One scene. Not a router.

```
var look := TaTokens.modern()
look.color_accent = Color(0.45, 0.22, 0.12)
look.content_margin = 6           # denser rows for a management screen
TaThemeBuilder.apply_to(self, look, false)
var pause := preload("res://addons/theme_assist/scenes/pause.tscn").instantiate()
add_child(pause)
var bar := TaChip.new()
bar.set_caption("Clock")
bar.set_text("D1 · 7:00 AM")
var slot := TaSlot.new()
slot.set_caption("Late flower")
slot.badge_text = "98"
var tag := TaTag.new()
tag.text = "Female"
var rail := TaButtonCol.new()
rail.add_button("Water")
rail.set_button_text(0, "Watered")
# Section titles are Labels beside the column, not children of it.
var sheet := TaModal.new()
sheet.title = "Midnight"
sheet.body = "The lights are out."
sheet.z_index = 40
add_child(sheet)
sheet.show_modal()
```

`TaDimmer.on(host)` is one dimmer per host. A second overlay on that same node passes a key: `TaDimmer.on(host, "phone")`. `TaModal` keeps its dimmer as its own child.

## Presentation shell

Emoji and a short name, with an optional tile color. No baked icons.

```
var apps := TaIconGrid.new()
apps.grid_columns = 4
apps.cell_count = 4
apps.set_glyph(0, "☀", "Grove", Color(0.35, 0.55, 0.75))
```

A pot mark sits in the cell and survives a theme refresh. The caption stays the word underneath.

```
slot.set_center_text("🌱")
slot.set_caption("Late flower")
slot.set_cell_size(Vector2(72, 72))
```

A management readout stacks the grey caption over the value. Tint is optional.

```
var cash := TaChip.new()
cash.set_stacked(true)
cash.set_caption("Cash")
cash.set_text("120")
cash.set_value_color(Color(0.88, 0.76, 0.42))
```

A day ring with no panel and no caption. Color the bar after refresh.

```
var day := TaRadial.new()
day.set_caption_visible(false)
day.set_chrome_visible(false)
day.set_diameter(28)
day.set_value(40)
day.get_bar().tint_progress = Color(0.95, 0.75, 0.35)
```

A checklist keeps the words you pass, including a live count. The second array marks done rows.

```
quest.set_objectives(PackedStringArray(["Water x2", "Sell"]), [true, false])
```

A phone bezel is a panel, not a new widget. Clip the screen, give it a rim, and put a notch `ColorRect` in the corner. `TaWindow` stays the draggable desktop window. `TaMinimap` stays the corner radar.

Pins on a percent board: one full-rect `Control`, each pin a child with anchors at `Vector2(x, y)` in 0–1. Header and cancel are a `Label` and a `Button` on that same board.

A gold menu card is a `PanelContainer` plus `TaButtonCol`. The dangerous row is `button.theme_type_variation = "TaDanger"`. That is the hamburger menu. `pause.tscn` stays the Esc overlay.

## Paint vs framebuffer

Framed and Pixel are the Pixel family: chrome and type drawn in art pixels, a whole number of screen pixels each (`pixel_scale` at 1080, rounded for your display), nearest-neighbour.

- `apply_to(node, TaTokens.pixel())`: paint. The Theme is built at the art scale, the **HD window stays**, and juice tilts and scales stay smooth. The usual choice.
- `apply_to(node, TaTokens.pixel(), true)` or `TaLook.apply(node, TaTokens.pixel())`: framebuffer. The window becomes your project canvas ÷ the art scale (on 1920×1080: Pixel 640×360, Framed 960×540) with integer stretch, and the Theme is built at scale 1. A Vector look restores the window.
- Display sync full-rects the **scene root** only. Nested HUD anchors stay put.
- `look.crt_intensity = 0.2` adds scanlines to any look. No preset turns it on.

## Every display

The kit draws every look for a 1080 px tall canvas and scales it to yours: a Steam Deck, 720p, 1080p, 1440p, and native 4K all open finished (README → Every display). One knob sets the density of every preset:

```
var look := TaTokens.flat()
look.ui_scale = 1.2   # the whole UI 20% bigger, on every display
TaLook.save(look)
```

Your own widgets join the same scale with `TaLook.metric(hd, pixel_art)`: `hd` px on vector looks, `pixel_art` art pixels on pixel looks. Size them in `refresh_metrics()`, which `TaLook.refresh_tree` calls after a look change and after a window crosses a scale step (`TaLook.refit()`):

```
func refresh_metrics() -> void:
	custom_minimum_size = Vector2(TaLook.metric(320, 110), TaLook.button_height())
```

Container gaps come from the Theme: `separation`, `h_separation`, and `v_separation` are the kit gap on this display, so a VBox needs no override. A fixed number stays 8 px at 4K.

To preview a display in a test or a capture script, set `TaDisplay.factor_override = 2.0` (native 4K: a 1:1 canvas two 1080 heights tall; 0.741 is a Deck) and call `TaLook.refit()`. Set it back to 0 to read the real window.

## Retint

```
var look := TaTokens.modern()
look.color_accent = Color(0.7, 0.2, 0.15)
look.toast_seconds = 4.0
look.dimmer_alpha = 0.7
look.motion_open_seconds = 0.28
TaThemeBuilder.apply_to(self, look)
```

Switch between a Vector and a Pixel look later: `TaLook.refresh_tree(self)`.

**Glass over a full-bleed scene.** Give the surfaces alpha. Panels, popups, and buttons stay as clear as their text allows over *any* scene (the builder checks them over white and over black) and turn more opaque only where they must. Your palette decides how clear that is: panels also hold muted and semantic labels, so mid-tone greens and reds need nearly opaque glass to read over snow or sky. Light text colours let it stay clear:

```
var look := TaTokens.flat()
look.color_bg = Color(0.02, 0.02, 0.03)
look.color_surface = Color(0.02, 0.02, 0.03, 0.55)   # comes out at 0.6 with this text
look.color_text = Color(1, 1, 1)
look.color_muted = Color(0.85, 0.85, 0.85)
look.color_success = Color(0.6, 1.0, 0.7)
look.color_danger = Color(1.0, 0.72, 0.72)
look.color_warning = Color(1.0, 0.9, 0.6)
TaThemeBuilder.apply_to(self, look)
```

**Check your own look.** `TaContrast.check(look)` builds the Theme and returns one line per text pair under 4.5:1 (empty means it passes), with glass judged over white and black. It needs no nodes, so it runs in a SceneTree script's `_init`, a tool script, or CI. The kit's four looks pass it. (`audit(host, look)`, the 1.12.0 name, still works.) If you edit the Theme after `apply_to` (a skin that restyles `TaToast`), pass it: `check(look, root.theme)` judges your edited Theme instead. Pairs your own types add, and colour emoji (a glyph, not a Theme colour), are outside it. `TaContrast.ratio(a, b)`, `worst(ink, fill)`, `over(top, below)`, and `ink_on(look, fill)` are there for your own colours.

```
for issue in TaContrast.check(my_look, root.theme):
	push_warning(issue)   # "Button.font_color on normal: 3.66 < 4.5"
```

## Fanfare

```
TaFanfare.celebrate(score)
TaFanfare.deny(panel)
TaFanfare.level_up(score)
TaFanfare.panel_in(window)
TaFanfare.confirm(button)
TaFanfare.notify(hud)
TaSfx.play_on(self, TaSfx.confirm())
```

`look.fanfare` scales how big these play: Flat 0.6, Framed 0.8, Modern 1.2, Pixel 1.5; 0 is calm. `TaJuice.reduced_motion = true` skips the motion (juice, transitions) and keeps the sounds. `TaSfx.muted = true` silences every kit sound (Options → UI sounds).

## Semantic buttons + type ramp

Set a Label’s `theme_type_variation` to `TaTitle` or `TaCaption`.  
Buttons: `TaPrimary` (the accent-filled main action), `TaDanger`, `TaSuccess`, `TaWarning`.

## Pixel chrome knobs

Pixel-family chrome is generated from the tokens, so it follows every retint. The knobs, in art pixels:

```
var look := TaTokens.framed()
look.pixel_scale = 3      # screen px per art px at 1080 (rounded for the display)
look.border_width = 2     # outer frame of panels, windows, dialogs
look.control_border = 1   # frame of buttons, fields, slots, tags (0: fill only)
look.edge = 1             # lighter band inside the frame
look.inset = 1            # dark line inside the band
look.lip = 2              # press depth under buttons
look.radius = 2           # pixel-stepped corners
look.shadow_size = 1      # solid drop shadow
look.chip_ribbon = true   # tags and badges end in a notched ribbon
look.select_brackets = true  # selection and focus as corner brackets
look.title_mark = true    # a framed gem before window and header titles
TaThemeBuilder.apply_to(self, look)
```

**Your own art.** Build the Theme, then put your StyleBoxTextures on the types you want to replace, and save that Theme as the project theme:

```
var theme := TaThemeBuilder.make(TaTokens.pixel())
var plate := StyleBoxTexture.new()
plate.texture = preload("res://my_ui/button.png")
plate.set_texture_margin_all(3)
theme.set_stylebox("normal", "Button", plate)
ResourceSaver.save(theme, "res://my_ui/theme.res")
```

## Fonts

```
var look := TaTokens.flat()
look.face = preload("res://fonts/MySans.ttf")
look.face_title = preload("res://fonts/MySans-Bold.ttf")  # TaTitle, window and dialog titles
look.face_bold = preload("res://fonts/MySans-Bold.ttf")   # TaBold and [b]
look.face_caption = preload("res://fonts/MySans.ttf")     # TaCaption
TaThemeBuilder.apply_to(self, look)
```

Flat ships with Barlow Semi Condensed (Medium for body, SemiBold for titles) and Modern with Barlow (Medium and Bold), the same family in a wider cut. They live in the addon's `fonts/` folder under the SIL Open Font License; `TaTokens.bundled_font("Barlow-Bold.ttf")` loads one for any look. Set a face to null for Godot's default font.

Framed and Pixel use the kit's bitmap faces: `TaPixelFont.face(TaPixelFont.GRAIN)` (mixed case), `GRAIN_SMALL` (small caps), `CHUNK` (bold), and `TALL` (Pixel's tall, narrow face). Any of them works on any look.

## Composites

Inline widgets keep their own size in containers: TaTag, TaBadge, TaSlot, TaStepper, and TaCompass never stretch, and TaChip and TaVBar keep their width. Set `size_flags_horizontal = Control.SIZE_EXPAND_FILL` on one when you want it to stretch.

### TaButton

The kit's Button: hover lift, press squash, focus lift, and the press sound, wired by the button itself. Every button the kit builds is one. Subclass it and override `_init` or `_ready` freely (no `super` needed): the wiring lives in `_notification`. `TaSlot` and `TaInfoIcon` extend it.

```
class_name BuyButton
extends TaButton

func _ready() -> void:
	text = "Buy"
	press_sound = &"confirm"   # &"press", &"confirm", &"close", or &"" for none
```

### TaBadge

```
var badge := TaBadge.new()
badge.text = "New"
badge.tone = TaBadge.Tone.ACCENT
add_child(badge)
```

### TaToastHost / TaToast

```
var host := TaToastHost.new()
add_child(host)
host.show_message("Saved")
host.set_corner(TaToastHost.Corner.TOP_CENTER)
host.inset = Vector2(0, 48)   # hang under a 48 px HUD row
host.max_width = 320          # 0 uses the look's width
```

Prefer the host. A lone `TaToast` is the row the host spawns.

### TaDialog

```
var d := TaDialog.new()
d.title = "Prestige?"
d.body = "Wipe crumbs?"
add_child(d)
d.confirmed.connect(_on_wipe)
d.show_dialog()
```

### TaItemTooltip

```
var tip := TaItemTooltip.new()
tip.title = "Sword"
tip.body = "A blade."
tip.attach(hover_target)
```

### TaSlot / TaSlotGrid

```
var slot := TaSlot.new()
slot.tooltip_title = "Gem"
slot.badge_text = "3"
add_child(slot)
var grid := TaSlotGrid.new()
grid.grid_columns = 4
grid.slot_count = 8
add_child(grid)
```

Display only. No loot database. `badge_text` is the count: it sits in the slot's top-right corner, inside the slot's width, on its top frame, clear of the icon, and rises over the top edge a little. `TaSlotGrid` keeps that much room between rows; in a grid of your own, set its row gap to at least `TaSlot.count_room(grid)`.

### TaWindow / TaTabWindow / TaHeaderPanel

```
var win := TaWindow.new()
win.title = "Inspector"
win.get_content().add_child(Label.new())
add_child(win)
var tabs := TaTabWindow.new()
tabs.title = "Loadout"
tabs.add_page("Stats", Label.new())
add_child(tabs)
var panel := TaHeaderPanel.new()
panel.title = "Loadout"
panel.get_content().add_child(Label.new())
add_child(panel)
```

Not IDE docking.

### TaFieldRow

```
var row := TaFieldRow.new()
row.caption = "Name"
row.set_field(LineEdit.new())
add_child(row)
```

One labeled field. `TaInspector.add_row` stacks many of these.

### TaInspector

```
var inspect := TaInspector.new()
inspect.add_row("Name", LineEdit.new())
add_child(inspect)
```

### TaInfoPopup / TaInfoIcon

```
var popup := TaInfoPopup.new()
add_child(popup)
popup.popup_message("Hover help.", anchor)
var info := TaInfoIcon.new()
info.title = "Hint"
info.body = "Click for TaInfoPopup."
add_child(info)
```

### TaTransition

```
TaTransition.on(self).fade_through()
# TaTransition.on(self).wipe_through()
# TaTransition.on(self).through()
```

Helper overlay, same as `TaDimmer`: spawn with `.on(host)`, not Create New Node. Not a scene router.

### TaPromptHint / TaRebindRow

```
var hint := TaPromptHint.new()
add_child(hint)
var row := TaRebindRow.new()
row.action = &"ui_accept"
add_child(row)
```

First keyboard event only. Does not persist.

### TaChip / TaBar / TaVBar / TaRadial

```
var chip := TaChip.new()
chip.set_caption("Gold")
chip.set_value(120)
add_child(chip)
var bar := TaBar.new()
bar.set_caption("HP")
bar.set_value(62)
add_child(bar)
var vbar := TaVBar.new()
vbar.set_caption("MP")
vbar.set_value(40)
add_child(vbar)
var radial := TaRadial.new()
radial.set_caption("XP")
radial.set_value(72)
add_child(radial)
```

### TaTag

```
var tag := TaTag.new()
tag.text = "Quest"
tag.dismissible = true
add_child(tag)
```

### TaButtonRow / TaButtonCol / TaToggleGroup

```
var row := TaButtonRow.new()
row.set_captions(PackedStringArray(["Save", "Load"]))
add_child(row)
var col := TaButtonCol.new()
col.set_captions(PackedStringArray(["Resume", "Options"]))
add_child(col)
var group := TaToggleGroup.new()
group.add_option("Low")
group.add_option("High")
add_child(group)
```

### TaSortList / TaReorderList / TaIconGrid

```
var sort := TaSortList.new()
sort.set_items(PackedStringArray(["Oak", "Ash"]))
add_child(sort)
var list := TaReorderList.new()
list.set_items(PackedStringArray(["First", "Second"]))
add_child(list)
var icons := TaIconGrid.new()
icons.grid_columns = 4
icons.cell_count = 8
add_child(icons)
```

### Options panel

```
var options := preload("res://addons/theme_assist/scenes/options.tscn").instantiate()
add_child(options)
```

## HUD in the world

The HUD is the canvas strip (`scenes/hud.tscn`) plus `TaWorldAttach`, which puts the same components into a 3D scene wearing the active look. It is not a preset: switch looks and both follow.

### TaWorldAttach

```
var attach := TaWorldAttach.new()
attach.position = Vector3(0, 2.2, 0)   # above the enemy's head
enemy.add_child(attach)
var hp := TaBar.new()
hp.set_caption("HP")
hp.set_range(72, 100)
attach.add_content(hp)                 # the same TaBar the canvas strip uses
```

`mode`: `BILLBOARD` (default) draws into a SubViewport on a camera-facing Sprite3D, so it scales with distance and hides behind walls (`on_top = true` draws through them). `SCREEN` pins the content to the HUD canvas over the 3D point: the same size at any distance, always crisp. `pixel_size` is world units per content pixel at 1080: on a 4K canvas the content has twice the pixels and the quad keeps its world size. Far from the camera a `BILLBOARD` grows so its caption capitals stay at 9 screen pixels on vector looks (whole pixels on pixel looks, whose faces break up when shrunk), measured on the real screen. A `TaBar` keeps room for its widest value, so the number sits wholly in the fill or the track. Nameplates side by side: a name over the bar (`attach.add_content(name)` then `attach.add_content(bar)`) keeps each plate as narrow as its bar. Make the name a `TaTag` so it sits on a surface: small light type with only a halo is lost on a mid-tone sky. `max_distance` fades it out. Text placed straight on a scene (`TaInteractHint`, `TaFloater`) uses `TaSceneText` and `TaSceneSuccess`: light ink with a dark halo in every look (a drop shadow on pixel looks), as subtitles do, so it reads over a night or a snow scene. A hint placed inside a panel instead sets `hint.on_scene = false` for plain ink. Display only: no clicks in the world. `TaLook.bind(look)` (and so every `apply_to`) refreshes every attach.

```
TaFloater.pop_world(enemy, "-12")      # a damage number over a 3D object
```

Example: `examples/world_hud/world_hud.tscn` (keys 1–4 switch the look).

## HUD atoms (canvas)

The canvas half. Any of these also goes into a `TaWorldAttach`.

**Bar text.** A `TaBar` value (`set_range(180, 480)`, or the percentage after `set_value`) is solid ink split at the fill edge, so it reads on the fill and on the empty track alike. Text that does not fit across the bar at its widest is not drawn: a default `TaVBar` is narrower than "100%", so it is a plain gauge until you widen `get_bar()`. `get_bar().show_percentage = false` hides the percentage.

```
var hp := TaBar.new()
hp.set_caption("HP")
hp.set_range(72, 100)

var ammo := TaChip.new()
ammo.set_caption("AMMO")
ammo.set_pair(30, 90)

var hint := TaInteractHint.new()
hint.set_prompt("E", "Open chest")

var feed := TaKillFeed.new()
feed.push_line("Eliminated cube")
host.set_corner(TaToastHost.Corner.BOTTOM_LEFT)

var reticle := TaReticle.new()
add_child(reticle)
reticle.ping_hit()
var vig := TaVignette.new()
add_child(vig)
vig.flash(1.0)

var hot := TaHotbar.new()
var map := TaMinimap.new()
var party := TaPartyFrame.new()
party.set_member_name("Ally")
var bubble := TaSpeechBubble.new()
bubble.set_text("Pay the debt.")
var card := TaShopCard.new()
card.set_title("Spud SMG")
var row := TaStatRow.new()
row.set_stat("Damage", 8)

var pick := TaChoicePicker.new()
pick.set_heading("Level up")
pick.set_choice(0, "Berserk", "+8 Damage")
pick.choice_picked.connect(_on_pick)

var splash := TaWinSplash.new()
splash.set_amount("+54")
splash.present()

var banner := TaBanner.new()
banner.set_title("WAVE 3")
banner.set_sub("12")

var buffs := TaBuffStrip.new()
buffs.set_buff(0, "Haste")

var bet := TaStepper.new()
bet.set_value(5)

var quest := TaQuestTracker.new()
quest.set_objectives(PackedStringArray(["Clear the crypt"]))
```

`TaPromptHint` stays the pause Esc|Enter strip. World `[E]` is `TaInteractHint`. Combat lines are `TaKillFeed`, not `TaToastHost`.

Thin FPS chrome: Flat with `content_margin` and `button_min_height` turned down, saved from the playground.

Playground **Recipes** tab: FPS / Dungeon / Shop / Casino. Each shell wears your saved look. **Copy recipe** on Casino pastes a felt-table shell (vault chip, `Table` for your art, `TaPlateButton`). The widgets on that row are samples. Example: `examples/fps_hud/fps_hud.tscn` prints `FPS_RECIPE_OK`.

`TaSlot.set_cell_size(Vector2(64, 64))` keeps a grid cell across theme changes. Assigning `custom_minimum_size` does too. `Vector2.ZERO` returns to the look's slot size (48 px; 22 art px in Framed and Pixel).

Baked plaque or chip art uses `TaPlateButton.set_plate(texture)`. It does not paint a theme caption. Felt stays your `TextureRect`. Chip rails are a row of plates you fill.

```
TaFloater.pop(hud, "+12 gold", Vector2(80, 80))
var compass := TaCompass.new()
var board := TaScoreboard.new()
var cell := TaHighlightCell.new()
cell.set_selected(true)
hot.paint_demo_icons()
```

Badge/Tag tones: `DEFAULT`, `ACCENT`, `MUTED`, `DANGER`, `SUCCESS`, `WARNING`, `RARITY`.

Your own tones live on the look. They survive every `apply_to`:

```
var look := TaTokens.modern()
look.tones = {"money": Color(0.2, 0.55, 0.3), "coa": Color(0.3, 0.4, 0.7)}
TaThemeBuilder.apply_to(self, look)
tag.tone_name = "money"             # TaTagMoney
badge.tone_name = "coa"             # TaBadgeCoa
host.show_message("+$40", -1.0, TaBadge.Tone.DEFAULT, "money")
```

Badge on any control (unread count, phone tile, hotbar key). Empty text hides it:

```
TaBadge.attach(phone_button, "3")
TaBadge.attach(phone_button, "")
```

"Ready" loop on any control. Reduced motion leaves it still:

```
TaJuice.pulse(ready_pot, Color(0.8, 1.0, 0.4))
TaJuice.stop_pulse(ready_pot)
```

Dial with a hole and a centre number. Color by threshold is one line of yours:

```
dial.set_ring_width(6)
dial.set_value(pct)
dial.set_center_text("%d%%" % pct)
dial.get_bar().tint_progress = look.color_danger if pct < 30 else look.color_success
```

## Keyboard, Esc, and overlays

**Who gets Esc.** Godot hands `_unhandled_input` to the **last node in the tree first**. The pause drop-in is usually added last, so without help it hears Esc before your drawers. The fix is a router:

```
# One per scene. Esc: top open overlay first, then pause.tscn toggles.
var router := TaCancelRouter.new()
add_child(router)
# TaModal, TaOverlay, TaDialog, and pause.tscn join it on open. Your own panels:
func open_phone() -> void:
	phone.show()
	router.push(phone, close_phone)   # leaves the stack when hidden or freed
# HUD state Esc clears before the menu opens, but never ahead of an open overlay:
router.push(selection_box, clear_selection, true)   # true = under every overlay
# Something other than pause when nothing is open:
router.fallback = func() -> void: system_menu.toggle()
# A gamepad Back button or an on-screen arrow does exactly what Esc does:
router.cancel()
# "Is a menu up?" (block gameplay input), router or not: TaOverlay.any_open(self)
```

Without a router, two ways to stay in charge:

```
# 1. Your overlay says "not now" while it is open. Pause checks the whole tree.
func blocks_pause_cancel() -> bool:
	return visible

# 2. You route Esc. Pause never reads it; you open it last.
pause.listen_cancel = false
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if prompt.visible: prompt.hide_modal()
		elif drawer.visible: drawer.hide_modal()
		else: pause.toggle()
		get_viewport().set_input_as_handled()
```

`pause.pause_tree = false` keeps `SceneTree.paused` alone for games that freeze their own clock. Toasts do not take Esc unless `host.esc_dismisses = true`, and even then an open overlay goes first; with a router the toasts sit under every overlay (Esc: overlay, then toast, then pause). A listening `TaRebindRow` takes Esc before anyone (it cancels the listen).

**Your own pause menu.** Keep the overlay (dimmer, tree pause, Esc, focus, Options) and swap the card:

```
pause.menu = preload("res://ui/system_menu.tscn")   # or pause.set_menu(my_menu)
# In your menu: pause.dismiss() to resume, pause.open_options() for the Options panel.
```

**Your own full-screen overlay.** Extend or instance `TaOverlay`. It is full rect, hidden and click-through until `open()`, dims, traps focus, returns focus on `close()`, and joins the router:

```
var layer := TaOverlay.new()
add_child(layer)
my_panel.z_index = 1          # above the dimmer
layer.add_child(my_panel)
layer.open()                  # Esc closes; override handle_cancel() for more
layer.closed.connect(_on_phone_closed)
```

If you build one by hand, use `set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`, not `set_anchors_preset`: the second keeps old offsets and leaves the overlay 0×0.

One layer can veil differently from the rest, and close on a click outside its panel:

```
phone_layer.dim_alpha = 0.25              # light: the room stays readable (-1 = the look's)
phone_layer.dim_blur = 0.0                # no blur on this one
phone_layer.close_on_outside_click = true # the click does what Esc does
```

**A card beside a control.** `TaPopover` opens next to its anchor on the side with room, inside `safe_insets` (x left, y top, z right, w bottom), follows the anchor, and scrolls when taller than the room. A click elsewhere closes it and still reaches what was clicked, so pressing another pot opens that pot's card. Esc closes it (through the router when placed) and focus goes back to the anchor. It does not dim or trap focus. A side passed to `open()` is for that open only; the next `open(anchor)` uses `side` again. A card draws above your layers (`z_index` 90), so a `TaModal`, `TaOverlay`, or pause opening elsewhere closes it first. A layer of your own does the same with `get_tree().call_group(TaPopover.GROUP, "close")`.

```
var card := TaPopover.new()
add_child(card)
card.safe_insets = Vector4(8, 64, 96, 8)   # clear of the HUD row and the right rail
card.get_content().add_child(plant_panel)
pot.pressed.connect(func() -> void: card.open(pot))   # or card.open(pot, TaPopover.Placement.BELOW)
```

In a row of anchors, pass the row as `keep_clear` (Controls or global Rect2s). Among the sides with room, AUTO takes the one covering least of them, so the other pots stay clickable:

```
card.keep_clear = pots   # an Array of the row's Controls; the anchor itself is skipped
```

**A scroll inside a centred card.** A ScrollContainer has no height of its own, so in a CenterContainer it collapses to 0 px. `TaFit.hug_scroll(scroll, max_height)` keeps it as tall as its content, up to the cap, and refits when the content changes (`TaModal` and `TaPopover` use it).

**Clicks follow tree order, not `z_index`.** An overlay drawn on top (higher `z_index`) but added before a sibling still loses clicks to that sibling. Add layers in the order they stack: scene, HUD, popovers, drawers, modals, menus.

**Rebuild a list without losing focus.** A HUD that rebuilds its buttons on every clock tick frees the focused one. Rebuild only when the set of items changes (compare a signature: the ids joined into a string) and restyle in place otherwise.

**Focus.** A hidden list never grabs focus. Menus use a vertical chain so Left/Right stay put:

```
TaFocus.chain([resume, options, quit], TaFocus.Axis.VERTICAL)
TaFocus.rows([[tile_a, tile_b], [tile_c, tile_d], [list_row], [back]])
TaFocus.trap(my_overlay)    # Tab cannot leave while it is visible
TaFocus.release(my_overlay)
TaFocus.focus_first(my_overlay)   # after you rebuild its children
TaFocus.wrap(buttons, TaFocus.Axis.HORIZONTAL)   # Right on the last goes to the first
```

`TaModal` and `pause.tscn` trap and release on their own. `TaModal` hands focus back to whatever had it before `show_modal()`. `TaButtonRow`, `TaButtonCol`, `TaToggleGroup`, and `TaHotbar` wrap at their ends already.

**Gamepad.** There is no second input path: kit components answer `ui_accept`, `ui_cancel`, and the `ui_up` / `ui_down` / `ui_left` / `ui_right` focus moves, which Godot maps to the stick, the d-pad, and A/B by default. Focus arriving from a pad or keys gives the same lift and tick as a mouse hover, and `ui_accept` plays the press. `TaPromptHint` swaps its glyphs when a pad is in use.

**Keys that do not navigate.** Godot matches `ui_up` / `ui_accept` exactly, so Shift+Down or a numpad digit with NumLock on is not "down". That is deliberate and we do not rewrite it. If your platform sends physical-only keys (some remote desktops, xdotool), add a physical-key event to the action once at boot:

```
var down := InputEventKey.new()
down.physical_keycode = KEY_DOWN
InputMap.action_add_event("ui_down", down)
```

## Menu page, prompt, confirm card, recap

One `TaModal`, four jobs. All are `TaOverlay` sheets: dimmer, focus trap, focus return, and router membership.

```
# Menu page: title, X, scroll body capped at 80% of the screen.
var page := TaModal.new()
page.title = "Journal"
page.confirm_text = ""
page.closable = true
page.panel_width = 640
page.max_height_ratio = 0.8   # of the screen height
page.max_height_px = 680      # and never taller than this (the smaller cap wins)
add_child(page)
page.get_content().add_child(journal_rows)
page.show_modal()

# Prompt: Enter confirms, Esc cancels.
var ask := TaModal.new()
ask.title = "Nickname"
ask.cancel_text = "Cancel"
add_child(ask)
ask.add_text_field(current_name, 16)
ask.confirmed.connect(func() -> void: rename(ask.get_text_field().text))
ask.show_modal()

# Confirm card: costs, one option group, bullets, Back | Water. Rebuild per action.
var card := TaModal.new()
card.title = "Water"
card.cancel_text = "Back"
card.confirm_text = "Water"
add_child(card)
func show_water() -> void:
	card.clear_content()
	card.add_costs([["⏱", "15 min"], ["⚡", "-2"]])
	var amount := card.add_options("Amount", PackedStringArray(["Light", "Soak"]))
	card.add_bullets(PackedStringArray(["Soak doubles runoff."]))
	card.show_modal()   # confirm has focus, so Enter waters
# The same chips anywhere else (a shop row, the HUD):
shop_row.add_child(TaBadge.cost_row([["⏱", "15 min"], ["⚡", "-2"]]))
# Colour emoji keep their colours (Godot does not tint them): a gold ⚡ vanishes on a
# Warning chip. Tone a chip whose glyph your font draws in one colour; it takes the ink.

# Recap the player must read: rows, blurb, no Esc.
var recap := TaModal.new()
recap.title = "Day 4 complete"
recap.body = "The grove is quiet."
recap.confirm_text = "OK · continue"
recap.esc_closes = false
add_child(recap)
var rows := TaInspector.new()
var sold := Label.new(); sold.text = "+$120"; sold.theme_type_variation = "TaSuccessLabel"
rows.add_row("Sold", sold)
recap.get_content().add_child(rows)
recap.show_modal()
```

Choice with odds: put the odds in the body, `picker.set_choice(0, "Haggle", "60% · +$40")`. Cards take focus, so arrows and Enter pick. The result is a recap sheet as above.

Settings row with an example: `inspector.add_row("Clock", toggles)` with `toggles.add_option("12h · 4:05 PM")`.

## Text styles and fonts

`[b]`, `[i]`, and `[s]` in a `RichTextLabel` use the look's faces. `TaBold` and `TaItalic` are Label variations.

```
look.face = preload("res://fonts/body.ttf")
look.face_bold = preload("res://fonts/body_bold.ttf")      # optional; null emboldens face
look.face_italic = preload("res://fonts/body_italic.ttf")  # optional; null stays upright
```

Italic is never faked. In Godot 4.7 a `FontVariation` slant leaves straight stems (l, t, F) upright while round letters lean, which reads as broken, not italic. **Without `face_italic`, `[i]` and `TaItalic` stay upright.** Any OFL italic works, for example the italic cut of the family you use for `face`.

Emoji and other missing glyphs: desktop builds fall back to system fonts on their own. Web exports have none, so emoji show as boxes. Add a fallback chain to the look; every face gets it, the Pixel face included, and your fonts are not modified:

```
look.fallback_fonts = [preload("res://fonts/NotoColorEmoji.ttf")]
TaThemeBuilder.apply_to(self, look)
```

We do not bundle an emoji font. Noto Color Emoji alone is about forty times the size of the addon.

## Panels and destructive buttons

`TaDangerQuiet` is a surface button with a danger border and danger text. Same height as its neighbours. Use it for New game in a menu. Keep `TaDanger` for the confirm button that actually wipes.

Gradient card, no shader:

```
var grad := Gradient.new()
grad.set_color(0, Color("#2b5d3a")); grad.set_color(1, Color("#12301d"))
var tex := GradientTexture2D.new()
tex.gradient = grad
tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(1, 1)
var box := StyleBoxTexture.new()
box.texture = tex
wallet.add_theme_stylebox_override("panel", box)
```

Backdrop blur behind every pause and modal: `look.dimmer_blur = 6.0` (px). 0 is the plain veil.

Toasts: `host.set_corner(TaToastHost.Corner.BOTTOM_CENTER)`, `host.max_visible = 3`, `host.overflow = TaToastHost.Overflow.DROP_OLDEST`, `host.merge_repeats = true` so "You're busy" refreshes instead of stacking.

## Stock dropdowns and trees

OptionButton is the first-class dropdown (Kit tab): `options.add_item("Alpha")`.  
Tree is Theme-painted; use `TaSortList` when you need a sort header.

## Not this pack

Persistent settings, scene router, loot DB, full input mapper — not Theme Assist.

Also not here: an app shell with a back stack (that is a page router), a global Esc singleton (`TaCancelRouter` is a node you place), a key re-dispatcher, trend chevrons, and a stat-card builder. The recipes above cover the screens those were asked for.

Also out of scope: drag/rotate inventory and reel *symbol art* (use `TaHighlightCell` for win chrome). World-space HP and damage numbers are in scope: `TaWorldAttach` (the same `TaBar` as the canvas strip) and `TaFloater.pop_world`; see HUD in the world.
