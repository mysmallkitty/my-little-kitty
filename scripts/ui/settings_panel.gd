class_name SettingsPanel
extends SlidePopup

@export var config_path := "user://settings.cfg"

@onready var _key_ready_panel: Control = $Panel/KeyReadyPanel
@onready var _confirm_button: BaseButton = $Panel/Comfirm
@onready var _cancel_button: BaseButton = $Panel/Cancle
@onready var _logout_button: BaseButton = $Panel/Logout
@onready var _master_slider: HSlider = $Panel/Volume/Master
@onready var _sfx_slider: HSlider = $Panel/Volume/SFX
@onready var _bgm_slider: HSlider = $Panel/Volume/BGM

@onready var _key_buttons := {
	"ui_left": $Panel/Input/LEFT as KeyButton,
	"ui_right": $Panel/Input/RIGHT as KeyButton,
	"ui_up": $Panel/Input/UP as KeyButton,
	"ui_down": $Panel/Input/DOWN as KeyButton,
	"player_jump": $Panel/Input/JUMP as KeyButton,
	"player_dash": $Panel/Input/DASH as KeyButton,
	"key_reload": $Panel/Input/RESTART as KeyButton,
}

var _listening_action := ""
var _saved_bindings: Dictionary = {}
var _pending_bindings: Dictionary = {}
var _saved_volume: Dictionary = {}
var _pending_volume: Dictionary = {}
const VOLUME_MIN_DB := -60.0

func _ready() -> void:
	super()
	_connect_buttons()
	_setup_volume_sliders()
	_load_settings()
	_apply_bindings(_saved_bindings)
	_pending_bindings = _saved_bindings.duplicate(true)
	_apply_volume(_saved_volume)
	_pending_volume = _saved_volume.duplicate(true)
	if _key_ready_panel != null:
		_key_ready_panel.visible = false
		_key_ready_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)

func open() -> void:
	_reload_saved_state()
	show_popup()

func close() -> void:
	_end_listen()
	hide_popup()
func _reload_saved_state() -> void:
	_load_settings()
	_pending_bindings = _saved_bindings.duplicate(true)
	_pending_volume = _saved_volume.duplicate(true)
	_apply_bindings(_pending_bindings)
	_apply_volume(_pending_volume)
	_refresh_key_labels()

func _connect_buttons() -> void:
	for action in _key_buttons.keys():
		var button = _key_buttons[action]
		if button != null and not button.button_up.is_connected(_on_key_button_pressed):
			button.button_up.connect(_on_key_button_pressed.bind(action))
		if button != null and not button.gui_input.is_connected(_on_key_button_gui_input):
			button.gui_input.connect(_on_key_button_gui_input.bind(action))
	if _confirm_button != null and not _confirm_button.pressed.is_connected(_on_confirm_pressed):
		_confirm_button.pressed.connect(_on_confirm_pressed)
	if _cancel_button != null and not _cancel_button.pressed.is_connected(_on_cancel_pressed):
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _logout_button != null and not _logout_button.pressed.is_connected(_on_logout_pressed):
		_logout_button.pressed.connect(_on_logout_pressed)
	if _master_slider != null and not _master_slider.value_changed.is_connected(_on_master_changed):
		_master_slider.value_changed.connect(_on_master_changed)
	if _sfx_slider != null and not _sfx_slider.value_changed.is_connected(_on_sfx_changed):
		_sfx_slider.value_changed.connect(_on_sfx_changed)
	if _bgm_slider != null and not _bgm_slider.value_changed.is_connected(_on_bgm_changed):
		_bgm_slider.value_changed.connect(_on_bgm_changed)

func _on_key_button_pressed(action: String) -> void:
	_listening_action = action
	if _key_ready_panel != null:
		_key_ready_panel.visible = true
	_set_listen_mode(true)

