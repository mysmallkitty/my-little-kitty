extends Node

const WIP_DIR := "user://maps/wip"
const DOWNLOADED_DIR := "user://maps"
const CACHE_DIR := "user://maps/cache"
const MAP_CACHE_DIR := "user://maps/cache/maps"
const PREVIEW_CACHE_DIR := "user://maps/cache/previews"
const CACHE_META_DIR := "user://maps/cache/meta"
const TUTORIAL_MAP_PATH := "user://maps/wip/tutorial.kittymap"
const TUTORIAL_STATE_PATH := "user://tutorial_state.json"
const TUTORIAL_BUNDLED_PATH := "res://maps/tutorial.kittymap"
const TUTORIAL_B64 := """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"""

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
const PROFILE_ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"
const PROFILE_ALPHABET_32 := "lLpXrkbMmKVIGFECDBz6y4juD0mktnQP"
const PLAYER_SIZE_X := 9
const PLAYER_SIZE_Y := 8
const PLAYER_CODE_LEN := 72
const PLAYER_CODE_TOTAL_LEN := 73
const PLAYER_ALPHABET_64 = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"
var PLAYER_ALPHABET_32 = PLAYER_ALPHABET_64.substr(0, 32)
var _profile_texture_cache: Dictionary = {}
var _profile_palette: Array = []
var _player_texture_cache: Dictionary = {}
var _player_palette: Array = []
var _button_sfx_player: AudioStreamPlayer
var _button_sfx_connected: Dictionary = {}
var _click_sfx_connected: Dictionary = {}

func _ready() -> void:
	_ensure_audio_layout()
	_load_settings()
	_apply_audio()
	_setup_button_sfx()
	Engine.max_physics_steps_per_frame = 1
	Engine.max_fps = 60
	_profile_palette = Palatte.new().colors_64
	_player_palette = _build_player_palette()

func _setup_button_sfx() -> void:
	if _button_sfx_player == null:
		_button_sfx_player = AudioStreamPlayer.new()
		_button_sfx_player.bus = "sfx"
		_button_sfx_player.stream = load("res://audio/click.wav")
		_button_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_button_sfx_player)
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	_connect_buttons_recursive(tree.root)

func _on_node_added(node: Node) -> void:
	_register_button(node as BaseButton)
	_register_clickable_control(node as Control)

func _connect_buttons_recursive(node: Node) -> void:
	if node == null:
		return
	_register_button(node as BaseButton)
	_register_clickable_control(node as Control)
	for child in node.get_children():
		if child is Node:
			_connect_buttons_recursive(child)

func _register_button(button: BaseButton) -> void:
	if button == null:
		return
	if button is IconButton:
		return
	var id := button.get_instance_id()
	if _button_sfx_connected.has(id):
		return
	_button_sfx_connected[id] = true
	button.pressed.connect(_on_any_button_pressed, CONNECT_DEFERRED)
	button.tree_exited.connect(_on_button_exited.bind(id), CONNECT_DEFERRED)

func _register_clickable_control(control: Control) -> void:
	if control == null:
		return
	if control is BaseButton:
		return
	if control.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	if control.has_meta("no_click_sfx"):
		return
	var id := control.get_instance_id()
	if _click_sfx_connected.has(id):
		return
	_click_sfx_connected[id] = true
	control.gui_input.connect(_on_clickable_gui_input, CONNECT_DEFERRED)
	control.tree_exited.connect(_on_clickable_exited.bind(id), CONNECT_DEFERRED)

func _on_clickable_exited(id: int) -> void:
	_click_sfx_connected.erase(id)

func _on_button_exited(id: int) -> void:
	_button_sfx_connected.erase(id)

func _on_any_button_pressed() -> void:
	_play_click_sfx()

func _on_clickable_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_play_click_sfx()

func _play_click_sfx() -> void:
	if _button_sfx_player == null:
		return
	_button_sfx_player.play()

func get_tick_dt() -> float:
	var ticks := int(Engine.physics_ticks_per_second)
	if ticks <= 0:
		ticks = 60
	return 1.0 / float(ticks)

