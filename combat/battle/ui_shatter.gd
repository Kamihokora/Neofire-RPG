extends Node2D
## 用当前界面的纹理碎片作刚体；只处理视觉，绝不移动真实的战斗节点。

var bodies: Array[RigidBody2D] = []
var _rng := RandomNumberGenerator.new()


func burst(snapshot: Texture2D, regions: Array[Rect2], viewport_size: Vector2) -> void:
	_rng.randomize()
	var uv_scale := snapshot.get_size() / viewport_size
	for rect in regions:
		var columns := maxi(2, int(ceil(rect.size.x / 170)))
		var rows := maxi(1, int(ceil(rect.size.y / 150)))
		for y in rows:
			for x in columns:
				var a := rect.position + rect.size * Vector2(float(x) / columns, float(y) / rows)
				var b := rect.position + rect.size * Vector2(float(x + 1) / columns, float(y + 1) / rows)
				var corners := [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]
				_fragment(snapshot, PackedVector2Array([corners[0], corners[1], corners[2]]), uv_scale)
				_fragment(snapshot, PackedVector2Array([corners[0], corners[2], corners[3]]), uv_scale)
	var cleanup := get_tree().create_timer(2.0)
	cleanup.timeout.connect(queue_free)


func _fragment(snapshot: Texture2D, points: PackedVector2Array, uv_scale: Vector2) -> void:
	var center := (points[0] + points[1] + points[2]) / 3
	var body := RigidBody2D.new()
	body.position = center
	body.collision_layer = 0
	body.collision_mask = 0
	body.gravity_scale = 1.8
	body.linear_velocity = Vector2((center.x - 960) * 0.4 + _rng.randf_range(-160, 160), _rng.randf_range(-350, -100))
	body.angular_velocity = _rng.randf_range(-3.5, 3.5)
	var polygon := Polygon2D.new()
	var local := PackedVector2Array()
	var uv := PackedVector2Array()
	for point in points:
		local.append(point - center)
		uv.append(point * uv_scale)
	polygon.polygon = local
	polygon.uv = uv
	polygon.texture = snapshot
	body.add_child(polygon)
	var collision := CollisionPolygon2D.new()
	collision.polygon = local
	body.add_child(collision)
	add_child(body)
	bodies.append(body)