func _on_key_button_gui_input(event: InputEvent, action: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not mb.pressed:
				_on_key_button_pressed(action)

func _input(event: InputEvent) -> void:
	if not visible or _listening_action == "":
		return
	var key_event := event as InputEventKey
	if key_event != null:
		if not key_event.pressed or key_event.echo:
			get_viewport().set_input_as_handled()
			return
		var code := _key_event_code(key_event)
		if code == KEY_ESCAPE:
			_cancel_listen()
			get_viewport().set_input_as_handled()
			return
		if code == KEY_TAB:
			get_viewport().set_input_as_handled()
			return
		_set_action_key(_listening_action, code, true)
		_pending_bindings[_listening_action] = code
		_end_listen()
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()

func _set_action_key(action: String, code: int, apply_input_map: bool) -> void:
	if apply_input_map:
		InputMap.action_erase_events(action)
		if code != 0:
			var ev := InputEventKey.new()
			ev.keycode = code
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	var button = _key_buttons.get(action, null)
	if button != null:
		button.set_keycode(code)

func _apply_bindings(bindings: Dictionary) -> void:
	for action in _key_buttons.keys():
		var code := int(bindings.get(action, _get_action_keycode(action)))
		_set_action_key(action, code, true)
	_refresh_key_labels()

func _on_confirm_pressed() -> void:
	_sync_pending_volume_from_sliders()
	_saved_bindings = _pending_bindings.duplicate(true)
	_saved_volume = _pending_volume.duplicate(true)
	_save_settings()
	close()

func _on_cancel_pressed() -> void:
	_sync_pending_volume_from_sliders()
	_pending_bindings = _saved_bindings.duplicate(true)
	_apply_bindings(_saved_bindings)
	_pending_volume = _saved_volume.duplicate(true)
	_apply_volume(_saved_volume)
	_end_listen()
	close()

func _on_logout_pressed() -> void:
	AuthService.logout()
	get_tree().call_group("profile_panels", "refresh_from_api")
	get_tree().call_group("user_profile_panels", "refresh_from_api")
	close()

func _load_settings() -> void:
	_saved_bindings.clear()
	var cfg := ConfigFile.new()
	var err := cfg.load(config_path)
	var legacy_map := {
		"ui_left": "player_left",
		"ui_right": "player_right",
	}
	_saved_volume = {
		"master": _get_game_volume("master"),
		"sfx": _get_game_volume("sfx"),
		"bgm": _get_game_volume("bgm"),
	}
	if err == OK:
		_saved_volume["master"] = float(cfg.get_value("audio", "master", _saved_volume["master"]))
		_saved_volume["sfx"] = float(cfg.get_value("audio", "sfx", _saved_volume["sfx"]))
		_saved_volume["bgm"] = float(cfg.get_value("audio", "bgm", _saved_volume["bgm"]))
		if cfg.has_section_key("audio", "master_db"):
			_saved_volume["master"] = _db_to_linear(float(cfg.get_value("audio", "master_db", _get_bus_db("Master"))))
		if cfg.has_section_key("audio", "sfx_db"):
			_saved_volume["sfx"] = _db_to_linear(float(cfg.get_value("audio", "sfx_db", _get_bus_db("sfx"))))
		if cfg.has_section_key("audio", "bgm_db"):
			_saved_volume["bgm"] = _db_to_linear(float(cfg.get_value("audio", "bgm_db", _get_bus_db("bgm"))))
	for action in _key_buttons.keys():
		var code := 0
		if err == OK and cfg.has_section_key("input", action):
			code = int(cfg.get_value("input", action))
		elif err == OK and legacy_map.has(action):
			var legacy_action := str(legacy_map[action])
			if cfg.has_section_key("input", legacy_action):
				code = int(cfg.get_value("input", legacy_action))
		if code == 0:
			code = _get_action_keycode(action)
		_saved_bindings[action] = code

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	for action in _saved_bindings.keys():
		cfg.set_value("input", action, int(_saved_bindings[action]))
	cfg.set_value("audio", "master", float(_saved_volume.get("master", 1.0)))
	cfg.set_value("audio", "sfx", float(_saved_volume.get("sfx", 1.0)))
	cfg.set_value("audio", "bgm", float(_saved_volume.get("bgm", 1.0)))
	cfg.save(config_path)

func _get_action_keycode(action: String) -> int:
	var events := InputMap.action_get_events(action)
	for ev in events:
		var key_ev := ev as InputEventKey
		if key_ev == null:
			continue
		var code := _key_event_code(key_ev)
		if code != 0:
			return code
	return 0

func _key_event_code(key_event: InputEventKey) -> int:
	if key_event.keycode != 0:
		return key_event.keycode
	return key_event.physical_keycode

func _end_listen() -> void:
	_listening_action = ""
	if _key_ready_panel != null:
		_key_ready_panel.visible = false
	_set_listen_mode(false)

func _cancel_listen() -> void:
	_end_listen()

func _apply_volume(volumes: Dictionary) -> void:
	var master := clampf(float(volumes.get("master", 1.0)), 0.0, 1.0)
	var sfx := clampf(float(volumes.get("sfx", 1.0)), 0.0, 1.0)
	var bgm := clampf(float(volumes.get("bgm", 1.0)), 0.0, 1.0)
	if Engine.has_singleton("Game"):
		Game.set_master_volume(master)
		Game.set_sfx_volume(sfx)
		Game.set_bgm_volume(bgm)
	else:
		_set_bus_db("Master", _linear_to_db(master))
		_set_bus_db("sfx", _linear_to_db(sfx))
		_set_bus_db("bgm", _linear_to_db(bgm))
	_update_slider_from_values({
		"master": master,
		"sfx": sfx,
		"bgm": bgm,
	})

func _set_bus_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
		if bus_name != "Master":
			AudioServer.set_bus_send(idx, "Master")
	AudioServer.set_bus_volume_db(idx, db)

func _get_bus_db(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)

func _update_slider_from_state() -> void:
	if _master_slider != null:
		_master_slider.value = _get_game_volume("master")
	if _sfx_slider != null:
		_sfx_slider.value = _get_game_volume("sfx")
	if _bgm_slider != null:
		_bgm_slider.value = _get_game_volume("bgm")

func _update_slider_from_values(volumes: Dictionary) -> void:
	if _master_slider != null:
		_master_slider.value = clampf(float(volumes.get("master", 1.0)), 0.0, 1.0)
	if _sfx_slider != null:
		_sfx_slider.value = clampf(float(volumes.get("sfx", 1.0)), 0.0, 1.0)
	if _bgm_slider != null:
		_bgm_slider.value = clampf(float(volumes.get("bgm", 1.0)), 0.0, 1.0)

func _on_master_changed(value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	_pending_volume["master"] = v
	if Engine.has_singleton("Game"):
		Game.set_master_volume(v)
	else:
		_set_bus_db("Master", _linear_to_db(v))

func _on_sfx_changed(value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	_pending_volume["sfx"] = v
	if Engine.has_singleton("Game"):
		Game.set_sfx_volume(v)
	else:
		_set_bus_db("sfx", _linear_to_db(v))

func _on_bgm_changed(value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	_pending_volume["bgm"] = v
	if Engine.has_singleton("Game"):
		Game.set_bgm_volume(v)
	else:
		_set_bus_db("bgm", _linear_to_db(v))

func _linear_to_db(value: float) -> float:
	if value <= 0.0:
		return VOLUME_MIN_DB
	return linear_to_db(value)

func _db_to_linear(db: float) -> float:
	if db <= VOLUME_MIN_DB:
		return 0.0
	return db_to_linear(db)

func _setup_volume_sliders() -> void:
	for slider in [_master_slider, _sfx_slider, _bgm_slider]:
		if slider == null:
			continue
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.page = 0.01

func _refresh_key_labels() -> void:
	for action in _key_buttons.keys():
		var button = _key_buttons.get(action, null)
		if button == null:
			continue
		var code := _get_action_keycode(action)
		button.set_keycode(code)

func _set_listen_mode(active: bool) -> void:
	for action in _key_buttons.keys():
		var button = _key_buttons.get(action, null)
		if button != null:
			button.disabled = active
	if _master_slider != null:
		_master_slider.editable = not active
	if _sfx_slider != null:
		_sfx_slider.editable = not active
	if _bgm_slider != null:
		_bgm_slider.editable = not active
	if _confirm_button != null:
		_confirm_button.disabled = active
	if _cancel_button != null:
		_cancel_button.disabled = active
	if _logout_button != null:
		_logout_button.disabled = active

func _get_game_volume(kind: String) -> float:
	if Engine.has_singleton("Game"):
		match kind:
			"master":
				return clampf(float(Game.master_volume), 0.0, 1.0)
			"sfx":
				return clampf(float(Game.sfx_volume), 0.0, 1.0)
			"bgm":
				return clampf(float(Game.bgm_volume), 0.0, 1.0)
	return 1.0

func _sync_pending_volume_from_sliders() -> void:
	if _master_slider != null:
		_pending_volume["master"] = _master_slider.value
	if _sfx_slider != null:
		_pending_volume["sfx"] = _sfx_slider.value
	if _bgm_slider != null:
		_pending_volume["bgm"] = _bgm_slider.value
