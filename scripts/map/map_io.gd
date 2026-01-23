class_name MapIO
extends RefCounted

static func save_map(path: String, map_data: MapData, compact: bool = true) -> int:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data: Dictionary = map_data.to_compact_dict() if compact else map_data.to_dict()
	var indent := "" if compact else "\t"
	var json_text := JSON.stringify(data, indent)
	file.store_string(json_text)
	file.close()
	return OK

static func load_map(path: String) -> MapData:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = parsed
	return map_from_dict(data)

static func map_from_dict(data: Dictionary) -> MapData:
	if data.has("v"):
		return MapData.from_compact_dict(data)
	return MapData.from_dict(data)
