extends Control
## 横向眼部切入。Atlas 只取文手立绘双眼，不修改原图。

const EYE_REGION := Rect2(540, 625, 650, 380)
var _banner: Node2D
var _eye_art: TextureRect
var _tween: Tween


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Art.hide()
	$Title.hide()
	$Flash.hide()
	_banner = Node2D.new()
	_banner.name = "EyeBanner"
	_banner.position = Vector2(0, 252)
	add_child(_banner)
	_polygon(_banner, PackedVector2Array([Vector2(0, 22), Vector2(1850, -72), Vector2(1920, 302), Vector2(0, 412)]), Color(0.015, 0.015, 0.025))
	_polygon(_banner, PackedVector2Array([Vector2(0, 40), Vector2(1838, -54), Vector2(1920, 282), Vector2(0, 392)]), Color.WHITE)
	var mask := _polygon(_banner, PackedVector2Array([Vector2(0, 58), Vector2(1818, -31), Vector2(1920, 264), Vector2(0, 371)]), Color(0.15, 0.6, 0.66))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_eye_art = TextureRect.new()
	_eye_art.name = "Eyes"
	_eye_art.position = Vector2(0, -310)
	_eye_art.size = Vector2(1920, 920)
	_eye_art.pivot_offset = _eye_art.size * 0.5
	_eye_art.rotation = -0.43
	_eye_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_eye_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_eye_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(_eye_art)
	_polygon(_banner, PackedVector2Array([Vector2(0, 382), Vector2(1480, 306), Vector2(1370, 330), Vector2(0, 404)]), Color(0.9, 0.08, 0.16))
	_polygon(_banner, PackedVector2Array([Vector2(1360, -18), Vector2(1810, -42), Vector2(1770, -25), Vector2(1320, 2)]), Color(0.9, 0.08, 0.16))


func play(_form_id: String, title: String, art_path: String = "res://neofire/Neofire-write.png") -> void:
	var eyes := AtlasTexture.new()
	eyes.atlas = load(art_path)
	eyes.region = EYE_REGION
	_eye_art.texture = eyes
	$Title.text = title
	visible = true
	_banner.position.x = -2200
	_eye_art.position.x = 70
	$Dim.modulate.a = 0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_banner, ^"position:x", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_property($Dim, ^"modulate:a", 0.8, 0.18)
	_tween.tween_property(_eye_art, ^"position:x", -45.0, 0.78)
	await _tween.finished
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_banner, ^"position:x", 2200.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	_tween.tween_property($Dim, ^"modulate:a", 0.0, 0.18)
	await _tween.finished
	visible = false


func _polygon(parent: Node, points: PackedVector2Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	parent.add_child(polygon)
	return polygon
