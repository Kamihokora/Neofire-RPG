extends Node
## 独立联调入口：只在本场景赠送经验/词条/形态值，F5正式游戏不发测试资源。

var game: Node
var table: Node2D


func _ready() -> void:
	start.call_deferred()


func start() -> void:
	RunState.instance.reset_run()
	game = load("res://game.tscn").instantiate()
	add_child(game)
	game.save_store.directory = "user://progression_preview_slots"
	await get_tree().process_frame
	await get_tree().process_frame
	var state := RunState.instance
	state.journey.award_experience(30, state)
	for id: String in state.journey.inspiration()["words"]:
		state.journey.add_inspiration(id, 2)
	state.journey.compose("test1", "test2")
	state.journey.compose("old_computer", "remove_360")
	state.set_form_value(10)
	var player: Node2D = game.current_player()
	table = load("res://gameplay/proposal_table.tscn").instantiate()
	table.name = "TestProposalTable"
	game.current_map.add_child(table)
	table.global_position = player.global_position + Vector2(64, 0)
	var pickup: Node2D = load("res://gameplay/inspiration_pickup.tscn").instantiate()
	pickup.name = "TestInspiration"
	game.current_map.add_child(pickup)
	pickup.global_position = player.global_position + Vector2(-64, 0)
	game.phone.open_phone("notebook")
