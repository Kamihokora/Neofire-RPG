class_name MapTransition
extends CanvasLayer
## 场景切换的黑场。
##
## 关键点：它挂在 /root 上（不是当前场景里），所以 change_scene_to_file 换成新场景时
## 它自己不会被一起释放，能接着把新场景淡入。

const FADE_TIME := 0.22
## 比战斗层(20)、对话层(10)、淡入淡出层都高
const FADE_LAYER := 120

var _rect: ColorRect


## 淡出 → 切场景 → 淡入 → 自毁
static func play(path: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		push_error("[MapTransition] 没有 SceneTree，切场景失败")
		return
	var transition := MapTransition.new()
	tree.root.add_child(transition)
	transition._go(path)


func _ready() -> void:
	layer = FADE_LAYER
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 黑场期间别让玩家还能点到下面的东西
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rect)


func _go(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		queue_free()
		return
	var out := create_tween()
	out.tween_property(_rect, ^"color:a", 1.0, FADE_TIME)
	await out.finished
	var err := tree.change_scene_to_file(path)
	if err != OK:
		push_error("[MapTransition] 切场景失败（err=%d）：%s" % [err, path])
	# 等新场景进树并 ready，再淡入
	await tree.process_frame
	await tree.process_frame
	var back := create_tween()
	back.tween_property(_rect, ^"color:a", 0.0, FADE_TIME)
	await back.finished
	queue_free()
