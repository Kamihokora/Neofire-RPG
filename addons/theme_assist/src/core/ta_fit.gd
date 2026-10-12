class_name TaFit
extends Object

# AGENT: Layout helpers for the Godot footguns that overlays hit. Static, no nodes.
# INVARIANT: fit_scroll gives a ScrollContainer its content's height plus its own
# frame, capped; past the cap it scrolls. Uncapped, it never scrolls.
# DO NOT: Lay out anything but the scroll it is given. Do not autoload.

## A ScrollContainer has no minimum height of its own, so inside a CenterContainer
## (every centred card) it collapses to 0 px and its content vanishes.
## TaFit.hug_scroll(scroll, max_height) keeps it as tall as its content, up to a cap.

const _HUG_META := &"_ta_hug_max"


## Size `scroll` to its content now. max_height <= 0: no cap (and no scrolling).
static func fit_scroll(scroll: ScrollContainer, max_height: float = 0.0) -> void:
	if not is_instance_valid(scroll) or scroll.get_child_count() == 0:
		return
	var content := scroll.get_child(0) as Control
	if content == null:
		return
	# The frame's own margins count too, or short content still shows a scrollbar.
	var frame := 0.0
	if scroll.is_inside_tree() and scroll.has_theme_stylebox("panel"):
		frame = scroll.get_theme_stylebox("panel").get_minimum_size().y
	var want := content.get_combined_minimum_size().y + frame
	if max_height > 0.0:
		want = minf(want, max_height)
	scroll.custom_minimum_size.y = want
	scroll.vertical_scroll_mode = (
			ScrollContainer.SCROLL_MODE_AUTO
			if max_height > 0.0
			else ScrollContainer.SCROLL_MODE_DISABLED
	)


## fit_scroll now and again whenever the content's size changes. Call again to change
## the cap; it does not connect twice.
static func hug_scroll(scroll: ScrollContainer, max_height: float = 0.0) -> void:
	if not is_instance_valid(scroll) or scroll.get_child_count() == 0:
		return
	var content := scroll.get_child(0) as Control
	if content == null:
		return
	var hooked := scroll.has_meta(_HUG_META)
	scroll.set_meta(_HUG_META, max_height)
	if not hooked:
		var refit := func() -> void:
			if is_instance_valid(scroll):
				fit_scroll(scroll, float(scroll.get_meta(_HUG_META, 0.0)))
		content.minimum_size_changed.connect(refit)
	fit_scroll(scroll, max_height)
