extends RefCounted
## 开场与交涉返回共用的方向缓入。位置和透明度还原到调用前的值。

static func reveal(owner: Node, items: Array[CanvasItem], duration: float = 0.46) -> void:
	var states: Array[Dictionary] = []
	for item in items:
		if not is_instance_valid(item) or not item.visible:
			continue
		var home: Vector2 = item.position
		var tint := item.modulate
		var center := home
		if item is Control:
			center += item.size * 0.5
		var offset := Vector2(0, 52)
		if center.y < 125:
			offset = Vector2(0, -32)
		elif center.y < 650:
			offset = Vector2(-48 if center.x < 960 else 48, 0)
		var delay := 0.06 if center.y > 840 else 0.0
		item.position = home + offset
		item.modulate.a = 0.001
		states.append({"item": item, "home": home, "offset": offset, "tint": tint, "delay": delay})
	# 先提交一次绘制。首次编译着色器的大帧不应吞掉整段开场动画。
	await RenderingServer.frame_post_draw
	var elapsed := 0.0
	while elapsed < duration + 0.06:
		elapsed += minf(owner.get_process_delta_time(), 1.0 / 30.0)
		for state in states:
			var item: CanvasItem = state["item"]
			if not is_instance_valid(item):
				continue
			var progress := clampf((elapsed - state["delay"]) / duration, 0, 1)
			var eased := 1.0 - pow(1.0 - progress, 3.0)
			item.position = state["home"] + state["offset"] * (1.0 - eased)
			var tint: Color = state["tint"]
			item.modulate = Color(tint, tint.a * sin(progress * PI * 0.5))
		await owner.get_tree().process_frame
	for state in states:
		var item: CanvasItem = state["item"]
		if is_instance_valid(item):
			item.position = state["home"]
			item.modulate = state["tint"]
