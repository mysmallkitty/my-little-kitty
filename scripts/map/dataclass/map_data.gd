class_name MapData
extends RefCounted

const TILE_SIZE := 8
const MIN_CHUNK_SIZE := Vector2i(40, 23)
const COMPACT_VERSION := 4
const INVALID_SOURCE_ID := -2147483648

var version := COMPACT_VERSION
var metadata := _make_metadata()
var chunks: Array[ChunkData] = []
var start_chunk_id := ""
var layers: Dictionary = {}
var spawn := Vector2i(3, 3)

func _init() -> void:
	layers = _make_layers()

static func _make_layers() -> Dictionary:
	return {
		"object": [],
		"deco": [],
		"block": [],
		"terrain": [],
		"hazard": [],
	}

static func _make_metadata() -> Dictionary:
	return {
		"title": "",
		"detail": "",
		"map_id": -1,
		"difficulty": 1,
		"bg": "",
		"is_verified": false,
	}

static func _normalize_layers(raw: Dictionary) -> Dictionary:
	var out := _make_layers()
	_append_layer_entries(out, raw, "object", Vector2i.ZERO)
	_append_layer_entries(out, raw, "deco", Vector2i.ZERO)
	_append_layer_entries(out, raw, "block", Vector2i.ZERO)
	_append_layer_entries(out, raw, "terrain", Vector2i.ZERO)
	_append_layer_entries(out, raw, "hazard", Vector2i.ZERO)

	if raw.has("scene") and typeof(raw["scene"]) == TYPE_ARRAY:
		_append_entries_with_offset(out["object"], raw["scene"], Vector2i.ZERO)
	if raw.has("fg") and typeof(raw["fg"]) == TYPE_ARRAY:
		_append_entries_with_offset(out["deco"], raw["fg"], Vector2i.ZERO)
	if raw.has("damage") and typeof(raw["damage"]) == TYPE_ARRAY:
		_append_entries_with_offset(out["hazard"], raw["damage"], Vector2i.ZERO)
	if raw.has("collision") and typeof(raw["collision"]) == TYPE_DICTIONARY:
		var collision: Dictionary = raw["collision"]
		if collision.has("terrain") and typeof(collision["terrain"]) == TYPE_ARRAY:
			_append_entries_with_offset(out["terrain"], collision["terrain"], Vector2i.ZERO)
		if collision.has("tiles") and typeof(collision["tiles"]) == TYPE_ARRAY:
			_append_entries_with_offset(out["block"], collision["tiles"], Vector2i.ZERO)
	return out

static func _normalize_metadata(raw: Dictionary) -> Dictionary:
	var out := _make_metadata()
	if raw.has("title"):
		out["title"] = str(raw.get("title", ""))
	if raw.has("detail"):
		out["detail"] = str(raw.get("detail", ""))
	if raw.has("map_id"):
		out["map_id"] = int(raw.get("map_id", -1))
	if raw.has("difficulty"):
		out["difficulty"] = clampi(int(raw.get("difficulty", 1)), 1, 8)
	if raw.has("bg"):
		out["bg"] = str(raw.get("bg", ""))
	if raw.has("is_verified"):
		out["is_verified"] = bool(raw.get("is_verified", false))
	return out

static func create_debug() -> MapData:
	var map := MapData.new()
	var chunk_a := ChunkData.new()
	chunk_a.id = _make_chunk_id()
	chunk_a.pos = Vector2i(0, 0)
	chunk_a.size = MIN_CHUNK_SIZE
	map.chunks.append(chunk_a)

	var chunk_b := ChunkData.new()
	chunk_b.id = _make_chunk_id()
	chunk_b.pos = Vector2i(MIN_CHUNK_SIZE.x, 0)
	chunk_b.size = MIN_CHUNK_SIZE
	map.chunks.append(chunk_b)

	map.start_chunk_id = chunk_a.id
	map.spawn = chunk_a.pos + Vector2i(3, 3)
	return map

