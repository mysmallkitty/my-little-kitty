class_name PixelCanvas
extends Control

signal changed

var palette: Array = []
var pixels := PackedInt32Array()
var active_index := 0
var draw_grid := true

func _ready() -> void:
	if palette.is_empty():
		palette = Palatte.new().colors
	_ensure_pixels()
	queue_redraw()

func set_palette(colors: Array) -> void:
	palette = colors
	queue_redraw()

func set_pixels(indices: PackedInt32Array) -> void:
	pixels = indices
	_ensure_pixels()
	queue_redraw()

func get_pixels() -> PackedInt32Array:
	return pixels

func set_active_index(index: int) -> void:
	active_index = clampi(index, 0, palette.size() - 1)

func clear(index: int = 0) -> void:
	_ensure_pixels()
	for i in range(pixels.size()):
		pixels[i] = index
	queue_redraw()
	changed.emit()

func _ensure_pixels() -> void:
	if pixels.size() != Game.PROFILE_CODE_LEN:
		pixels = PackedInt32Array()
		pixels.resize(Game.PROFILE_CODE_LEN)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_paint_at(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_at(mm.position)

func _paint_at(pos: Vector2) -> void:
	if palette.is_empty():
		return
	var cell := _cell_size()
	if cell <= 0.0:
		return
	var x := int(floor(pos.x / cell))
	var y := int(floor(pos.y / cell))
	if x < 0 or y < 0 or x >= Game.PROFILE_SIZE or y >= Game.PROFILE_SIZE:
		return
	var idx := y * Game.PROFILE_SIZE + x
	if idx < 0 or idx >= pixels.size():
		return
	if pixels[idx] == active_index:
		return
	pixels[idx] = active_index
	queue_redraw()
	changed.emit()

func _cell_size() -> float:
	var cell_x := size.x / float(Game.PROFILE_SIZE)
	var cell_y := size.y / float(Game.PROFILE_SIZE)
	return min(cell_x, cell_y)

func _draw() -> void:
	if palette.is_empty():
		return
	var cell := _cell_size()
	var idx := 0
	for y in range(Game.PROFILE_SIZE):
		for x in range(Game.PROFILE_SIZE):
			var color_index := int(pixels[idx])
			if color_index < 0 or color_index >= palette.size():
				color_index = 0
			var color: Color = palette[color_index]
			draw_rect(Rect2(Vector2(x * cell, y * cell), Vector2(cell, cell)), color, true)
			if draw_grid:
				draw_rect(Rect2(Vector2(x * cell, y * cell), Vector2(cell, cell)), Color(0, 0, 0, 0.15), false, 1.0)
			idx += 1
