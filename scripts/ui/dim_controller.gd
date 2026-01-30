class_name DimController
extends ColorRect

@export var target_alpha := 0.55
@export var fade_time := 0.2

var _count := 0
var _tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var color := self.color
	color.a = 0.0
	self.color = color

func acquire() -> void:
	_count += 1
	if _count == 1:
		_show_dim()

func release() -> void:
	_count = max(0, _count - 1)
	if _count == 0:
		_hide_dim()

func _show_dim() -> void:
	visible = true
	_kill_tween()
	var color := self.color
	var target := Color(color.r, color.g, color.b, target_alpha)
	if color.a <= 0.0:
		color.a = 0.0
	self.color = color
	_tween = create_tween()
	_tween.tween_property(self, "color", target, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _hide_dim() -> void:
	_kill_tween()
	var color := self.color
	var target := Color(color.r, color.g, color.b, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "color", target, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.finished.connect(_on_hide_finished)

func _on_hide_finished() -> void:
	if _count == 0:
		visible = false

func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
