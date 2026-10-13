class_name Pawn
extends Node2D

enum CellType {
	ACTOR,
	OBSTACLE,
	OBJECT,
}

@export var type := CellType.ACTOR

var active: bool = true: set = set_active

func set_active(value: bool) -> void:
	active = value
	set_process(value)
	set_process_input(value)


## 对话框/血条之类该浮所在的世界坐标（"头顶锚点"）。
## 默认就是逻辑坐标；Walker 会覆盖它，把走路过程中 Pivot 的位移算进来，
## 否则格子瞬移会让跟随物一跳一跳。
func get_bubble_anchor() -> Vector2:
	return global_position
