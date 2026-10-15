# 新火 RPG（Neofire）

Godot **4.7.2** / GDScript / Compatibility 渲染。探索（自由移动 + 队友跟随）→ 走近按 E 对话 → 切战斗（OMORI 式版面 + 卡牌）→ 战后对话，一条完整可跑的环。

> 本 README 只讲「怎么跑、怎么改、改哪里」。

---

## 社团协作资料

给参与制作的画手、文手和曲师：[在线协作文档](https://docs.qq.com/aio/DY1ZPWVVOYkFhR3Vq?p=Dyis0yTEvx8FYMcpCoGcM0)。

本地资料已集中到 `docs/`：[新火RPG企划](docs/新火RPG企划.md)、[角色案](docs/角色案.md)、[游戏机制实现](docs/游戏机制实现.md)。企划与角色设定由社团共同维护，当前可玩效果以本 README 和实际游戏为准。

## 1. 跑起来

| 想干什么 | 怎么做 |
|---|---|
| 玩整个游戏 | 编辑器按 **F5**（主场景是 `game.tscn`） |
| 只试某一张地图 | 打开 `grid_movement/exploration.tscn` 或 `exploration_trial.tscn`，按 **F6** |
| 预览战斗界面 | 打开 `tests/battle_ui_preview.tscn`，按 **F6**；支持正常出牌、结束回合和应援点击 |
| 试抽弃动画与抛洒 | 打开 `tests/card_effect_preview.tscn`，按 **F6**；固定起手包含抛洒、修订、弃牌测试卡 `test1`、起草、灵感 |
| 试立绘变身与交涉 | 打开 `tests/writer_form_preview.tscn`，按 **F6**；量表已满，点击右侧文手表情或量表；三个选项分别为好感度 +10、敌人易伤、结束对话 |
| 跑自检 | 打开 `tests/system_check.tscn` 按 **F6**，报告写在 `debug_shots/system_check.txt`（每行 [PASS]/[FAIL]，末尾给总数） |

## 2. 编辑地图（重点）

**`game.tscn` 是外壳，编辑器里是空的 —— 这是正常的**（地图是运行时加载的，编辑器里会显示一块提示牌）。
地图、事件、碰撞都在下面这两张场景里编辑：

| 场景 | 是什么 |
|---|---|
| `grid_movement/exploration.tscn` | **测试房间1**：tilemap 房间（墙由 Grid 图层的 `src>=3` 格子自动生成碰撞） |
| `grid_movement/exploration_trial.tscn` | **测试房间2**：手绘背景板（碰撞靠手动摆，见下） |

### 2.1 拖动事件 / 改位置

选中节点直接拖，或改检查器里的 `position`（`Player`、`Follower1~3`、`Enemy`、`KeyObject`、`ReturnPoint`、`MapSpawn` 都是普通节点）。

编辑器里角色显示的是**蓝色/黄色占位框**（行走图是运行时从 `Actor1.png` 按 `character_index` 切的，编辑器里不切，这是正常的，按 F5/F6 才是真身）。

### 2.2 加碰撞箱（想摆哪摆哪）

把 **`grid_movement/blocks/collision_block.tscn`** 拖进地图场景，然后：

- 拖动节点 = 移动碰撞位置
- 检查器 → `box_size`（宽×高，像素）= 改大小；**或**选中子节点 `Shape`，视口工具栏会出现矩形把手，直接拉伸
- `height_ratio` = 只挡下半截的比例（横版常用 0.5~0.7，1 = 整块挡）
- 编辑器里画出来的**粉框就是碰撞范围**，运行时看不见（画面用地图美术）

测试房间2 里已经有 4 个示例（`CollisionBlocks/EdgeLeft|Right|Top|Bottom`），就是地图边界，随便拖/删/复制。

### 2.3 加一个「会说话的事件」

把 **`grid_movement/events/story_event.tscn`** 拖进地图场景，然后：

1. 根节点检查器里选 `character_index`（图版第几个角色，0~7）——想隐形就假把它挪进墙里/删掉 Sprite
2. 子节点 `DialoguePlayer` → `dialogue_file` 选一个 `.dtl` 剧本
3. 拖动节点 = 改位置；它已经自动在 `interactable` 组里，玩家走近按 E 就会开对话

目前的转移写在剧本里（下一节）；新增触发可与程序协作实现。

### 2.4 加一个「落点」（换地图后站在哪）

把 **`grid_movement/map_spawn.tscn`** 拖进地图，改 `spawn_id`（剧本里就写这个名字）、`facing`（到达时朝哪）。同一张地图可以放多个落点。

### 2.5 相机缩放（拉近 / 远瞰）

- **房间默认值**：改那个房间场景里 `Player` 实例的 `camera_zoom`（当前所有房间都是 (1.5, 1.5)）。
- **调查对话自动拉近**：走近按 E 看东西那种对话（调查类）会自动缩到 `DialoguePlayer.investigate_zoom`（默认 1.7），对话结束自动还原；不想用就把 `zoom_on_investigate` 关掉。
- **远瞰判定区**：把 `grid_movement/zones/camera_zone.tscn` 拖进地图 → 拖到位置、改 `box_size` / `zoom`（想拉远看全景就写小一点，比如 1.0）；玩家踩进去就变，走出去自动还原。编辑器里画绿框提示，运行时看不见。
- **代码接口**（可叠加，后请求的生效，全部收回就回房间默认）：
  ```gdscript
  player.request_zoom(&"investigate", Vector2(1.7, 1.7))
  player.release_zoom(&"investigate")
  ```
  判定区 / 对话都往这套上面丢，多个来源不会互相覆盖（栈式）。

## 3. 改剧本（不用写代码）

剧本是纯文本，在 `dialogue/dialogic/timelines/*.dtl`：

```
只是一把钥匙……                      ← 没有冒号 = 旁白
焰铃: 捡起来看看！                    ← 说话者（中文名/别名都认）
[signal arg="lock"]                  ← 这一行时停住玩家；unlock 解除
[signal arg="transfer:trial/SpawnFromMain"]   ← 换地图 + 落点（RPG Maker 的「场所移动」）
- 去外面看看                          ← 选项，缩进用 TAB
	焰铃: 那就出去转转。
	[signal arg="transfer:trial/SpawnFromMain"]
- 还是留在这里
	焰铃: 好吧，那就算了。
jump DONE                            ← 主流程跳过下面的「离开反应」
label leave_1                        ← 玩家在队内角色说话时走开 → 跳到这里
```

- 换地图的目标写 **`地图id/落点id`**：`main` = 测试房间1，`trial` = 测试房间2，落点 = `MapSpawn` 的 `spawn_id`（登记表在 `grid_movement/map_system.gd` 的 `MAPS`，加新地图只改那里一行）。
- 选项：方向键 / **WASD** 换选中，**E / F / 回车 / 空格**确认，鼠标点哪个选哪个（选选项时玩家会被锁住）。
- 台词太长想换行：行尾加 `\`。

## 4. 改数值 / 换素材

| 想改 | 去哪儿 |
|---|---|
| 卡牌（伤害/费用/稀有度/描述） | `combat/cards/cards.json`、起手牌 `starting_deck.json`（改完重启即生效） |
| 敌人（血量/意图序列） | `combat/enemies/enemy_basic.json` |
| 战斗手感（能量/手牌/形态加成） | `combat/battle/battle.gd` 顶部常量 + `game_state.gd`（`FORM_COST` 等） |
| 移动/跟随/交互距离/相机缩放 | `grid_movement/pawns/actor_player.gd`、`actor_npc.gd` 的导出参数（每个房间可在实例上覆盖） |
| 行走图（8 角色 × 4 向 × 3 帧） | `assets/characters/actor_sheet.gd`（图版 `neofire/Actor1.png`） |
| 对话外观（底板/名字牌/正文/选项） | `dialogue/dialogic/layout/neofire_box.gd` + `.tscn`；选项底图 = 名字框同款素材的小图 `assets/ui/labels/label_red_small.png` |
| UI 素材来源 | `assets/ui/`（复用 dobo-ui 免费素材与临时 StS2 素材） |
| 战斗背景 | `combat/battle/battle.tscn` 根节点的 `battle_background`；留空时使用 `neofire/background_test.png` |
| 战斗框体、顶部入口、四个应援表情 | `combat/battle/battle_hud.gd`；条槽素材在 `assets/ui/bars/` |
| 焰铃的状态图标 | `combat/battle/status_row.gd`、`assets/ui/status/`（暂借 StS2） |
| 飞牌轨迹与火焰 | `combat/battle/card_flight.gd`、`flame_trail.gd`；回合与效果共用抽弃通道 |
| 立绘/眼部切入/变身 | `combat/battle/portrait_stage.gd`、`portrait_glow.gdshader`、`cut_in.gd`；文手图引用 `neofire/Neofire-write.png` |
| 交涉演出与共用缓入 | `combat/battle/writer_dialogue.gd`、`ui_shatter.gd`、`ui_transition.gd`；流程在 `battle.gd::_play_form_cutin` |

牌堆现在用四列大卡浏览：悬停放大，点击展开大卡；左右按钮或方向键切换，Escape 先退回牌堆，再关闭牌堆。拖出手牌会留下白色槽位，取消时原卡吸附回位；重叠手牌按原槽位选中，悬停放大不会挤占邻牌的命中区。

新卡**抛洒**为 1 费技能，已加入起始牌组：选一张其他手牌，确认后免费打出，仍需满足形态限制。确认前取消会原样归位、不扣费。选多张时会标记已选卡面并询问“确定是这几张吗？”。`test1` 仅在专用预览中临时注册，用于试弃两张手牌；不会写入正式卡表。

回合起手/效果抽牌会从左下牌堆沿火焰轨迹飞入，回合结束/效果弃牌飞向右下牌堆；底板按当前手牌跨度伸缩。右侧量表为大竖条，表情有小幅随机闲逛、轻跳与摇摆，点击区保持固定。

敌人血量默认收起，鼠标移到敌人立绘或易伤图标时在右上角显示，框和数值覆盖于立绘上层。易伤图标挂在敌人身上，悬停显示效果说明；双方有格挡时血条渐变为蓝色，格挡归零后恢复。应援区已去框，量表贴画面右缘，四个表情从左侧轻微遮住量表；只保留当前值/上限读数，点击功能不变。

卡面在内部以 608×832 排版，手牌/牌堆/放大查看共用 `BattleCardView`。正式卡框、插画边框、费用宝石、横幅及类型铭牌按 StS2 `card.tscn` 组合，保留白底插画占位；字体使用真正的粗体 MSDF 字形与描边，未使用合成加粗。说明区固定宽高，自动换行和缩字号，防止文字撑出卡框。手牌基准1.15倍、悬停1.6倍。状态前台微微盖住左侧立绘，结束回合移到右下，形态竖条与表情同步放大。

左侧立绘使用常驻斜切上半身舞台。进入文手形态会横向切入双眼、白光粒子变身，战斗界面化为物理碎片后出现打字对话与三个测试选项。**当前测试设置为一轮对话**：选择任一选项后自然退出、不返还形态值，手牌/能量/战斗回合保留。`test2` 默认给敌人 1 层易伤。战斗开场和交涉返回共用方向缓入，落稳后解锁操作。单独体验演出可 F6 运行 `tests/writer_form_preview.tscn`。

## 5. 目录速查

```
game.tscn / game.gd           外壳（常驻舞台：淡黑 + 地图挂载 MapHost + 战斗层 + Dialogic 布局）
game_state.gd                 GameState / RunState（autoload）：形态值、应援值、mercy 等 run 级状态
grid_movement/                地图：exploration.tscn(房间1) / exploration_trial.tscn(房间2)
  blocks/                     collision_block.tscn —— 拖拽用的碰撞箱
  events/                     story_event.tscn —— 拖拽用的对话事件
  map_system.gd               事件转移（地图登记表 + request/落点）
  map_spawn.gd / .tscn        落点（换地图后站哪）+ 拖拽用预制体
  map_transition.gd           没外壳时（单独跑一张地图）的淡黑切场景
  pawns/                      actor_player.gd(主角) / actor_npc.gd(NPC/队友/敌人) / actor_sheet.gd(切图)
  grid/                       grid.gd(旧格子记账) / walls.gd(由瓦片生成碰撞 + 相机边界)
dialogue/                     dialogue_player.gd(对话驱动器) / dialogue_ui.gd(入口)
  dialogic/layout/            neofire_box(气泡样式) / neofire_story(全屏立绘样式)
  dialogic/timelines/*.dtl    剧本（纯文本，直接手改）
combat/battle/                战斗场景/卡牌/牌堆/立绘切入；combat/cards/*.json 数值
tests/system_check.tscn|gd    自检（130+ 条断言，改动前后跑一遍）
debug_shots/                  自检截图 + 报告
```

## 6. 已知待办

- 测试房间2 还是「平背景板」：接最终手绘图后，用 `collision_block.tscn` 自己摆碰撞（或继续在房间1 那种 Grid 图层上画墙）。
- 战斗是**点击出牌**，没有卡组构筑界面；敌人美术是占位图。
- 「文手形态」已接通一轮交涉原型；正式对白、分支与其他形态仍待策划，现有 `test1`～`test3` 仅供验证。
- 顶部角色技能/物品栏为 `test1`～`test4` 占位面板；设置入口暂不可用。四个应援表情都有独立触发信号，文手沿用已有进退形态逻辑，其余三个只显示测试提示，正式效果待策划。

---

原项目：Godot 官方 demo *Grid-based movement*（asset library 2729），后被改造成《新火 RPG》。
License 见 `LICENSE.md`；Dialogic 见 `dialogic-README.md`。
