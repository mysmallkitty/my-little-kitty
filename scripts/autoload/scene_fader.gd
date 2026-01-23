extends CanvasLayer

@export var fade_time := 0.2

var _rect: ColorRect
var _busy := false

func _ready() -> void:
	layer = 1000
	_rect = ColorRect.new()
	_rect.color = Color(0, 0, 0, 0.0)
	_rect.anchors_preset = Control.PRESET_FULL_RECT
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_sync_rect()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size_changed):
		viewport.size_changed.connect(_on_viewport_size_changed)

func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	get_tree().change_scene_to_file(path)
	await _fade_to(0.0)
	_busy = false

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_rect, "color:a", alpha, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _on_viewport_size_changed() -> void:
	_sync_rect()

func _sync_rect() -> void:
	if _rect == null:
		return
	_rect.position = Vector2.ZERO
	var viewport := get_viewport()
	if viewport == null:
		return
	_rect.size = viewport.get_visible_rect().size
