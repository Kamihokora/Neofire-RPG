# 新火 RPG（Neofire）交接文档

> 给下一轮对话的 agent 看。写在 2025-10·· 那次会话结束时（Godot 4.7.2，Windows，项目 `B:/Godot/Neofire`）。
> 用户是策划/导演型，中文沟通，重视"外观不要被改坏"和"可验证的结果"。请用中文回答。

---

## 0. 一句话现状

游戏已经是"探索（自由移动 + 队友跟随）→ 走近按 E 对话（Dialogic 驱动）→ 切战斗（OMORI 式版式 + 卡牌）→ 战后对话"的完整可跑闭环，
并且有一份**可重复运行的自检**（`tests/system_check.tscn`，97 项断言全绿）来保证改动不回退。

---

## 1. 跑测试 / 验证的正确姿势（很重要，别踩我踩过的坑）

1. `godot_open_scene("res://tests/system_check.tscn")` —— **必须先显式打开**。
   编辑器的"当前场景"经常被别的标签页抢走（尤其用户手动点过），此时 `godot_run_scene` 会去跑那个场景，测试等于没跑，你会白等一分钟。
2. `godot_run_scene(wait_ms: 15000)`（工具上限 15s），然后 **bash `sleep 55~60`**，再 `cat debug_shots/system_check.txt`。
   报告是**每条断言即时落盘**的，所以中途崩了也能看到已经跑到哪一条。
3. 报告里有 `[debug]` 行（名字节点、相机、box 坐标、interactable 组等），排查时先看它们。
4. 断言失败时不要急着改产品代码 —— 我已多次遇到"断言写错/过时"（写死推进次数、旧布局假设、忘了边缘回避…）。先判断是产品错了还是断言错了。
5. 界面截图在 `debug_shots/`（`check_*.png`），修视觉问题前后对比这两张最有用。

### 编辑器会回写磁盘（反复咬人）

- 关编辑器 / 焦点变化时，**打开着的旧场景标签页会被自动保存回磁盘**。我删过 5 次僵尸场景（`dialogue/quick_dialogue.tscn`、`test_*_dialogue.tscn`、`dev_probe_*.tscn`）它们都会回来，还会让编辑器的当前标签页停在死场景上。
- 自检开头有 `_cleanup_zombie_scenes()` 自愈清理；**但根治办法是让用户关掉那些标签页**（已多次告知）。
- `project.godot` 里我手加的 `autoload` 行曾经被编辑器内存设置覆盖掉 → `game_state.gd` 里因此做了**自举兜底**（见下）。

---

## 2. 目录 / 文件地图

```
addons/dialogic/                     Dialogic 2.0-alpha-20（对话系统，运行时用）
addons/x_agent_rpc/                  编辑器 RPC（我的工具用的，别动）
addons/theme_assist/                 主题辅助

game.tscn / game.gd                  主场景：探索 ↔ 战斗切换、淡入淡出、战后对话
game_state.gd                        GameState（autoload，也是 RunState）：run 级状态中枢
project.godot                        autoload: Dialogic + GameState；dialogic 配置；无自定义 input action

--- 探索 / 移动 ---
grid_movement/exploration.tscn       主探索场景（Grid 图层 + Walls 碰撞 + Player + 3 队友 + Opponent(第8个角色) + Object(钥匙)）
grid_movement/exploration_trial.tscn 试用场景：background_test2.png 上的同一套（含返回点 + 自己的 DialogueUI）
grid_movement/pawns/actor_player.gd  自由移动主角（CharacterBody2D + 跟随相机 + 足迹 + 交互）
grid_movement/pawns/actor_npc.gd     敌人/队友/静止 NPC 三合一（跟足迹 / 朝向玩家）
assets/characters/actor_sheet.gd     Actor1.png 切片工具（8 角色 × 4 向 × 3 帧，48px）
grid_movement/grid/grid.gd           旧的格子逻辑（还留着，只做记账 + resync/clean 工具）
grid_movement/grid/walls.gd          由 Grid 图层生成碰撞盒（42 个）+ 相机边界
grid_movement/pawns/pawn.gd/walker.gd 旧格子 Pawn（**已不被探索使用**，仅旧战斗/兼容函数引用）

--- 对话（Dialogic）---
dialogue/dialogic/layout/neofire_box.gd|tscn     气泡样式：浮在说话者头顶 + 尖角 + 开合动画 + 选项
dialogue/dialogic/layout/neofire_story.gd|tscn   A 方案样式：全屏立绘上台 + 底部对话框（背景可选，默认关）
dialogue/dialogic/layout/neofire_style.tres      默认样式（= neofire_box）
dialogue/dialogic/layout/neofire_story_style.tres
dialogue/dialogic/characters/*.dch               6 个角色（焰铃/文手/画手/曲师/问号/敌人）
dialogue/dialogic/timelines/*.dtl                纯文本剧本（见下）
dialogue/dialogue_player/dialogue_player.gd      对话驱动器（锁移动 / 离开反应 / 结束 / goto 切场景）
dialogue/dialogue_ui.gd                          入口 + is_busy()（grid.gd / game.gd / 主角都调它）
dialogue/dialogue_box_skin.gd + skins/default_skin.tres   手绘素材替换接口（皮肤）

--- 战斗 ---
combat/battle/battle.tscn|gd         战斗场景（CanvasLayer layer=20，必须高于 Dialogic 的 10）
combat/battle/card_data.gd/card_db.gd JSON → CardData
combat/battle/card_view.gd           手牌件（代码搭 UI，点击出牌）
combat/battle/pile_view.gd           抽牌堆/弃牌堆查看器
combat/battle/cut_in.gd              形态切换全身立绘切入
combat/cards/cards.json              15 张卡；starting_deck.json 起手 12 张
combat/enemies/enemy_basic.json      敌人 + 意图序列
assets/ui/intents/*.png              意图精灵图（从 B:/Godot/sts2modding 复制，md5 一致）

--- 自检 ---
tests/system_check.tscn|gd           97 项断言（A集成/B外观/C剧本/D分支/E存档/F战斗/G形态/H真实游戏上下文/J自由移动/K队友）
```

---

## 3. 剧本格式（策划手改这里，不用碰代码）

`dialogue/dialogic/timelines/*.dtl`，**纯文本**：

