class_name Kittynet
extends SlidePopup

@export var online_refresh_interval := 10.0
@export var search_debounce := 0.35
@export var online_page_size := 30
@export var search_page_size := 40
@export var leaderboard_page_size := 40
@export var records_max := 8

@onready var main_page: Control = $Panel/MainPage
@onready var user_page: Control = $Panel/UserPage
@onready var leaderboard_page: Control = $Panel/LeaderBoard
@onready var _panel: Control = $Panel
@onready var _loading: Control = $Panel/Loading
@onready var _loading_anim: AnimatedSprite2D = $Panel/Loading/AnimatedSprite2D
@onready var search_input: LineEdit = $Panel/MainPage/SearchPlayers
@onready var my_page_button: BaseButton = $Panel/MainPage/MyPage
@onready var global_rank_button: BaseButton = $Panel/MainPage/GlobalRank
@onready var main_players: GridContainer = $Panel/MainPage/PlayersScroll/Players
@onready var leaderboard_players: GridContainer = $Panel/LeaderBoard/PlayersScroll/Players
@onready var leaderboard_back: BaseButton = $Panel/LeaderBoard/Back
@onready var user_back: BaseButton = $Panel/UserPage/Back
@onready var close_button: BaseButton = $Panel/Close

@onready var user_name_label: Label = $Panel/UserPage/Username
@onready var user_rank_label: Label = $Panel/UserPage/Rank
@onready var user_profile_pic: TextureRect = $Panel/UserPage/ProfilePicture
@onready var user_country: TextureRect = $Panel/UserPage/Country
@onready var user_pp_rank_icon: TextureRect = $Panel/UserPage/PPRank
@onready var user_pp_label: Label = $Panel/UserPage/Label
@onready var user_play_count: Label = $Panel/UserPage/PlayCount
@onready var user_clear_count: Label = $Panel/UserPage/ClearedCount
@onready var user_death_count: Label = $Panel/UserPage/DeathCount
@onready var user_join_date: Label = $Panel/UserPage/JoinDate
@onready var record_root: Control = $Panel/UserPage/RecordRow

var _main_user_template: Control
var _leader_user_template: Control
var _record_template: Control
var _search_timer: Timer
var _refresh_timer: Timer
var _presence_request: HTTPRequest
var _online_ids: Dictionary = {}
var _search_text := ""
var _loading_count := 0
var _cached_page_state := {}
var _user_back_target := "main"
var _presence_paused := false
func _ready() -> void:
	super()
	_setup_templates()
	_connect_ui()
	_connect_auth_state()
	_setup_timers()
	_show_main_page()
	if visible:
		_refresh_online_list()
	_setup_loading()
	if visible:
		_resume_presence_stream()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_pause_presence_stream()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_resume_presence_stream()

func _setup_templates() -> void:
	_main_user_template = main_players.get_child(0) as Control
	if _main_user_template != null:
		_main_user_template.visible = false
	_main_user_template = _main_user_template if _main_user_template != null else null

	_leader_user_template = leaderboard_players.get_child(0) as Control
	if _leader_user_template != null:
		_leader_user_template.visible = false
	_leader_user_template = _leader_user_template if _leader_user_template != null else null

	_record_template = record_root.get_node_or_null("RecordRow") as Control
	if _record_template != null:
		_record_template.visible = false

func _setup_loading() -> void:
	if _loading == null:
		return
	_loading.visible = false
	_loading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _loading_anim != null:
		_loading_anim.stop()

