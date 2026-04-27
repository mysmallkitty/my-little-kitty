class_name ProfilePanel
extends Control

@onready var username_label: Label = $Username
@onready var level_label: Label = $Level
@onready var profile_picture: TextureRect = $ProfilePicture
@onready var rank_icon: TextureRect = $SkillRank

func _ready() -> void:
	add_to_group("profile_panels")
	refresh_from_api()


func refresh_from_api() -> void:
	var me := _get_me_data()
	if me.is_empty():
		set_profile("click here to login", 0, null, null, false)
		return
	var username := str(me.get("username", "guest"))
	var level := int(me.get("level", 1))
	var sprite_code := str(me.get("profile_sprite", ""))
	var tex := Game.get_profile_texture(sprite_code)
	set_profile(username, level, tex, null, false)

func set_profile(username: String, level: int, picture: Texture2D, rank_texture: Texture2D, show_rank: bool) -> void:
	if username_label != null:
		username_label.text = username
	if level_label != null:
		level_label.text = str(level)
	if profile_picture != null:
		if picture != null:
			profile_picture.texture = picture
			profile_picture.visible = true
		else:
			profile_picture.texture = null
			profile_picture.visible = false
	if rank_icon != null:
		rank_icon.visible = show_rank and rank_texture != null
		if rank_texture != null:
			rank_icon.texture = rank_texture

func _get_me_data() -> Dictionary:
	var me = ApiClient.me
	if typeof(me) == TYPE_DICTIONARY:
		if me.has("data") and typeof(me.get("data", null)) == TYPE_DICTIONARY:
			return me.get("data", {})
		return me
	return {}

func _is_supporter(me: Dictionary) -> bool:
	return str(me.get("role", "")) == "sup"

func _on_player_sprite_pressed() -> void:
	var panels := get_tree().get_nodes_in_group("player_sprite_edit_panels")
	if panels.is_empty():
		return
	var editor := panels[0]
	if editor != null and editor.has_method("open_for_me"):
		editor.open_for_me()
