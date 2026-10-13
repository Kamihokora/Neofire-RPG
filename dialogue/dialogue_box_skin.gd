@tool
class_name DialogueBoxSkin
extends Resource
## 对话框外观皮肤 —— 手绘素材的替换接口。
##
## 用法：把 .tres 挂到 QuickDialogue 的 skin 上即生效；**留空就用场景里调好的那套**
## （= 当前这套暂用的免费素材，外观一字不改）。
## 换手绘素材有两条路，都通：
##   ① 改这个 .tres（推荐：底板/名字牌/箭头/字体/配色/尺寸全在这里，一处改完）
##   ② 直接在 dialogue/dialogic/layout/neofire_box.tscn 里换贴图（所见即所得，但只影响这一个场景）
##
## 注意：skin 一旦挂上就**接管全部外观字段**（含默认值），场景里的同名设置会被覆盖。

@export_group("底板")
## 建议用 StyleBoxTexture + 九宫格切图，手绘底板就能任意拉伸不变形
@export var panel_style: StyleBox
@export var box_size: Vector2 = Vector2(540.0, 156.0)

@export_group("头像")
## 头像框相对底板的位置与尺寸（方形；贴图用 KEEP_ASPECT_COVERED 裁切）
@export var avatar_rect: Rect2 = Rect2(14.0, 42.0, 92.0, 92.0)

@export_group("名字牌")
@export var name_plate_texture: Texture2D
@export var name_plate_rect: Rect2 = Rect2(118.0, 14.0, 200.0, 38.0)
## 没写 name_color 的角色用这个色（characters.json 里每角色的 name_color 优先）
@export var name_color: Color = Color(1, 1, 1, 1)
@export var name_outline_color: Color = Color(0.13, 0.02, 0.06, 1)
@export var name_outline_size: int = 5

@export_group("正文")
@export var text_rect: Rect2 = Rect2(118.0, 60.0, 406.0, 80.0)
## 旁白（没有名字牌的行）用的颜色，会覆盖 characters.json 顶层的 narrator_color
@export var narrator_text_color: Color = Color(0.8, 0.8, 0.8, 1)
@export var text_color: Color = Color(1, 1, 1, 1)

@export_group("字体")
@export var font: Font
@export var name_font_size: int = 22
@export var text_font_size: int = 24

@export_group("继续箭头")
@export var continue_texture: Texture2D
@export var continue_rect: Rect2 = Rect2(496.0, 116.0, 28.0, 26.0)

@export_group("配色取舍")
## 是否采用 characters.json 里的配色（name_color / narrator_color）。
## 默认关 = 保持你现在调好的白字外观（角色的 name_color 只管其它地方用）
@export var use_json_colors: bool = false

@export_group("尖角（指向说话者，算法借自 Dialogic 的 text_bubble.gd）")
@export var tail_enabled: bool = true
@export var tail_color: Color = Color(0.07, 0.07, 0.09, 1)
## 尾巴根部的宽度（越靠尖端越细，收成一个角）
@export var tail_root_width: float = 26.0
## 尾巴根离底板左右角的距离，避免戳到圆角
@export var tail_root_margin: float = 60.0
## 根部往底板内部缩一点，藏住接缝
@export var tail_root_inset: float = 8.0
## 尾巴画到离说话者多远就停（0.25 = 少画 25%，不糊到角色脸上）
@export var tail_tip_gap: float = 0.25
## 尾巴的弯曲程度（0 = 直线）
@export var tail_curve: float = 0.5

@export_group("开合动画（借自 Dialogic 的 open/close）")
@export var open_duration: float = 0.12
@export var close_duration: float = 0.16
@export var open_from_scale: float = 0.82