```
只是一把钥匙……                    ← 没冒号 = 旁白
焰铃: 捡起来看看！                  ← 说话者；中文名/别名都能用（"新火娘"也行，运行时自动补别名）
[signal arg="lock"]                ← 该行时停（锁玩家移动）；unlock 解除
[signal arg="goto:res://路径.tscn"] ← 切场景
焰铃: 要不要先出去走走？
- 去外面看看（测试地图）            ← 选项；缩进用 TAB
	[signal arg="goto:res://grid_movement/exploration_trial.tscn"]
- 还是留在这里
	焰铃: 好吧。
jump DONE                          ← 主流程跳过"离开反应"块
label leave_1                      ← 玩家在队内角色说话时走开 → 跳到这里（不结束）
```

- 离开反应的档位：`leave_1` / `leave_3`…，代码取"不超过当前离开次数的最大档"（`dialogue_player.gd::_pick_leave_tier`）。
- 多行台词：行尾加 `\`。

---

## 4. 关键机制与可调参数

| 机制 | 位置 / 参数 |
|---|---|
| 自由移动 | `actor_player.gd`：`speed=220`、`walk_fps=8`、`talk_range=96`、`interact_keys=[E,F]`、`camera_follow` |
| 队伍跟随 | `actor_npc.gd`：`leader_path`（留空=不跟随）、`party_index`、`follow_spacing=44`、`move_speed=230`；足迹在 `actor_player.gd`（每 8px 一点，上限 600） |
| 角色图版 | `assets/characters/actor_sheet.gd`：`character_index`（0-7 先横后纵）、`SHEET_COLUMNS=4`；主角=0，队友=1/2/3，敌人=7 |
| 碰撞 | `walls.gd`：`src>=3` 的格子=墙，横向合并；`height_ratio` 可只挡下半截；`apply_camera_limits` 用所有图层并集 |
| 对话气泡 | `neofire_box.gd`：`head_offset=96`、`follow_smoothing=10`、`tail_*`、`choice_*` |
| A 方案 | `neofire_story.gd`：`show_background`（默认 **false**，直接在图版上对话）、`background_image` |
| 战斗数值 | `battle.gd`：`ENERGY_PER_TURN=3`、`HAND_SIZE=5`、`FORM_BONUS_DAMAGE=2`、`FORM_BLOCK_PER_TURN=3`；`game_state.gd`：`FORM_COST=10`、`FORM_TURNS=5`、`RARITY_COST` |
| 卡牌/敌人 | `combat/cards/cards.json`、`combat/enemies/enemy_basic.json`（改完重启即生效，JSON 不走资源系统） |

---

## 5. 踩过的坑（按"下次别再由我重新发现"整理）

**Dialogic**
1. layout 根节点必须是 **CanvasLayer**：挂在默认 canvas 上会被 Camera2D 二次变换（气泡整体偏离角色）。我一度用 `Control`，实测渲染位置与期望差一个相机位移。
2. 换样式后**必须等 layout `ready` 再 `start()`**：否则 `Dialogic.start()` 会在 ready 时 `clear()`，把 `base_style` 清空，第一个文本事件就把样式切回默认（表现为"切了 1.4 秒又变回去"）。
3. 每段对话要**显式定样式**（`DialoguePlayer.style`，留空=默认），否则会沿用上一段的样式。
4. `DialogicNode_NameLabel` 的 `name_label_root`（Node 导出）在 .tscn 里用相对路径解析**不可靠**（`".."` 解析成它自己）→ 必须在代码里指定。
5. 旁白时 `update_name_label(null)` 会**提前 return**（`speaker_identifier` 初始就是空）→ 名字牌要自己在 `about_to_show_text` 里收起来。
6. 选项容器（`VBoxContainer`）**必须一直 visible**：`show_current_question()` 先 `hide_all_choices()` 再用 `get_choice_button()` 找按钮，而它要求按钮 `is_visible_in_tree()`。
7. `end_behaviour` 默认 `0` 会在时间线结束时**销毁 layout**（收场淡出被切掉）；我设成 `2`（match 里没有 2 的分支 = 什么都不做）。
8. 子系统是 `Dialogic.Inputs`（不是 `Input`）；`Dialogic.Text/Jump/Choices/Styles/Save`。
9. `portraits` 的值是**字典**（`{"scene":…, "export_overrides":{"image":…}}`），不是贴图路径字符串；用 `character.add_portrait("default", 图)` 建。
10. 在打字未结束时 `end_timeline()` 会触发 Dialogic 的负索引 bug（`is_question(-1)` → Out of bounds）。收尾前先 `finish_text(true)`（`DialoguePlayer._end_timeline()` 已处理）。
11. 角色目录（`dialogic/directories/dch_directory`）由编辑器维护、会清掉手加的别名键 → 我在 `dialogue_player._ready` 里**运行时补**显示名/昵称别名。

**Godot / 编辑器**
12. 关编辑器会把打开的旧场景标签页**自动保存回磁盘**（僵尸场景来源）。
13. `project.godot` 手改会被编辑器内存设置覆盖（autoload/input 尤其）→ 我用了两个规避：主角交互键**不走 InputMap**（轮询 `Input.is_key_pressed`）；GameState 做**自举兜底**（`RunState.instance` 发现 autoload 没生效就自己挂到 /root）。
14. Camera2D 离树后 **canvas 变换不重置**（残留），没有自己相机的场景会被前一个场景的相机偏移 → 需要的话给场景自己的 Camera2D（`exploration_trial.tscn` 有）。
15. `.tscn` 里组必须写在**节点头部**：`[node name="X" ... groups=["a"]]`；写成单独一行属性会被静默忽略（我因此浪费了一轮）。
16. 新增 `class_name` 脚本后要 `godot_import_resources` 重扫，否则 lint 报"找不到类型"。
17. `@export var x: Node` 在 .tscn 里的可靠性差（见 4）。
18. Godot 4 的 `tile_map_data` 是 base64 的 PackedByteArray，别自己按 12 字节硬解（我解错过一次）→ **运行时用 `get_used_cells()` + `get_cell_source_id()` 拿事实**。

**我自己犯过的（测试相关）**
19. 自检里**直接调方法**会绕过真实输入管线 → 交互 bug 抓不到。测交互必须 `Input.parse_input_event(...)`。
20. 自检里留下的旧场景实例会"充数"（例如旧 DialogueUI 还在组里，让主角拿到别的场景的入口 → 假通过）。J 段现在会先清旧实例并断言"入口属于自己这棵树"。
21. 断言别写死推进次数（打字速度会变），别假设没有边缘回避（气泡会被推进屏幕内 50px 左右）。
22. 用直接的 `position =` 挪过 pawn 之后要 `grid.resync_pawn()` / `grid.clean_stale_cells()`，否则格子记账和实体脱节 → 空气墙 + `has_node on null`。

---

## 5.1 ⚠ 不要把注释写进 .tscn（我踩过，会把整个场景搞成“加载失败”）

- 我在 `actor_player.tscn` 的 `[node ...]` **头部之前**加了 `## ...` 注释行，结果编辑器报：
  “由于缺少依赖项，加载失败：`actor_player.tscn` / `exploration.tscn`” —— 而文件本身就在盘上、什么都没删。
