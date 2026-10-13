extends Control
## 形态切换时的全身立绘切入（OMORI 式的“大招演出”）。
##
## 时序：立绘从右侧滑入 + 闪白 → 标题从左侧滑入 → 停留 → 整体淡出。
## 调用：play("writer", "文手形态", "res://assets/portraits/xinhuo_normal.png")

const IN_TIME := 0.35
const HOLD_TIME := 0.75
const OUT_TIME := 0.3

@onready var _art: TextureRect = $Art
@onready var _title: Label = $Title
@onready var _flash: ColorRect = $Flash
@onready var _dim: ColorRect = $Dim

var _tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 播放切入。返回的 await 在演出播完后继续。
func play(_form_id: String, title: String, art_path: String = "") -> void:
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		_art.texture = load(art_path)
	_title.text = title
	visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()

	var art_home := _art.position
	var title_home := _title.position

	# 入场
	_dim.modulate.a = 0.0
	_art.position = art_home + Vector2(520.0, 0.0)
	_title.position = title_home - Vector2(420.0, 0.0)
	_art.modulate.a = 0.0
	_title.modulate.a = 0.0
	_flash.color.a = 0.9

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_dim, ^"modulate:a", 1.0, IN_TIME)
	_tween.tween_property(_art, ^"position", art_home, IN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_art, ^"modulate:a", 1.0, IN_TIME)
	_tween.tween_property(_title, ^"position", title_home, IN_TIME + 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_title, ^"modulate:a", 1.0, IN_TIME + 0.12)
	_tween.tween_property(_flash, ^"color:a", 0.0, IN_TIME)
	await _tween.finished

	await get_tree().create_timer(HOLD_TIME).timeout

	# 收场
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, ^"modulate:a", 0.0, OUT_TIME)
	await _tween.finished

	visible = false
	modulate.a = 1.0
	_art.position = art_home
	_title.position = title_home