func to_dict() -> Dictionary:
	var out := {
		"version": version,
		"metadata": _normalize_metadata(metadata),
		"start_chunk_id": start_chunk_id,
		"spawn": [spawn.x, spawn.y],
		"chunks": [],
		"layers": _normalize_layers(layers),
	}
	for chunk in chunks:
		out["chunks"].append(chunk.to_dict())
	return out

static func from_dict(data: Dictionary) -> MapData:
	var map := MapData.new()
	map.version = int(data.get("version", 1))
	var meta_data: Dictionary = data.get("metadata", {})
	if data.has("map_id"):
		meta_data["map_id"] = data.get("map_id", -1)
	if data.has("difficulty"):
		meta_data["difficulty"] = data.get("difficulty", 1)
	if data.has("bg"):
		meta_data["bg"] = data.get("bg", "")
	if data.has("is_verified"):
		meta_data["is_verified"] = data.get("is_verified", false)
	map.metadata = _normalize_metadata(meta_data)
	map.start_chunk_id = str(data.get("start_chunk_id", ""))
	var has_spawn := data.has("spawn")
	if has_spawn:
		map.spawn = _vec2i_from_value(data.get("spawn", null))
	var has_top_layers := data.has("layers") and typeof(data.get("layers", null)) == TYPE_DICTIONARY
	if has_top_layers:
		map.layers = _normalize_layers(data.get("layers", {}))
	else:
		map.layers = _make_layers()
	var chunk_list: Array = data.get("chunks", [])
	var legacy_spawn_set := false
	for entry in chunk_list:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict := entry as Dictionary
		var chunk := ChunkData.from_dict(entry_dict)
		map.chunks.append(chunk)
		if not has_top_layers and entry_dict.has("layers") and typeof(entry_dict["layers"]) == TYPE_DICTIONARY:
			_merge_layers(map.layers, entry_dict["layers"], chunk.pos)
		if not has_spawn and not legacy_spawn_set and entry_dict.has("spawn"):
			if map.start_chunk_id == "" or chunk.id == map.start_chunk_id:
				var spawn_local := _vec2i_from_value(entry_dict.get("spawn", [3, 3]))
				map.spawn = chunk.pos + spawn_local
				legacy_spawn_set = true
	if not has_spawn and not legacy_spawn_set:
		_set_default_spawn(map)
	return map

func to_compact_dict() -> Dictionary:
	var name_table: Array[String] = []
	var name_index: Dictionary = {}
	var scene_table: Array[String] = []
	var scene_index: Dictionary = {}
	var chunks_out: Array = []

	for chunk in chunks:
		chunks_out.append([
			chunk.id,
			chunk.pos.x,
			chunk.pos.y,
			chunk.size.x,
			chunk.size.y,
		])

	var layers_compact := _compact_layers(layers, name_table, name_index, scene_table, scene_index)
	var meta := _normalize_metadata(metadata)
	var out: Dictionary = {
		"v": COMPACT_VERSION,
		"m": [
			str(meta.get("title", "")),
			str(meta.get("detail", "")),
			int(meta.get("map_id", -1)),
			clampi(int(meta.get("difficulty", 1)), 1, 8),
			str(meta.get("bg", "")),
			1 if bool(meta.get("is_verified", false)) else 0,
		],
		"s": start_chunk_id,
		"p": [spawn.x, spawn.y],
		"c": chunks_out,
	}
	if not layers_compact.is_empty():
		out["l"] = layers_compact
	if name_table.size() > 0:
		out["sn"] = name_table
	if scene_table.size() > 0:
		out["sp"] = scene_table
	return out