func _connect_ui() -> void:
	if search_input != null:
		if not search_input.text_changed.is_connected(_on_search_changed):
			search_input.text_changed.connect(_on_search_changed)
		if not search_input.text_submitted.is_connected(_on_search_submitted):
			search_input.text_submitted.connect(_on_search_submitted)
	if my_page_button != null and not my_page_button.pressed.is_connected(_on_my_page_pressed):
		my_page_button.pressed.connect(_on_my_page_pressed)
	if global_rank_button != null and not global_rank_button.pressed.is_connected(_on_global_rank_pressed):
		global_rank_button.pressed.connect(_on_global_rank_pressed)
	if leaderboard_back != null and not leaderboard_back.pressed.is_connected(_on_back_to_main):
		leaderboard_back.pressed.connect(_on_back_to_main)
	if user_back != null and not user_back.pressed.is_connected(_on_back_to_main):
		user_back.pressed.connect(_on_back_to_main)
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func _connect_auth_state() -> void:
	if ApiClient != null and not ApiClient.auth_state_changed.is_connected(_on_auth_state_changed):
		ApiClient.auth_state_changed.connect(_on_auth_state_changed)

func _on_auth_state_changed(_is_logged_in: bool, _reason: String) -> void:
	_restart_presence_stream()

func _setup_timers() -> void:
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = search_debounce
	add_child(_search_timer)
	_search_timer.timeout.connect(_on_search_timer)

	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = false
	_refresh_timer.wait_time = online_refresh_interval
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_on_refresh_timer)
	_refresh_timer.start()

func _on_refresh_timer() -> void:
	if not visible:
		return
	if not main_page.visible:
		return
	if _search_text != "":
		return
	_refresh_online_list()

func _on_search_changed(text: String) -> void:
	_search_text = text.strip_edges()
	_search_timer.start()

func _on_search_submitted(text: String) -> void:
	_search_text = text.strip_edges()
	_search_timer.stop()
	_run_search_or_online()

func _on_search_timer() -> void:
	_run_search_or_online()

func _run_search_or_online() -> void:
	if _search_text == "":
		_refresh_online_list(false)
		return
	_refresh_search(_search_text)

func _on_my_page_pressed() -> void:
	var me := _get_me_data()
	if me.is_empty():
		return
	_open_user_page(int(me.get("id", -1)), me, "main")

func _on_global_rank_pressed() -> void:
	_show_leaderboard()

func _on_back_to_main() -> void:
	if user_page.visible:
		if _user_back_target == "leader":
			_show_leaderboard()
		else:
			_show_main_page()
		return
	_show_main_page()

func _on_close_pressed() -> void:
	close_popup()

func open_popup() -> void:
	show_popup()
	_show_main_page()
	_resume_presence_stream()
	if _search_text == "":
		_refresh_online_list()

func close_popup() -> void:
	hide_popup()
	_pause_presence_stream()

func is_open() -> bool:
	return visible

func _show_main_page() -> void:
	main_page.visible = true
	user_page.visible = false
	leaderboard_page.visible = false

func _show_user_page() -> void:
	main_page.visible = false
	user_page.visible = true
	leaderboard_page.visible = false

func _show_leaderboard() -> void:
	main_page.visible = false
	user_page.visible = false
	leaderboard_page.visible = true
	_refresh_leaderboard()

func _refresh_online_list(show_loading: bool = true) -> void:
	if show_loading:
		_loading_on()
	var result: Dictionary = await KittynetService.list_online_users(online_page_size, 0)
	if show_loading:
		_loading_off()
	if not result.get("ok", false):
		return
	var users := _extract_user_items(result.get("data", null))
	_online_ids.clear()
	for entry in users:
		var uid := int(entry.get("id", entry.get("user_id", 0)))
		if uid > 0:
			_online_ids[uid] = true
	var filtered := users
	if result.get("source", "") == "fallback":
		if _has_online_flag(users):
			filtered = _filter_online(users)
	# if no is_online info, show as-is
	_populate_user_grid(main_players, _main_user_template, filtered, true)

func _refresh_search(text: String) -> void:
	var result: Dictionary = await KittynetService.search_users(text, search_page_size, 0)
	if not result.get("ok", false):
		return
	var users := _extract_user_items(result.get("data", null))
	_apply_online_hint(users)
	_populate_user_grid(main_players, _main_user_template, users, false)

func _refresh_leaderboard() -> void:
	_loading_on()
	var result: Dictionary = await KittynetService.fetch_leaderboard(1, leaderboard_page_size)
	_loading_off()
	if not result.get("ok", false):
		return
	var users := _extract_user_items(result.get("data", null))
	_populate_user_grid(leaderboard_players, _leader_user_template, users, false)

