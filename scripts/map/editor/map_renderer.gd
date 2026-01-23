class_name MapRenderer
extends Node2D

@export var tile_set: TileSet = preload("res://objs/tiles.tres")
@export var layer_texture_filter := CanvasItem.TEXTURE_FILTER_NEAREST

var catalog: TileCatalog
var tile_layers: Dictionary = {}
var scene_root: Node2D
var _alt_cache: Dictionary = {}
var _alt_cache_tile_set: TileSet
var _flags_matrix_cache: Dictionary = {}
var _terrain_map: Dictionary = {}
var _scene_nodes: Dictionary = {}

const LAYER_ORDER := [
	{"name": "hazard", "z": -20},
	{"name": "terrain", "z": -10},
	{"name": "block", "z": -10},
	{"name": "deco", "z": 10},
	{"name": "object", "z": 20},
]

func render_map(map_data: MapData) -> void:
	if tile_set == null or map_data == null:
		return
	if _alt_cache_tile_set != tile_set:
		_alt_cache.clear()
		_alt_cache_tile_set = tile_set
	catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	_clear_layers()
	_terrain_map.clear()
	_render_layers(map_data)

func _ensure_layers() -> void:
	for entry in LAYER_ORDER:
		var name := str(entry["name"])
		var z_index := int(entry["z"])
		if name == "object":
			if scene_root == null:
				scene_root = Node2D.new()
				scene_root.name = "ObjectTiles"
				add_child(scene_root)
			scene_root.z_index = z_index
			continue
		if not tile_layers.has(name):
			var layer := TileMapLayer.new()
			layer.name = name.capitalize()
			layer.tile_set = tile_set
			layer.z_index = z_index
			layer.texture_filter = layer_texture_filter
			add_child(layer)
			tile_layers[name] = layer
		else:
			var existing = tile_layers[name]
			if existing is TileMapLayer:
				var layer := existing as TileMapLayer
				layer.tile_set = tile_set
				layer.z_index = z_index
				layer.texture_filter = layer_texture_filter

func _clear_layers() -> void:
	for key in tile_layers.keys():
		var layer = tile_layers[key]
		if layer is TileMapLayer:
			(layer as TileMapLayer).clear()
	if scene_root != null:
		for child in scene_root.get_children():
			child.queue_free()
	_scene_nodes.clear()

func _render_layers(map_data: MapData) -> void:
	var terrain_groups: Dictionary = {}
	var layers := map_data.layers
	var base := Vector2i.ZERO
	_apply_layer_tiles("hazard", layers.get("hazard", []), base)
	_apply_layer_tiles("deco", layers.get("deco", []), base)
	_apply_layer_tiles("block", layers.get("block", []), base)
	_collect_terrain_cells(terrain_groups, layers.get("terrain", []), base)
	_spawn_scene_entries(layers.get("object", []), base)
	_apply_terrain_groups(terrain_groups)

func _resolve_tile_layer(layer_name: String) -> String:
	match layer_name:
		"block", "terrain":
			return layer_name
		_:
			return layer_name

func _apply_layer_tiles(layer_name: String, entries: Array, base: Vector2i) -> void:
	var resolved := _resolve_tile_layer(layer_name)
	if not tile_layers.has(resolved):
		return
	var layer = tile_layers[resolved]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var local_pos := _vec2i_from_value(entry.get("pos", null))
		var world_pos := base + local_pos
		var source_id: int = TileCatalog.INVALID_SOURCE
		if entry.has("source_id"):
			source_id = int(entry.get("source_id", TileCatalog.INVALID_SOURCE))
		else:
			var source_name := str(entry.get("source", ""))
			source_id = catalog.get_source_id(source_name)
		if source_id == TileCatalog.INVALID_SOURCE:
			continue
		var atlas := _vec2i_from_value(entry.get("atlas", [0, 0]))
		var flags := int(entry.get("alt", 0))
		var alt_id := _get_alt_id_for_flags(source_id, atlas, flags)
		tile_layer.set_cell(world_pos, source_id, atlas, alt_id)