static func from_compact_dict(data: Dictionary) -> MapData:
	var map := MapData.new()
	map.version = int(data.get("v", COMPACT_VERSION))
	var meta: Array = data.get("m", [])
	var meta_dict := _make_metadata()
	if meta.size() > 0:
		meta_dict["title"] = str(meta[0])
	if meta.size() > 1:
		meta_dict["detail"] = str(meta[1])
	if meta.size() > 2:
		meta_dict["map_id"] = int(meta[2])
	if meta.size() > 3:
		meta_dict["difficulty"] = clampi(int(meta[3]), 1, 8)
	if meta.size() > 4:
		meta_dict["bg"] = str(meta[4])
	if meta.size() > 5:
		meta_dict["is_verified"] = bool(meta[5])
	map.metadata = _normalize_metadata(meta_dict)
	map.start_chunk_id = str(data.get("s", ""))
	var has_spawn := data.has("p")
	if has_spawn:
		map.spawn = _vec2i_from_value(data.get("p", null))

	var name_table: Array = data.get("sn", [])
	var scene_table: Array = data.get("sp", [])
	var has_top_layers := data.has("l") and typeof(data.get("l", null)) == TYPE_DICTIONARY
	if has_top_layers:
		map.layers = _expand_compact_layers(data.get("l", {}), name_table, scene_table)
	else:
		map.layers = _make_layers()

	var chunk_list: Array = data.get("c", [])
	var legacy_spawn_set := false
	for raw_entry in chunk_list:
		if typeof(raw_entry) != TYPE_ARRAY:
			continue
		var entry: Array = raw_entry
		if entry.size() < 5:
			continue
		var chunk := ChunkData.new()
		chunk.id = str(entry[0])
		chunk.pos = Vector2i(int(entry[1]), int(entry[2]))
		chunk.size = Vector2i(int(entry[3]), int(entry[4]))
		map.chunks.append(chunk)
		if not has_top_layers and entry.size() >= 8:
			var layers_compact: Dictionary = {}
			if typeof(entry[7]) == TYPE_DICTIONARY:
				layers_compact = entry[7]
			var legacy_layers := _expand_compact_layers(layers_compact, name_table, scene_table)
			_merge_layers(map.layers, legacy_layers, chunk.pos)
			if not has_spawn and not legacy_spawn_set and entry.size() >= 7:
				if map.start_chunk_id == "" or chunk.id == map.start_chunk_id:
					map.spawn = chunk.pos + Vector2i(int(entry[5]), int(entry[6]))
					legacy_spawn_set = true
	if not has_spawn and not legacy_spawn_set:
		_set_default_spawn(map)
	return map

func get_chunk_by_id(chunk_id: String) -> ChunkData:
	for chunk in chunks:
		if chunk.id == chunk_id:
			return chunk
	return null

func get_chunk_at_tile(tile_pos: Vector2i) -> ChunkData:
	for chunk in chunks:
		if _tile_in_chunk(tile_pos, chunk):
			return chunk
	return null

func get_adjacent_chunk(chunk: ChunkData, dir: Vector2i) -> ChunkData:
	var a_min := chunk.pos
	var a_max := chunk.pos + chunk.size
	for other in chunks:
		if other == chunk:
			continue
		var b_min := other.pos
		var b_max := other.pos + other.size
		if dir == Vector2i.LEFT:
			if b_max.x == a_min.x and _ranges_overlap(a_min.y, a_max.y, b_min.y, b_max.y):
				return other
		elif dir == Vector2i.RIGHT:
			if b_min.x == a_max.x and _ranges_overlap(a_min.y, a_max.y, b_min.y, b_max.y):
				return other
		elif dir == Vector2i.UP:
			if b_max.y == a_min.y and _ranges_overlap(a_min.x, a_max.x, b_min.x, b_max.x):
				return other
		elif dir == Vector2i.DOWN:
			if b_min.y == a_max.y and _ranges_overlap(a_min.x, a_max.x, b_min.x, b_max.x):
				return other
	return null