func _ensure_audio_layout() -> void:
	var layout := load("res://audio/audio_bus.tres")
	if layout is AudioBusLayout:
		AudioServer.set_bus_layout(layout)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	bgm_volume = clampf(float(cfg.get_value("audio", "bgm", bgm_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	if cfg.has_section_key("audio", "master_db"):
		master_volume = clampf(db_to_linear(float(cfg.get_value("audio", "master_db", linear_to_db(master_volume)))), 0.0, 1.0)
	if cfg.has_section_key("audio", "bgm_db"):
		bgm_volume = clampf(db_to_linear(float(cfg.get_value("audio", "bgm_db", linear_to_db(bgm_volume)))), 0.0, 1.0)
	if cfg.has_section_key("audio", "sfx_db"):
		sfx_volume = clampf(db_to_linear(float(cfg.get_value("audio", "sfx_db", linear_to_db(sfx_volume)))), 0.0, 1.0)

func ensure_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(WIP_DIR)
	DirAccess.make_dir_recursive_absolute(DOWNLOADED_DIR)
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(MAP_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(PREVIEW_CACHE_DIR)
	DirAccess.make_dir_recursive_absolute(CACHE_META_DIR)
	_ensure_tutorial_map()

func _ensure_tutorial_map() -> void:
	if FileAccess.file_exists(TUTORIAL_MAP_PATH):
		return
	if not FileAccess.file_exists(TUTORIAL_BUNDLED_PATH):
		_write_tutorial_from_b64()
		return
	var src := FileAccess.open(TUTORIAL_BUNDLED_PATH, FileAccess.READ)
	if src == null:
		_write_tutorial_from_b64()
		return
	var bytes := src.get_buffer(src.get_length())
	src.close()
	if bytes.is_empty():
		_write_tutorial_from_b64()
		return
	var dst := FileAccess.open(TUTORIAL_MAP_PATH, FileAccess.WRITE)
	if dst == null:
		_write_tutorial_from_b64()
		return
	dst.store_buffer(bytes)
	dst.close()

func _write_tutorial_from_b64() -> void:
	if TUTORIAL_B64.strip_edges() == "":
		return
	var bytes := Marshalls.base64_to_raw(TUTORIAL_B64)
	if bytes.is_empty():
		return
	var dst := FileAccess.open(TUTORIAL_MAP_PATH, FileAccess.WRITE)
	if dst == null:
		return
	dst.store_buffer(bytes)
	dst.close()

func should_force_tutorial() -> bool:
	return not has_completed_tutorial() and FileAccess.file_exists(TUTORIAL_MAP_PATH)

func has_completed_tutorial() -> bool:
	if not FileAccess.file_exists(TUTORIAL_STATE_PATH):
		return false
	var file := FileAccess.open(TUTORIAL_STATE_PATH, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	return bool(data.get("completed", false))

func mark_tutorial_completed() -> void:
	var file := FileAccess.open(TUTORIAL_STATE_PATH, FileAccess.WRITE)
	if file == null:
		return
	var payload := {
		"completed": true,
		"completed_at": int(Time.get_unix_time_from_system()),
	}
	file.store_string(JSON.stringify(payload, ""))
	file.close()

func is_tutorial_map_path(path: String) -> bool:
	if path.strip_edges() == "":
		return false
	var normalized := path.replace("\\", "/")
	return normalized.ends_with("/tutorial.kittymap")

func cache_map(map_id: String, map_data: MapData) -> void:
	if map_id == "" or map_data == null:
		return
	map_cache[map_id] = map_data

func get_cached_map(map_id: String) -> MapData:
	if map_cache.has(map_id):
		return map_cache[map_id]
	return null

func get_rank_from_total_pp(pp) -> int:
	if pp < 300:
		return 1
	elif pp < 2000:
		return 2
	elif pp < 5000:
		return 3
	elif pp < 9000:
		return 4
	elif pp < 14000:
		return 5
	elif pp < 18000:
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
	var idx := _ensure_bus(bus_name)
	if idx < 0:
		return
	var db := linear_to_db(value)
	AudioServer.set_bus_volume_db(idx, db)

func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, bus_name)
	if bus_name != "Master":
		AudioServer.set_bus_send(idx, "Master")
	return idx

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

func get_player_texture(code: String) -> Texture2D:
	if code == "":
		return load("res://graphics/kitty.png")
	var decoded := decode_player_sprite(code)
	if decoded.is_empty():
		return load("res://graphics/kitty.png")
	var cache_key := str(decoded.get("prefix", "0")) + ":" + str(decoded.get("data", ""))
	if _player_texture_cache.has(cache_key):
		return _player_texture_cache[cache_key]
	var data: String = decoded.get("data", "")
	if data.length() != PLAYER_CODE_LEN:
		return load("res://graphics/kitty.png")
	var img := Image.create(PLAYER_SIZE_X, PLAYER_SIZE_Y, false, Image.FORMAT_RGBA8)
	var idx := 0
	for y in range(PLAYER_SIZE_Y):
		for x in range(PLAYER_SIZE_X):
			var ch := data.substr(idx, 1)
			var color_index := _player_index_from_char(ch)
			if color_index < 0 or color_index >= _player_palette.size():
				color_index = 0
			var color: Color = _player_palette[color_index]
			img.set_pixel(x, y, color)
			idx += 1
	var tex := ImageTexture.create_from_image(img)
	_player_texture_cache[cache_key] = tex
	return tex

func get_player_palette() -> Array:
	return _player_palette

func encode_player_sprite(indices: PackedInt32Array) -> String:
	print("debugpoint1")
	print(indices.size())
	if indices.size() != PLAYER_CODE_LEN:
		return ""
	var out := "1"
	var alphabet = PLAYER_ALPHABET_64
	for i in range(indices.size()):
		var idx := int(indices[i])
		if idx < 0 or idx >= alphabet.length():
			idx = 0
		out += alphabet[idx]
	return out

func decode_player_sprite(code: String) -> Dictionary:
	if code.length() == PLAYER_CODE_LEN:
		return {"prefix": "0", "data": code}
	if code.length() != PLAYER_CODE_TOTAL_LEN:
		return {}
	var prefix := code.substr(0, 1)
	var data := code.substr(1, PLAYER_CODE_LEN)
	if prefix != "0" and prefix != "1":
		return {}
	return {"prefix": prefix, "data": data}

func player_indices_from_code(code: String) -> PackedInt32Array:
	var decoded := decode_player_sprite(code)
	var data: String = decoded.get("data", "")
	var out := PackedInt32Array()
	out.resize(PLAYER_CODE_LEN)
	for i in range(PLAYER_CODE_LEN):
		if i >= data.length():
			out[i] = 0
		else:
			out[i] = _player_index_from_char(data.substr(i, 1))
	return out

func player_indices_from_kitty() -> PackedInt32Array:
	var tex := load("res://graphics/kitty.png")
	if tex == null or not (tex is Texture2D):
		return PackedInt32Array()
	var img := (tex as Texture2D).get_image()
	if img == null:
		return PackedInt32Array()
	var out := PackedInt32Array()
	out.resize(PLAYER_CODE_LEN)
	var idx := 0
	var w = min(PLAYER_SIZE_X, img.get_width())
	var h = min(PLAYER_SIZE_Y, img.get_height())
	for y in range(h):
		for x in range(w):
			var color := img.get_pixel(x, y)
			var palette_index := _player_palette_index_from_color(color)
			out[idx] = palette_index
			idx += 1
	for i in range(idx, PLAYER_CODE_LEN):
		out[i] = 0
	return out

func _player_palette_index_from_color(color: Color) -> int:
	if color.a <= 0.0:
		return 0
	for i in range(_player_palette.size()):
		if _player_palette[i].is_equal_approx(color):
			return i
	return 0

func _player_index_from_char(ch: String) -> int:
	var idx := PLAYER_ALPHABET_64.find(ch)
	if idx < 0:
		return 0
	return idx

func _build_player_palette() -> Array:
	var out: Array = []
	out.append(Color(0, 0, 0, 0))
	var base = Palatte.new().colors_64
	for c in base:
		out.append(c)
	return out

func profile_code_from_indices(indices: PackedInt32Array, use_64) -> String:
	var alphabets = PROFILE_ALPHABET if use_64 else PROFILE_ALPHABET_32
	if indices.size() != PROFILE_CODE_LEN:
		return ""
	var out := ""
	for i in range(indices.size()):
		var idx := int(indices[i])
		if idx < 0 or idx >= alphabets.length():
			idx = 0
		out += alphabets[idx]
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
