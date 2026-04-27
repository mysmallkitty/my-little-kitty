extends Node2D

@export var map_select_play_scene := "res://roots/map_select_play.tscn"
@export var map_select_editor_scene := "res://roots/map_select_editor.tscn"
@export var settings_panel_scene: PackedScene = preload("res://ui/panels/settings_panel.tscn")

var play_button: BaseButton
var editor_button: BaseButton
var settings_button: BaseButton
var kittynet_button: BaseButton
var profile_panel: Control
var auth_panel: Control
var profile_detail: Control
var settings_panel: SettingsPanel
var kittynet_panel: Kittynet
var _death_label: Label
var _death_timer: Timer

func _ready() -> void:
	Game.ensure_dirs()
	_bind_ui()
	_connect_buttons()
	_setup_profile_click()
	_setup_settings_panel()
	_setup_death_counter()
	if auth_panel != null:
		auth_panel.visible = false
	if Game.should_force_tutorial():
		Game.current_map_path = Game.TUTORIAL_MAP_PATH
		Game.current_map_data = null
		Game.current_map_id = ""
		Game.return_scene = "res://roots/main_menu.tscn"
		_change_scene("res://roots/map_play.tscn")

func _connect_buttons() -> void:
	if play_button != null and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if editor_button != null and not editor_button.pressed.is_connected(_on_editor_pressed):
		editor_button.pressed.connect(_on_editor_pressed)
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if kittynet_button != null and not kittynet_button.pressed.is_connected(_on_kittynet_pressed):
		kittynet_button.pressed.connect(_on_kittynet_pressed)

func _setup_profile_click() -> void:
	if profile_panel == null:
		return
	profile_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if not profile_panel.gui_input.is_connected(_on_profile_input):
		profile_panel.gui_input.connect(_on_profile_input)

func _on_profile_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _is_logged_in():
				_open_profile_detail()
			else:
				_open_auth_panel()

func _on_play_pressed() -> void:
	_change_scene(map_select_play_scene)

func _on_editor_pressed() -> void:
	_change_scene(map_select_editor_scene)

func _on_settings_pressed() -> void:
	if settings_panel == null:
		return
	if settings_panel.visible:
		settings_panel.close()
	else:
		settings_panel.open()

func _on_kittynet_pressed() -> void:
	if kittynet_panel == null:
		return
	if kittynet_panel.has_method("is_open") and kittynet_panel.is_open():
		if kittynet_panel.has_method("close_popup"):
			kittynet_panel.close_popup()
		else:
			kittynet_panel.hide()
		return
	if kittynet_panel.has_method("open_popup"):
		kittynet_panel.open_popup()
	else:
		kittynet_panel.visible = true

func _open_auth_panel() -> void:
	if auth_panel == null:
		return
	if auth_panel.has_method("open_login"):
		auth_panel.open_login()
	elif auth_panel.has_method("show_popup"):
		auth_panel.show_popup()
	else:
		auth_panel.visible = true

func _open_profile_detail() -> void:
	if profile_detail == null:
		return
	if profile_detail.has_method("open_with_me"):
		profile_detail.open_with_me(_get_me_data())
	elif profile_detail.has_method("show_popup"):
		profile_detail.show_popup()
	else:
		profile_detail.visible = true

func _change_scene(path: String) -> void:
	var root := get_tree().root
	if root != null:
		var fader: Node = root.get_node_or_null("SceneFader")
		if fader != null and fader.has_method("change_scene"):
			fader.change_scene(path)
			return
	get_tree().change_scene_to_file(path)

func _bind_ui() -> void:
	play_button = _find_button("UI/Hud/Buttons/Play", "Play")
	editor_button = _find_button("UI/Hud/Buttons/Editor", "Editor")
	settings_button = _find_button("UI/Hud/Buttons/Settings", "Settings")
	kittynet_button = _find_button("UI/Hud/Buttons/KittynetOpen", "KittynetOpen")
	profile_panel = get_node_or_null("UI/ProfilePanel") as Control
	auth_panel = get_node_or_null("UI/AuthPanel") as Control
	profile_detail = get_node_or_null("UI/UserProfileDetail") as Control
	kittynet_panel = get_node_or_null("UI/Kittynet") as Kittynet
	_death_label = get_node_or_null("UI/Hud/TodaysDeathCount") as Label
	if kittynet_panel != null:
		kittynet_panel.hide()

func _setup_death_counter() -> void:
	if _death_label == null:
		return
	_death_label.visible = true
	_update_death_label(0)
	call_deferred("_fetch_recent_deaths")
	if _death_timer == null:
		_death_timer = Timer.new()
		_death_timer.one_shot = false
		_death_timer.wait_time = 10.0
		add_child(_death_timer)
		_death_timer.timeout.connect(_fetch_recent_deaths)
	_death_timer.start()

func _fetch_recent_deaths() -> void:
	var result: Dictionary = await ApiClient.GET("/api/v1/records/global-deaths")
	if not result.get("ok", false):
		return
	var data = result.get("data", null)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var count := int(data.get("recent_24h_deaths", 0))
	_update_death_label(count)

func _update_death_label(count: int) -> void:
	if _death_label == null:
		return
	var label_text := "In last 24 hours\n%d kitties crossed the Rainbow Bridge." % count
	_death_label.text = label_text

func _setup_settings_panel() -> void:
	settings_panel = get_node_or_null("UI/SettingsPanel") as SettingsPanel
	if settings_panel != null:
		settings_panel.visible = false
		return
	if settings_panel_scene == null:
		return
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer == null:
		return
	settings_panel = settings_panel_scene.instantiate() as SettingsPanel
	if settings_panel == null:
		return
	settings_panel.visible = false
	ui_layer.add_child(settings_panel)

func _find_button(path: String, _name: String) -> BaseButton:
	var node := get_node_or_null(path)
	if node is BaseButton:
		return node
	var fallback := find_child(_name, true, false)
	if fallback is BaseButton:
		return fallback
	return null

func _is_logged_in() -> bool:
	return ApiClient.access_token != "" and not _get_me_data().is_empty()

func _get_me_data() -> Dictionary:
	var me = ApiClient.me
	if typeof(me) == TYPE_DICTIONARY:
		if me.has("data") and typeof(me.get("data", null)) == TYPE_DICTIONARY:
			return me.get("data", {})
		return me
	return {}