- 原因：`.tscn` 的解析器对**节点块内部**的 `#` 行容忍，但在 `[node ...]` 之前的注释会被当成“属性名”解析失败，
  这个资源就整个加载不了（依赖它的 `exploration.tscn` / `system_check.tscn` 跟着报错）。
- 规矩：**.tscn 里一行注释也别写**（把解释写在对应的 .gd / 本文件里）；
  已经全部清掉了：`actor_player.tscn` / `actor_npc.tscn` / `neofire_box.tscn` / 新增的三个预制体。
- 自查手段：`godot_get_node_properties(scene, ".")` —— 能返回属性 = 场景能加载；
  或看编辑器是否弹“缺少依赖项”。

## 6. 还没做的（用户知道，按优先级）

1. **地图/碰撞**：手绘地图（参考 `neofire/background_test2.png`，2458×1481）还没接。目前两套地图：旧 tilemap 版（有碰撞）和试用版（只有背景图、无碰撞）。接了手绘图后：继续在 Grid 图层画墙（src≥3）自动生成碰撞，或自己摆碰撞盒（把 `Walls` 的脚本摘掉）。
2. **战斗**：卡牌是**点击出牌**（不是 StS 的拖拽）；没有卡组构筑界面（`GameState.rarity_budget/deck_rarity_cost()` 已可用）；敌人美术是白底占位图。
3. **文手形态的"交涉 Galgame 场景"**（敌方立绘居中 + 对话选项 + 好感度 Mercy 条）：`GameState.mercy` 接口已留（≥100 直接和平解决已接），形态现在是"持续 5 回合的数值强化 + 全身立绘切入"。
4. **旧代码**：`Walker`/`Pawn`/`grid.request_move` 已不被探索使用（只留着兼容函数与被引用的场景），确认新移动完全替代后可清理；`combat/`（旧 demo 战斗）除了 `combat/combatants/*` 之外也基本没人用了。
5. 编辑器里那几个僵尸标签页希望用户关掉（见 §1）。

---

## 7. 验证过的事实（拿来对照，别重复怀疑）

- 外观基线：底板 540×156、头像框 (14,42,92,92)、名字牌 (118,14,200,38)、正文 (118,60,406,80)、箭头 (496,116,28,26)、字号 22/24、九宫格 40px、贴图 `panel_black.png` —— 迁移到 Dialogic 后**逐项一致**。
- Actor1.png = 576×384 = 4 列 × 2 行角色，每块 3 列×4 行 48px（下/左/右/上）。
- 主探索里碰撞盒 42 个（源 1021 格合并而来），与图层对齐。
- 队友跟随：走动后距离 53/93/141 px，互相不重叠（约 40px 间距）。
- 战斗：能量 3、手牌 5、应援值→形态值、形态加伤 6→8、提前退出退 8 点、鼠标点击手牌能出牌（能量 3→2）。
- 存档：对话中途 `Dialogic.Save.save()` → 结束 → `load()` 能回到同一剧本同一句。

---

## 8. 复核补记（2026-10-13 17:30，由接手 agent 实跑核对）

### 8.1 已修：F17 是一条假绿/假红都可能的断言（产品没错）

- 接手后首跑：**96 通过 / 1 失败**，挂在 `F17 鼠标点击手牌能出牌 能量 3→3 手牌 5→4`。
- 根因是**断言写错**，不是产品回归：`battle.gd:123` 有 `draw_pile.shuffle()`，起手 12 张里有 3 张 0 费牌（blot/bookmark/opening_line），首张是 0 费时 `energy < energy_before` 必然不成立 → **约 25% 概率误报**。
- 已改 `tests/system_check.gd`：先取该牌 `CardDB.get_card(battle.hand[0]).cost`，断言 `energy == energy_before - cost` 且 `hand.size() == hand_before - 1`，并加一行 `[debug] F17 点击的手牌=… 费用=…`。顺手消掉 `system_check.gd:576` 的 `unused_variable` 警告。
- 改后实跑：**97 通过 / 0 失败**（这一跑恰好又抽到 0 费牌，`能量 3→3（牌费 0） 手牌 5→4`，正是当初误报的那种情形）。
- 教训与 §1.4 一致：**先怀疑断言，再怀疑产品**。另外「97 全绿」这个数字本身不可靠 —— 它依赖那一跑的手牌运气。

### 8.2 更正：§6.4 把 `pawn.gd` 当死代码是错的

- 实测 `grid_movement/exploration.tscn` 的 `Object`（钥匙）节点 `script = ExtResource("9")` 就是 `grid_movement/pawns/pawn.gd`（24 行，`class_name Pawn`）。
- 它被 `dialogue/dialogic/layout/neofire_box.gd::_anchor_screen_pos()` 通过 `has_method("get_bubble_anchor")` 调用 → **钥匙对话气泡的头顶锚点**。
- `actor_player.gd` / `actor_npc.gd` 都**没有**实现 `get_bubble_anchor()`，删掉 `pawn.gd` 后它们会退回 `global_position` 兜底（钥匙气泡锚点因此改变）。`walker.gd` 也定义了同名方法。
- 结论：`Walker`（格子移动）可以谈清理；**`Pawn` 不能删**，它是钥匙节点的脚本 + 气泡锚点接口。清理前先确认 `get_bubble_anchor` 有新归属。

