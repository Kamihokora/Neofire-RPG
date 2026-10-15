# 手机菜单素材

- `phone_collage.png`：用户提供的 `neofire/Things_for_Agent/半调化手持手机.png` 的原样副本。用户说明来源为 <https://www.pinterest.com/pin/1080301029383489724/>；本次未能从网页取得更多来源信息。保留原图及透明边缘，Godot 导入时限制最长边2048，运行时旋转定位，没有生成或重绘图片。
- `save.png`、`load.png`：此前从项目已有的 dobo 免费 UI 包挑出的 mail/adventure 图标。
- `pop_warning.svg`、`pop_bubble.svg`、`pop_bolt.svg`：本次为菜单编写的临时矢量图形。半调色带由 `ui/pop_halftone.gdshader` 绘制，不烘焙成背景图；名称、说明和正文仍为独立文字控件。
- 其余应用图标复用项目已有 `assets/ui/icons/` 与 `assets/ui/combat/`；四位角色暂复用 `neofire/GIF/` 中的四个既有表情PNG，最终角色小人可替换 `phone_stage.gd` 的 `PET_ART`。
- 透明英文和确认标题使用 `theme/fonts/menu_heavy.otf`，为本机已有 `SourceHanSansCN-Heavy.otf` 的原样副本（Source Han Sans CN Heavy，字重900）。项目内带 `theme/fonts/menu_heavy_LICENSE.txt`，对应 Adobe Source Han Sans 官方仓库的 SIL OFL 1.1；不是合成加粗。字体项目：<https://github.com/adobe-fonts/source-han-sans>。
- 小人景深由 `ui/pet_defocus.gdshader` 对已有表情纹理做加权采样，主页零模糊走快速路径；未生成模糊版图片。
- `proposal_pin.svg`、`thought_cloud.svg`：为提案图钉和圆润思考气泡编写的临时SVG。气泡仅参考用户提供的圆润轮廓与连接小泡布局，文字、词条和交互均为独立控件；没有使用图像生成工具。
