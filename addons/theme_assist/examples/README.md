# Theme Assist examples

Minimal consumers. Not games. Copy the playground **Recipes → Copy recipe** shell, or run these scenes. Both wear the look you saved in the playground (Flat until you Save one).

## FPS HUD

`fps_hud/fps_hud.tscn` — CanvasLayer HUD using only Theme Assist atoms:

HP/armor `set_range`, ammo `set_pair`, `[E]` `TaInteractHint`, `TaKillFeed`, `TaReticle`, `TaVignette`, toast `set_corner` (bottom-right, away from the feed), pause drop-in.

```
godot --headless --path . res://addons/theme_assist/examples/fps_hud/fps_hud.tscn
```

Prints `FPS_RECIPE_OK`.

## World HUD

`world_hud/world_hud.tscn` — a 3D scene: crates wear `TaBar` nameplates through `TaWorldAttach` (billboards in the world), a loot `TaChip` is pinned to the canvas over a 3D point (`Mode.SCREEN`), and the HUD strip (`scenes/hud.tscn`) shows the same `TaBar` on the canvas. Press 1–4 to switch Flat / Modern / Framed / Pixel: both halves follow.

```
godot --headless --path . res://addons/theme_assist/examples/world_hud/world_hud.tscn
```

Prints `WORLD_HUD_OK`.
