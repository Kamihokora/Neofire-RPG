extends Node
## 系统自检（把这次交付的每条需求都断言一遍）。
##
## 用法：编辑器里打开 tests/system_check.tscn 运行（F6）。
## 输出：控制台 + debug_shots/system_check.txt，每行 [PASS]/[FAIL]，末尾给总数。
##
## 覆盖：
##   A Dialogic 集成与“旧解析器退休”      E Dialogic 存档（存/读回到同一句）
##   B 外观不变（对照迁移前基线数值）      F 战斗版式（OMORI：小头像/大敌人/头顶意图）
##   C 剧本行为（旁白/跟随/时停/离开反应） G 形态切换 + 全身立绘切入（由卡牌触发）
##   D 分支选项

@export var exploration_scene: PackedScene
@export var battle_scene: PackedScene
@export var game_scene: PackedScene
@export var trial_scene: PackedScene

@export_group("自检范围（省 token）")
## 只跑这几段，逗号分隔，比如 "F,G,J"；留空 = 全部跑。
## 段号 = 报告里的段标题字母：A集成 B外观 C剧本 D分支 E存档 F战斗 G形态 H游戏内 J自由移动 K队友 L转移 M编辑器 N相机
@export var only_sections: String = ""
## true = 报告里只写失败行和 debug 行（通过的省略），结论行照样给
@export var quiet_pass: bool = false

const REPORT := "res://debug_shots/system_check.txt"
const TL_DIR := "res://dialogue/dialogic/timelines/"
const CHAR_DIR := "res://dialogue/dialogic/characters/"
const CUTIN_ART := "res://assets/portraits/xinhuo_normal.png"

var _lines: Array[String] = []
var _pass := 0
var _fail := 0
## 要跑的段（空 = 全跑）
var _wanted: PackedStringArray = PackedStringArray()
var _zombies_cleaned: Array[String] = []

var _layout: Node = null
var _player: Node = null
var _obj: Node = null
var _ui: Node = null
var _dp: Node = null
var _signals: Array[String] = []


#region 断言基础设施
################################################################################

func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_pass += 1
		if not quiet_pass:
			_write("[PASS] %s %s" % [label, detail])
	else:
		_fail += 1
		_write("[FAIL] %s %s" % [label, detail])


## 这一段要不要跑（only_sections 为空 = 全跑）
func _want(section: String) -> bool:
	return _wanted.is_empty() or _wanted.has(section)


## 命令行也能筛：godot --path . -- --only=F,G --quiet
func _parse_scope() -> void:
	var raw := only_sections
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			raw = arg.trim_prefix("--only=")
		elif arg == "--quiet":
			quiet_pass = true
	_wanted = PackedStringArray()
	for part: String in raw.split(","):
		var s := part.strip_edges().to_upper()
		if not s.is_empty() and not _wanted.has(s):
			_wanted.append(s)


## 需要一个能用的探索世界：C/D/E 这些段都要。只跑那一段时现搭一个，别依赖别人先跑过。
func _ensure_world() -> void:
	if _world != null and is_instance_valid(_world) and _player != null and is_instance_valid(_player):
		return
	await _spawn_world()


func _eq(label: String, actual: Variant, expected: Variant) -> void:
	_check(label, actual == expected, "实际=%s 期望=%s" % [actual, expected])


