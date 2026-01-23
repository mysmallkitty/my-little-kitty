extends Node2D

@export var map_select_play_scene := "res://roots/map_select_play.tscn"
@export var map_select_editor_scene := "res://roots/map_select_editor.tscn"

var play_button: BaseButton
var editor_button: BaseButton
var settings_button: BaseButton
var profile_panel: Control
var auth_panel: Control
var profile_detail: Control

func _ready() -> void:
	Game.ensure_dirs()
	_bind_ui()
	_connect_buttons()
	_setup_profile_click()
	if auth_panel != null:
		auth_panel.visible = false

func _connect_buttons() -> void:
	if play_button != null and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if editor_button != null and not editor_button.pressed.is_connected(_on_editor_pressed):
		editor_button.pressed.connect(_on_editor_pressed)
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)

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
	# TODO: settings panel hookup
	pass

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
	profile_panel = get_node_or_null("UI/ProfilePanel") as Control
	auth_panel = get_node_or_null("UI/AuthPanel") as Control
	profile_detail = get_node_or_null("UI/UserProfileDetail") as Control

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
