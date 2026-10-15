@tool
extends StyleBox
## dobo 圆角横条：两端随高度等比缩放，中间只沿横向伸展。
## 保留原图的圆弧、高光、描边和阴影，不把弧线切入九宫格的拉伸区域。

var texture: Texture2D


static func create(path: String) -> StyleBox:
	var style: StyleBox = (load("res://assets/ui/dobo_button_style.gd") as GDScript).new()
	style.set(&"texture", load(path))
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _draw(canvas_item: RID, rect: Rect2) -> void:
	if texture == null or rect.size.x <= 0 or rect.size.y <= 0:
		return
	var source := texture.get_size()
	var cap := minf(source.x * 0.25, source.y)
	var width := minf(cap * rect.size.y / source.y, rect.size.x * 0.5)
	var destinations := [Rect2(rect.position, Vector2(width, rect.size.y)), Rect2(rect.position + Vector2(width, 0), Vector2(rect.size.x - width * 2, rect.size.y)), Rect2(rect.position + Vector2(rect.size.x - width, 0), Vector2(width, rect.size.y))]
	var regions := [Rect2(0, 0, cap, source.y), Rect2(cap, 0, source.x - cap * 2, source.y), Rect2(source.x - cap, 0, cap, source.y)]
	for i in 3:
		if destinations[i].size.x > 0:
			RenderingServer.canvas_item_add_texture_rect_region(canvas_item, destinations[i], texture.get_rid(), regions[i])
