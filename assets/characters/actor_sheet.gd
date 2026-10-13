class_name ActorSheet
extends RefCounted
## Actor 总图版的切片工具（Actor1.png）。
##
## 图版排布：横向 4 个角色、纵向 2 个角色（共 8 个），
## 每个角色块 = 3 列 × 4 行、每格 48×48（4 向 × 3 帧）。
##   索引按「先横后纵」：0 1 2 3
##                       4 5 6 7
## 第 0 行 = 面朝下，1 = 左，2 = 右，3 = 上（RPG Maker VX 惯例）。

const SHEET_PATH := "res://assets/characters/Actor1.png"
const FRAME_SIZE := 48
const SHEET_COLUMNS := 4
const FRAMES_PER_DIR := 3
const DIRECTIONS := 4

const ROW_FOR_DIRECTION := {
	Vector2i.DOWN: 0, Vector2i.LEFT: 1, Vector2i.RIGHT: 2, Vector2i.UP: 3,
}


static func available() -> bool:
	return ResourceLoader.exists(SHEET_PATH)


## 角色块在图版里的左上角
static func block_origin(character_index: int) -> Vector2i:
	return Vector2i(
		(character_index % SHEET_COLUMNS) * FRAMES_PER_DIR * FRAME_SIZE,
		floori(float(character_index) / float(SHEET_COLUMNS)) * DIRECTIONS * FRAME_SIZE)


## 把某个角色的 4 向 × 3 帧切成 SpriteFrames（动画名 walk_down / idle_up ...）
static func build_frames(character_index: int, walk_fps: float = 8.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if not available():
		push_error("[ActorSheet] 找不到行走图：%s" % SHEET_PATH)
		return frames
	frames.remove_animation(&"default")
	var sheet: Texture2D = load(SHEET_PATH)
	var origin := block_origin(character_index)
	if origin.x + FRAMES_PER_DIR * FRAME_SIZE > sheet.get_width() \
			or origin.y + DIRECTIONS * FRAME_SIZE > sheet.get_height():
		push_error("[ActorSheet] 角色 %d 超出图版范围（图版 %s）" % [character_index, sheet.get_size()])
	for dir: Vector2i in ROW_FOR_DIRECTION:
		var row: int = ROW_FOR_DIRECTION[dir]
		var walk_name := anim_name(dir, "walk")
		var idle_name := anim_name(dir, "idle")
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, walk_fps)
		frames.set_animation_loop(walk_name, true)
		frames.add_animation(idle_name)
		frames.set_animation_speed(idle_name, 1.0)
		frames.set_animation_loop(idle_name, false)
		for col in FRAMES_PER_DIR:
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(origin.x + col * FRAME_SIZE, origin.y + row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
			frames.add_frame(walk_name, at)
		frames.add_frame(idle_name, frames.get_frame_texture(walk_name, 1))
	return frames


static func anim_name(dir: Vector2i, kind: String) -> StringName:
	var suffix := "down"
	match dir:
		Vector2i.LEFT:
			suffix = "left"
		Vector2i.RIGHT:
			suffix = "right"
		Vector2i.UP:
			suffix = "up"
	return StringName("%s_%s" % [kind, suffix])


## 把任意方向向量压成 4 向之一
static func direction_from_vector(dir: Vector2) -> Vector2i:
	if absf(dir.x) >= absf(dir.y):
		return Vector2i.RIGHT if dir.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if dir.y > 0.0 else Vector2i.UP
