class_name ChunkData
extends RefCounted

var id := ""
var pos := Vector2i.ZERO
var size := Vector2i(40, 23)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"pos": [pos.x, pos.y],
		"size": [size.x, size.y],
	}

static func from_dict(data: Dictionary) -> ChunkData:
	var chunk := ChunkData.new()
	chunk.id = str(data.get("id", ""))
	var pos_data: Array = data.get("pos", [0, 0])
	var size_data: Array = data.get("size", [40, 23])
	chunk.pos = Vector2i(int(pos_data[0]), int(pos_data[1]))
	chunk.size = Vector2i(int(size_data[0]), int(size_data[1]))
	return chunk