func _collect_terrain_cells(groups: Dictionary, entries: Array, base: Vector2i) -> void:
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var info: Dictionary = {}
		if entry.has("source_id"):
			info = catalog.get_terrain_info_by_id(int(entry.get("source_id", TileCatalog.INVALID_SOURCE)))
		else:
			var source_name := str(entry.get("source", ""))
			info = catalog.get_terrain_info(source_name)
		if info.size() == 0:
			continue
		var local_pos := _vec2i_from_value(entry.get("pos", null))
		var world_pos := base + local_pos
		_terrain_map[world_pos] = info
		var key := "%s:%s" % [str(info["terrain_set"]), str(info["terrain"])]
		if not groups.has(key):
			groups[key] = {
				"info": info,
				"cells": [],
			}
		var group: Dictionary = groups[key]
		group["cells"].append(world_pos)

func _apply_terrain_groups(groups: Dictionary) -> void:
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	for key in groups.keys():
		var group: Dictionary = groups[key]
		var info: Dictionary = group.get("info", {})
		var cells: Array = group.get("cells", [])
		if info.size() == 0 or cells.is_empty():
			continue
		var terrain_set := int(info.get("terrain_set", 0))
		var terrain := int(info.get("terrain", 0))
		tile_layer.set_cells_terrain_connect(cells, terrain_set, terrain, true)

func _spawn_scene_entries(entries: Array, base: Vector2i) -> void:
	if scene_root == null:
		return
	for item in entries:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = item
		var scene_path := str(entry.get("scene", ""))
		if scene_path == "":
			continue
		var packed := load(scene_path)
		if not (packed is PackedScene):
			continue
		var node = (packed as PackedScene).instantiate()
		if node is Node2D:
			var local_pos := _vec2i_from_value(entry.get("pos", null))
			var world_pos := (base + local_pos) * MapData.TILE_SIZE
			var node2d := node as Node2D
			node2d.position = world_pos
			var rot := int(entry.get("rot", 0))
			var fh := bool(entry.get("fh", false))
			var fv := bool(entry.get("fv", false))
			if rot != 0:
				node2d.rotation = deg_to_rad(90.0 * float(rot))
			if fh or fv:
				var scale := node2d.scale
				if fh:
					scale.x *= -1.0
				if fv:
					scale.y *= -1.0
				node2d.scale = scale
		scene_root.add_child(node)
		var key := base + _vec2i_from_value(entry.get("pos", null))
		_scene_nodes[key] = node

func update_tile(layer_name: String, world_pos: Vector2i, entry: Dictionary) -> void:
	if tile_set == null:
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	var resolved := _resolve_tile_layer(layer_name)
	if not tile_layers.has(resolved):
		return
	var layer = tile_layers[resolved]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	if entry.is_empty():
		tile_layer.set_cell(world_pos, -1)
		return
	var source_id: int = TileCatalog.INVALID_SOURCE
	if entry.has("source_id"):
		source_id = int(entry.get("source_id", TileCatalog.INVALID_SOURCE))
	else:
		var source_name := str(entry.get("source", ""))
		source_id = catalog.get_source_id(source_name)
	if source_id == TileCatalog.INVALID_SOURCE:
		tile_layer.set_cell(world_pos, -1)
		return
	var atlas := _vec2i_from_value(entry.get("atlas", [0, 0]))
	var flags := int(entry.get("alt", 0))
	var alt_id := _get_alt_id_for_flags(source_id, atlas, flags)
	tile_layer.set_cell(world_pos, source_id, atlas, alt_id)

func update_scene(world_pos: Vector2i, entry: Dictionary) -> void:
	if tile_set == null:
		return
	_ensure_layers()
	_remove_scene_at(world_pos)
	if entry.is_empty():
		return
	var scene_path := str(entry.get("scene", ""))
	if scene_path == "":
		return
	var packed := load(scene_path)
	if not (packed is PackedScene):
		return
	var node = (packed as PackedScene).instantiate()
	if node is Node2D:
		var node2d := node as Node2D
		node2d.position = Vector2(world_pos) * MapData.TILE_SIZE
		var rot := int(entry.get("rot", 0))
		var fh := bool(entry.get("fh", false))
		var fv := bool(entry.get("fv", false))
		if rot != 0:
			node2d.rotation = deg_to_rad(90.0 * float(rot))
		if fh or fv:
			var scale := node2d.scale
			if fh:
				scale.x *= -1.0
			if fv:
				scale.y *= -1.0
			node2d.scale = scale
	scene_root.add_child(node)
	_scene_nodes[world_pos] = node