func _write(line: String) -> void:
	print(line)
	_lines.append(line)
	var f := FileAccess.open(REPORT, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()


func _shoot(shot_name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://debug_shots/%s.png" % shot_name)
	_write("  （截图：debug_shots/%s.png）" % shot_name)
	await get_tree().process_frame


## 按一下某个键（真实输入管线，键盘类交互都走它）
func _press_key(keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().create_timer(0.15).timeout
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## 用真实鼠标事件点一个控件。
## 注意：走 Viewport.push_input（和 F17 出牌同一个套路），
## Input.parse_input_event 注入的鼠标位置不会更新 GUI 的 hover 状态（实测点了没反应）。
func _click_control(control: Control) -> void:
	var pos: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	get_viewport().push_input(motion)
	await get_tree().process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	get_viewport().push_input(up)


func _section(title: String) -> void:
	_write("")
	_write("=== %s ===" % title)


## 场上（整棵树里）有几个玩家：>1 说明地图实例叠在了一起（画面上会出现两支队）
func _players_in_tree() -> int:
	return get_tree().get_nodes_in_group(&"player").size()


## 场上活着的地图场景数（地图场景根节点在 map_scene 组里）
func _maps_in_tree() -> int:
	return get_tree().get_nodes_in_group(&"map_scene").size()


## 清掉自检自己留下的地图实例。它们会：叠影成"两支队"、
## 抢 player_camera 组（让 Walls 把地图边界写到别人家的相机上）。外壳里那张地图不动。
func _clear_stray_maps() -> void:
	var shell: Node = get_tree().get_first_node_in_group(&"game_shell")
	var cleaned := 0
	for node: Node in get_tree().get_nodes_in_group(&"map_scene"):
		if shell != null and shell.is_ancestor_of(node):
			continue
		if node == self or not self.is_ancestor_of(node):
			continue
		node.queue_free()
		cleaned += 1
	if cleaned > 0:
		await get_tree().process_frame
		await get_tree().process_frame


## 当前活跃的 2D 相机必须是主角那台跟随相机。
## 以前 game.tscn 里烘了一台外壳相机、exploration.tscn 里还留了一台地图相机（zoom 1.5），
## 谁后进树谁就成了 current → 游戏里画面钉死、相机不跟人走（自检却看不出来，因为树里先有别的相机）。
func _check_active_camera(label: String, map: Node, player: Node2D) -> void:
	var active: Camera2D = get_viewport().get_camera_2d()
	var want: Camera2D = player.get_node_or_null(^"Camera") as Camera2D
	_check(label + "：当前相机是主角的跟随相机", active != null and want != null and active == want,
		"活跃=%s 主角相机=%s"
			% [str(active.get_path()) if active != null else "无",
				str(want.get_path()) if want != null else "无"])
	# 有 Walls 的地图，地图边界应该写在"真正活跃"的那台相机上
	if map != null and map.has_node(^"Walls"):
		_check(label + "：相机拿到了地图边界（Walls 写对了相机）",
			active != null and active.limit_right < 10000000 and active.limit_left > -10000000,
			"limits=(%d, %d, %d, %d)"
				% [active.limit_left, active.limit_top, active.limit_right, active.limit_bottom]
				if active != null else "没有活跃相机")
#endregion


## 编辑器会把已删除的旧场景标签页回写到磁盘（引用的脚本已删 → 加载报错）。
## 每次自检先把它们清掉，做到自愈。
func _cleanup_zombie_scenes() -> Array[String]:
	var zombies := [
		"res://dialogue/quick_dialogue.tscn", "res://dialogue/test_quick_dialogue.tscn",
		"res://dialogue/test_story_dialogue.tscn", "res://dev_probe_gen.tscn",
		"res://dev_probe_skin.tscn", "res://dev_probe_battle.tscn",
		"res://dev_probe_loop.tscn", "res://dev_probe_dialogic.tscn", "res://dev_probe_edge.tscn",
	]
	var cleaned: Array[String] = []
	for path: String in zombies:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
			if not FileAccess.file_exists(abs_path):
				cleaned.append(path.get_file())
	return cleaned


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://debug_shots"))
	_parse_scope()
	_zombies_cleaned = _cleanup_zombie_scenes()
	await get_tree().process_frame
	if not _wanted.is_empty() or quiet_pass:
		_write("（本次范围：%s%s）"
			% [",".join(_wanted) if not _wanted.is_empty() else "全部",
				" · 静默通过" if quiet_pass else ""])
	if _want("A"):
		_check_dialogic_setup()
	if _want("B"):
		await _check_appearance()
	if _want("C"):
		await _check_script_behaviour()
	if _want("D"):
		await _check_branch()
	if _want("E"):
		await _check_save()
	if _want("F"):
		await _check_battle()
	if _want("G"):
		await _check_form_cutin()
	if _want("H"):
		await _check_in_game()
	if _want("J"):
		await _check_free_move()
	if _want("K"):
		await _check_party_and_trial()
	if _want("L"):
		await _check_map_transfer()
	if _want("M"):
		await _check_editor_tools()
	if _want("N"):
		await _check_camera_zoom()

	_write("")
	_write("===== 结果：%d 通过 / %d 失败 =====" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


## 战后对话驱动器是否真的进了场景树（H5 的失败根因就是它没进树）
func _dialog_driver_in_tree(game: Node) -> bool:
	var map: Node = game.current_map
	if map == null:
		return false
	var canvas: Node = map.get_node_or_null("DialogueCanvas")
	if canvas == null:
		return false
	for child in canvas.get_children():
		if child.has_method(&"start_dialogue_with"):
			return true
	return false


var _world: Node = null


func _spawn_world() -> void:
	if _world != null and is_instance_valid(_world):
		_world.queue_free()
		await get_tree().process_frame
	var inst: Node = exploration_scene.instantiate()
	_world = inst
	add_child(inst)
	await get_tree().create_timer(0.4).timeout
	_player = inst.get_node("Grid/Player")
	_obj = inst.get_node("Grid/Object")
	_ui = inst.get_node("DialogueCanvas/DialogueUI")
	_dp = _obj.get_node("DialoguePlayer")
	_player.position = _obj.position + Vector2(-64, 0)
	await get_tree().process_frame


## 复用的 sts2modding 素材是否与源文件逐字节一致（md5）
func _sts_provenance() -> bool:
	var pairs := {
		"res://assets/ui/intents/attack.png": "B:/Godot/sts2modding/images/packed/intents/attack/intent_attack_1.png",
		"res://assets/ui/intents/defend.png": "B:/Godot/sts2modding/images/packed/intents/intent_defend.png",
		"res://assets/ui/intents/buff.png": "B:/Godot/sts2modding/images/packed/intents/intent_buff.png",
		"res://assets/ui/intents/debuff.png": "B:/Godot/sts2modding/images/packed/intents/intent_debuff.png",
	}
	for local: String in pairs:
		var src: String = pairs[local]
		if not FileAccess.file_exists(src):
			return false
		if FileAccess.get_md5(ProjectSettings.globalize_path(local)) != FileAccess.get_md5(src):
			return false
	return true


## 角色头像来源：custom_info.avatar 优先，否则 portrait 的图
func _avatar_source(character: DialogicCharacter) -> String:
	var info: Dictionary = character.custom_info
	if info.has("avatar") and not str(info["avatar"]).is_empty():
		return str(info["avatar"])
	var portrait: Dictionary = character.get_portrait_info(character.default_portrait)
	var overrides: Dictionary = portrait.get("export_overrides", {})
	return str(overrides.get("image", ""))


func _layout_node() -> Node:
	return Dialogic.Styles.get_layout_node()


func _next_line() -> void:
	await get_tree().create_timer(0.4).timeout
	var l: Node = _layout_node()
	if l != null and l._text_label.revealing:
		Dialogic.Inputs.handle_input()
		await get_tree().create_timer(0.2).timeout
	Dialogic.Inputs.handle_input()
	await get_tree().create_timer(0.3).timeout


## 安全结束时间线（先收掉打字，避免 Dialogic 的 is_question(-1) 报错）
func _safe_end_timeline() -> void:
	for node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		if node.has_method(&"finish_text"):
			node.finish_text(true)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline()
	await get_tree().create_timer(0.4).timeout


## 一直推到当前时间线结束（最多 max_steps 次），避免写死次数被打字速度坑
func _finish_current_timeline(max_steps := 12) -> void:
	var steps := 0
	while Dialogic.current_timeline != null and steps < max_steps:
		await _next_line()
		steps += 1


func _on_signal(argument: Variant) -> void:
	_signals.append(str(argument))


#region A. Dialogic 集成
################################################################################

func _check_dialogic_setup() -> void:
	_section("A. Dialogic 集成 / 旧解析器退休")
	_check("A1 Dialogic autoload", get_node_or_null(^"/root/Dialogic") != null)
	_check("A2a GameState 运行时存在", get_node_or_null(^"/root/GameState") != null and RunState.instance != null,
		"/root/GameState=%s" % get_node_or_null(^"/root/GameState"))
	var autoload_entry: Variant = ProjectSettings.get_setting("autoload/GameState", "")
	_check("A2b GameState 注册为 autoload", str(autoload_entry).contains("game_state.gd"),
		"project.godot: autoload/GameState=%s" % autoload_entry)
	_check("A3 默认样式指向自定义 layout", DialogicStylesUtil.get_default_style_path().ends_with("neofire_style.tres"),
		DialogicStylesUtil.get_default_style_path())

	var timelines := ["npc", "object", "player_won", "player_lose", "test_story", "test_branch"]
	var missing: Array[String] = []
	for t: String in timelines:
		var tl: Variant = load(TL_DIR + t + ".dtl")
		if not (tl is DialogicTimeline):
			missing.append(t)
	_check("A4 六个剧本都能载入 DialogicTimeline", missing.is_empty(), "缺=%s" % [missing])

	var chars := {"xinhuo": true, "write": true, "draw": true, "rhythm": true, "manga": true, "enemy": false}
	var bad: Array[String] = []
	for id: String in chars:
		var c: DialogicCharacter = load(CHAR_DIR + id + ".dch")
		if c == null:
			bad.append(id + ":载入失败")
		elif bool(c.custom_info.get("party", false)) != bool(chars[id]):
			bad.append(id + ":party标记错")
		elif _avatar_source(c).is_empty():
			bad.append(id + ":既无 avatar 也无 portrait")
	_check("A5 六个角色资源（含 party/头像）", bad.is_empty(), "问题=%s" % [bad])

	# 旧的解析代码与数据必须消失
	var retired := [
		"res://dialogue/quick_dialogue.gd", "res://dialogue/characters.json",
		"res://dialogue/dialogue_data", "res://dialogue/story_dialogue.gd",
		"res://dialogue/interface/interface.gd",
	]
	var alive: Array[String] = []
	for path: String in retired:
		if ResourceLoader.exists(path) or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			alive.append(path)
	_check("A6 旧的 JSON/剧本解析代码与数据已退休", alive.is_empty(), "仍在=%s" % [alive])

	# 编辑器标签页会把这些旧场景回写到磁盘（引用的脚本已删）—— 自检开头已自愈清理
	var still_there: Array[String] = []
	for path: String in ["res://dialogue/quick_dialogue.tscn", "res://dialogue/test_quick_dialogue.tscn", "res://dialogue/test_story_dialogue.tscn"]:
		if FileAccess.file_exists(ProjectSettings.globalize_path(path)):
			still_there.append(path.get_file())
	_check("A7 迁移遗留的僵尸场景已清理", still_there.is_empty(),
		"本轮清掉=%s 仍在=%s（若仍在，请在编辑器里关掉这些标签页——编辑器会回写）" % [_zombies_cleaned, still_there])
	_check("A8 意图精灵图来自 sts2modding（逐字节一致）", _sts_provenance(),
		"比对 assets/ui/intents/*.png 与 B:/Godot/sts2modding/images/packed/intents/*")
#endregion


#region B. 外观不变
################################################################################

func _check_appearance() -> void:
	_section("B. 外观不变（对照迁移前基线）")
	await _spawn_world()
	_ui.show_dialogue(_player, _dp)
	await get_tree().create_timer(0.4).timeout
	_layout = _layout_node()
	_check("B0 自定义 layout 已创建", _layout != null and _layout is NeofireDialogueBox,
		"%s" % _layout)

	var box: Panel = _layout._box
	var avatar: TextureRect = _layout._avatar
	var plate: TextureRect = _layout._name_plate
	var text: RichTextLabel = _layout._text_label
	var hint: TextureRect = _layout._continue_hint
	_check("B1 底板尺寸", box.size.is_equal_approx(Vector2(540.0, 156.0)), "实际=%s 期望=(540, 156)" % box.size)
	_eq("B2 头像框", Rect2(avatar.position, avatar.size), Rect2(14.0, 42.0, 92.0, 92.0))
	_eq("B3 名字牌框", Rect2(plate.position, plate.size), Rect2(118.0, 14.0, 200.0, 38.0))
	_eq("B4 正文框", Rect2(text.position, text.size), Rect2(118.0, 60.0, 406.0, 80.0))
	_eq("B5 继续箭头框", Rect2(hint.position, hint.size), Rect2(496.0, 116.0, 28.0, 26.0))
	_eq("B6 名字字号", _layout._name_label.get_theme_font_size(&"font_size"), 22)
	_eq("B7 正文字号", text.get_theme_font_size(&"normal_font_size"), 24)
	_eq("B8 名字默认色（白字外观）", _layout._name_label.get_theme_color(&"font_color"), Color.WHITE)
	_eq("B9 底板贴图", (box.get_theme_stylebox(&"panel") as StyleBoxTexture).texture.resource_path,
		"res://assets/ui/panels/panel_black.png")
	var sb := box.get_theme_stylebox(&"panel") as StyleBoxTexture
	_eq("B10 底板九宫格", Vector4(sb.texture_margin_left, sb.texture_margin_top, sb.texture_margin_right, sb.texture_margin_bottom),
		Vector4(40.0, 40.0, 40.0, 40.0))


func _play_object() -> void:
	await _ensure_world()
	_player.position = _obj.position + Vector2(-64, 0)
	_player.set_active(true)
	_ui.show_dialogue(_player, _dp)
	await get_tree().create_timer(0.4).timeout
	_layout = _layout_node()
#endregion


#region H. 真实游戏上下文（game.tscn，带自己的 Camera2D）
################################################################################

## 用户看到的就是这个场景：探索场景有独立的 Camera2D。
## 分两段验证：物件对话用气泡（贴头顶）、开战对话用方案A（全屏立绘）。
func _check_in_game() -> void:
	_section("H. 真实游戏上下文（game.tscn）")
	# 前面几节留下的地图实例先清掉：它们会把 player_camera 组搅混（相机边界写错相机）
	await _clear_stray_maps()
	_world = null
	var game: Node = game_scene.instantiate()
	add_child(game)
	await get_tree().create_timer(0.8).timeout
	var world: Node = game.current_map
	_check("H0 [游戏内] 外壳按 MapSystem.DEFAULT_MAP 加载开局地图（当前 = 测试房间2）",
		world != null and game.map_host.get_child_count() == 1
			and MapSystem.scene_path(MapSystem.DEFAULT_MAP).get_file() == str(world.scene_file_path).get_file(),
		"DEFAULT_MAP=%s current_map=%s MapHost子节点=%d"
			% [MapSystem.DEFAULT_MAP, str(world.scene_file_path) if world != null else "无",
				game.map_host.get_child_count()])
	# 后面的气泡/开战/战斗都在主房间（测试房间1）里发生，这里显式切过去
	game.load_map("main", "SpawnFromTrial")
	await get_tree().create_timer(1.8).timeout
	world = game.current_map
	var player: Node = world.get_node("Grid/Player")
	var obj: Node = world.get_node("Grid/Object")
	var opp: Node = world.get_node("Grid/Opponent")
	var ui: Node = world.get_node("DialogueCanvas/DialogueUI")
	_check_active_camera("H0b [游戏内]", world, player)
	# 相机真的跟着人走：挪一段玩家，屏幕中心的世界坐标应该跟着变
	var follow_cam: Camera2D = (player as Node2D).get_node_or_null(^"Camera") as Camera2D
	if follow_cam != null:
		var center_before: Vector2 = follow_cam.get_screen_center_position()
		(player as Node2D).global_position += Vector2(240.0, 0.0)
		follow_cam.reset_smoothing()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var center_after: Vector2 = follow_cam.get_screen_center_position()
		_check("H0c [游戏内] 相机跟着玩家走（不是钉死在一处）",
			center_after.distance_to(center_before) > 100.0,
			"屏幕中心 前=%s 后=%s" % [center_before, center_after])
		(player as Node2D).global_position -= Vector2(240.0, 0.0)
		follow_cam.reset_smoothing()

	# --- 气泡样式（调查物件）：推进到队内角色那句，必须贴在主角头顶 ---
	player.position = obj.position + Vector2(-64.0, 0.0)
	ui.show_dialogue(player, obj.get_node("DialoguePlayer"))
	await get_tree().create_timer(0.6).timeout
	_layout = _layout_node()
	_check("H1 [游戏内] 物件对话用气泡样式", _layout is NeofireDialogueBox, "%s" % _layout)
	await _next_line()
	# 新主角带跟随相机，先把平滑复位，否则断言会算进相机缓动的滞后
	var cam: Camera2D = player.get_node_or_null(^"Camera")
	if cam != null:
		cam.reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	_layout = _layout_node()
	var anchor: Vector2 = _layout._anchor_screen_pos()
	var got: Vector2 = _layout._box.get_global_transform_with_canvas().origin
	_write("  [debug] 渲染=%s box.position=%s 锚点=%s 相机=%s"
		% [got, _layout._box.position, anchor, player.get_viewport().get_camera_2d()])
	# 关键不变量：控件的实际渲染坐标 == 它自己的 position（相机只作用一次）。
	# 当初漏掉 CanvasLayer 时，这两者会差一个相机偏移。
	_check("H2 [游戏内] 气泡渲染坐标 == 控件自身坐标（相机只作用一次）",
		got.distance_to(_layout._box.position) <= 2.0,
		"渲染=%s 控件坐标=%s 差=%.2f" % [got, _layout._box.position, got.distance_to(_layout._box.position)])
	# 竖直方向：底边在头顶上方 head_offset 附近（边缘回避会把气泡稍微推高/推偏，给点余量）
	var gap: float = anchor.y - (got.y + _layout._box.size.y)
	_check("H2b [游戏内] 气泡底边在头顶上方（head_offset 附近）",
		gap >= _layout.head_offset - 4.0 and gap <= _layout.head_offset + 48.0,
		"底边距头顶=%.1f head_offset=%.1f" % [gap, _layout.head_offset])
	await _shoot("check_game_dialogue")
	await _safe_end_timeline()
	await get_tree().create_timer(0.9).timeout

	# --- 方案A（开战对话）：全屏立绘上台 ---
	player.position = opp.position + Vector2(-96.0, 0.0)
	var opp_dp: Node = opp.get_node("DialoguePlayer")
	_write("  [debug] 开战驱动器 style='%s' file='%s'" % [opp_dp.style, opp_dp.dialogue_file])
	_write("  [debug] 切前 style='%s' current='%s' layout=%s"
		% [Dialogic.Styles.style, Dialogic.Styles.get_current_style(), _layout_node()])
	ui.show_dialogue(player, opp_dp)
	await get_tree().create_timer(0.3).timeout
	_write("  [debug] 切后 style='%s' current='%s' layout=%s"
		% [Dialogic.Styles.style, Dialogic.Styles.get_current_style(), _layout_node()])
	await get_tree().create_timer(1.1).timeout
	_layout = _layout_node()
	_check("H3 [游戏内] 开战对话用方案A（全屏立绘 layout）", _layout is NeofireStoryDialogue, "%s" % _layout)
	var on_stage := 0
	if _layout is NeofireStoryDialogue:
		for container: Node in _layout.get_node("PortraitLayer").get_children():
			for child: Node in container.get_children():
				if child is CanvasItem and (child as CanvasItem).visible:
					on_stage += 1
	_check("H4 [游戏内] 敌人立绘上台", on_stage >= 1, "台上立绘=%d" % on_stage)
	if _layout is NeofireStoryDialogue:
		_check("H4b [游戏内] 开战对话不再铺全屏背景（直接在图版上进行）",
			not (_layout.get_node(^"Background") as CanvasItem).visible
				and not (_layout.get_node(^"BackgroundImage") as CanvasItem).visible,
			"Background可见=%s BackgroundImage可见=%s"
				% [(_layout.get_node(^"Background") as CanvasItem).visible,
					(_layout.get_node(^"BackgroundImage") as CanvasItem).visible])
	await _shoot("check_game_story")

	# 推完这段对话（不写死次数，避免打字速度影响时序）→ 自动进战斗
	await _finish_current_timeline()
	await get_tree().create_timer(2.8).timeout
	var battle: CanvasLayer = game.combat_screen
	_check("H5 [游戏内] 对话结束自动进战斗", battle != null and battle.visible and battle.enemy_hp > 0,
		"敌人=%s HP=%d" % [battle.enemy_name, battle.enemy_hp])
	await _shoot("check_game_battle")

	# 打完 → 战后对话 → 结束后玩家必须能动（曾经因为驱动器没进场景树而永久锁死）
	battle.enemy_hp = 1
	var dealt := false
	for i: int in battle.hand.size():
		var card: CardData = CardDB.get_card(battle.hand[i])
		if card == null or not battle._can_play(card):
			continue
		for e in card.effects:
			if CardData.kind_from(str(e.get("kind", ""))) == CardData.EffectKind.DAMAGE:
				battle.play_card(i)
				dealt = true
				break
		if dealt:
			break
	if not dealt:
		battle._damage_enemy(3)
	_check("H6 [游戏内] 击败敌人", battle._over and battle.enemy_hp == 0, "敌人HP=%d" % battle.enemy_hp)
	await get_tree().create_timer(3.6).timeout
	_check("H7 [游戏内] 战后对话已开始（回到气泡样式）",
		Dialogic.current_timeline != null and _layout_node() is NeofireDialogueBox,
		"timeline=%s layout=%s" % [Dialogic.current_timeline, _layout_node()])
	await _next_line()
	await get_tree().create_timer(1.2).timeout
	_check("H8 [游戏内] 战后角色恢复可移动（不再锁死）", player.active == true,
		"玩家可动=%s" % player.active)
	await _shoot("check_game_after_win")
	game.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion


#region J. 自由移动 + 走近交互 + 碰撞（取代旧的格子移动测试）
################################################################################

func _check_free_move() -> void:
	_section("J. 自由移动 / 走近交谈 / 碰撞 / 行走图")
	await _clear_stray_maps()
	for ui: Node in get_tree().get_nodes_in_group(&"dialogue_ui"):
		if is_instance_valid(ui):
			ui.get_parent().get_parent().queue_free()
	await get_tree().create_timer(0.4).timeout
	var inst: Node = exploration_scene.instantiate()
	add_child(inst)
	await get_tree().create_timer(0.5).timeout
	var player: Node2D = inst.get_node("Grid/Player")
	var obj: Node2D = inst.get_node("Grid/Object")
	var opp: Node2D = inst.get_node("Grid/Opponent")
	var walls: Node = inst.get_node("Walls")
	var followers: Array[Node] = []
	for i in 3:
		var f: Node = inst.get_node_or_null("Grid/Follower%d" % (i + 1))
		if f != null:
			followers.append(f)

	_check("J1 主角换成自由移动的 CharacterBody2D",
		player is CharacterBody2D and player.has_method(&"set_locked"),
		"%s" % player.get_class())
	var frames: SpriteFrames = player.get_node("Sprite").sprite_frames
	_check("J2 行走图 4 向 × 3 帧（来自 Actor1.png）",
		frames != null and frames.has_animation(&"walk_down") and frames.has_animation(&"walk_up")
			and frames.has_animation(&"walk_left") and frames.has_animation(&"walk_right")
			and frames.get_frame_count(&"walk_down") == 3,
		"动画=%s" % [frames.get_animation_names()])
	var first: AtlasTexture = null
	if frames != null:
		first = frames.get_frame_texture(&"walk_down", 0) as AtlasTexture
	_check("J3 帧是 48×48 的图版切片",
		first != null and first.region.size == Vector2(48, 48) and str(first.atlas.resource_path).contains("Actor1.png"),
		"region=%s atlas=%s" % [first.region if first != null else Rect2(), first.atlas.resource_path if first != null else ""])

	_check("J2b 主角拿到的对话入口属于自己这棵树（不是别的场景残留）",
		player._dialogue_ui_node() != null and inst.is_ancestor_of(player._dialogue_ui_node()),
		"入口=%s" % player._dialogue_ui_node())
	_check("J3b 主场景里三个队友都在（跟主角）", followers.size() == 3,
		"队友=%d" % followers.size())
	_check("J3c 敌人有碰撞箱（碰撞层非 0）", int(opp.get(&"collision_layer")) != 0,
		"敌人 collision_layer=%s" % opp.get(&"collision_layer"))
	var misaligned := 0
	var checked := 0
	for box: Node in walls.get_children():
		if checked >= 12:
			break
		checked += 1
		var cell: Vector2i = (inst.get_node("Grid") as TileMapLayer).local_to_map(
			(inst.get_node("Grid") as TileMapLayer).to_local((box as Node2D).global_position))
		var src: int = (inst.get_node("Grid") as TileMapLayer).get_cell_source_id(cell)
		if src < 3:
			misaligned += 1
	_check("J3d 碰撞盒与 Grid 图层对齐（抽 12 个都在墙格上）", misaligned == 0,
		"抽检=%d 不对齐=%d" % [checked, misaligned])
	_check("J4 碰撞层生成了碰撞盒", walls != null and walls.get_child_count() > 0,
		"碰撞盒数=%d" % (walls.get_child_count() if walls else -1))

	# 自由移动：按住右键若干物理帧，应当真的位移（不是格子吸附）
	var start_pos: Vector2 = player.position
	Input.action_press(&"move_right")
	for i in 12:
		await get_tree().physics_frame
	var moved: float = player.position.x - start_pos.x
	_check("J5 按住方向键会连续位移（自由移动，非格子吸附）",
		moved > 8.0 and fmod(absf(moved), 64.0) > 0.5,
		"位移=%.1f px（若是格子移动会正好 64 的整数倍）" % moved)
	_check("J6 按住方向键时切到该方向的行走动画",
		player.get_node("Sprite").animation == &"walk_right",
		"当前动画=%s" % player.get_node("Sprite").animation)
	Input.action_release(&"move_right")
	await get_tree().physics_frame

	# 走路抖动：物理位移与屏幕位移都不应该出现“倒退步”。
	# （地面吸附没关会每帧被吸一下；相机在物理帧之间平滑追赶也会让画面持续抖。）
	var world_steps: Array[float] = []
	var screen_steps: Array[float] = []
	var prev_world: Vector2 = player.global_position
	var prev_screen: Vector2 = (player.get_node("Sprite") as Node2D).get_global_transform_with_canvas().origin
	Input.action_press(&"move_right")
	for i in 28:
		await get_tree().physics_frame
		var w: Vector2 = player.global_position
		var s: Vector2 = (player.get_node("Sprite") as Node2D).get_global_transform_with_canvas().origin
		world_steps.append(w.x - prev_world.x)
		screen_steps.append(s.x - prev_screen.x)
		prev_world = w
		prev_screen = s
	Input.action_release(&"move_right")
	await get_tree().physics_frame
	var world_back := 0
	var screen_back := 0
	var world_forward := 0
	for d: float in world_steps:
		if d < -0.01:
			world_back += 1
		elif d > 0.01:
			world_forward += 1
	for d: float in screen_steps:
		if d < -0.01:
			screen_back += 1
	_write("  [debug] 走路步长 world=%s" % [world_steps.map(func(d: float) -> String: return "%.2f" % d)])
	_write("  [debug] 走路步长 screen=%s" % [screen_steps.map(func(d: float) -> String: return "%.2f" % d)])
	_check("J11 走路不抖：物理位移没有倒退步，而且真的在前进",
		world_back == 0 and world_forward >= 20,
		"倒退步=%d 前进步=%d / %d" % [world_back, world_forward, world_steps.size()])
	_check("J12 走路不抖：屏幕位移没有倒退步（相机没在物理帧之间追一半）",
		screen_back == 0, "倒退步=%d / %d" % [screen_back, screen_steps.size()])

	await _shoot("check_free_move")

	# 走近物件 → 有交互目标 + 提示
	player.position = obj.position + Vector2(-40.0, 0.0)
	player.set_locked(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_write("  [debug] interactable 组=%s 玩家全局=%s 钥匙全局=%s 距离=%.1f range=%.1f active=%s"
		% [get_tree().get_nodes_in_group(&"interactable").map(func(n: Node) -> String: return n.name),
			player.global_position, obj.global_position,
			player.global_position.distance_to(obj.global_position), player.talk_range, player.active])
	_check("J7 走近后出现交互目标与提示",
		player._interact_target == obj and player.get_node("Hint").visible,
		"目标=%s 提示=%s" % [player._interact_target.name if player._interact_target else "无", player.get_node("Hint").visible])

	# 按 E 触发调查对话（走真实输入管线：parse_input_event，而不是直接调方法）
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.6).timeout
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().physics_frame
	# 调查类（OBJECT）对话按设计**不锁**移动，可以边走边看
	_check("J8 按 E 触发调查对话（调查类不锁移动）",
		Dialogic.current_timeline != null and player.active,
		"timeline=%s 玩家active=%s（应为 true）" % [Dialogic.current_timeline, player.active])

	# 对话中走开 → 离开反应（自由移动下就是真的走远）
	player.position = obj.position + Vector2(-400.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	var dp: Node = obj.get_node("DialoguePlayer")
	# 对话中再按 E：不该重开（同一段对话只开始一次）
	var started := [0]
	dp.dialogue_started.connect(func() -> void: started[0] += 1)
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.5).timeout
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().physics_frame
	_check("J8b 对话中再按 E 不会重开对话", started[0] == 0,
		"期间又开始了 %d 次" % started[0])
	_check("J8c 对话中不显示交互提示", not player.get_node("Hint").visible,
		"提示可见=%s" % player.get_node("Hint").visible)

	_check("J9 对话中走开仍触发离开反应", dp.leave_count >= 1,
		"离开计数=%d" % dp.leave_count)
	await _safe_end_timeline()

	# 走近敌人 → 按 E → 方案A 开战对话
	player.set_locked(false)
	player.position = opp.position + Vector2(-40.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(1.0).timeout
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().physics_frame
	_check("J10 走近敌人按 E 触发开战对话（战前对话锁移动）",
		Dialogic.current_timeline != null and not player.active,
		"timeline=%s 玩家active=%s（应为 false）" % [Dialogic.current_timeline, player.active])
	await _safe_end_timeline()

	inst.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion


#region K. 队友跟随 / 敌人用第 8 个 / 试用场景
################################################################################

func _check_party_and_trial() -> void:
	_section("K. 队友跟随（RPG Maker 式）/ 敌人第 8 个 / 试用场景")
	await _clear_stray_maps()
	var inst: Node = exploration_scene.instantiate()
	add_child(inst)
	await get_tree().create_timer(0.5).timeout
	# 只用来确认这个场景确实有 Player（取不到会报错）；本段断言不直接读它
	@warning_ignore("unused_variable")
	var player: Node2D = inst.get_node("Grid/Player")
	var enemy: Node2D = inst.get_node("Grid/Opponent")

	var goto_obj: DialogicTimeline = load(TL_DIR + "object.dtl")
	var goto_back: DialogicTimeline = load(TL_DIR + "return_main.dtl")
	_check("K0 钥匙对话有'去测试场景'选项、测试场景有'返回'对话",
		goto_obj != null and goto_back != null
			and goto_obj.as_text().contains("transfer:trial/SpawnFromMain")
			and goto_back.as_text().contains("transfer:main/SpawnFromTrial"),
		"object.dtl 选项=%s return_main.dtl=%s"
			% ["有" if goto_obj != null and goto_obj.as_text().contains("transfer:trial") else "无",
				"有" if goto_back != null and goto_back.as_text().contains("transfer:main") else "无"])
	_check("K1 敌人用图版第 8 个角色（index 7）", enemy.get(&"character_index") == 7,
		"enemy.character_index=%s" % enemy.get(&"character_index"))
	var enemy_first: AtlasTexture = null
	var ef: SpriteFrames = enemy.get_node("Sprite").sprite_frames
	if ef != null:
		enemy_first = ef.get_frame_texture(&"idle_down", 0) as AtlasTexture
	var want_block: Vector2i = ActorSheet.block_origin(7)
	_check("K2 敌人帧取自 Actor1.png 第 8 块（idle 用中间帧）",
		enemy_first != null and enemy_first.region.position == Vector2(want_block.x + 48, want_block.y),
		"region=%s" % [enemy_first.region if enemy_first != null else Rect2()])

	# 换地图实例之前先把上一张干掉：两张地图叠在场上会看到"两支队"的鬼影
	inst.queue_free()
	await get_tree().create_timer(0.3).timeout

	# 队友：试用场景里三个跟随者
	if trial_scene == null:
		_check("K3 试用场景已挂到自检上", false, "trial_scene 为空")
		return
	var trial: Node = trial_scene.instantiate()
	add_child(trial)
	await get_tree().create_timer(0.6).timeout
	var lead: Node2D = trial.get_node("Player")
	var followers: Array[Node] = []
	for i in 3:
		followers.append(trial.get_node("Follower%d" % (i + 1)))
	_check("K3 试用场景里三个队友都在", followers.size() == 3 and followers[0] != null,
		"队友=%d" % followers.size())
	var idx: Array[int] = []
	for f: Node in followers:
		idx.append(int(f.get(&"character_index")))
	_check("K4 队友用左边四个里剩下的三个（1/2/3，有区分度）", idx == [1, 2, 3], "索引=%s" % [idx])

	# 队长走一段，队友应当跟上来（每帧沿足迹追）
	var before: Array[float] = []
	for f: Node in followers:
		before.append((f as Node2D).global_position.distance_to(lead.global_position))
	Input.action_press(&"move_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_press(&"move_down")
	for i in 30:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	Input.action_release(&"move_down")
	for i in 40:
		await get_tree().physics_frame
	var after: Array[float] = []
	for f: Node in followers:
		after.append((f as Node2D).global_position.distance_to(lead.global_position))
	_check("K5 队长走动后队友仍跟在身后（没被落下）",
		after[0] < 220.0 and after[1] < 300.0 and after[2] < 380.0,
		"跟随距离 前=%s 后=%s" % [before.map(func(d: float) -> String: return "%.0f" % d),
			after.map(func(d: float) -> float: return roundf(d))])
	# 队友之间不该重叠
	var gap := (followers[0] as Node2D).global_position.distance_to((followers[1] as Node2D).global_position)
	_check("K6 队友之间不重叠（间距合理）", gap > 8.0 and gap < 90.0, "间距=%.1f" % gap)

	# 测试房间2 的内容：#8 改成会说话的 NPC、左边多一个 7 号角色复刻钥匙对话
	var room2_enemy: Node = trial.get_node_or_null(^"Enemy")
	var room2_enemy_dp: Node = room2_enemy.get_node_or_null(^"DialoguePlayer") if room2_enemy != null else null
	var room2_alone: DialogicTimeline = load(TL_DIR + "room2_alone.dtl")
	_check("K7 测试房间2 的 8 号角色改成会说话（「这里没有一个人…」+ 两个选项）",
		room2_enemy != null and room2_enemy_dp != null
			and room2_enemy_dp.dialogue_file.ends_with("room2_alone.dtl")
			and room2_alone != null and room2_alone.as_text().contains("这里没有一个人")
			and room2_alone.as_text().contains("去到其他房间")
			and room2_alone.as_text().contains("离开"),
		"剧本=%s" % [room2_enemy_dp.dialogue_file if room2_enemy_dp != null else "无"])
	var room2_key: Node = trial.get_node_or_null(^"KeyObject")
	var room2_key_dp: Node = room2_key.get_node_or_null(^"DialoguePlayer") if room2_key != null else null
	var room2_key_tl: DialogicTimeline = load(TL_DIR + "room2_key.dtl")
	_check("K8 测试房间2 左边多了一个 7 号角色，复刻钥匙的对话（并指向房间1）",
		room2_key != null and room2_key.get(&"character_index") == 6
			and room2_key.is_in_group(&"interactable") and room2_key_dp != null
			and room2_key_dp.dialogue_file.ends_with("room2_key.dtl")
			and room2_key_tl != null and room2_key_tl.as_text().contains("捡起来看看")
			and room2_key_tl.as_text().contains("transfer:main/SpawnFromTrial"),
		"索引=%s 剧本=%s" % [room2_key.get(&"character_index") if room2_key != null else "无",
			room2_key_dp.dialogue_file if room2_key_dp != null else "无"])
	_check("K6b 场上只有一支队伍 / 一张地图（没把旧地图叠在上面）",
		_players_in_tree() == 1 and _maps_in_tree() == 1,
		"玩家=%d 地图=%d" % [_players_in_tree(), _maps_in_tree()])
	await _shoot("check_party_follow")
	trial.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion


#region C. 剧本行为
################################################################################

func _check_script_behaviour() -> void:
	_section("C. 剧本行为（object.dtl）")
	await _play_object()
	_check("C1 旁白行：跟触发对象、无头像、无名字",
		_layout._box_actor == _obj and not _layout._avatar.visible and _layout._name_label.text == "",
		"跟随=%s 头像=%s 名字='%s'" % [_layout._box_actor.name, _layout._avatar.visible, _layout._name_label.text])
	_write("  [debug] 名字节点: hide_when_empty=%s root=%s 在组里=%s"
		% [_layout._name_label.hide_when_empty, _layout._name_label.name_label_root,
			_layout._name_label.is_in_group(&"dialogic_name_label")])
	_check("C1b 旁白行不显示名字牌（那个空框）", not _layout._name_plate.visible,
		"名字牌可见=%s 名字文本='%s'" % [_layout._name_plate.visible, _layout._name_label.text])

	await _next_line()
	_check("C2 焰铃行：跟主角、有头像、名字=焰铃",
		_layout._box_actor == _player and _layout._avatar.visible and _layout._name_label.text == "焰铃",
		"跟随=%s 头像=%s 名字='%s'" % [_layout._box_actor.name, _layout._avatar.visible, _layout._name_label.text])

	await _next_line()
	_check("C3 [signal arg=lock] 生效（该行时停）", _player.active == false, "玩家可动=%s" % _player.active)

	# 对话框必须贴在锚点头顶：断言"实际渲染位置 == layout 自己算的屏幕目标"
	# （这正是当初"相机被应用两次"会破的不变量），再单独查竖直关系。
	# 水平方向会被"边缘回避"推开，所以不能直接拿 anchor 减半宽来比。
	var anchor: Vector2 = _layout._anchor_screen_pos()
	var target_pos: Vector2 = _layout._target_box_position()
	var got: Vector2 = _layout._box.get_global_transform_with_canvas().origin
	_check("C7 气泡渲染位置 == layout 算的屏幕目标（无二次相机变换）", got.distance_to(target_pos) <= 2.0,
		"渲染=%s 目标=%s 差=%.2f" % [got, target_pos, got.distance_to(target_pos)])
	var bottom_gap: float = anchor.y - (got.y + _layout._box.size.y)
	_check("C7b 气泡底边在锚点头顶上方 head_offset 处", absf(bottom_gap - _layout.head_offset) <= 2.0,
		"底边距头顶=%.1f 期望=%.1f" % [bottom_gap, _layout.head_offset])
	_check("C7c 气泡水平方向仍朝着锚点（没有被推开太远）",
		absf((got.x + _layout._box.size.x * 0.5) - anchor.x) <= _layout._box.size.x * 0.5 + 160.0,
		"水平偏移=%.1f" % absf((got.x + _layout._box.size.x * 0.5) - anchor.x))

	# 主流程走完（object.dtl 现在末尾有一次选择：去测试场景 / 留下）
	# 一路推到结束：中途弹出选项就选第 2 项（"还是留在这里"）
	for i in 6:
		if Dialogic.current_timeline == null:
			break
		var question_open := false
		for child: Node in _layout._choices.get_children():
			if child is Button and child.visible:
				question_open = true
				break
		if question_open:
			Dialogic.Choices.select_choice(2)
			await get_tree().create_timer(0.5).timeout
		else:
			await _next_line()
	await get_tree().create_timer(0.5).timeout
	_check("C4 主流程结束（选完选项）：解锁 + 时间线清空",
		_player.active == true and Dialogic.current_timeline == null,
		"玩家可动=%s timeline=%s" % [_player.active, Dialogic.current_timeline])

	# 离开反应：重开，停在第 2 行（队内角色）后走开
	await _play_object()
	await _next_line()
	var before: int = _dp.leave_count
	_player.position = _obj.position + Vector2(-400, 0)
	await get_tree().create_timer(0.6).timeout
	_check("C5 走开触发 leave_1 反应（不结束对话）",
		_dp.leave_count == before + 1 and _layout._text_label.text.contains("钥匙不在我手边"),
		"计数 %d→%d 文本='%s'" % [before, _dp.leave_count, _layout._text_label.text])
	await _next_line()   # 点掉反应那句 → jump DONE → 剧本结束
	await get_tree().create_timer(0.6).timeout
	_check("C6 离开反应播完收场", Dialogic.current_timeline == null and _player.active,
		"timeline=%s 玩家可动=%s" % [Dialogic.current_timeline, _player.active])
#endregion


#region D. 分支
################################################################################

func _check_branch() -> void:
	_section("D. 分支选项（test_branch.dtl）")
	await _ensure_world()
	Dialogic.signal_event.connect(_on_signal)
	_signals.clear()
	_player.position = _obj.position + Vector2(-64, 0)
	var tl: DialogicTimeline = load(TL_DIR + "test_branch.dtl")
	Dialogic.start(tl)
	await get_tree().create_timer(0.8).timeout
	_layout = _layout_node()
	var labels: Array[String] = []
	var kinds: Array[String] = []
	for child: Node in _layout._choices.get_children():
		kinds.append("%s(%s,vis=%s)" % [child.name, child.get_class(), child.visible])
		if child is Button and child.visible:
			# 文字现在写在 Button 的子 Label 上（DialogicNode_ChoiceButton.text_node）
			var text_node: Node = child.get(&"text_node")
			labels.append((text_node as Label).text if text_node is Label else (child as Button).text)
	_write("  [debug] Choices 子节点=%d %s" % [_layout._choices.get_child_count(), kinds])
	for child: Node in _layout._choices.get_children():
		if child is Button:
			var c: TextureRect = child.get_node_or_null(^"Cursor")
			_write("  [debug] %s rect=%s pos=%s cursor(size=%s rot=%.0f vis=%s) sep=%s"
				% [child.name, (child as Control).get_rect(), (child as Control).position,
					c.size if c != null else Vector2.ZERO, rad_to_deg(c.rotation) if c != null else 0.0,
					c.visible if c != null else false,
					_layout._choices.get_theme_constant(&"separation")])
	_check("D1 选项 UI 弹出且按钮文本正确", _layout._choices.visible and labels == ["直接走开", "问清楚"],
		"可见=%s 按钮=%s" % [_layout._choices.visible, labels])

	# 外观：小红胶囊 + 左侧小箭头，贴在对话框右侧外侧
	var first_choice: Button = _layout._choices.get_child(0)
	var bg_style := first_choice.get_theme_stylebox(&"normal") as StyleBoxTexture
	var cursor := first_choice.get_node_or_null(^"Cursor") as TextureRect
	var box_right: float = _layout._box.position.x + _layout._box.size.x
	_check("D1a 选项是小胶囊（不是旧的 560×56 灰大盘）",
		first_choice.size.y <= 56.0 and first_choice.size.x <= 360.0,
		"选项尺寸=%s（旧版 560×56）" % [first_choice.size])
	_check("D1b 选项底图用名字框同款素材 + 左侧箭头指向文字（-90°）",
		bg_style != null and bg_style.texture != null
			and bg_style.texture.resource_path.contains("labels/label")
			and cursor != null and cursor.texture != null
			and is_equal_approx(cursor.rotation, deg_to_rad(-90.0)),
		"选项底图=%s（名字框用 %s）箭头=%s 角度=%.1f°"
			% [bg_style.texture.resource_path if bg_style != null and bg_style.texture != null else "无",
				_layout._name_plate.texture.resource_path if _layout._name_plate.texture != null else "无",
				cursor.texture.resource_path if cursor != null and cursor.texture != null else "无",
				rad_to_deg(cursor.rotation) if cursor != null else 0.0])
	_check("D1c 选项贴在对话框右侧外侧、不压住底板",
		_layout._choices.position.x >= box_right - 1.0,
		"选项x=%.1f 对话框右边=%.1f" % [_layout._choices.position.x, box_right])
	# 让截图里能看到光标箭头（它只在悬停/选中时出现）
	first_choice.grab_focus()
	await get_tree().create_timer(0.2).timeout
	await _shoot("check_choices")

	Dialogic.Choices.select_choice(2)
	await get_tree().create_timer(0.8).timeout
	await _next_line()
	_check("D2 选中第 2 项走到对应分支", _signals.has("branch_ask") and not _signals.has("branch_leave"),
		"收到信号=%s" % [_signals])
	var shown_buttons := 0
	for child: Node in _layout._choices.get_children():
		if child is Button and child.visible:
			shown_buttons += 1
	_check("D3 选项收起（按钮隐藏）", shown_buttons == 0, "仍显示的按钮=%d" % shown_buttons)

	# 键盘优先：方向键/WASD 换选中、E/回车确认（不用鼠标）
	_signals.clear()
	Dialogic.start(tl)
	await get_tree().create_timer(0.8).timeout
	_layout = _layout_node()
	await get_tree().create_timer(0.3).timeout   # 等 Dialogic 的 0.2s 防误触封锁期过去
	var choice_buttons: Array[Button] = _layout._visible_choice_buttons()
	_check("D4a 弹选项时默认选中第一项（键盘直接能操作）",
		choice_buttons.size() == 2 and _layout._choice_index == 0
			and (choice_buttons[0].get_node(^"Cursor") as CanvasItem).visible,
		"选项=%d 选中=%d 第一项箭头=%s"
			% [choice_buttons.size(), _layout._choice_index,
				(choice_buttons[0].get_node(^"Cursor") as CanvasItem).visible])
	await _press_key(KEY_DOWN)
	var after_down: int = _layout._choice_index
	await _press_key(KEY_W)
	var after_w: int = _layout._choice_index
	_check("D4b ↓ 和 W 都能换选中（方向键与 WASD 等价）",
		after_down == 1 and after_w == 0,
		"↓之后=%d W之后=%d（应为 1 → 0）" % [after_down, after_w])
	await _press_key(KEY_S)
	var c0: CanvasItem = choice_buttons[0].get_node(^"Cursor") as CanvasItem
	var c1: CanvasItem = choice_buttons[1].get_node(^"Cursor") as CanvasItem
	_check("D4c 小箭头跟着选中走（S 选到第二项）",
		_layout._choice_index == 1 and c1.visible and not c0.visible,
		"选中=%d 第一项箭头=%s 第二项箭头=%s" % [_layout._choice_index, c0.visible, c1.visible])
	await _press_key(KEY_E)
	await get_tree().create_timer(0.5).timeout
	var still_open := 0
	for child: Node in _layout._choices.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			still_open += 1
	_check("D5a 按 E 能确认选项（选项随即收起）", still_open == 0, "仍开着的选项=%d" % still_open)
	await _next_line()
	_check("D5b 确认走的是当前选中项（第二项 → branch_ask）",
		_signals.has("branch_ask") and not _signals.has("branch_leave"),
		"收到信号=%s" % [_signals])

	# 鼠标：点哪个选哪个（不被"默认选中项"抢走）
	_signals.clear()
	Dialogic.start(tl)
	await get_tree().create_timer(1.1).timeout
	_layout = _layout_node()
	var mouse_buttons: Array[Button] = _layout._visible_choice_buttons()
	if mouse_buttons.size() == 2:
		await _click_control(mouse_buttons[1])
		await get_tree().create_timer(0.6).timeout
		var mouse_open := 0
		for child: Node in _layout._choices.get_children():
			if child is CanvasItem and (child as CanvasItem).visible:
				mouse_open += 1
		_check("D6a 鼠标点第二项：选项收起", mouse_open == 0, "仍开着的选项=%d" % mouse_open)
		await _next_line()
		_check("D6b 鼠标点第二项走的是第二项（没被默认选中项抢走）",
			_signals.has("branch_ask") and not _signals.has("branch_leave"),
			"收到信号=%s" % [_signals])
	else:
		_check("D6a 鼠标点第二项：选项收起", false, "可见选项=%d" % mouse_buttons.size())
	Dialogic.signal_event.disconnect(_on_signal)
#endregion


#region E. 存档
################################################################################

func _check_save() -> void:
	_section("E. Dialogic 存档（Dialogic 管存档）")
	await _play_object()
	await _next_line()
	var text_at_save: String = _layout._text_label.text
	var timeline_at_save: DialogicTimeline = Dialogic.current_timeline
	var speaker_at_save: String = _layout._name_label.text

	if not Dialogic.Save.has_slot("check_slot"):
		Dialogic.Save.add_empty_slot("check_slot")
	var err_save: int = Dialogic.Save.save("check_slot")
	_check("E1 对话中途存档", err_save == OK, "save()=%d 槽位=%s" % [err_save, Dialogic.Save.get_slot_names()])

	# 结束当前对话，再读档
	await _safe_end_timeline()
	await get_tree().create_timer(0.8).timeout
	_check("E2 存档前先结束对话", Dialogic.current_timeline == null, "timeline=%s" % Dialogic.current_timeline)

	var err_load: int = Dialogic.Save.load("check_slot")
	await get_tree().create_timer(0.9).timeout
	_layout = _layout_node()
	_check("E3 读档回到同一剧本同一句",
		err_load == OK and _layout._text_label.text == text_at_save and _layout._name_label.text == speaker_at_save,
		"load()=%d 文本='%s'（存档时='%s'）说话者='%s'（存档时='%s'）"
			% [err_load, _layout._text_label.text, text_at_save, _layout._name_label.text, speaker_at_save])
	_check("E4 读档后时间线一致", Dialogic.current_timeline == timeline_at_save,
		"%s vs %s" % [Dialogic.current_timeline, timeline_at_save])
	await _safe_end_timeline()
	await get_tree().create_timer(0.5).timeout
#endregion


#region F. 战斗版式
################################################################################

func _check_battle() -> void:
	_section("F. 战斗版式（OMORI：小头像 + 大敌人 + 头顶意图）")
	RunState.instance.reset_run()
	RunState.instance.add_support(4)
	var battle: CanvasLayer = battle_scene.instantiate()
	add_child(battle)
	await get_tree().create_timer(0.5).timeout
	battle.initialize([])
	await get_tree().create_timer(0.6).timeout

	_check("F1 战斗根为 CanvasLayer（免疫场景相机变换）", battle is CanvasLayer, "%s" % battle.get_class())

	var view: Vector2 = battle.get_viewport().get_visible_rect().size
	var party: Control = battle.get_node("Party")
	var party_rect := Rect2(party.global_position, party.size)
	_check("F2 我方小头像在屏幕左下", party_rect.position.x < view.x * 0.35 and party_rect.position.y > view.y * 0.5,
		"party rect=%s 视口=%s" % [party_rect, view])
	var party_avatar: TextureRect = party.get_child(0).get_child(0)
	_check("F2b 小头像贴图已加载", party_avatar.texture != null and party_avatar.size.x <= 120.0,
		"纹理=%s 尺寸=%s" % [party_avatar.texture.resource_path if party_avatar.texture else "无", party_avatar.size])

	var enemy: TextureRect = battle.get_node("EnemyArea/EnemySprite")
	var enemy_rect := Rect2(enemy.global_position, enemy.size)
	_check("F3 敌人大图（>=400px，位置见 F9 居中）",
		enemy.texture != null and enemy_rect.size.x >= 400.0,
		"纹理=%s rect=%s" % [enemy.texture.resource_path if enemy.texture else "无", enemy_rect])

	var intent: Control = battle.get_node("EnemyArea/IntentBox")
	var intent_rect := Rect2(intent.global_position, intent.size)
	_check("F4 意图浮在敌人头顶", intent_rect.position.y + intent_rect.size.y <= enemy_rect.position.y + 1.0,
		"意图底=%.0f 敌人顶=%.0f" % [intent_rect.position.y + intent_rect.size.y, enemy_rect.position.y])

	var icon: TextureRect = battle.get_node("EnemyArea/IntentBox/IntentIcon")
	_check("F5 意图图标来自 sts2modding 精灵图",
		icon.texture != null and icon.texture.resource_path.begins_with("res://assets/ui/intents/"),
		"%s" % [icon.texture.resource_path if icon.texture else "无"])

	_check("F6 首回合：能量满/手牌 5 张", battle.energy == 3 and battle.hand.size() == 5,
		"能量=%d 手牌=%d" % [battle.energy, battle.hand.size()])
	_check("F7 应援值在开局转化为形态值", RunState.instance.support_value == 0 and RunState.instance.form_value == 4,
		"应援=%d 形态值=%d" % [RunState.instance.support_value, RunState.instance.form_value])
	_check("F8 卡牌 JSON 资源可读", CardDB.all().size() >= 14 and CardDB.get_card("ink_slash") != null,
		"卡数=%d ink_slash=%s" % [CardDB.all().size(), CardDB.has_card("ink_slash")])
	# 参考图要求：敌人在正中间、右侧竖排应援量表
	_check("F9 敌人水平居中", absf(enemy_rect.get_center().x - view.x * 0.5) <= 20.0,
		"敌人中心x=%.1f 屏幕中心x=%.1f" % [enemy_rect.get_center().x, view.x * 0.5])
	var gauge: Control = battle.get_node("RightGauge")
	var gauge_rect := Rect2(gauge.global_position, gauge.size)
	var bar: ProgressBar = battle.get_node("RightGauge/GaugeBar")
	_check("F10 右侧竖排应援量表", gauge_rect.position.x > view.x * 0.85 and gauge_rect.size.y > gauge_rect.size.x * 2.0
			and bar.fill_mode == ProgressBar.FILL_BOTTOM_TO_TOP,
		"量表 rect=%s fill_mode=%d" % [gauge_rect, bar.fill_mode])
	_check("F11 回合指示", battle.get_node("Turn").text.contains("回合"), "'%s'" % battle.get_node("Turn").text)

	# 弃牌堆 / 抽卡堆：图标（sts2 精灵图）+ 数字徽章，可点开看牌
	var draw_btn: Button = battle.get_node("PileDraw")
	var disc_btn: Button = battle.get_node("PileDiscard")
	var draw_count := draw_btn.get_node_or_null(^"CountBadge/Count") as Label
	var disc_count := disc_btn.get_node_or_null(^"CountBadge/Count") as Label
	_check("F12 牌堆按钮：用 sts2 精灵图 + 数字徽章",
		(draw_btn.get_node_or_null(^"Icon") as TextureRect) != null
			and (draw_btn.get_node_or_null(^"Icon") as TextureRect).texture != null
			and draw_count != null and disc_count != null
			and draw_count.text == str(battle.draw_pile.size())
			and disc_count.text == str(battle.discard_pile.size()),
		"抽=%s 弃=%s 图标=%s"
			% [draw_count.text if draw_count != null else "无",
				disc_count.text if disc_count != null else "无",
				(draw_btn.get_node(^"Icon") as TextureRect).texture.resource_path if draw_btn.get_node_or_null(^"Icon") != null else "无"])
	battle._on_pile_draw_pressed()
	await get_tree().create_timer(0.2).timeout
	var pile: BattlePileView = battle.get_node("PileView")
	var row_count := pile._rows.get_child_count()
	_check("F13 打开抽牌堆能看到牌", pile.visible and row_count == battle.draw_pile.size(),
		"可见=%s 行数=%d 抽牌堆=%d" % [pile.visible, row_count, battle.draw_pile.size()])
	await _shoot("check_pile_view")
	pile.close_view()
	await get_tree().create_timer(0.2).timeout
	_check("F14 关闭后收起", not pile.visible, "visible=%s" % pile.visible)

	# 打击感：伤害数字 + 抖动后归位
	var sprite_base: Vector2 = battle._enemy_sprite.position
	battle._damage_enemy(5)
	await get_tree().create_timer(0.15).timeout
	var numbers := 0
	for child in battle.get_children():
		if child.name.begins_with("DamageNumber"):
			numbers += 1
	_check("F15 命中飘出伤害数字", numbers >= 1, "伤害数字节点=%d" % numbers)
	await _shoot("check_hit")
	await get_tree().create_timer(1.0).timeout
	_check("F16 抖动结束后归位", battle._enemy_sprite.position.distance_to(sprite_base) < 0.5,
		"位移=%.2f" % battle._enemy_sprite.position.distance_to(sprite_base))

	# 鼠标点击手牌应当能出牌（战斗层要盖在 Dialogic 输入层之上，点击不能被吃掉）
	if battle.hand.size() > 0:
		var card_view: Control = battle._hand_box.get_child(0)
		var click_pos: Vector2 = card_view.get_global_rect().get_center()
		var energy_before: int = battle.energy
		var hand_before: int = battle.hand.size()
		# 起手是洗过的：抽到的第一张可能是 0 费牌，所以只能断言“按牌面费用扣能量”，
		# 不能写死 energy < energy_before（那会 25% 概率误报）
		var played_card: CardData = CardDB.get_card(battle.hand[0])
		var played_cost: int = played_card.cost if played_card != null else -1
		# 出牌后原来的第 2 张会顶到第 1 位（抽牌效果追加在末尾，不会插到前面）
		var next_card: String = battle.hand[1] if hand_before >= 2 else ""
		print("[debug] F17 点击的手牌=%s 费用=%d" % [battle.hand[0], played_cost])
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = click_pos
		down.global_position = click_pos
		get_viewport().push_input(down)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = click_pos
		up.global_position = click_pos
		get_viewport().push_input(up)
		await get_tree().create_timer(0.4).timeout
		# 注意：不能断言"手牌少 1 张"——起草/空白页这类牌自带抽牌效果，手牌数不一定变
		var left_hand: bool = hand_before < 2 or (battle.hand.size() > 0 and battle.hand[0] == next_card)
		_check("F17 鼠标点击手牌能出牌",
			played_cost >= 0 and battle.energy == energy_before - played_cost and left_hand,
			"能量 %d→%d（牌费 %d） 手牌 %d→%d 首位牌 %s→%s 点击位置=%s"
				% [energy_before, battle.energy, played_cost, hand_before, battle.hand.size(),
					next_card, battle.hand[0] if battle.hand.size() > 0 else "空", click_pos])
	else:
		_check("F17 鼠标点击手牌能出牌", false, "手里没牌")

	# 敌人回合真的会打我：HP 条藏在 row→col→Hp 两层下面，直接 get_node 会拿到 null
	# → 我方 HP 永远停在初始值（看起来“被打也不掉血”）。缓存引用后要真的跟着掉。
	var hp_before: int = battle.player_hp
	battle._enemy_turn()
	await get_tree().create_timer(1.5).timeout
	var hp_after: int = battle.player_hp
	var hp_bar: ProgressBar = battle._party_hp_bar
	_check("F18 敌人回合会打我，我方 HP 条跟着掉",
		hp_after < hp_before and hp_bar != null and int(hp_bar.value) == hp_after,
		"HP %d→%d 条=%s" % [hp_before, hp_after, str(hp_bar.value) if hp_bar != null else "无"])

	# 稀有度区分（sts2 那套：金 > 紫 > 蓝 > 灰）
	var rarities: Array[int] = []
	var frames: Array[String] = []
	for id: Variant in CardDB.all():
		var c: CardData = CardDB.get_card(str(id))
		if c == null:
			continue
		if not rarities.has(c.rarity):
			rarities.append(c.rarity)
		var path := str(BattleCardView.RARITY_FRAMES.get(c.rarity, ""))
		if not frames.has(path):
			frames.append(path)
	_check("F19 卡牌有稀有度区分（卡框/标题颜色按稀有度不同，当前卡池至少 3 档）",
		rarities.size() >= 3 and frames.size() >= 3 and BattleCardView.RARITY_COLORS.size() == 4,
		"出现过的稀有度=%s 卡框种类=%d" % [rarities, frames.size()])

	await _shoot("check_battle_layout")
	battle.queue_free()
	await get_tree().create_timer(0.2).timeout
#endregion


#region L. 事件转移（RPG Maker 式“场所移动”）
################################################################################

func _check_map_transfer() -> void:
	_section("L. 事件转移（RPG Maker 式：换版图 + 落点）")
	await _clear_stray_maps()
	MapSystem.clear()

	_check("L1 地图登记表认得 main/trial（场景文件也都在）",
		MapSystem.has_map("main") and MapSystem.has_map("trial")
			and ResourceLoader.exists(MapSystem.scene_path("main"))
			and ResourceLoader.exists(MapSystem.scene_path("trial")),
		"main=%s trial=%s" % [MapSystem.scene_path("main"), MapSystem.scene_path("trial")])

	var parsed := MapSystem.parse_target("trial/SpawnFromMain")
	var parsed_old := MapSystem.parse_target("res://game.tscn")
	var parsed_bad := MapSystem.parse_target("没这张图/xxx")
	_check("L2 目标串解析：地图/落点、老写法 res:// 路径、乱写的被拒",
		str(parsed.get("map", "")) == "trial" and str(parsed.get("spawn", "")) == "SpawnFromMain"
			and str(parsed.get("path", "")) == MapSystem.scene_path("trial")
			and str(parsed_old.get("path", "")) == "res://game.tscn"
			and parsed_bad.is_empty(),
		"trial/SpawnFromMain=%s  res://=%s  乱写=%s" % [parsed, parsed_old, parsed_bad])

	# 选项真的能把玩家送出去：走真实鼠标点击（不是直接调 select_choice）
	# dry_run：只记请求不真的切场景（不然自检自己会被换掉）
	MapSystem.dry_run = true
	var inst: Node = exploration_scene.instantiate()
	add_child(inst)
	await get_tree().create_timer(0.5).timeout
	var player: Node2D = inst.get_node("Grid/Player")
	var obj: Node2D = inst.get_node("Grid/Object")
	var main_spawn := MapSpawn.find("SpawnFromTrial", inst)
	_check("L3a 主房间里有‘从试用场景回来’的落点", main_spawn != null,
		"SpawnFromTrial=%s" % [str(main_spawn.global_position) if main_spawn != null else "找不到"])
	# 走近钥匙再按 E（跟真实玩法一样）
	player.position = obj.position + Vector2(-40.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().create_timer(0.8).timeout
	key.pressed = false
	Input.parse_input_event(key)
	await get_tree().create_timer(0.8).timeout
	var layout := _layout_node()
	# 选项在 5 句台词之后：一句句推进到选项出现（不写死次数，看选项出没出）
	var visible_buttons: Array[Control] = []
	for i in 10:
		visible_buttons.clear()
		for child: Node in layout._choices.get_children():
			if child is Control and (child as Control).visible:
				visible_buttons.append(child)
		if visible_buttons.size() > 0 or Dialogic.current_timeline == null:
			break
		await _next_line()
	_check("L3b 钥匙对话弹出两个选项（走去外面 / 留下来）", visible_buttons.size() == 2,
		"可见选项=%d（timeline=%s）" % [visible_buttons.size(), Dialogic.current_timeline != null])
	_check("L3b2 选项打开时玩家被锁住（不能一边走一边选）", not player.active,
		"玩家active=%s（对话本身是调查类、不锁；选项必须锁）" % player.active)
	MapSystem.clear()
	var clicked := [0]
	var selected := [0]
	if visible_buttons.size() > 0:
		var b := visible_buttons[0]
		b.pressed.connect(func() -> void: clicked[0] += 1)
		Dialogic.Choices.choice_selected.connect(func(_i: Dictionary) -> void: selected[0] += 1)
		_write("  [debug] 选项 rect=%s mouse_filter=%d visible_in_tree=%s disabled=%s focus_mode=%d"
			% [b.get_global_rect(), b.mouse_filter, b.is_visible_in_tree(),
				b.disabled if b is Button else false, b.focus_mode])
		# Dialogic 弹选项后有 0.2s 的“防误触”封锁期（_choice_blocker），这期间点选会被忽略
		await get_tree().create_timer(0.35).timeout
		_write("  [debug] 点前 blocker.is_stopped=%s" % [Dialogic.Choices._choice_blocker.is_stopped()])
		await _click_control(b)
		await get_tree().create_timer(0.6).timeout
		var layers: Array[String] = []
		for n: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
			layers.append("%s(L%d)" % [n.name, (n as CanvasLayer).layer])
		var mp: Vector2 = get_viewport().get_mouse_position()
		_write("  [debug] 点击后：pressed=%d choice_selected=%d hovered=%s"
			% [clicked[0], selected[0], get_viewport().gui_get_hovered_control()])
		_write("  [debug] 鼠标实际位置=%s 在选项里=%s | CanvasLayer=%s | 视口=%s"
			% [mp, b.get_global_rect().has_point(mp), layers, get_viewport().get_visible_rect().size])
	var still_open := 0
	for child: Node in layout._choices.get_children():
		if child is Control and (child as Control).visible:
			still_open += 1
	_check("L3c 鼠标点选项真的能选中（选项随即收起）", still_open == 0,
		"仍开着的选项=%d（点击前有 %d 个）" % [still_open, visible_buttons.size()])
	_check("L3c2 选完把移动还回去（调查类对话的原有手感）", player.active,
		"玩家active=%s" % player.active)
	# 分支是：先播一句台词，再到 [signal arg="transfer:..."]，所以要继续推进
	for i in 6:
		if MapSystem.history.size() > 0:
			break
		await _next_line()
	var req := MapSystem.last_request
	_check("L3d 选完会自动请求转移到 trial/SpawnFromMain",
		str(req.get("map", "")) == "trial" and str(req.get("spawn", "")) == "SpawnFromMain",
		"请求=%s（历史=%d 条，timeline=%s）" % [req, MapSystem.history.size(), Dialogic.current_timeline != null])
	inst.queue_free()
	await get_tree().create_timer(0.3).timeout

	# 落点真的生效：新地图的玩家自己站到 MapSpawn 上，队友排到身后一列
	MapSystem.clear()
	MapSystem.request("trial/SpawnFromMain")
	var trial: Node = trial_scene.instantiate()
	add_child(trial)
	await get_tree().create_timer(0.6).timeout
	var marker := MapSpawn.find("SpawnFromMain", trial)
	var arrived: Node2D = trial.get_node("Player")
	_check("L4a 进新地图后玩家站在落点上",
		marker != null and arrived.global_position.distance_to(marker.global_position) < 1.0,
		"玩家=%s 落点=%s"
			% [arrived.global_position, str(marker.global_position) if marker != null else "找不到"])
	var behind := 0
	var lined := 0
	if marker != null:
		for node: Node in get_tree().get_nodes_in_group(&"party_follower"):
			if not (node is ActorNpc) or not trial.is_ancestor_of(node):
				continue
			var npc_pos: Vector2 = (node as Node2D).global_position
			if absf(npc_pos.x - marker.global_position.x) >= 1.0:
				continue
			lined += 1
			if npc_pos.y < marker.global_position.y - 4.0:
				behind += 1
	_check("L4b 队友落在身后一列（落点面朝下 → 身后就是上方）",
		lined >= 3 and behind == lined, "队内队友在正后方=%d / 共 %d" % [behind, lined])
	await _shoot("check_map_transfer")
	trial.queue_free()
	await get_tree().create_timer(0.3).timeout

	# 没有转移请求时不能乱挪人（落点是一次性的）
	MapSystem.clear()
	var fresh: Node = trial_scene.instantiate()
	add_child(fresh)
	await get_tree().create_timer(0.5).timeout
	var start_pos: Vector2 = (fresh.get_node("Player") as Node2D).global_position
	_check("L4c 没有转移请求时玩家待在场景写好的位置",
		start_pos.is_equal_approx(Vector2(900, 700)), "玩家=%s（场景里是 (900,700)）" % [start_pos])
	fresh.queue_free()
	await get_tree().create_timer(0.3).timeout

	var back_tl: DialogicTimeline = load(TL_DIR + "return_main.dtl")
	_check("L5 返回对话也走同一套（transfer:main/SpawnFromTrial）",
		back_tl != null and back_tl.as_text().contains("transfer:main/SpawnFromTrial"),
		"return_main.dtl=%s" % ["有" if back_tl != null and back_tl.as_text().contains("transfer:main") else "无"])

	# L6 外壳换地图：地图是独立的 .tscn，作为 MapHost 的孩子换进换出
	MapSystem.dry_run = false   # 这一整段要走真的换地图（dry_run 是给 L3 的选项测试用的）
	_check("L6a 两张地图都是独立 .tscn（都在 map_scene 组里）",
		load(MapSystem.scene_path("main")) != null and load(MapSystem.scene_path("trial")) != null
			and MapSystem.scene_path("main") != MapSystem.scene_path("trial"),
		"main=%s trial=%s" % [MapSystem.scene_path("main"), MapSystem.scene_path("trial")])
	var shell: Node = game_scene.instantiate()
	add_child(shell)
	await get_tree().create_timer(0.8).timeout
	var first_map: Node = shell.current_map
	_check("L6b 外壳开局按 DEFAULT_MAP 挂地图（只有一张）",
		first_map != null and shell.map_host.get_child_count() == 1
			and MapSystem.scene_path(MapSystem.DEFAULT_MAP).get_file() == str(first_map.scene_file_path).get_file(),
		"DEFAULT_MAP=%s current_map=%s MapHost子节点=%d"
			% [MapSystem.DEFAULT_MAP, str(first_map.name) if first_map != null else "无",
				shell.map_host.get_child_count()])
	# 走生产路径：MapSystem.request → 外壳换地图（而不是直接调 load_map）
	MapSystem.request("trial/SpawnFromMain")
	await get_tree().create_timer(1.8).timeout
	var now_map: Node = shell.current_map
	var now_player: Node2D = shell.current_player()
	var now_marker := MapSpawn.find("SpawnFromMain", now_map)
	var party_in_map := 0
	for node: Node in get_tree().get_nodes_in_group(&"party_follower"):
		if now_map.is_ancestor_of(node):
			party_in_map += 1
	_check("L6c 换地图后 MapHost 下仍只有一张（旧地图被摘掉，不会两队人叠影）",
		shell.map_host.get_child_count() == 1 and now_map != first_map and not is_instance_valid(first_map),
		"MapHost子节点=%d 旧地图还在=%s" % [shell.map_host.get_child_count(), is_instance_valid(first_map)])
	_check("L6d 队伍整建制到达新地图（玩家在落点上、3 个队友跟在身后）",
		now_player != null and now_marker != null
			and now_player.global_position.distance_to(now_marker.global_position) < 1.0
			and party_in_map == 3,
		"玩家=%s 落点=%s 队友=%d"
			% [str(now_player.global_position) if now_player != null else "无",
				str(now_marker.global_position) if now_marker != null else "无", party_in_map])
	await _shoot("check_map_swap")
	_check_active_camera("L6f", now_map, now_player)
	# 回程也走生产路径：MapSystem.request → 外壳换回 main，落在 SpawnFromTrial 上
	MapSystem.request("main/SpawnFromTrial")
	await get_tree().create_timer(1.8).timeout
	var back_player: Node2D = shell.current_player()
	var back_marker := MapSpawn.find("SpawnFromTrial", shell.current_map)
	var party_back := 0
	for node: Node in get_tree().get_nodes_in_group(&"party_follower"):
		if shell.current_map.is_ancestor_of(node):
			party_back += 1
	_check("L6e 回程（MapSystem.request → 外壳）也只剩一张地图、落点正确",
		shell.map_host.get_child_count() == 1 and back_marker != null and back_player != null
			and back_player.global_position.distance_to(back_marker.global_position) < 1.0
			and party_back == 3,
		"地图=%s 玩家=%s 落点=%s 队友=%d"
			% [str(shell.current_map.name), str(back_player.global_position) if back_player != null else "无",
				str(back_marker.global_position) if back_marker != null else "无", party_back])
	shell.queue_free()
	await get_tree().create_timer(0.4).timeout
	MapSystem.dry_run = false
	MapSystem.clear()
#endregion


#region M. 编辑器工具（拖拽用：碰撞箱 / 事件预制体 / 落点）
################################################################################

func _check_editor_tools() -> void:
	_section("M. 编辑器工具（给可视化编辑用）")

	# 碰撞箱：拖进场景就能改大小，形状跟着 box_size / height_ratio 走
	var block_scene: PackedScene = load("res://grid_movement/blocks/collision_block.tscn")
	_check("M1 碰撞箱预制体存在且是 StaticBody2D（碰撞层 1 = 挡玩家）",
		block_scene != null, "%s" % [block_scene])
	if block_scene != null:
		var block: Node2D = block_scene.instantiate() as Node2D
		add_child(block)
		await get_tree().process_frame
		block.set(&"box_size", Vector2(200.0, 80.0))
		block.set(&"height_ratio", 0.5)
		await get_tree().process_frame
		var shape := block.get_node_or_null(^"Shape") as CollisionShape2D
		var rect := shape.shape as RectangleShape2D if shape != null else null
		_check("M2 改 box_size / height_ratio 后碰撞形状同步（只挡下半截）",
			rect != null and rect.size.is_equal_approx(Vector2(200.0, 40.0))
				and shape.position.y > 0.0 and (block as StaticBody2D).collision_layer == 1,
			"形状=%s 偏移=%.1f 层=%d"
				% [rect.size if rect != null else Vector2.ZERO,
					shape.position.y if shape != null else 0.0, block.collision_layer])
		block.queue_free()
		await get_tree().create_timer(0.2).timeout

	# 事件预制体：拖进场景 → 填 character_index / dialogue_file 就行
	var event_scene: PackedScene = load("res://grid_movement/events/story_event.tscn")
	var event: Node = event_scene.instantiate() if event_scene != null else null
	if event != null:
		add_child(event)
		await get_tree().create_timer(0.2).timeout
		var driver: Node = event.get_node_or_null(^"DialoguePlayer")
		_check("M3 事件预制体：带互动组 + 自带对话驱动器（检查器里只需填剧本和角色图）",
			event.is_in_group(&"interactable") and driver != null and driver.has_method(&"start_dialogue_with")
				and event.has_node(^"Sprite"),
			"interactable=%s Driver=%s" % [event.is_in_group(&"interactable"), driver != null])
		# 填了剧本就能直接当事件用
		driver.set(&"dialogue_file", TL_DIR + "room2_alone.dtl")
		_check("M4 事件能记住检查器里填的剧本",
			str(driver.get(&"dialogue_file")).ends_with("room2_alone.dtl"),
			"剧本=%s" % [driver.get(&"dialogue_file")])
		event.queue_free()
		await get_tree().create_timer(0.2).timeout
	else:
		_check("M3 事件预制体：带互动组 + 自带对话驱动器", false, "story_event.tscn 不存在")

	# 落点预制体（换地图的目的地）
	var spawn_scene: PackedScene = load("res://grid_movement/map_spawn.tscn")
	var spawn: MapSpawn = spawn_scene.instantiate() if spawn_scene != null else null
	_check("M5 落点预制体：Marker2D + map_spawn 组（拖到哪就落在哪）",
		spawn != null and spawn is Marker2D and spawn.spawn_id == &"Spawn1",
		"spawn_id=%s" % [str(spawn.spawn_id) if spawn != null else "无"])
	if spawn != null:
		spawn.queue_free()

	# 测试房间2 里的示例碰撞箱（边界），也是“可以拖”的样板
	var room2: Node = trial_scene.instantiate()
	add_child(room2)
	await get_tree().create_timer(0.4).timeout
	var blocks: Node = room2.get_node_or_null(^"CollisionBlocks")
	var edge_count := 0
	if blocks != null:
		for child: Node in blocks.get_children():
			if child is StaticBody2D and child.is_in_group(&"collision_block"):
				edge_count += 1
	_check("M6 测试房间2 有 4 个示例碰撞箱（边界，随便拖/删）", edge_count >= 4, "示例碰撞箱=%d" % edge_count)
	room2.queue_free()
	await get_tree().create_timer(0.3).timeout

	# 外壳的编辑器提示牌不能跑进运行时（owner 留空那招要真的有效）
	var shell: Node = game_scene.instantiate()
	add_child(shell)
	await get_tree().create_timer(0.8).timeout
	_check("M7 外壳的编辑器提示牌不会出现在运行时场景里",
		shell.get_node_or_null(^"__editor_hint") == null,
		"__editor_hint=%s" % [shell.get_node_or_null(^"__editor_hint")])
	shell.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion


#region N. 相机缩放（默认值 / 调查对话拉近 / 判定区远瞰）
################################################################################

func _check_camera_zoom() -> void:
	_section("N. 相机缩放（房间默认 / 调查对话 / 判定区）")
	await _clear_stray_maps()

	var inst: Node = exploration_scene.instantiate()
	add_child(inst)
	await get_tree().create_timer(0.5).timeout
	var player: ActorPlayer = inst.get_node("Grid/Player")
	var cam: Camera2D = player.get_node(^"Camera")
	_check("N1 房间默认缩放 = 1.5（写在 actor_player.tscn，可按房间覆盖）",
		player.camera_zoom.is_equal_approx(Vector2(1.5, 1.5)) and cam.zoom.is_equal_approx(Vector2(1.5, 1.5)),
		"导出默认=%s 相机=%s" % [player.camera_zoom, cam.zoom])

	# 缩放栈：请求 → 过渡到目标；收回 → 回默认
	player.request_zoom(&"test_zone", Vector2(1.0, 1.0))
	await get_tree().create_timer(0.5).timeout
	var in_zone: Vector2 = cam.zoom
	player.request_zoom(&"test_dialogue", Vector2(1.8, 1.8))
	await get_tree().create_timer(0.5).timeout
	var stacked: Vector2 = cam.zoom
	player.release_zoom(&"test_dialogue")
	await get_tree().create_timer(0.5).timeout
	var back_to_zone: Vector2 = cam.zoom
	player.release_zoom(&"test_zone")
	await get_tree().create_timer(0.5).timeout
	var back_to_default: Vector2 = cam.zoom
	_check("N2 缩放栈：后请求的生效，逐个收回后回到上一层/默认",
		in_zone.distance_to(Vector2(1.0, 1.0)) < 0.05
			and stacked.distance_to(Vector2(1.8, 1.8)) < 0.05
			and back_to_zone.distance_to(Vector2(1.0, 1.0)) < 0.05
			and back_to_default.distance_to(Vector2(1.5, 1.5)) < 0.05,
		"区=%s → 叠对话=%s → 收回对话=%s → 收回区=%s" % [in_zone, stacked, back_to_zone, back_to_default])

	# 调查对话（OBJECT）自动拉近到 1.7，对话结束自动还原
	var obj: Node = inst.get_node("Grid/Object")
	player.position = obj.position + Vector2(-40.0, 0.0)
	player.set_locked(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ui: Node = inst.get_node("DialogueCanvas/DialogueUI")
	ui.show_dialogue(player, obj.get_node("DialoguePlayer"))
	await get_tree().create_timer(0.7).timeout
	var during: Vector2 = cam.zoom
	await _safe_end_timeline()
	await get_tree().create_timer(0.6).timeout
	var after: Vector2 = cam.zoom
	_check("N3 调查对话自动拉近到 1.7，结束后回到房间默认",
		during.distance_to(Vector2(1.7, 1.7)) < 0.05 and after.distance_to(Vector2(1.5, 1.5)) < 0.05,
		"对话中=%s 结束后=%s" % [during, after])

	# 判定区：踩进去 → 远瞰缩放，走出去 → 还原
	var zone_scene: PackedScene = load("res://grid_movement/zones/camera_zone.tscn")
	var zone: Area2D = zone_scene.instantiate() as Area2D if zone_scene != null else null
	if zone == null:
		_check("N4 判定区踩进去改缩放、走出去还原", false, "camera_zone.tscn 加载失败")
	else:
		zone.set(&"zone_id", &"overlook_test")
		zone.set(&"zoom", Vector2(1.0, 1.0))
		zone.set(&"box_size", Vector2(600.0, 400.0))
		inst.add_child(zone)
		zone.global_position = player.global_position
		for i in 8:
			await get_tree().physics_frame
		await get_tree().create_timer(0.5).timeout
		var inside: Vector2 = cam.zoom
		player.global_position += Vector2(1600.0, 0.0)   # 走出判定区
		for i in 12:
			await get_tree().physics_frame
		await get_tree().create_timer(0.5).timeout
		var outside: Vector2 = cam.zoom
		_check("N4 判定区踩进去改缩放、走出去自动还原（可做远瞰）",
			inside.distance_to(Vector2(1.0, 1.0)) < 0.05 and outside.distance_to(Vector2(1.5, 1.5)) < 0.05,
			"区里=%s 出去后=%s" % [inside, outside])
		zone.queue_free()

	inst.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion


#region G. 形态切换 + 全身立绘切入
################################################################################

func _check_form_cutin() -> void:
	_section("G. 形态切换 + 全身立绘切入（由按钮触发）")
	RunState.instance.reset_run()
	var battle: CanvasLayer = battle_scene.instantiate()
	add_child(battle)
	await get_tree().create_timer(0.5).timeout
	battle.initialize([])
	await get_tree().create_timer(0.6).timeout

	# 形态值不满 → 按钮不可用，点了也开不了
	_check("G1 形态值不满时「进入文手形态」按钮不可用",
		RunState.instance.form_value < RunState.instance.FORM_COST and battle._form_button.disabled,
		"形态值=%d 按钮disabled=%s" % [RunState.instance.form_value, battle._form_button.disabled])

	# 攒满形态值 → 按钮可用 → 点一下应该触发全身立绘切入
	RunState.instance.set_form_value(RunState.instance.FORM_COST)
	battle._update_ui()
	await get_tree().create_timer(0.2).timeout
	_check("G2 形态值满后按钮可用", not battle._form_button.disabled,
		"形态值=%d disabled=%s" % [RunState.instance.form_value, battle._form_button.disabled])

	battle._on_form_button_pressed()   # 故意不 await，好在演出中途断言
	await get_tree().create_timer(0.35).timeout
	var cutin: Control = battle.get_node("CutIn")
	var art: TextureRect = battle.get_node("CutIn/Art")
	_check("G3 点按钮触发全屏立绘切入", cutin.visible, "CutIn.visible=%s" % cutin.visible)
	await _shoot("check_form_cutin")
	_check("G4 切入用的是新火娘全身立绘", art.texture != null and art.texture.resource_path == CUTIN_ART,
		"%s" % [art.texture.resource_path if art.texture else "无"])
	_check("G5 切入标题正确", battle.get_node("CutIn/Title").text == "文手形态",
		"'%s'" % battle.get_node("CutIn/Title").text)
	_check("G6 形态已进入且形态值被消耗", RunState.instance.form_id == "writer" and RunState.instance.form_value == 0,
		"形态='%s' 形态值=%d" % [RunState.instance.form_id, RunState.instance.form_value])

	await get_tree().create_timer(2.2).timeout
	_check("G7 演出结束后按钮恢复可用", not battle._busy and not battle._end_turn_button.disabled,
		"busy=%s" % battle._busy)

	# 形态加伤
	var hp_before: int = battle.enemy_hp
	battle._damage_enemy(6)
	_check("G8 形态下伤害 +2（6 → 8）", hp_before - battle.enemy_hp == 8,
		"敌人 %d → %d" % [hp_before, battle.enemy_hp])

	# 退出形态的退还公式（用了 1 回合 / 共 5 回合，消耗 10 → 退 10-ceil(1/5*10)=8）
	battle.turn = 2
	RunState.instance.form_turns_used = 1   # 模拟"形态用了 1 回合就提前退出"
	var refunded: int = RunState.instance.exit_form(true)
	_check("G9 提前退出按比例退还形态值", refunded == 8, "退还=%d 形态值=%d" % [refunded, RunState.instance.form_value])
	battle.queue_free()
	await get_tree().create_timer(0.3).timeout
#endregion