func _open_user_page(user_id: int, user_data: Dictionary = {}, back_target: String = "") -> void:
	if back_target == "":
		back_target = "leader" if leaderboard_page.visible else "main"
	_user_back_target = back_target
	_show_user_page()
	if user_id <= 0:
		return
	var data := user_data
	if data.is_empty() or not _has_full_user_detail(data):
		_loading_on()
		var res: Dictionary = await KittynetService.fetch_user_detail(user_id)
		_loading_off()
		if res.get("ok", false):
			if typeof(res.get("data", null)) == TYPE_DICTIONARY:
				data = res.get("data", {})
	_apply_user_detail(data)
	_refresh_user_records(user_id)

func _refresh_user_records(user_id: int) -> void:
	_loading_on()
	var res: Dictionary = await KittynetService.fetch_user_records(user_id, 100)
	_loading_off()
	if not res.get("ok", false):
		_set_user_records([])
		return
	var records := _extract_record_items(res.get("data", null))
	records.sort_custom(func(a, b): return float(a.get("pp", 0.0)) > float(b.get("pp", 0.0)))
	_set_user_records(records)

func _populate_user_grid(root: GridContainer, template: Control, users: Array, hide_offline: bool) -> void:
	if root == null or template == null:
		return
	for child in root.get_children():
		if child == template:
			continue
		child.queue_free()
	for entry in users:
		if hide_offline and not _is_user_online(entry):
			continue
		var panel := template.duplicate() as Control
		if panel == null:
			continue
		panel.visible = true
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_user_panel_input.bind(entry), CONNECT_DEFERRED)
		_set_user_panel(panel, entry)
		root.add_child(panel)

func _set_user_panel(panel: Control, data: Dictionary) -> void:
	var username_label := panel.get_node_or_null("Row/Username") as Label
	if username_label != null:
		username_label.text = str(data.get("username", ""))
	var rank_label := panel.get_node_or_null("Rank") as Label
	if rank_label != null:
		rank_label.text = _format_rank_label(data.get("rank", null))
	var profile_pic := panel.get_node_or_null("TextureRect") as TextureRect
	if profile_pic != null:
		var sprite_code := str(data.get("profile_sprite", ""))
		var tex := Game.get_profile_texture(sprite_code)
		profile_pic.texture = tex if tex != null else load("res://graphics/ui/16px/user_guest.png")
	var pp_icon := panel.get_node_or_null("Row/PPIcon") as TextureRect
	if pp_icon != null:
		var total_pp := int(data.get("total_pp", 0))
		pp_icon.texture = load("res://graphics/ui/8px/ranks/%s.png" % str(Game.get_rank_from_total_pp(total_pp)))
	var online_label := panel.get_node_or_null("IsOnline") as Label
	if online_label != null:
		var online := _is_user_online(data)
		online_label.visible = true
		online_label.text = "online" if online else "offline"
		online_label.self_modulate = Color(0.57, 1.0, 0.22, 1.0) if online else Color(0.7, 0.7, 0.7, 1.0)

func _apply_user_detail(user: Dictionary) -> void:
	if user.is_empty():
		return
	user_name_label.text = str(user.get("username", "guest"))
	user_rank_label.text = _format_rank_label(user.get("rank", null))
	var sprite_code := str(user.get("profile_sprite", ""))
	var tex := Game.get_profile_texture(sprite_code)
	user_profile_pic.texture = tex if tex != null else load("res://graphics/ui/16px/user_guest.png")
	user_country.texture = _get_flag_png(user.get("country", "unknown"))
	var total_pp := int(user.get("total_pp", 0))
	user_pp_label.text = str(total_pp) + "pp"
	user_pp_rank_icon.texture = load("res://graphics/ui/8px/ranks/%s.png" % str(Game.get_rank_from_total_pp(total_pp)))
	user_play_count.text = str(int(user.get("total_attempts", 0)))
	user_clear_count.text = str(int(user.get("total_clears", 0)))
	user_death_count.text = str(int(user.get("total_deaths", 0)))
	user_join_date.text = _format_date(str(user.get("created_at", "")))