### 8.3 逐项核对为“真实”的部分

- `project.godot` autoload：`Dialogic="*uid://ds2q0uclmolvu"` + `GameState="*res://game_state.gd"` —— 都在，无需自举兜底也已生效。
- 僵尸场景（`dialogue/quick_dialogue.tscn`、`test_*_dialogue.tscn`、`dev_probe_*.tscn`）**当前磁盘上确实不存在**，§1 那个老毛病此刻是干净的。
- §4 参数表逐项 grep 核对，全部一致：`speed=220 / walk_fps=8 / talk_range=96 / interact_keys=[E,F] / follow_spacing=44 / move_speed=230 / head_offset=96 / follow_smoothing=10 / show_background=false / ENERGY_PER_TURN=3 / HAND_SIZE=5 / FORM_BONUS_DAMAGE=2 / FORM_BLOCK_PER_TURN=3 / FORM_COST=10 / FORM_TURNS=5 / FRAME_SIZE=48 / SHEET_COLUMNS=4`。
- `J4 碰撞盒数=42`、`B2 头像框 (14,42,92,92)`，与 §7 基线一致。
- §6 的“还没做”仍成立：无卡组构筑 UI（全仓无 `deck_build/构筑`）、出牌是 `card_view` 点击（`battle._on_card_pressed`）、`GameState.mercy` 只有裸变量（无 Galgame 交涉场景）。
- 两处无伤大雅的漂移：§7 的跟随距离实测为 **52/91/141**（文档写 53/93/141）；`_check` 调用点源码里 92 处，运行时报 97 项（部分是循环内断言），数字口径不同但都对。

---

## 9. 第二轮改动：选项外观 + RPG Maker 式事件转移（2026-10-13 晚）

自检现在 **117 项全绿**（新增 D1a-c / H0 / K6b / L1-L6e）。

### 9.1 选项（Dialogic 分支）外观：改成"名字框同款小红标签"

- 素材：`assets/ui/labels/label_red_small.png`（**名字牌 `labelAdvanced_red.png` 的 1/4 缩图，184×46**，用 PIL 生成）。
  - 为什么要缩图：原图 734×185 的圆头半径约 92px，直接九宫格拉到 46px 高的按钮上，圆头会被挤瘪。1/4 缩图后半径 = 23px，正好适配小胶囊。
  - 换名字框素材时记得同步重生这张小图（`PIL: resize((184,46), LANCZOS)`）。
- `dialogue/dialogic/layout/neofire_box.gd`：选项 = `StyleBoxTexture(label_red_small.png)` 九宫格（margin 23）+ 自建 `Label`（`DialogicNode_ChoiceButton.text_node`）+ 左侧小箭头 `Cursor`（`arrow_red`，rotation −90° = 指向文字，悬停/选中才显示）。
  - **不要设 `button.flat = true`**：flat 的按钮不画 normal 样式 → 未被选中的选项只剩文字没底图。
  - **`TextureRect` 的 `expand_mode` 必须在 `size = ...` 之前设**，否则 `set_size` 被贴图最小尺寸顶成 116×93 的大箭头（踩过）。
  - 选项贴对话框右侧外侧、垂直居中；每项宽度 = 自己文字宽（右对齐一竖列）。
- ContinueHint（继续箭头）在 `neofire_box.tscn` 里翻转 180°（`flip_h/flip_v`）：素材是朝上的三角，现在朝下 = "还有下一句"。
- 自检截图：`debug_shots/check_choices.png`。

### 9.2 事件转移（RPG Maker 的"场所移动"）：换版图 + 落点

- 剧本写法（`dialogue/dialogic/timelines/*.dtl`）：
  ```
  [signal arg="transfer:trial/SpawnFromMain"]   # 地图 id / 落点 id
  [signal arg="transfer:trial"]                 # 只写地图 id → 落在该地图的默认落点
  [signal arg="goto:res://x/y.tscn"]            # 老写法：无条件换根场景
  ```
- `grid_movement/map_system.gd`（`class_name MapSystem`，全静态）
  - `MAPS`：id → 地图场景。**加新地图只改这里一行。**
  - `parse_target()` / `has_map()` / `request(target)` / `set_pending(map_id, spawn)` / `consume_spawn()`。
  - `dry_run = true`：只记录请求不发车（自检的选项测试靠它，否则自检场景会被换掉）。
  - 有外壳时把活交给外壳（`game_shell` 组），没外壳（单独跑一张地图）才回退到 `MapTransition` 换根场景。
- `grid_movement/map_spawn.gd`（`class_name MapSpawn extends Marker2D`）：地图里的落点，`spawn_id` + `facing` + `is_default`，`find(id, scope)` 按地图范围找。
  - 主房间：`SpawnFromTrial` (224, 288)；试用场景：`SpawnFromMain` (900, 700)。
- `game.gd`（外壳）+ `game.tscn`：
  - **地图不再烘进 game.tscn**；`MapHost` (Node2D) 是挂载点，`load_map(map_id, spawn, instant)` 淡黑 → 摘旧地图 → 挂新地图 → 淡回。
  - **同一时刻 MapHost 下只有一张地图**（旧地图立刻 `remove_child` + `queue_free`）——之前"画面上莫名多出一支队"就是两张地图实例叠在一起。
  - `current_map` / `current_player()` / `current_dialogue_ui()`：所有跨系统的查询都限定在当前地图里。
  - 战斗期间地图 `process_mode = DISABLED`（不再 remove/add 整个场景）。
- 主角落点：`actor_player.gd::_apply_map_spawn()`（`_ready` 里 `call_deferred`，要等队友都进树）+ `land_at(pos, facing)`：定位玩家、把足迹铺成一条朝后的直线、队友按 `trail_point(i)` 站好（所以到新地图是整支队排成一列）。

### 9.3 新增的自检段（都是"用户看到的东西"）

- `D1a-c`：选项是小胶囊（≤ 360×56）、底图用 `labels/label*`、箭头 −90°、贴在对话框右侧外侧。
- `H0`：外壳开局把 main 地图当孩子加载（MapHost 子节点 = 1）。
- `K6b`：场上只有一支队伍 / 一张地图（防"地图实例叠影"）。
- `L1-L6e`：登记表、目标串解析、**真实鼠标点击选项**能选中并发出转移请求、落点生效、队友排队、回程（`request → 外壳`）落点正确、换地图后 MapHost 只剩一张。
  - 截图：`check_choices.png` / `check_map_transfer.png` / `check_map_swap.png`。

