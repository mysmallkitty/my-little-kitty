class_name MapSearchFilterPanel
extends "res://scripts/ui/popup_panel.gd"

signal apply_requested(filters: Dictionary)
signal reset_requested

@onready var _apply_button: BaseButton = $Panel/Apply
@onready var _reset_button: BaseButton = $Panel/Reset
@onready var _search_input: LineEdit = $Panel/Search
@onready var _ranked_only: CheckButton = $Panel/IsRanked
@onready var _loved_only: CheckButton = $Panel/IsLoved
@onready var _search_by: OptionButton = $Panel/SearchBy
@onready var _order_by: OptionButton = $Panel/OrderBy
@onready var _rating_min: HSlider = $Panel/RatingMin
@onready var _rating_max: HSlider = $Panel/RatingMax
@onready var _rating_label: Label = $Panel/Rating

var _defaults: Dictionary = {}

func _ready() -> void:
	super()
	_defaults = _capture_state()
	_update_rating_label()
	if _apply_button != null and not _apply_button.pressed.is_connected(_on_apply_pressed):
		_apply_button.pressed.connect(_on_apply_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)
	if _search_input != null and not _search_input.text_submitted.is_connected(_on_search_submitted):
		_search_input.text_submitted.connect(_on_search_submitted)
	if _rating_min != null and not _rating_min.value_changed.is_connected(_on_rating_changed):
		_rating_min.value_changed.connect(_on_rating_changed)
	if _rating_max != null and not _rating_max.value_changed.is_connected(_on_rating_changed):
		_rating_max.value_changed.connect(_on_rating_changed)

func set_filters(filters: Dictionary) -> void:
	if filters == null:
		filters = {}
	_reset_to_defaults(false)
	var title := str(filters.get("title", ""))
	var creator := str(filters.get("creator", ""))
	var map_id = filters.get("map_id", null)
	if title != "":
		_set_search("title", title)
	elif creator != "":
		_set_search("creator", creator)
	elif map_id != null:
		_set_search("id", str(map_id))

	var sort := str(filters.get("sort", "latest"))
	_set_sort(sort)
	_ranked_only.button_pressed = bool(filters.get("ranked_only", false))
	_loved_only.button_pressed = bool(filters.get("loved_only", false))
	if filters.has("rating_min"):
		_rating_min.value = float(filters.get("rating_min", _rating_min.value))
	if filters.has("rating_max"):
		_rating_max.value = float(filters.get("rating_max", _rating_max.value))
	_update_rating_label()

func _on_search_submitted(_text: String) -> void:
	_on_apply_pressed()

func _on_apply_pressed() -> void:
	apply_requested.emit(_build_filters())

func _on_reset_pressed() -> void:
	_reset_to_defaults(true)
	reset_requested.emit()

func _reset_to_defaults(keep_focus: bool) -> void:
	if _search_input != null:
		_search_input.text = str(_defaults.get("search_text", ""))
	if _search_by != null:
		_search_by.selected = int(_defaults.get("search_by", 0))
	if _order_by != null:
		_order_by.selected = int(_defaults.get("order_by", 0))
	if _ranked_only != null:
		_ranked_only.button_pressed = bool(_defaults.get("ranked_only", false))
	if _loved_only != null:
		_loved_only.button_pressed = bool(_defaults.get("loved_only", false))
	if _rating_min != null:
		_rating_min.value = float(_defaults.get("rating_min", _rating_min.min_value))
	if _rating_max != null:
		_rating_max.value = float(_defaults.get("rating_max", _rating_max.max_value))
	_update_rating_label()
	if keep_focus and _search_input != null:
		_search_input.grab_focus()

func _capture_state() -> Dictionary:
	return {
		"search_text": _search_input.text if _search_input != null else "",
		"search_by": _search_by.selected if _search_by != null else 0,
		"order_by": _order_by.selected if _order_by != null else 0,
		"ranked_only": _ranked_only.button_pressed if _ranked_only != null else false,
		"loved_only": _loved_only.button_pressed if _loved_only != null else false,
		"rating_min": _rating_min.value if _rating_min != null else 1.0,
		"rating_max": _rating_max.value if _rating_max != null else 11.0,
	}

func _build_filters() -> Dictionary:
	var filters: Dictionary = {}
	var search_text := ""
	if _search_input != null:
		search_text = _search_input.text.strip_edges()
	if search_text != "":
		match _get_search_mode():
			"title":
				filters["title"] = search_text
			"creator":
				filters["creator"] = search_text
			"id":
				if search_text.is_valid_int():
					filters["map_id"] = int(search_text)
			_:
				filters["title"] = search_text
	filters["sort"] = _get_sort_mode()
	if _ranked_only != null and _ranked_only.button_pressed:
		filters["ranked_only"] = true
	if _loved_only != null and _loved_only.button_pressed:
		filters["loved_only"] = true
	if _rating_min != null:
		var min_default := float(_defaults.get("rating_min", _rating_min.min_value))
		if abs(_rating_min.value - min_default) > 0.001:
			filters["rating_min"] = _rating_min.value
	if _rating_max != null:
		var max_default := float(_defaults.get("rating_max", _rating_max.max_value))
		if abs(_rating_max.value - max_default) > 0.001:
			filters["rating_max"] = _rating_max.value
	return filters

func _get_search_mode() -> String:
	if _search_by == null:
		return "title"
	match _search_by.selected:
		1:
			return "creator"
		2:
			return "id"
		_:
			return "title"

func _set_search(mode: String, value: String) -> void:
	if _search_input != null:
		_search_input.text = value
	if _search_by == null:
		return
	match mode:
		"creator":
			_search_by.selected = 1
		"id":
			_search_by.selected = 2
		_:
			_search_by.selected = 0

func _get_sort_mode() -> String:
	if _order_by == null:
		return "latest"
	match _order_by.selected:
		1:
			return "plays"
		2:
			return "loved"
		3:
			return "rating"
		_:
			return "latest"

func _set_sort(sort: String) -> void:
	if _order_by == null:
		return
	match sort:
		"plays":
			_order_by.selected = 1
		"loved":
			_order_by.selected = 2
		"rating":
			_order_by.selected = 3
		_:
			_order_by.selected = 0

func _on_rating_changed(_value: float) -> void:
	_update_rating_label()

func _update_rating_label() -> void:
	if _rating_label == null or _rating_min == null or _rating_max == null:
		return
	var min_text := "%.1f" % _rating_min.value
	var max_val := _rating_max.value
	var max_default := float(_defaults.get("rating_max", _rating_max.max_value))
	var max_text := "inf" if abs(max_val - max_default) <= 0.001 else "%.1f" % max_val
	_rating_label.text = "rating: %s ~ %s" % [min_text, max_text]
