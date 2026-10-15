extends RefCounted
## 独立存档容器；先写临时文件并校验，再替换正式文件，保留上一份有效备份。

const FORMAT := "neofire.save"
const VERSION := 2
const SLOT_COUNT := 3
const MAX_BYTES := 4 * 1024 * 1024
var directory := "user://save_slots"


func _path(slot: int) -> String:
	return directory.path_join("slot_%d.json" % slot)


func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func _json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value == null or value is String or value is bool or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for child: Variant in value:
			if not _json_safe(child, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _json_safe(value[key], depth + 1):
				return false
		return true
	return false


func write_slot(slot: int, payload: Dictionary) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "存档槽不存在"}
	if _read_file(_path(slot)).get("unsupported", false):
		return {"ok": false, "error": "此存档版本不兼容，未覆盖原文件"}
	if not _json_safe(payload):
		return {"ok": false, "error": "当前进度含有无法保存的数据，原存档已保留"}
	var body := JSON.stringify(payload)
	var envelope := {"format": FORMAT, "version": VERSION, "saved_at": Time.get_datetime_string_from_system(true), "body": body, "sha256": body.sha256_text()}
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		return {"ok": false, "error": "无法建立存档目录"}
	var target := _path(slot)
	var temporary := target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法写入存档"}
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	if not _read_file(temporary).get("ok", false):
		return {"ok": false, "error": "新存档校验未通过，原存档已保留"}
	if _read_file(target).get("ok", false):
		error = DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(target + ".bak"))
		if error != OK:
			return {"ok": false, "error": "无法保留旧存档，已停止覆盖"}
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	if error != OK:
		return {"ok": false, "error": "无法替换存档，原存档已保留"}
	return {"ok": true}


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "empty": true, "error": "空存档"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"ok": false, "error": "存档无法读取"}
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return {"ok": false, "error": "存档格式损坏"}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or envelope.get("format") != FORMAT:
		return {"ok": false, "error": "存档格式损坏"}
	# JSON把数字读成float；Array.has对int/float采用严格类型匹配。
	var version: Variant = envelope.get("version")
	if not (version is int or version is float) or (version != 1 and version != VERSION):
		return {"ok": false, "unsupported": true, "error": "存档版本暂不兼容"}
	var body: Variant = envelope.get("body")
	if not body is String or body.sha256_text() != envelope.get("sha256"):
		return {"ok": false, "error": "存档校验失败"}
	var body_parser := JSON.new()
	if body_parser.parse(body) != OK:
		return {"ok": false, "error": "存档内容损坏"}
	var payload: Variant = body_parser.data
	if not payload is Dictionary:
		return {"ok": false, "error": "存档内容损坏"}
	return {"ok": true, "data": payload, "saved_at": str(envelope.get("saved_at", ""))}


func read_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "存档槽不存在"}
	var result := _read_file(_path(slot))
	# 高版本存档不能静默退回旧备份。
	if result.get("ok", false) or result.get("unsupported", false):
		return result
	var backup := _read_file(_path(slot) + ".bak")
	if backup.get("ok", false):
		backup["recovered"] = true
		return backup
	return result


func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var info := read_slot(slot)
		info["slot"] = slot
		result.append(info)
	return result
