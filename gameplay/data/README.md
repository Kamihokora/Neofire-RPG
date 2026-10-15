# 成长、应援与灵感配置

这些数值用于联调，正式卡牌与技能策划由用户和Gemini维护。改JSON后重新运行游戏生效；不要在存档使用期间随意改ID。测试名称用test1、test2等。

| 文件 | 内容 |
| --- | --- |
| `creator_skills.json` | 四名创作者的独立技能：`owner`为write/draw/rhythm/manga，`tier`为2/4/6/10，`starting`决定新游戏是否已学会。 |
| `progression.json` | 队伍共享等级、累计经验门槛、升级赠卡/解锁技能/养成资源，以及牌库最小数量。当前临时曲线为10/30/60/100经验到2/3/4/5级。 |
| `inspiration.json` | 灵感词条、无序二词配方、想法说明、大提案解锁开关、小提案产物。 |
| `../../combat/enemies/enemy_basic.json` | `rewards.experience`、`rewards.inspirations`为胜利奖励；`writer_inspiration`为该敌人交涉选项test1提供的词条ID。 |

右侧站位固定对应10/6/4/2消耗，使用该成员对应档位的装配技能，不改变卡牌能量。技能效果复用战斗结算，支持damage/block/draw/energy/weak/vulnerable等现有卡牌效果，strength走战斗力量接口。第一章只有文手10费形态；其余角色10费保持禁用，不编造额外形态。每位创作者每个玩家回合最多使用一次。

白色`common`词条按数量扣除，可重复获得和合成；黑色`story`词条每种最多持有1个，合成消耗后永久记为已用，不能重复收集。配方输入按ID无序匹配。大提案`kind: major`置顶并显示图钉；小提案`kind: note`可以多次提交。合成只存想法，不直接改变解锁开关或发物品；在可用的四人桌提交才落实效果。

接入调查事件可以把`gameplay/inspiration_pickup.tscn`拖到地图上，配置`word_id`、`amount`、`experience_reward`。四人桌使用`gameplay/proposal_table.tscn`，`occupied=true`时不能开会；需要附近的玩家通过现有E/F交互打开。此轮没有制作正式咖啡厅地图或群口剧情。

程序入口：

```gdscript
var state := RunState.instance
state.journey.award_experience(10, state)
state.journey.add_inspiration("test1", 2)
# compose只存想法；提交入口需经四人桌权限检查。
state.journey.compose("test1", "test2")
```

文手自言自语：连接`game.phone.writer_monologue_requested(context)`。`context.event`目前为selected/incompatible/before_compose/composed，包含词条ID或配方ID。剧情代码可以接自己的对话系统，也可以调用`game.phone.show_writer_monologue("test1")`显示气泡内短句；这一轮不写正式台词。

整理入口开关为`game.phone.inspiration_organize_available`。开启整理后按获得顺序吸附成网格，关闭恢复反弹；当前无二级分类筛选。白色数量包含重复份数，未使用灵感总量超过5时扩大可探索图版。右键拖动、滚轮和WASD/方向键控制镜头。

从文手进入思考时，手机和小人放大并向画面边缘移动，云朵尾部跟随文手头顶；更换小人素材后调整`ui/menu_pet.gd`的`thought_anchor`（相对点击区域的局部位置）。从笔记本加号进入时，列表左移，右侧云朵作为二级面板，尾部跟随加号的位置；可直接点击左侧已存想法切回详情。Esc先收回二级面板，再返回手机。大气泡开启时隐藏小气泡；黑白说明不常驻显示，后续放到tips系统。

F6运行`tests/progression_preview.tscn`：只在该预览中给30经验、测试词条、满量表与两篇已合成想法，地图旁边放四人桌和调查便签；初始打开笔记本。存档使用独立的`user://progression_preview_slots`，F5正式游戏不发这些资源。
