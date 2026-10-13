extends Control
## B 系统的入口节点（grid.gd / game.gd 都调 show_dialogue(player, dialogue_player)）。
##
## 表现层已经搬到 Dialogic 的自定义 layout（dialogue/dialogic/layout/neofire_box.gd），
## 这里只做转发：把游戏侧的对话驱动器 DialoguePlayer 叫起来。

func _ready() -> void:
	# 自由移动的主角靠这个组找对话入口
	add_to_group(&"dialogue_ui")


## 有对话正在播吗（主角用它判断"对话中按 E 无效"）
func is_busy() -> bool:
	return Dialogic.current_timeline != null


func show_dialogue(player: Node2D, dialogue: Node) -> void:
	if dialogue == null:
		return
	# 驱动器必须在场景树上：它的 _ready 才接得上 Dialogic 的信号（否则对话结束不会解锁玩家）
	if dialogue.get_parent() == null:
		add_child(dialogue)
	if dialogue.has_method(&"start_dialogue_with"):
		dialogue.start_dialogue_with(player)
	else:
		push_error("[DialogueUI] %s 不是新的对话驱动器（缺 start_dialogue_with）" % dialogue)