func get_adjacent_chunk_for_tile(chunk: ChunkData, tile_pos: Vector2i, dir: Vector2i) -> ChunkData:
	for other in chunks:
		if other == chunk:
			continue
		if dir == Vector2i.LEFT:
			if other.pos.x + other.size.x == chunk.pos.x and tile_pos.y >= other.pos.y and tile_pos.y < other.pos.y + other.size.y:
				return other
		elif dir == Vector2i.RIGHT:
			if other.pos.x == chunk.pos.x + chunk.size.x and tile_pos.y >= other.pos.y and tile_pos.y < other.pos.y + other.size.y:
				return other
		elif dir == Vector2i.UP:
			if other.pos.y + other.size.y == chunk.pos.y and tile_pos.x >= other.pos.x and tile_pos.x < other.pos.x + other.size.x:
				return other
		elif dir == Vector2i.DOWN:
			if other.pos.y == chunk.pos.y + chunk.size.y and tile_pos.x >= other.pos.x and tile_pos.x < other.pos.x + other.size.x:
				return other
	return null

static func _tile_in_chunk(tile_pos: Vector2i, chunk: ChunkData) -> bool:
	return tile_pos.x >= chunk.pos.x \
		and tile_pos.y >= chunk.pos.y \
		and tile_pos.x < chunk.pos.x + chunk.size.x \
		and tile_pos.y < chunk.pos.y + chunk.size.y

static func _ranges_overlap(a_min: int, a_max: int, b_min: int, b_max: int) -> bool:
	return a_min < b_max and b_min < a_max

static func _make_chunk_id() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var stamp := Time.get_unix_time_from_system()
	return "%s_%s" % [str(stamp), str(rng.randi())]

static func _get_array_from_dict(data: Dictionary, key: String) -> Array:
	if data.has(key) and typeof(data[key]) == TYPE_ARRAY:
		return data[key]
	return []

static func _compact_layers(_layers: Dictionary, name_table: Array[String], name_index: Dictionary, scene_table: Array[String], scene_index: Dictionary) -> Dictionary:
	var layers_compact: Dictionary = {}
	var hazard_entries := _compact_tile_entries(_get_array_from_dict(_layers, "hazard"), name_table, name_index)
	if not hazard_entries.is_empty():
		layers_compact["d"] = hazard_entries
	var deco_entries := _compact_tile_entries(_get_array_from_dict(_layers, "deco"), name_table, name_index)
	if not deco_entries.is_empty():
		layers_compact["f"] = deco_entries
	var block_entries := _compact_tile_entries(_get_array_from_dict(_layers, "block"), name_table, name_index)
	if not block_entries.is_empty():
		layers_compact["o"] = block_entries
	var terrain_entries := _compact_terrain_entries(_get_array_from_dict(_layers, "terrain"), name_table, name_index)
	if not terrain_entries.is_empty():
		layers_compact["t"] = terrain_entries
	var object_entries := _compact_scene_entries(_get_array_from_dict(_layers, "object"), scene_table, scene_index)
	if not object_entries.is_empty():
		layers_compact["n"] = object_entries
	return layers_compact

static func _compact_tile_entries(entries: Array, name_table: Array[String], name_index: Dictionary) -> Array:
	var out: Array = []
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var pos := _vec2i_from_value(entry.get("pos", null))
		var source_id := _encode_source_id(entry, name_table, name_index)
		if source_id == INVALID_SOURCE_ID:
			continue
		var atlas := _vec2i_from_value(entry.get("atlas", [0, 0]))
		var alt := int(entry.get("alt", 0))
		out.append(pos.x)
		out.append(pos.y)
		out.append(source_id)
		out.append(atlas.x)
		out.append(atlas.y)
		out.append(alt)
	return out

