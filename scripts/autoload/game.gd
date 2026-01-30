extends Node

const WIP_DIR := "user://maps/wip"
const DOWNLOADED_DIR := "user://maps"
const CACHE_DIR := "user://maps/cache"
const MAP_CACHE_DIR := "user://maps/cache/maps"
const PREVIEW_CACHE_DIR := "user://maps/cache/previews"
const CACHE_META_DIR := "user://maps/cache/meta"

var current_map_path: String = ""
var current_map_id: String = ""
var last_play_map_id: String = ""
var last_editor_map_path: String = ""
var return_scene: String = ""
var current_map_data: MapData
var map_cache: Dictionary = {}
var random_bg_path: String = ""
var master_volume := 1.0
var bgm_volume := 1.0
var sfx_volume := 1.0
const PROFILE_SIZE := 16
const PROFILE_CODE_LEN := 256
const PROFILE_ALPHABET := "0123456789abcdefghijklmnopqrstuv"
var _profile_texture_cache: Dictionary = {}
var _profile_palette: Array = []

func _ready() -> void:
	_apply_audio()
	Engine.max_fps = 60
	_profile_palette = Palatte.new().colors

func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(WIP_DIR)
	DirAccess.make_dir_recursive_absolute(DOWNLOADED_DIR)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(MAP_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(PREVIEW_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(CACHE_META_DIR)

func cache_map(map_id: String, map_data: MapData) -> void:
	if map_id == "" or map_data == null:
		return
	map_cache[map_id] = map_data

func get_cached_map(map_id: String) -> MapData:
	if map_cache.has(map_id):
		return map_cache[map_id]
	return null

func get_rank_from_total_pp(pp) -> int:
	if pp < 500:
		return 1
	elif pp < 1000:
		return 2
	elif pp < 2500:
		return 3
	elif pp < 5000:
		return 4
	elif pp < 10000:
		return 5
	elif pp < 20000:
		return 6
	return 7

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio()

func _apply_audio() -> void:
	_set_bus_volume("Master", master_volume)
	_set_bus_volume("bgm", bgm_volume)
	_set_bus_volume("sfx", sfx_volume)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(idx, db)

func _format_ticks(frames: int) -> String:
	var ticks := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	if ticks <= 0:
		ticks = 60
	var total_seconds := frames / float(ticks)
	var minutes := int(total_seconds / 60)
	var seconds := int(total_seconds) % 60
	var frac := frames % ticks
	return "%02d:%02d:%02d" % [minutes, seconds, frac]

func get_profile_texture(code: String) -> Texture2D:
	if code.length() != PROFILE_CODE_LEN:
		return null
	if _profile_texture_cache.has(code):
		return _profile_texture_cache[code]
	var img := Image.create(PROFILE_SIZE, PROFILE_SIZE, false, Image.FORMAT_RGBA8)
	var idx := 0
	for y in range(PROFILE_SIZE):
		for x in range(PROFILE_SIZE):
			var ch := code.substr(idx, 1)
			var color_index := _profile_index_from_char(ch)
			var color = _profile_palette[color_index]
			img.set_pixel(x, y, color)
			idx += 1
	var tex := ImageTexture.create_from_image(img)
	_profile_texture_cache[code] = tex
	return tex

func profile_code_from_indices(indices: PackedInt32Array) -> String:
	if indices.size() != PROFILE_CODE_LEN:
		return ""
	var out := ""
	for i in range(indices.size()):
		var idx := int(indices[i])
		if idx < 0 or idx >= PROFILE_ALPHABET.length():
			idx = 0
		out += PROFILE_ALPHABET[idx]
	return out

func profile_indices_from_code(code: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(PROFILE_CODE_LEN)
	for i in range(PROFILE_CODE_LEN):
		if i >= code.length():
			out[i] = 0
		else:
			out[i] = _profile_index_from_char(code.substr(i, 1))
	return out

func _profile_index_from_char(ch: String) -> int:
	var idx := PROFILE_ALPHABET.find(ch)
	if idx < 0:
		return 0
	return idx