func _has_full_user_detail(user: Dictionary) -> bool:
	if not user.has("total_attempts"):
		return false
	if not user.has("total_clears"):
		return false
	if not user.has("total_deaths"):
		return false
	if not user.has("created_at"):
		return false
	if not user.has("country"):
		return false
	return true

func _set_user_records(records: Array) -> void:
	if _record_template == null:
		return
	for child in record_root.get_children():
		if child == _record_template:
			continue
		child.queue_free()
	var row_height = max(1.0, _record_template.size.y)
	var max_rows := records_max
	if record_root.size.y > 0.0 and row_height > 1.0:
		max_rows = min(max_rows, int(floor(record_root.size.y / row_height)))
	for i in range(min(max_rows, records.size())):
		var entry: Dictionary = records[i]
		var row := _record_template.duplicate() as Control
		if row == null:
			continue
		row.visible = true
		row.position = _record_template.position + Vector2(0, row_height * float(i))
		var title_label := row.get_node_or_null("TitleCreator") as Label
		if title_label != null:
			title_label.text = _record_title(entry)
		var pp_label := row.get_node_or_null("PP") as Label
		if pp_label != null:
			pp_label.text = "%dpp" % int(entry.get("pp", 0))
		var rank_label := row.get_node_or_null("Label") as Label
		if rank_label != null:
			rank_label.text = str(i + 1)
		record_root.add_child(row)

func _record_title(entry: Dictionary) -> String:
	var title := ""
	var creator := ""
	if entry.has("map"):
		var map_info = entry.get("map", {})
		if typeof(map_info) == TYPE_DICTIONARY:
			title = str(map_info.get("title", ""))
			creator = str(map_info.get("creator", map_info.get("username", "")))
	if title == "":
		title = str(entry.get("map_title", entry.get("title", "")))
	if creator == "":
		creator = str(entry.get("creator", entry.get("map_creator", "")))
	if title != "" and creator != "":
		return "%s - %s" % [title, creator]
	return title if title != "" else "--"

func _on_user_panel_input(event: InputEvent, data: Dictionary) -> void:
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var target := "leader" if leaderboard_page.visible else "main"
		_open_user_page(int(data.get("id", data.get("user_id", -1))), data, target)

func _extract_user_items(payload) -> Array:
	if typeof(payload) == TYPE_ARRAY:
		return payload
	if typeof(payload) == TYPE_DICTIONARY:
		if payload.has("items") and typeof(payload.get("items")) == TYPE_ARRAY:
			return payload.get("items")
	return []

func _extract_record_items(payload) -> Array:
	if typeof(payload) == TYPE_ARRAY:
		return payload
	if typeof(payload) == TYPE_DICTIONARY:
		if payload.has("items") and typeof(payload.get("items")) == TYPE_ARRAY:
			return payload.get("items")
		if payload.has("records") and typeof(payload.get("records")) == TYPE_ARRAY:
			return payload.get("records")
	return []

func _is_user_online(entry: Dictionary) -> bool:
	if entry.has("is_online"):
		return bool(entry.get("is_online", false))
	var uid := int(entry.get("id", entry.get("user_id", 0)))
	return _online_ids.has(uid)

func _apply_online_hint(users: Array) -> void:
	for entry in users:
		if entry.has("is_online"):
			continue
		var uid := int(entry.get("id", entry.get("user_id", 0)))
		entry["is_online"] = _online_ids.has(uid)

func _filter_online(users: Array) -> Array:
	var out: Array = []
	for entry in users:
		if _is_user_online(entry):
			out.append(entry)
	return out

func _has_online_flag(users: Array) -> bool:
	for entry in users:
		if entry.has("is_online"):
			return true
	return false

func _get_me_data() -> Dictionary:
	var me = ApiClient.me
	if typeof(me) == TYPE_DICTIONARY:
		if me.has("data") and typeof(me.get("data", null)) == TYPE_DICTIONARY:
			return me.get("data", {})
		return me
	return {}

func _format_date(value: String) -> String:
	if value == "":
		return "--"
	var parts := value.split("T")
	if parts.size() > 0 and parts[0] != "":
		return parts[0]
	return value

func _get_flag_png(code) -> Texture:
	var code_str := str(code).strip_edges().to_lower()
	if code_str == "" or code_str == "unknown":
		return load("res://graphics/ui/flags/unknown.png")
	var path := "res://graphics/ui/flags".path_join(code_str + ".png")
	if ResourceLoader.exists(path):
		return load(path)
	return load("res://graphics/ui/flags/unknown.png")

func _format_rank_label(rank_val) -> String:
	if rank_val == null:
		return "#--"
	var rank_num := int(rank_val)
	if rank_num <= 0:
		return "#--"
	return "#%s" % str(rank_num)

func _start_presence_stream() -> void:
	if _presence_paused or not visible or OS.has_feature("web"):
		return
	if _presence_request != null:
		return
	_presence_request = HTTPRequest.new()
	_presence_request.process_mode = Node.PROCESS_MODE_ALWAYS
	_presence_request.timeout = 0.0
	add_child(_presence_request)
	_presence_request.request_completed.connect(_on_presence_closed)
	_request_presence()

func _restart_presence_stream() -> void:
	if _presence_request != null:
		_presence_request.cancel_request()
		_presence_request.queue_free()
		_presence_request = null
	_start_presence_stream()

func _pause_presence_stream() -> void:
	_presence_paused = true
	if _presence_request != null:
		_presence_request.cancel_request()
		_presence_request.queue_free()
		_presence_request = null

func _resume_presence_stream() -> void:
	_presence_paused = false
	if not visible:
		return
	if not OS.has_feature("web"):
		_start_presence_stream()

func _setup_presence_keepalive() -> void:
	return

func _loading_on() -> void:
	if _loading_count == 0:
		_cache_page_state()
		_set_pages_visible(false)
	_loading_count += 1
	_set_loading_visible(true)

func _loading_off() -> void:
	_loading_count = max(0, _loading_count - 1)
	if _loading_count == 0:
		_restore_page_state()
		_set_loading_visible(false)

func _set_loading_visible(visible: bool) -> void:
	if _loading == null:
		return
	_loading.visible = visible
	if _loading_anim == null:
		return
	if visible:
		if not _loading_anim.is_playing():
			_loading_anim.play()
	else:
		_loading_anim.stop()

func _cache_page_state() -> void:
	_cached_page_state = {
		"main": main_page.visible if main_page != null else false,
		"user": user_page.visible if user_page != null else false,
		"leader": leaderboard_page.visible if leaderboard_page != null else false,
	}

func _restore_page_state() -> void:
	if _cached_page_state.is_empty():
		return
	if main_page != null:
		main_page.visible = bool(_cached_page_state.get("main", false))
	if user_page != null:
		user_page.visible = bool(_cached_page_state.get("user", false))
	if leaderboard_page != null:
		leaderboard_page.visible = bool(_cached_page_state.get("leader", false))
	_cached_page_state.clear()

func _set_pages_visible(visible: bool) -> void:
	if main_page != null:
		main_page.visible = visible
	if user_page != null:
		user_page.visible = visible
	if leaderboard_page != null:
		leaderboard_page.visible = visible

func _request_presence() -> void:
	if _presence_request == null:
		return
	var url := ApiClient._make_url("/api/v1/records/presence/stream")
	var headers := ApiClient._build_headers(PackedStringArray())
	var err := _presence_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_restart_presence_later()

func _on_presence_closed(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_restart_presence_later()

func _restart_presence_later() -> void:
	if _presence_request == null:
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 5.0
	add_child(timer)
	timer.timeout.connect(func():
		timer.queue_free()
		_request_presence()
	)
