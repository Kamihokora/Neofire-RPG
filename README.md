# 新火 RPG（Neofire）

Godot **4.7.2** / GDScript / Compatibility 渲染。探索（自由移动 + 队友跟随）→ 走近按 E 对话 → 切战斗（OMORI 式版面 + 卡牌）→ 战后对话，一条完整可跑的环。

> **接手的人先读 [`docs/HANDOFF.md`](docs/HANDOFF.md)**：现状、机制参数、踩过的坑、待办都在那里。
> 本 README 只讲「怎么跑、怎么改、改哪里」。

---

## 1. 跑起来

| 想干什么 | 怎么做 |
|---|---|
| 玩整个游戏 | 编辑器按 **F5**（主场景是 `game.tscn`） |
| 只试某一张地图 | 打开 `grid_movement/exploration.tscn` 或 `exploration_trial.tscn`，按 **F6** |
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

想让「踩到就换地图」之类的新触发，见 HANDOFF；目前的转移是写在剧本里的（下一节）。

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
| UI 素材来源 | `neofire/Things_for_Agent/Vector_UI_Pack_dobo_ui/`（已挑进 `assets/ui/`） |

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
docs/HANDOFF.md               交接文档（给 agent/程序看）
debug_shots/                  自检截图 + 报告
```

## 6. 已知待办（详细见 HANDOFF §6 / §9.6）

- 测试房间2 还是「平背景板」：接最终手绘图后，用 `collision_block.tscn` 自己摆碰撞（或继续在房间1 那种 Grid 图层上画墙）。
- 战斗是**点击出牌**，没有卡组构筑界面；敌人美术是占位图。
- 「文手形态」想做成交涉 Galgame（立绘 + 好感度 Mercy 条）：`GameState.mercy` 接口已留。

---

原项目：Godot 官方 demo *Grid-based movement*（asset library 2729），后被改造成《新火 RPG》。
License 见 `LICENSE.md`；Dialogic 见 `dialogic-README.md`。