static func _compact_terrain_entries(entries: Array, name_table: Array[String], name_index: Dictionary) -> Array:
	var out: Array = []
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var pos := _vec2i_from_value(entry.get("pos", null))
		var source_id := _encode_source_id(entry, name_table, name_index)
		if source_id == INVALID_SOURCE_ID:
			continue
		out.append(pos.x)
		out.append(pos.y)
		out.append(source_id)
	return out

static func _compact_scene_entries(entries: Array, scene_table: Array[String], scene_index: Dictionary) -> Array:
	var out: Array = []
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var scene_path := str(entry.get("scene", ""))
		if scene_path == "":
			continue
		var index: int
		if scene_index.has(scene_path):
			index = int(scene_index[scene_path])
		else:
			index = scene_table.size()
			scene_table.append(scene_path)
			scene_index[scene_path] = index
		var pos := _vec2i_from_value(entry.get("pos", null))
		var rot := int(entry.get("rot", 0))
		var fh := bool(entry.get("fh", false))
		var fv := bool(entry.get("fv", false))
		var flags := (rot & 3) | (4 if fh else 0) | (8 if fv else 0)
		out.append(pos.x)
		out.append(pos.y)
		out.append(index)
		out.append(flags)
	return out

static func _encode_source_id(entry: Dictionary, name_table: Array[String], name_index: Dictionary) -> int:
	if entry.has("source_id"):
		var raw_id = entry.get("source_id", INVALID_SOURCE_ID)
		if typeof(raw_id) == TYPE_INT or typeof(raw_id) == TYPE_FLOAT:
			return int(raw_id)
	var source_name := str(entry.get("source", ""))
	if source_name == "":
		return INVALID_SOURCE_ID
	if name_index.has(source_name):
		return -int(name_index[source_name]) - 1
	var index := name_table.size()
	name_table.append(source_name)
	name_index[source_name] = index
	return -index - 1

static func _expand_compact_layers(data: Dictionary, name_table: Array, scene_table: Array) -> Dictionary:
	var _layers := _make_layers()
	if data.has("d") and typeof(data["d"]) == TYPE_ARRAY:
		_layers["hazard"] = _expand_tile_entries(data["d"], name_table)
	if data.has("f") and typeof(data["f"]) == TYPE_ARRAY:
		_layers["deco"] = _expand_tile_entries(data["f"], name_table)
	if data.has("o") and typeof(data["o"]) == TYPE_ARRAY:
		_layers["block"] = _expand_tile_entries(data["o"], name_table)
	if data.has("t") and typeof(data["t"]) == TYPE_ARRAY:
		_layers["terrain"] = _expand_terrain_entries(data["t"], name_table)
	if data.has("n") and typeof(data["n"]) == TYPE_ARRAY:
		_layers["object"] = _expand_scene_entries(data["n"], scene_table)
	return _layers

static func _expand_tile_entries(raw: Array, name_table: Array) -> Array:
	var out: Array = []
	var idx := 0
	while idx + 5 < raw.size():
		var x := int(raw[idx])
		var y := int(raw[idx + 1])
		var source_id := int(raw[idx + 2])
		var ax := int(raw[idx + 3])
		var ay := int(raw[idx + 4])
		var alt := int(raw[idx + 5])
		var entry := {
			"pos": [x, y],
			"atlas": [ax, ay],
			"alt": alt,
		}
		if source_id >= 0:
			entry["source_id"] = source_id
		else:
			var name_index := -source_id - 1
			if name_index >= 0 and name_index < name_table.size():
				entry["source"] = str(name_table[name_index])
			else:
				idx += 6
				continue
		out.append(entry)
		idx += 6
	return out

static func _expand_terrain_entries(raw: Array, name_table: Array) -> Array:
	var out: Array = []
	var idx := 0
	while idx + 2 < raw.size():
		var x := int(raw[idx])
		var y := int(raw[idx + 1])
		var source_id := int(raw[idx + 2])
		var entry := {
			"pos": [x, y],
		}
		if source_id >= 0:
			entry["source_id"] = source_id
		else:
			var name_index := -source_id - 1
			if name_index >= 0 and name_index < name_table.size():
				entry["source"] = str(name_table[name_index])
			else:
				idx += 3
				continue
		out.append(entry)
		idx += 3
	return out

