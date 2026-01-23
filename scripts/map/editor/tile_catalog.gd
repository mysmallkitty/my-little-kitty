class_name TileCatalog
extends RefCounted

const INVALID_SOURCE := -1

var source_id_by_name: Dictionary = {}
var source_name_by_id: Dictionary = {}
var sources_by_prefix: Dictionary = {
	"terrain": [],
	"block": [],
	"hazard": [],
	"deco": [],
	"object": [],
}
var terrain_info_by_source: Dictionary = {}
var terrain_info_by_source_id: Dictionary = {}

static func build(tile_set: TileSet) -> TileCatalog:
	var catalog := TileCatalog.new()
	if tile_set == null:
		return catalog
	var source_count := tile_set.get_source_count()
	for i in source_count:
		var source_id := tile_set.get_source_id(i)
		var source = tile_set.get_source(source_id)
		if source == null:
			continue
		var name := str(source.resource_name)
		if name == "":
			continue
		catalog.source_name_by_id[source_id] = name
		var prefix := _detect_prefix(name)
		if prefix == "":
			continue
		catalog.source_id_by_name[name] = source_id
		if not catalog.sources_by_prefix.has(prefix):
			catalog.sources_by_prefix[prefix] = []
		catalog.sources_by_prefix[prefix].append(name)
		if prefix == "terrain":
			var terrain_info := _find_terrain_info(tile_set, name)
			if terrain_info.size() > 0:
				catalog.terrain_info_by_source[name] = terrain_info
				catalog.terrain_info_by_source_id[source_id] = terrain_info
	return catalog

func get_source_id(name: String) -> int:
	if source_id_by_name.has(name):
		return int(source_id_by_name[name])
	return INVALID_SOURCE

func get_terrain_info(name: String) -> Dictionary:
	if terrain_info_by_source.has(name):
		return terrain_info_by_source[name]
	return {}

func get_terrain_info_by_id(source_id: int) -> Dictionary:
	if terrain_info_by_source_id.has(source_id):
		return terrain_info_by_source_id[source_id]
	return {}

static func _detect_prefix(name: String) -> String:
	if name.begins_with("object_") or name.begins_with("o_"):
		return "object"
	if name.begins_with("deco_") or name.begins_with("d_"):
		return "deco"
	if name.begins_with("hazard_") or name.begins_with("h_"):
		return "hazard"
	if name.begins_with("block_") or name.begins_with("b_"):
		return "block"
	if name.begins_with("terrain_") or name.begins_with("t_"):
		return "terrain"
	return ""

static func _terrain_name_from_source(name: String) -> String:
	var prefixes := ["terrain_", "t_"]
	for prefix in prefixes:
		if name.begins_with(prefix):
			return name.substr(prefix.length())
	return name

static func _find_terrain_info(tile_set: TileSet, source_name: String) -> Dictionary:
	var terrain_name := _terrain_name_from_source(source_name)
	var set_count := tile_set.get_terrain_sets_count()
	for set_idx in set_count:
		var terrain_count := tile_set.get_terrains_count(set_idx)
		for terrain_idx in terrain_count:
			var name := tile_set.get_terrain_name(set_idx, terrain_idx)
			if name == terrain_name:
				return {
					"terrain_set": set_idx,
					"terrain": terrain_idx,
				}
	return {}
