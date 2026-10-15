extends "res://combat/battle/battle.gd"
## 只为 F6 体验充满量表，正式战斗仍需正常积累。

func _ready() -> void:
	RunState.instance.reset_run()
	RunState.instance.set_form_value(RunState.FORM_COST)
	super._ready()