func update_terrain_cell(world_pos: Vector2i, source_id: int) -> void:
	if tile_set == null:
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	if source_id == TileCatalog.INVALID_SOURCE:
		if _terrain_map.has(world_pos):
			_terrain_map.erase(world_pos)
		tile_layer.set_cell(world_pos, -1)
		_update_terrain_neighbors(world_pos)
		return
	var info := catalog.get_terrain_info_by_id(source_id)
	if info.size() == 0:
		if _terrain_map.has(world_pos):
			_terrain_map.erase(world_pos)
		tile_layer.set_cell(world_pos, -1)
		return
	_terrain_map[world_pos] = info
	_update_terrain_neighbors(world_pos)

func set_terrain_cell_raw(world_pos: Vector2i, source_id: int) -> void:
	if tile_set == null:
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	if source_id == TileCatalog.INVALID_SOURCE:
		if _terrain_map.has(world_pos):
			_terrain_map.erase(world_pos)
		tile_layer.set_cell(world_pos, -1)
		return
	var info := catalog.get_terrain_info_by_id(source_id)
	if info.size() == 0:
		if _terrain_map.has(world_pos):
			_terrain_map.erase(world_pos)
		tile_layer.set_cell(world_pos, -1)
		return
	_terrain_map[world_pos] = info

func update_terrain_region(points: Array[Vector2i]) -> void:
	if tile_set == null:
		return
	if points.is_empty():
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	var region: Dictionary = {}
	for pos in points:
		for y in range(-1, 2):
			for x in range(-1, 2):
				region[pos + Vector2i(x, y)] = true
	var groups: Dictionary = {}
	for key in region.keys():
		if typeof(key) != TYPE_VECTOR2I:
			continue
		var pos: Vector2i = key
		if not _terrain_map.has(pos):
			continue
		var info: Dictionary = _terrain_map[pos]
		var terrain_set := int(info.get("terrain_set", 0))
		var terrain := int(info.get("terrain", 0))
		var group_key := "%s:%s" % [str(terrain_set), str(terrain)]
		if not groups.has(group_key):
			groups[group_key] = {
				"terrain_set": terrain_set,
				"terrain": terrain,
				"cells": [],
			}
		var group: Dictionary = groups[group_key]
		group["cells"].append(pos)
	for group_key in groups.keys():
		var group: Dictionary = groups[group_key]
		var cells: Array = group.get("cells", [])
		if cells.is_empty():
			continue
		tile_layer.set_cells_terrain_connect(cells, int(group["terrain_set"]), int(group["terrain"]), true)

func update_terrain_rect(min_pos: Vector2i, max_pos: Vector2i) -> void:
	if tile_set == null:
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	var start_x = min(min_pos.x, max_pos.x)
	var end_x = max(min_pos.x, max_pos.x)
	var start_y = min(min_pos.y, max_pos.y)
	var end_y = max(min_pos.y, max_pos.y)
	var groups: Dictionary = {}
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			var pos := Vector2i(x, y)
			if not _terrain_map.has(pos):
				continue
			var info: Dictionary = _terrain_map[pos]
			var terrain_set := int(info.get("terrain_set", 0))
			var terrain := int(info.get("terrain", 0))
			var group_key := "%s:%s" % [str(terrain_set), str(terrain)]
			if not groups.has(group_key):
				groups[group_key] = {
					"terrain_set": terrain_set,
					"terrain": terrain,
					"cells": [],
				}
			var group: Dictionary = groups[group_key]
			group["cells"].append(pos)
	for group_key in groups.keys():
		var group: Dictionary = groups[group_key]
		var cells: Array = group.get("cells", [])
		if cells.is_empty():
			continue
		tile_layer.set_cells_terrain_connect(cells, int(group["terrain_set"]), int(group["terrain"]), true)

