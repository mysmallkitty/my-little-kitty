@tool
class_name KeyButton
extends TextureButton

@export var pressed_offset := Vector2(0, 2)

@onready var _label: Label = get_node_or_null("Key") as Label
@onready var _arrow: TextureRect = get_node_or_null("Arrow") as TextureRect

var _label_base := Vector2.ZERO
var _arrow_base := Vector2.ZERO
var _last_pressed := false

func _ready() -> void:
	_cache_bases()
	_apply_pressed_state(is_pressed())
	set_process(true)

func _process(_delta: float) -> void:
	var pressed := is_pressed()
	if pressed != _last_pressed:
		_apply_pressed_state(pressed)
	if Engine.is_editor_hint():
		_cache_bases()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and not is_pressed():
		_cache_bases()

func set_keycode(code: int) -> void:
	if _label == null or _arrow == null:
		return
	if _is_arrow_key(code):
		_label.visible = false
		_arrow.visible = true
		_arrow.rotation = deg_to_rad(_arrow_rotation_deg(code))
	else:
		_arrow.visible = false
		_label.visible = true
		_label.text = _keycode_to_label(code)

func _cache_bases() -> void:
	if _label != null:
		_label_base = _label.position
	if _arrow != null:
		_arrow_base = _arrow.position

func _apply_pressed_state(pressed: bool) -> void:
	_last_pressed = pressed
	var offset := pressed_offset if pressed else Vector2.ZERO
	if _label != null:
		_label.position = _label_base + offset
	if _arrow != null:
		_arrow.position = _arrow_base + offset

func _is_arrow_key(code: int) -> bool:
	return code == KEY_LEFT or code == KEY_RIGHT or code == KEY_UP or code == KEY_DOWN

func _arrow_rotation_deg(code: int) -> float:
	match code:
		KEY_LEFT:
			return 0.0
		KEY_RIGHT:
			return 180.0
		KEY_UP:
			return 90.0
		KEY_DOWN:
			return -90.0
	return 0.0

func _keycode_to_label(code: int) -> String:
	if code == 0:
		return "-"
	var key_event := InputEventKey.new()
	key_event.keycode = code
	var text := key_event.as_text_keycode()
	if text == "" or text == "Unknown":
		key_event.physical_keycode = code
		text = key_event.as_text_physical_keycode()
	if text == "" or text == "Unknown":
		text = OS.get_keycode_string(code)
	return text.to_upper()
