class_name MapPreview
extends Node2D

@export var tile_set: TileSet = preload("res://objs/tiles.tres")
@export var preview_scale := Vector2.ONE
@export var use_node_scale := true
@export var center_in_viewport := true
@export var preview_offset := Vector2.ZERO

var renderer: MapRenderer
var map_data: MapData
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE

func _ready() -> void:
	_base_position = position
	_base_scale = scale
	renderer = MapRenderer.new()
	renderer.tile_set = tile_set
	add_child(renderer)
	if not use_node_scale:
		scale = preview_scale

func set_map_data(map: MapData) -> void:
	map_data = map
	if renderer != null:
		renderer.render_map(map_data)
	_center_preview()

func _center_preview() -> void:
	if map_data == null or renderer == null:
		return
	var chunk: ChunkData = map_data.get_chunk_by_id(map_data.start_chunk_id)
	if chunk == null and map_data.chunks.size() > 0:
		chunk = map_data.chunks[0]
	if chunk == null:
		renderer.position = Vector2.ZERO
		return
	var rect := Rect2(Vector2(chunk.pos) * MapData.TILE_SIZE, Vector2(chunk.size) * MapData.TILE_SIZE)
	var center := rect.position + rect.size * 0.5
	renderer.position = -center + preview_offset
	if center_in_viewport:
		position = get_viewport_rect().size * 0.5
	else:
		position = _base_position