func rebuild_terrain_region(min_pos: Vector2i, max_pos: Vector2i) -> void:
	if tile_set == null:
		return
	if catalog == null:
		catalog = TileCatalog.build(tile_set)
	_ensure_layers()
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	var pad := Vector2i(1, 1)
	var min_x := int(min(min_pos.x, max_pos.x)) - pad.x
	var max_x := int(max(min_pos.x, max_pos.x)) + pad.x
	var min_y := int(min(min_pos.y, max_pos.y)) - pad.y
	var max_y := int(max(min_pos.y, max_pos.y)) + pad.y
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			tile_layer.set_cell(Vector2i(x, y), -1)
	var groups: Dictionary = {}
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var pos := Vector2i(x, y)
			if not _terrain_map.has(pos):
				continue
			var info: Dictionary = _terrain_map[pos]
			var terrain_set := int(info.get("terrain_set", 0))
			var terrain := int(info.get("terrain", 0))
			var group_key := "%s:%s" % [str(terrain_set), str(terrain)]
			if not groups.has(group_key):
				groups[group_key] = {
					"terrain_set": terrain_set,
					"terrain": terrain,
					"cells": [],
				}
			var group: Dictionary = groups[group_key]
			group["cells"].append(pos)
	for group_key in groups.keys():
		var group: Dictionary = groups[group_key]
		var cells: Array = group.get("cells", [])
		if cells.is_empty():
			continue
		tile_layer.set_cells_terrain_connect(cells, int(group["terrain_set"]), int(group["terrain"]), true)

func _update_terrain_neighbors(center: Vector2i) -> void:
	if not tile_layers.has("terrain"):
		return
	var layer = tile_layers["terrain"]
	if not (layer is TileMapLayer):
		return
	var tile_layer := layer as TileMapLayer
	var groups: Dictionary = {}
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var pos := Vector2i(x, y)
			if not _terrain_map.has(pos):
				continue
			var info: Dictionary = _terrain_map[pos]
			var terrain_set := int(info.get("terrain_set", 0))
			var terrain := int(info.get("terrain", 0))
			var key := "%s:%s" % [str(terrain_set), str(terrain)]
			if not groups.has(key):
				groups[key] = {
					"terrain_set": terrain_set,
					"terrain": terrain,
					"cells": [],
				}
			var group: Dictionary = groups[key]
			group["cells"].append(pos)
	for key in groups.keys():
		var group: Dictionary = groups[key]
		var cells: Array = group.get("cells", [])
		if cells.is_empty():
			continue
		tile_layer.set_cells_terrain_connect(cells, int(group["terrain_set"]), int(group["terrain"]), true)

func _remove_scene_at(world_pos: Vector2i) -> void:
	if _scene_nodes.has(world_pos):
		var node = _scene_nodes[world_pos]
		if node is Node:
			node.queue_free()
		_scene_nodes.erase(world_pos)
		return
	if scene_root == null:
		return
	var target_pos := Vector2(world_pos) * MapData.TILE_SIZE
	for child in scene_root.get_children():
		if child is Node2D:
			var node2d := child as Node2D
			if node2d.position == target_pos:
				child.queue_free()
				return

func _vec2i_from_value(value) -> Vector2i:
	if typeof(value) == TYPE_ARRAY:
		var arr: Array = value
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
	return Vector2i.ZERO

func get_alt_id_for_flags(source_id: int, atlas_coords: Vector2i, flags: int) -> int:
	return _get_alt_id_for_flags(source_id, atlas_coords, flags)