static func _expand_scene_entries(raw: Array, scene_table: Array) -> Array:
	var out: Array = []
	var idx := 0
	var stride := 4
	if raw.size() % 4 != 0 and raw.size() % 3 == 0:
		stride = 3
	while idx + (stride - 1) < raw.size():
		var x := int(raw[idx])
		var y := int(raw[idx + 1])
		var scene_idx := int(raw[idx + 2])
		if scene_idx < 0 or scene_idx >= scene_table.size():
			idx += stride
			continue
		var entry := {
			"pos": [x, y],
			"scene": str(scene_table[scene_idx]),
		}
		if stride == 4:
			var flags := int(raw[idx + 3])
			var rot := flags & 3
			var fh := (flags & 4) != 0
			var fv := (flags & 8) != 0
			entry["rot"] = rot
			entry["fh"] = fh
			entry["fv"] = fv
		out.append(entry)
		idx += stride
	return out

static func _merge_layers(target: Dictionary, source: Dictionary, offset: Vector2i) -> void:
	_append_layer_entries(target, source, "object", offset)
	_append_layer_entries(target, source, "deco", offset)
	_append_layer_entries(target, source, "block", offset)
	_append_layer_entries(target, source, "terrain", offset)
	_append_layer_entries(target, source, "hazard", offset)

	if source.has("scene") and typeof(source["scene"]) == TYPE_ARRAY:
		var object_dst: Array = target.get("object", [])
		_append_entries_with_offset(object_dst, source["scene"], offset)
		target["object"] = object_dst
	if source.has("fg") and typeof(source["fg"]) == TYPE_ARRAY:
		var deco_dst: Array = target.get("deco", [])
		_append_entries_with_offset(deco_dst, source["fg"], offset)
		target["deco"] = deco_dst
	if source.has("damage") and typeof(source["damage"]) == TYPE_ARRAY:
		var hazard_dst: Array = target.get("hazard", [])
		_append_entries_with_offset(hazard_dst, source["damage"], offset)
		target["hazard"] = hazard_dst
	if source.has("collision") and typeof(source["collision"]) == TYPE_DICTIONARY:
		var collision_src: Dictionary = source["collision"]
		var block_dst: Array = target.get("block", [])
		_append_entries_with_offset(block_dst, _get_array_from_dict(collision_src, "tiles"), offset)
		target["block"] = block_dst
		var terrain_dst: Array = target.get("terrain", [])
		_append_entries_with_offset(terrain_dst, _get_array_from_dict(collision_src, "terrain"), offset)
		target["terrain"] = terrain_dst

static func _append_layer_entries(target: Dictionary, source: Dictionary, key: String, offset: Vector2i) -> void:
	var source_entries := _get_array_from_dict(source, key)
	if source_entries.is_empty():
		return
	var target_entries: Array = target.get(key, [])
	_append_entries_with_offset(target_entries, source_entries, offset)
	target[key] = target_entries

static func _append_entries_with_offset(target: Array, source: Array, offset: Vector2i) -> void:
	for item in source:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var pos := _vec2i_from_value(entry.get("pos", null)) + offset
		var new_entry := entry.duplicate(true)
		new_entry["pos"] = [pos.x, pos.y]
		target.append(new_entry)

static func _set_default_spawn(map: MapData) -> void:
	var start_chunk := map.get_chunk_by_id(map.start_chunk_id)
	if start_chunk == null and map.chunks.size() > 0:
		start_chunk = map.chunks[0]
	if start_chunk != null:
		map.spawn = start_chunk.pos + Vector2i(3, 3)
	else:
		map.spawn = Vector2i(3, 3)

static func _vec2i_from_value(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO
