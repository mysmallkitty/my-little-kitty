class_name UserProfileDetail
extends SlidePopup

var username_label: Label
var rank_label: Label
var play_label: Label
var clear_label: Label
var death_label: Label
var created_label: Label
var level_label: Label
var close_button: BaseButton

func _ready() -> void:
	super()
	add_to_group("user_profile_panels")
	_bind_ui()
	_connect_buttons()
	refresh_from_api()

func open_with_me(me: Dictionary) -> void:
	_apply_me(me)
	show_popup()

func refresh_from_api() -> void:
	var me := _get_me_data()
	_apply_me(me)

func _bind_ui() -> void:
	username_label = get_node_or_null("Username") as Label
	rank_label = get_node_or_null("Rank") as Label
	play_label = get_node_or_null("PlayCount") as Label
	clear_label = get_node_or_null("ClearedCount") as Label
	death_label = get_node_or_null("DeathCount") as Label
	created_label = get_node_or_null("JoinDate") as Label
	level_label = get_node_or_null("LevelCreated") as Label
	close_button = get_node_or_null("CloseButton") as BaseButton

func _connect_buttons() -> void:
	if close_button != null and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

func _on_close_pressed() -> void:
	hide_popup()

func _apply_me(me: Dictionary) -> void:
	if me.is_empty():
		if username_label != null:
			username_label.text = "guest"
		if rank_label != null:
			rank_label.text = "#--"
		if play_label != null:
			play_label.text = "0"
		if clear_label != null:
			clear_label.text = "0"
		if death_label != null:
			death_label.text = "0"
		if created_label != null:
			created_label.text = "--"
		if level_label != null:
			level_label.text = "0"
		return
	if username_label != null:
		username_label.text = str(me.get("username", "guest")) + " (" + str(int(me.get("level", 1))) + ")"
	if rank_label != null:
		var rank = me.get("rank", null)
		rank_label.text = "#%s" % str(int(rank)) if rank != null else "#--"
	if play_label != null:
		play_label.text = str(int(me.get("total_attempts", 0)))
	if clear_label != null:
		clear_label.text = str(int(me.get("total_clears", 0)))
	if death_label != null:
		death_label.text = str(int(me.get("total_deaths", 0)))
	if created_label != null:
		created_label.text = _format_date(str(me.get("created_at", "")))

func _format_date(value: String) -> String:
	if value == "":
		return "--"
	var parts := value.split("T")
	if parts.size() > 0 and parts[0] != "":
		return parts[0]
	return value

func _get_me_data() -> Dictionary:
	var me = ApiClient.me
	if typeof(me) == TYPE_DICTIONARY:
		if me.has("data") and typeof(me.get("data", null)) == TYPE_DICTIONARY:
			return me.get("data", {})
		return me
	return {}