func _get_alt_id_for_flags(source_id: int, atlas_coords: Vector2i, flags: int) -> int:
	if flags == 0:
		return 0
	if tile_set == null:
		return 0
	var key := "%s:%s:%s" % [str(source_id), str(atlas_coords), str(flags)]
	if _alt_cache.has(key):
		return int(_alt_cache[key])
	var source = tile_set.get_source(source_id)
	if source is TileSetAtlasSource:
		var atlas_source := source as TileSetAtlasSource
		var alt_id := atlas_source.create_alternative_tile(atlas_coords)
		var data := atlas_source.get_tile_data(atlas_coords, alt_id)
		if data != null:
			var base_data := atlas_source.get_tile_data(atlas_coords, 0)
			if base_data != null:
				_copy_collision_shapes(base_data, data)
			var transform := _resolve_transform_flags(flags)
			data.set_transpose(transform["transpose"])
			data.set_flip_h(transform["flip_h"])
			data.set_flip_v(transform["flip_v"])
		_alt_cache[key] = alt_id
		return alt_id
	return 0

func _copy_collision_shapes(base_data: TileData, alt_data: TileData) -> void:
	if tile_set == null:
		return
	var layers := tile_set.get_physics_layers_count()
	if layers <= 0:
		return
	for layer_id in range(layers):
		var count := int(base_data.get_collision_polygons_count(layer_id))
		alt_data.set_collision_polygons_count(layer_id, count)
		for polygon_index in range(count):
			var points := base_data.get_collision_polygon_points(layer_id, polygon_index)
			alt_data.set_collision_polygon_points(layer_id, polygon_index, points)
			var one_way := base_data.is_collision_polygon_one_way(layer_id, polygon_index)
			alt_data.set_collision_polygon_one_way(layer_id, polygon_index, one_way)
			var margin := base_data.get_collision_polygon_one_way_margin(layer_id, polygon_index)
			alt_data.set_collision_polygon_one_way_margin(layer_id, polygon_index, margin)

func _resolve_transform_flags(flags: int) -> Dictionary:
	var rot := flags & 3
	var fh := (flags & 4) != 0
	var fv := (flags & 8) != 0
	var desired := _matrix_mul(_matrix_mul(_flip_matrix(fh, true), _flip_matrix(fv, false)), _rotation_matrix(rot))
	var mapping := _flags_matrix_map()
	var key := _matrix_key(desired)
	if mapping.has(key):
		return mapping[key]
	return {"flip_h": fh, "flip_v": fv, "transpose": false}

func _flags_matrix_map() -> Dictionary:
	if not _flags_matrix_cache.is_empty():
		return _flags_matrix_cache
	var mapping: Dictionary = {}
	for transpose in [false, true]:
		for flip_h in [false, true]:
			for flip_v in [false, true]:
				var mat := _flags_to_matrix(flip_h, flip_v, transpose)
				mapping[_matrix_key(mat)] = {
					"flip_h": flip_h,
					"flip_v": flip_v,
					"transpose": transpose,
				}
	_flags_matrix_cache = mapping
	return _flags_matrix_cache

func _flags_to_matrix(flip_h: bool, flip_v: bool, transpose: bool) -> Array:
	var mat := [1, 0, 0, 1]
	if transpose:
		mat = [0, 1, 1, 0]
	if flip_h:
		mat = _matrix_mul(_flip_matrix(true, true), mat)
	if flip_v:
		mat = _matrix_mul(_flip_matrix(true, false), mat)
	return mat

func _rotation_matrix(rot: int) -> Array:
	match rot & 3:
		1:
			return [0, -1, 1, 0]
		2:
			return [-1, 0, 0, -1]
		3:
			return [0, 1, -1, 0]
		_:
			return [1, 0, 0, 1]

func _flip_matrix(enabled: bool, horizontal: bool) -> Array:
	if not enabled:
		return [1, 0, 0, 1]
	if horizontal:
		return [-1, 0, 0, 1]
	return [1, 0, 0, -1]

func _matrix_mul(a: Array, b: Array) -> Array:
	return [
		int(a[0]) * int(b[0]) + int(a[1]) * int(b[2]),
		int(a[0]) * int(b[1]) + int(a[1]) * int(b[3]),
		int(a[2]) * int(b[0]) + int(a[3]) * int(b[2]),
		int(a[2]) * int(b[1]) + int(a[3]) * int(b[3]),
	]

func _matrix_key(mat: Array) -> String:
	return "%s,%s,%s,%s" % [str(mat[0]), str(mat[1]), str(mat[2]), str(mat[3])]