### 9.4 测试里的三个坑（别再踩）

1. **Dialogic 弹选项后有 0.2s 的防误触封锁期**（`Choices._choice_blocker`）。这期间按/点选项会被 `_on_choice_selected` 直接忽略 → 自检里点选项前要等 ≥ 0.35s。
2. **点的注入方式**：`Input.parse_input_event` 注入的鼠标位置**不会更新 GUI 的"鼠标在哪"**（点了没反应），要用 `get_viewport().push_input(...)`，并且先发一个 `InputEventMouseMotion` 让控件进入 hover。F17（点手牌）偶尔会漏点，就是这类环境抖动。
3. 分支选项的台词/信号在**选项之后**：点完还要继续推进台词（`_next_line()`）才会走到 `[signal arg="transfer:..."]`。

### 9.5 相机（"2D camera 没在正常运行"）—— 两处旧相机 + 一份错坐标的边界

现象：游戏里画面**钉死在一个地方，相机不跟人走**。三层根因，都是被 §9.2 那次重构暴露出来的：

1. `game.tscn` 里烘了一台外壳 `Camera2D`、`exploration.tscn` 里还留了一台地图 `Camera2D`（zoom 1.5）。
   三台相机都 `enabled = true`，**谁后进树谁就成了 current** → 实际生效的是外壳那台静态相机。
   → 两台旧相机已删；`actor_player._ready` 里显式 `_camera.make_current()`（不再靠树序）。
   → 后果：世界缩放从"碰巧的 1.5"回到主角相机的 1.0。想放大就把 `Player/Camera.zoom` 改回 1.5。
2. `walls.gd::_apply_camera_limits` 把**格子坐标当世界坐标**用（`rect.position.x * size`），
   忽略了图层自身与地图容器（MapHost 偏 (-524,-86)）的偏移 → 边界整块偏了约 524px，
   相机一开局就被顶在左上，人走远就不跟了。
   → 改成 `_layer_to_global * Rect2(格子范围)`，并用 `roundi()`（limit_* 是 int，直接赋 float 会报警告）。
   主房间现在的边界是 (-1292, -573, 1396, 1155)。
3. `get_first_node_in_group("player_camera")` 在场上有多张地图时会拿到**别人家的相机**，
   边界就写到一台没启用的相机上（自检里就这么错过一次）。
   → `walls.gd::_map_camera()` 只认自己这张地图里的主角相机。

自检新增（这些不变量之前没人看着，所以错了很久）：
- `H0b`：当前相机 == 主角的跟随相机（不是外壳/地图相机）；相机拿到了地图边界（limits 不是默认 ±10000000）。
- `H0c`：挪一段玩家，屏幕中心跟着动（相机真的在跟）。
- `L6f`：换地图后当前相机仍是**新地图里**的主角相机。
- `_clear_stray_maps()`：H/J/K/L 开头先清掉上一节留下的地图实例（叠影 + 抢 player_camera 组的根）。

## 10. 第三轮：选项键盘操作 + 测试房间2 的内容（2026-10-13 晚）

### 10.1 选项的输入模型（重写了）

需求原话：“出现选项时角色依旧可以移动 → 方向键（=WASD + 上下左右）优先操作选项，确认键选定；鼠标也要能点”。

- **选项按钮设 `focus_mode = FOCUS_NONE`**（`_build_choice_buttons`）。
  原因：Dialogic 的 `DialogicNode_ChoiceButton` 有“焦点跟鼠标”逻辑（`mouse_entered → grab_focus`，焦点一变还会 `warp_mouse`）——
  它会把用户的光标拽到别的选项上，点击也会被抢走（上一版就是这么把鼠标弄坏的）。
- 改为 layout 自己维护 `_choice_index` + 左侧小箭头（不靠 Godot 焦点系统），`_input` 里统一接管：
  - `move_up/move_down/move_left/move_right` 与 `ui_up/ui_down/...`：前者同时绑了**方向键和 WASD**，所以“方向键”天然包含 WASD。
  - 确认：`E/F`（`choice_confirm_keys`）、回车、小键盘回车、空格、手柄 A。
  - 鼠标左键：`_choice_button_at(pos)` 按矩形命中，**点在哪个选项上就选哪个**，并 `set_input_as_handled()` 吃掉事件。
  - 鼠标悬停也会把 `_choice_index` 挪过去（“点的”和“选的”一致）。
- 选项打开时锁住角色（`choice_lock_actor`；锁前状态记下来，选完还回去），时间线结束时也解锁。
- 自检：`D4a-c`（默认选中第一项、↓与 W 等价、箭头跟着选中）、`D5a-b`（E 确认走对分支）、`D6a-b`（鼠标点第二项、不被默认选中项抢走）、`L3b2/L3c2`（选选项时锁、选完还）。

### 10.2 测试房间2 的内容 + 开局房间改了

- **开局房间 = 测试房间2**：`MapSystem.DEFAULT_MAP = "trial"`（`res://grid_movement/exploration_trial.tscn`）。
  地图 id 仍是 `main`（测试房间1）/ `trial`（测试房间2），剧本里的写法不变。
- 测试房间2 的 **8 号角色**（节点 `Enemy`，`character_index = 7`）不再是战前对话：
  剧本换成新文件 `dialogue/dialogic/timelines/room2_alone.dtl`（“这里没有一个人……” + 选项【去到其他房间】【离开】），
  并把 `style`（原本是方案A 全屏立绘）撤了 → 回到气泡框。
- 测试房间2 左边新增 **7 号角色**（节点 `KeyObject`，`character_index = 6`，位置 (480,720)，在 `interactable` 组里）：
  剧本 `dialogue/dialogic/timelines/room2_key.dtl` = 钥匙对话的复刻版，转移目标翻成房间1（`transfer:main/SpawnFromTrial`）。
- 自检：`K7`（8 号角色是说话 NPC + 两个选项）、`K8`（7 号角色存在、索引 6、剧本复刻钥匙并指房间1）。
- `actor_player._apply_map_spawn` 现在先看 `MapSystem.has_pending()` 再消费；落点写空时落到该地图的默认落点（`is_default`）。

## 11. 第四轮：可视化编辑（拖拽加碰撞 / 摆事件）—— 2026-10-13 晚

用户原话：“我这里什么都没有，我的目标是能直接在编辑器里拖动添加碰撞箱或者改变已有事件的位置”。

### 11.1 为什么“什么都没有”（两个真因）

1. `game.tscn` 是外壳，**编辑器里它就是空的**（地图是运行时 `load_map` 加载的），打开的正好是它。
2. 角色的行走图是**运行时**从 `Actor1.png` 按 `character_index` 切的 → 编辑器里精灵是空的，事件在哪根本看不见，也就没法拖。

### 11.2 做了什么

- **编辑器占位框（gizmo）**：`actor_npc.gd` / `actor_player.gd` 加 `@tool` + `_draw()`：
  编辑器里画出 48×48 框 + `#角色索引` / “玩家”字样；`_ready` / `_physics_process` 开头都有 `if Engine.is_editor_hint(): return`。
  ⚠ 千万别在编辑器分支里往**子节点写属性**（比如给 Sprite 赋 `sprite_frames`）：
  那会把切好的贴图资源存进 `.tscn`（§4 说好的是运行时切图）。`_draw()` 不会写属性，所以安全。
- **碰撞箱**：`grid_movement/blocks/collision_block.tscn` + `collision_block.gd`（`@tool`）：
  StaticBody2D + CollisionShape2D；`box_size` / `height_ratio` 改了就同步形状（`height_ratio < 1` 贴底部，语义同 walls.gd）；
  编辑器里 `_draw()` 画粉色半透明框（运行时看不见）；`collision_layer = 1`，所以默认就能挡玩家（玩家 mask = 1）。
  测试房间2 里摆了 4 个示例当边界（`CollisionBlocks/EdgeLeft|Right|Top|Bottom`）。
- **事件预制体**：`grid_movement/events/story_event.tscn` = `actor_npc` + `DialoguePlayer` 子节点 + 已在 `interactable` 组里。
  设计师只需：拖进去 → 改 `character_index` → 改子节点 `dialogue_file`。
  （没给它单独写脚本：跨节点写属性会碰上编辑器脏标记/撤销的老问题，不如用现成的 inspector 流程。）
- **落点预制体**：`grid_movement/map_spawn.tscn`（Marker2D + `map_spawn.gd`）。
- **外壳提示牌**：`game.gd` 加 `@tool`，编辑器 `_ready` 建一块 Label 告诉你去哪张场景编辑；
  `label.owner = null` → **不会被存进 .tscn**（自检 `M7` 盯着这条：运行时不能出现 `__editor_hint`）。
- **README.md 重写成面向人**：怎么跑 / 怎么摆碰撞 / 怎么摆事件 / 剧本语法 / 数值在哪 / 目录速查。

### 11.3 自检新增段 M

`M1-M2` 碰撞箱预制体 + 改 box_size/height_ratio 后形状同步；`M3-M4` 事件预制体（互动组/驱动器/能记剧本）；
`M5` 落点预制体；`M6` 测试房间2 有示例碰撞箱；`M7` 外壳提示牌不进运行时。
（测试里故意不用 `CollisionBlock` 静态类型，改用 `set()`/duck typing，免得新 class_name 没重扫时报类型找不到。）

### 11.4 还没做（编辑体验）

- 房间2 的边界碰撞是**我按背景图尺寸估的**（背景 world 矩形 258~2200 × 155~1325），换成新美术后自己拖。
- 没有“踩到就触发”的事件触发器（转移目前只能写在剧本的 `[signal arg="transfer:..."]` 里）。
- 没有地图入口/出口的图形化标记（`MapSpawn` 只是个Marker，靠名字对应）。
- 房间2 没设相机边界（没有 Walls）→ 相机可以拍到背景外面；想锁就在那儿放一圈 collision_block + 或者加一个 Walls（需要 Grid 图层）。

### 11.5 第五轮：相机缩放（房间默认 / 调查对话拉近 / 判定区远瞰）

- `actor_player.tscn` 的 `Player/Camera` zoom 改成 **(1.5, 1.5)**；同时新增导出 `camera_zoom`（默认值，**每个房间可以在自己的 Player 实例上覆盖**）
  与 `zoom_duration = 0.25`。`_ready` 里会把 `_camera.zoom = camera_zoom`（保证场景里写的手感生效）。
- **缩放栈（可复用接口）**：
  ```gdscript
  player.request_zoom(&"investigate", Vector2(1.7, 1.7))   # 谁后请求谁生效
  player.release_zoom(&"investigate")                       # 收回 → 回到上一层或房间默认
  player.reset_zoom()                                       # 全部清掉
  ```
  实现是 `_zoom_requests` 字典 + `_zoom_order` 数组（Godot 字典对已存在的 key 不会重排顺序，所以另拿一个数组记先后），
  `_apply_zoom()` 用 Tween 过渡（`zoom_duration = 0` 就直接跳）。
- **调查对话**：`dialogue_player.gd` 新增 `investigate_zoom = (1.7,1.7)` / `zoom_on_investigate`；
  在 `start_dialogue_with` 里只有 **OBJECT（调查类）** 会 `request_zoom(&"investigate", ...)`，
  `_finish()`（含剧本载入失败、走开结束、正常结束）一定会 `release_zoom`——**别忘了在新增的收场路径里也收回**。
- **判定区（远瞰）**：新文件 `grid_movement/zones/camera_zone.gd|tscn`（`class_name CameraZone extends Area2D`）。
  `collision_mask = 2`（玩家层）→ `body_entered/body_exited` → request/release，所以走进走出自动变焦。
  导出：`zone_id`（栈 key，多个区要各起一个）/ `zoom` / `box_size`。可拖拽，编辑器 `_draw` 绿框 + 文字。
- 顺手把 `collision_block.gd` 也加了 `_adopt_shape()`：**编辑器里手拖 Shape 把手改出来的尺寸会被读回 `box_size`**，
  不然重开场景就被覆盖回去了（`_syncing` 旗标防回写循环）。
- 自检新增段 N：`N1` 房间默认 = 1.5；`N2` 缩放栈（后请求生效 + 逐层收回）；`N3` 调查对话 1.7 且结束回 1.5；
  `N4` 判定区踩进去改缩放、走出去还原。
- ⚠ 注意：`zoom 1.5` 会影响 H2/H2b 那类“屏幕空间”断言吗？不会——对话气泡在 CanvasLayer（屏幕空间），相机缩放只通过 `canvas_transform` 影响锚点换算。

## 13. 协作约定（省 token 版，2026-10-13 晚新共识）

用户明确要求：**不要再全量跑自检**（太烧 token）。今后：

1. **事实来源 = `docs/HANDOFF.md` + `README.md`**：新任务先读这两份，别把整个项目文件翻一遍。
2. **改动只 lint，不自检**：`godot_lint_scripts` 跑解析；小改不跑整份 `system_check`。
3. **要验证就写进自检 + 让用户跑**：把新断言加到 `tests/system_check.gd`，用户本地 F6 回结论。
4. **读文件用 offset/limit 只取要改的一段**；截图先压半尺寸再看。
5. **每个阶段结束把“下一步/参考文件路径”写进本文件**（§14 起），断了下一轮也能无缝接。

## 14. 战斗系统推进（路线 + sts2 参考）

用户原话：战斗系统的基础内容都能在 `B:/Godot/sts2modding` 里找到（先看 C#），
核心目标 = **复刻成可读性/可更正性更高的 .gd**；出牌太平淡，可参考 sts2 的版式，精灵图也先直接借过来，之后再替换。

### 14.1 sts2 C# 参考目录（先看这些）

- `B:/Godot/sts2modding/src/Core/Combat/`：`CombatManager.cs` / `CombatState.cs` / `CombatSide.cs`
  - `History/Entries/`：`CardPlayStartedEntry.cs` / `CardPlayFinishedEntry.cs` / `DamageReceivedEntry.cs` / `MonsterPerformedMoveEntry.cs` / `EnergySpentEntry.cs` / `BlockGainedEntry.cs`
- `src/Core/Entities/Cards/`（卡牌实体）、`Entities/Creatures/`（怪）、`Entities/Intents/`（意图）、`Entities/Powers/`（力量/易伤等状态）
- `src/Core/Commands/CardCmd.cs` / `PowerCmd.cs`（出牌/状态效果的执行命令）
- 意图精灵图：`sts2modding/images/packed/intents/...`（已经抄进 `assets/ui/intents/`，md5 一致）

### 14.2 刚修的第一个小 bug：进入战斗后玩家不掉血

- 根因：`combat/battle/battle.gd::_rebuild_party` 第一次搭建我方 HP 条时结构是
  `Party(row HBox → col VBox → Hp ProgressBar)`，但刷新分支里 `slot.get_node_or_null("Hp")`（slot=row）
  拿的是 `row/Hp` → **null** → 我方 HP 条永远停在初始值，`player_hp` 其实掉到了 63 但界面上永远是 72/72。
- 修法：加缓存引用 `_party_hp_bar` / `_party_info_label`（首次搭建时填，之后直接改值）。
- 回归：自检 `F18 敌人回合会打我，我方 HP 条跟着掉`。

### 14.3 已完成的第一批战斗优化（2026-10-13 晚，未跑自检、未提交 git）

- **玩家不掉血 bug 已修**（见 14.2）：`_rebuild_party` 缓存 `_party_hp_bar`/`_party_info_label` 后直接改值；回归 `F18`。
- **出牌手感**：
  - `card_view.gd`：悬停抬手 + 提亮（`mouse_entered/exited` → scale 1.07 + self_modulate，disabled 不亮）；
    新增 `_frame`（稀有度卡框 TextureRect，`STRETCH_SCALE` 填满）+ 类型色带改半透明。
  - `battle.gd::_animate_card_play`：牌从手牌容器摘出来（容器会接管 position）→ 抬大 → **飞向敌人** → 淡出 → queue_free；
    命中后的震屏/闪白/伤害数字本来就接在 `_damage_enemy` 里。
- **稀有度区分**（sts2 那套：金 > 紫 > 蓝 > 灰）：
  `card_view.gd` 的 `RARITY_FRAMES`（dobo 卡片框 `card_black/blue/purple/yellow.png`，已拷进 `assets/ui/cards/`）
  + `RARITY_COLORS`（标题颜色）。`writer_form`=rare(金)，`ink_slash`=basic(灰)。回归 `F19`。
- **战斗面板换肤**（`battle.gd::_style_controls()`，`_ready` 里调）：
  结束回合/形态/看牌堆/弃牌堆四个按钮 → dobo 胶囊（`button_black` normal / `button_red` hover，9-slice margin 24）；
  敌人血条/右侧量表 → 红/蓝前景 + 深色底（StyleBoxFlat）。
- 素材新增：`assets/ui/cards/card_black|blue|purple|yellow.png`、`assets/ui/buttons/button_black|red.png`（都从 Things_for_Agent 拷）。

### 14.4 下一步（战斗面板继续美化 + 遗物→四角色被动）

- 战斗面板还没动的地方：我方 Party 框 / 右侧量表 / 敌人区域 的背景面板（可用 dobo `Panels/panel_black.png`）；
  手牌弧线铺底、能量/回合/意图的 sts2 式排版（参考 `sts2modding/src/Core/Combat/` 的节点树）。
- 遗物系统（用户回忆缺失）→ 改造成 RPG 后，遗物可能变成**四个角色的被动**；目前四个角色还没有独立的菜单/数值面板。
  先战斗，角色被动/菜单是独立一块（要做之前先和用户对需求）。

### 14.4 已完成第二批（按 sts2 源码复刻；2026-10-13 深夜，未跑自检、未提交）

读的 sts2 源码：`src/Core/Nodes/Combat/`（`NCardPlay.cs` / `NCardPlayQueue.cs` / `NCombatCardPile.cs` / `NDrawPileButton.cs` /
`NDiscardPileButton.cs` / `NCombatPilesContainer.cs`）。

- **卡牌打出效果（按 NCardPlay.CenterCard）**：`battle.gd` 里 `_on_card_pressed` 改成
  `_lift_card_to_center()`（从手牌容器摘出 → 抬到屏幕中轴贴底 → 缩到 0.78）→ `play_card()` 结算效果 →
  `_send_card_away()`（再缩一下 + 淡出）。不再“飞向敌人”（sts2 是抬到中间，伤害表现交给 VFX/震屏）。
- **牌堆按钮（按 NCombatCardPile）**：用 sts2 精灵图 `images/packed/combat_ui/{draw_pile,discard_pile,pile_button_count}.png`
  （已拷到 `assets/ui/combat/`）；按钮变成“图标 + 右下数字徽章”，悬停放大 1.18、数量变化时弹一下；
  位置：抽牌堆左下 (40,838)、弃牌堆右下 (1760,838)；尺寸 120×126。
- **点牌堆看牌（按 NCardPileScreen）**：`pile_view.gd` 重写成**卡面网格**（不再列文字）：
  8 列 GridContainer + ScrollContainer + dobo 黑面板，卡面直接复用 `BattleCardView`（缩 0.85），
  排序 = 稀有度降 → 费用升 → 名字。自检 `F12` 改成查图标/徽章；`F13` 仍旧数 `_rows` 子节点数。
- **踩的坑（已在 §5 同类里）**：`BattleCardView` 的子节点（label/卡框）是在 `_ready` 里建的，
  **必须先 `_rows.add_child(cell)` 再 `view.setup(data)`**；否则 `_ready` 没跑，`setup` 会往 null 上写 `text`
  → 报 `base object of type 'Nil'`（栈顶在 `card_view.gd` 的 `_cost.text = ...`）。`setup()` 里已加了防御性 warning。
- **删掉「文手形态」能力卡**（用户要求：有按钮能直接开形态，这张卡意义不明）：
  `cards.json` / `starting_deck.json` 都删了；`G` 段测试改成用 `_form_button`（G1 形态值不满→按钮不可用，
  G2 满足→可用，G3 点按钮触发立绘切入，G4-G9 不变）；`F8` 卡数阈值 15→14；
  `F19` 改成“当前卡池至少 3 档稀有度 + 4 套卡框映射”（删卡后没有 rare 卡了）。

### 14.5 下一步

- 手牌还是 HBoxContainer：sts2 的手牌是 `NHandCardHolder` 自己管位置（悬停上抬/扇形展开），
  想要那个手感就得把手牌改成自排版（不再用 HBox）。
- 战斗面板还没动：我方 Party 框/右侧量表/敌人区域的背景面板；能量/回合/意图的 sts2 式排版（`NCombatUi.cs` 422 行可参考）。
- 遗物系统 → 四个角色的被动（需要先和用户对需求）；角色菜单/数值面板也还没做。

### 14.6 第六轮：走路发抖 + 调试控制台降噪（2026-10-13 深夜，未跑自检、未提交）

用户反馈：“人物在行走的时候不知道为啥一直在抖”。

- **根因（两个，都是经典坑）**：
  1. `CharacterBody2D.motion_mode` 默认是 **GROUNDED**：俯视地图里的地面吸附/斜坡判定（`floor_snap_length`）会让贴着墙走的身体每帧被吸一下 → 抖。
     → `actor_player.tscn` / `actor_npc.tscn` 都改成 `motion_mode = 1`（FLOATING）。
  2. `Camera2D.process_callback` 默认是 **IDLE**，而玩家是在 `_physics_process` 里移动的：
     平滑跟随会在两次物理帧之间追一半又回一点 → 画面持续抖（人越跑越快时最明显）。
     → `Player/Camera` 改成 `process_callback = 0`（PHYSICS），跟玩家同一个节拍。
- **回归断言**：`J11` 物理位移无倒退步且确实在前进；`J12` **屏幕**位移也无倒退步（专门盯相机抖动）。
  断言的 debug 行会把每一步的位移打出来（world/screen 各一串 28 个数），下次抖了能直接看出是物理还是相机。
- **控制台降噪**（用户在走 debug， warnings 很吵）：
  - Dialogic 的选项按钮在 `_ready` 里把 `mouse_entered` 连到 `grab_focus`，而我们故意用 `FOCUS_NONE` →
    每悬停一次刷一条 “This control can't grab focus”。已在 `neofire_box._build_choice_buttons` 里拆掉这个连接。
  - 项目设置 `dialogic/choices/autofocus_first = false`（我们自己的 `_choice_index` + 小箭头才是选中，
    Dialogic 再 grab_focus 一次只会多一条警告）。

### 14.7 第七轮：自检可以“只跑指定段”（省 token，用户要求）

- `tests/system_check.gd` 新增两个导出（在 `tests/system_check.tscn` 检查器里改）：
  - `only_sections: String` —— 只跑指定段，逗号分隔，例 `"F,G,J"`；**留空 = 全跑**。
  - `quiet_pass: bool` —— true 时报告里**不写 [PASS] 行**（只写 [FAIL] + [debug] + 结论行），于是一个“全绿”的验证只需要几十行。
- 也支持命令行：`godot --path . -- --only=F,G --quiet`（`OS.get_cmdline_user_args()`）。
- 段号：A集成 B外观 C剧本 D分支 E存档 F战斗 G形态 H游戏内 J自由移动 K队友 L转移 M编辑器 N相机。
- 报告开头会写一行 `（本次范围：F,G,J · 静默通过）`，粘给别人时一看就知道没跑全。
- 为了让“只跑一段”也能跑通，补了 `_ensure_world()`（C/D/E 开头自己现搭探索世界，不再依赖别的段先跑过）。
- **当前 `.tscn` 里预设的是 `only_sections = "F,G,J"` + `quiet_pass = true`**（正好是要验证的那几段）。
  ⚠ 以后要全量跑、或者要给别人看完整报告时，**把 `only_sections` 清空、`quiet_pass` 关掉**。

## 12. 还没做（汇总）

> 早期写在 §6 / §9.6 的条目都还成立；最新一条（编辑体验）见 §11.4。

- `exploration_trial.tscn` 还是一张 flat 背景板（无碰撞）——接 `neofire/background_test2.png` 手绘地图 + Grid 画墙（见 §6.1）。
- 转移目前没做"进地图时的朝向/队伍朝向"以外的花活（比如落点处的过场、音效、地图名提示）。
- 战斗仍然是点击出牌、没有卡组构筑界面（§6.2）。

