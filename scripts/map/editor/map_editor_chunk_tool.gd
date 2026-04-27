class_name MapEditorChunkTool
extends RefCounted

var editor

var dragging_chunk := false
var drag_start_tile := Vector2i.ZERO
var drag_prev_tile := Vector2i.ZERO
var drag_chunk_origin := Vector2i.ZERO
var drag_chunk_size := Vector2i.ZERO
var resizing_chunk := false
var resize_handle := ""
var _resize_limit_left := -1000000
var _resize_limit_right := 1000000
var _resize_limit_top := -1000000
var _resize_limit_bottom := 1000000

func setup(editor_ref) -> void:
	editor = editor_ref

func is_editing() -> bool:
	return editor.chunk_edit_mode

func set_edit_mode(pressed: bool) -> void:
	editor.chunk_edit_mode = pressed
	if not pressed:
		dragging_chunk = false
		resizing_chunk = false
		resize_handle = ""
	update_ui()

func update_ui() -> void:
	var show_controls = editor.chunk_edit_mode
	if editor.pen_button != null:
		editor.pen_button.toggle_mode = not show_controls
		editor.pen_button.button_pressed = (not show_controls and editor.tile_tool.tool == editor.Tool.PEN)
		var pen_icon := editor.pen_button as IconButton
		if pen_icon != null:
			pen_icon.icon_texture = editor.ICON_CHUNK_ADD if show_controls else editor.ICON_PEN
	if editor.rect_button != null:
		editor.rect_button.toggle_mode = not show_controls
		editor.rect_button.button_pressed = (not show_controls and editor.tile_tool.tool == editor.Tool.RECT)
		var rect_icon := editor.rect_button as IconButton
		if rect_icon != null:
			rect_icon.icon_texture = editor.ICON_CHUNK_REMOVE if show_controls else editor.ICON_RECT
	var can_delete = editor.map_data != null and editor.map_data.chunks.size() > 1 and editor.selected_chunk != null
	if editor.rect_button != null:
		editor.rect_button.disabled = show_controls and not can_delete
	var icon_button := editor.chunk_toggle as IconButton
	if icon_button != null:
		icon_button.icon_texture = editor.ICON_BACK if show_controls else editor.ICON_CHUNK

func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		var world_pos = editor.get_global_mouse_position()
		var handle_chunk: ChunkData = null
		var handle := ""
		for candidate in editor.map_data.chunks:
			var found := _get_chunk_handle_at_pos(candidate, world_pos)
			if found != "":
				handle_chunk = candidate
				handle = found
				break
		if handle_chunk != null:
			editor.selected_chunk = handle_chunk
			resize_handle = handle
			resizing_chunk = true
			drag_start_tile = editor._get_mouse_tile()
			drag_chunk_origin = handle_chunk.pos
			drag_chunk_size = handle_chunk.size
			_compute_resize_limits()
			editor._record_undo()
			update_ui()
			return
		var tile_pos = editor._get_mouse_tile()
		var chunk = editor.map_data.get_chunk_at_tile(tile_pos)
		if chunk != null:
			editor.selected_chunk = chunk
			dragging_chunk = true
			drag_start_tile = tile_pos
			drag_prev_tile = tile_pos
			drag_chunk_origin = chunk.pos
			drag_chunk_size = chunk.size
			editor._record_undo()
			update_ui()
	else:
		if resizing_chunk:
			resizing_chunk = false
			resize_handle = ""
			editor._sync_start_chunk_from_spawn()
			editor._clamp_spawn_after_chunk_change()
			editor._refresh_renderer(true)
		elif dragging_chunk:
			dragging_chunk = false
			editor._sync_start_chunk_from_spawn()
			editor._clamp_spawn_after_chunk_change()
			editor._refresh_renderer(true)

func handle_mouse_motion(_event: InputEventMouseMotion) -> void:
	if resizing_chunk:
		_resize_chunk()
		return
	if dragging_chunk:
		_drag_chunk()

func add_new_chunk() -> void:
	var chunk := ChunkData.new()
	chunk.id = editor._make_chunk_id()
	var center = editor.camera.get_screen_center_position()
	var center_tile := Vector2i(floor(center.x / MapData.TILE_SIZE), floor(center.y / MapData.TILE_SIZE))
	var desired_pos = center_tile - (MapData.MIN_CHUNK_SIZE / 2)
	chunk.pos = _find_non_overlapping_position(desired_pos, MapData.MIN_CHUNK_SIZE)
	chunk.size = MapData.MIN_CHUNK_SIZE
	editor.map_data.chunks.append(chunk)
	editor.selected_chunk = chunk
	editor._refresh_renderer(true)
	update_ui()

func delete_selected_chunk() -> void:
	if not editor.chunk_edit_mode:
		return
	if editor.map_data == null or editor.selected_chunk == null:
		return
	if editor.map_data.chunks.size() <= 1:
		return
	var index = editor.map_data.chunks.find(editor.selected_chunk)
	if index == -1:
		return
	editor._record_undo()
	var spawn_in_removed := _tile_in_chunk(editor.map_data.spawn, editor.selected_chunk)
	var removed_id = editor.selected_chunk.id
	editor.map_data.chunks.remove_at(index)
	editor.selected_chunk = null
	if spawn_in_removed and editor.map_data.chunks.size() > 0:
		editor._set_spawn(editor.map_data.chunks[0].pos + Vector2i(3, 3))
	if removed_id == editor.map_data.start_chunk_id:
		editor._sync_start_chunk_from_spawn()
	if editor.selected_chunk == null and not editor.map_data.chunks.is_empty():
		var pick_index: int = clampi(index - 1, 0, editor.map_data.chunks.size() - 1)
		editor.selected_chunk = editor.map_data.chunks[pick_index]
	editor._refresh_renderer(true)
	update_ui()

func _drag_chunk() -> void:
	var tile_pos = editor._get_mouse_tile()
	var delta = tile_pos - drag_prev_tile
	if delta == Vector2i.ZERO:
		return
	if editor.selected_chunk != null:
		var size = editor.selected_chunk.size
		var pos = editor.selected_chunk.pos
		var step_x := int(sign(delta.x))
		for _i in range(abs(delta.x)):
			var try_pos = pos + Vector2i(step_x, 0)
			if _chunk_overlaps(try_pos, size, editor.selected_chunk):
				break
			pos = try_pos
		var step_y := int(sign(delta.y))
		for _i in range(abs(delta.y)):
			var try_pos = pos + Vector2i(0, step_y)
			if _chunk_overlaps(try_pos, size, editor.selected_chunk):
				break
			pos = try_pos
		if pos != editor.selected_chunk.pos:
			editor.selected_chunk.pos = pos
	drag_prev_tile = tile_pos

func _resize_chunk() -> void:
	if editor.selected_chunk == null or editor.map_data == null:
		return
	var tile_pos = editor._get_mouse_tile()
	var min_size = MapData.MIN_CHUNK_SIZE
	var left = drag_chunk_origin.x
	var right = drag_chunk_origin.x + drag_chunk_size.x
	var top = drag_chunk_origin.y
	var bottom = drag_chunk_origin.y + drag_chunk_size.y
	var limit_left := _resize_limit_left
	var limit_right := _resize_limit_right
	var limit_top := _resize_limit_top
	var limit_bottom := _resize_limit_bottom
	if limit_left > right - min_size.x:
		limit_left = right - min_size.x
	if limit_right < left + min_size.x:
		limit_right = left + min_size.x
	if limit_top > bottom - min_size.y:
		limit_top = bottom - min_size.y
	if limit_bottom < top + min_size.y:
		limit_bottom = top + min_size.y
	match resize_handle:
		"left":
			var new_left: int = int(clampi(tile_pos.x, limit_left, right - min_size.x))
			editor.selected_chunk.pos.x = new_left
			editor.selected_chunk.size.x = right - new_left
		"right":
			var new_right: int = int(clampi(tile_pos.x + 1, left + min_size.x, limit_right))
			editor.selected_chunk.pos.x = left
			editor.selected_chunk.size.x = new_right - left
		"top":
			var new_top: int = int(clampi(tile_pos.y, limit_top, bottom - min_size.y))
			editor.selected_chunk.pos.y = new_top
			editor.selected_chunk.size.y = bottom - new_top
		"bottom":
			var new_bottom: int = int(clampi(tile_pos.y + 1, top + min_size.y, limit_bottom))
			editor.selected_chunk.pos.y = top
			editor.selected_chunk.size.y = new_bottom - top

func _compute_resize_limits() -> void:
	_resize_limit_left = -1000000
	_resize_limit_right = 1000000
	_resize_limit_top = -1000000
	_resize_limit_bottom = 1000000
	if editor.map_data == null or editor.selected_chunk == null:
		return
	var left = drag_chunk_origin.x
	var right = drag_chunk_origin.x + drag_chunk_size.x
	var top = drag_chunk_origin.y
	var bottom = drag_chunk_origin.y + drag_chunk_size.y
	for other in editor.map_data.chunks:
		if other == editor.selected_chunk:
			continue
		var other_left = other.pos.x
		var other_right = other.pos.x + other.size.x
		var other_top = other.pos.y
		var other_bottom = other.pos.y + other.size.y
		if _ranges_overlap(top, bottom, other_top, other_bottom):
			if other_right <= right:
				_resize_limit_left = max(_resize_limit_left, other_right)
			if other_left >= right:
				_resize_limit_right = min(_resize_limit_right, other_left)
		if _ranges_overlap(left, right, other_left, other_right):
			if other_bottom <= bottom:
				_resize_limit_top = max(_resize_limit_top, other_bottom)
			if other_top >= bottom:
				_resize_limit_bottom = min(_resize_limit_bottom, other_top)

func _get_chunk_handle_at_pos(chunk: ChunkData, world_pos: Vector2) -> String:
	var rect = _chunk_rect_pixels(chunk)
	var hit = editor.CHUNK_HANDLE_HIT
	var half = hit * 0.5
	var left_mid := Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5)
	var right_mid := Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y * 0.5)
	var top_mid := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y)
	var bottom_mid := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + rect.size.y)
	if Rect2(left_mid - Vector2(half, half), Vector2(hit, hit)).has_point(world_pos):
		return "left"
	if Rect2(right_mid - Vector2(half, half), Vector2(hit, hit)).has_point(world_pos):
		return "right"
	if Rect2(top_mid - Vector2(half, half), Vector2(hit, hit)).has_point(world_pos):
		return "top"
	if Rect2(bottom_mid - Vector2(half, half), Vector2(hit, hit)).has_point(world_pos):
		return "bottom"
	return ""

func _chunk_rect_pixels(chunk: ChunkData) -> Rect2:
	return Rect2(Vector2(chunk.pos) * MapData.TILE_SIZE, Vector2(chunk.size) * MapData.TILE_SIZE)

func _chunk_overlaps(pos: Vector2i, size: Vector2i, ignore: ChunkData) -> bool:
	if editor.map_data == null:
		return false
	for other in editor.map_data.chunks:
		if other == ignore:
			continue
		if _rects_overlap_strict(pos, size, other.pos, other.size):
			return true
	return false

func _rects_overlap_strict(a_pos: Vector2i, a_size: Vector2i, b_pos: Vector2i, b_size: Vector2i) -> bool:
	var a_right = a_pos.x + a_size.x
	var b_right = b_pos.x + b_size.x
	var a_bottom = a_pos.y + a_size.y
	var b_bottom = b_pos.y + b_size.y
	return a_pos.x < b_right and b_pos.x < a_right and a_pos.y < b_bottom and b_pos.y < a_bottom

func _ranges_overlap(a_min: int, a_max: int, b_min: int, b_max: int) -> bool:
	return a_min < b_max and b_min < a_max

func _tile_in_chunk(tile_pos: Vector2i, chunk: ChunkData) -> bool:
	return tile_pos.x >= chunk.pos.x \
		and tile_pos.y >= chunk.pos.y \
		and tile_pos.x < chunk.pos.x + chunk.size.x \
		and tile_pos.y < chunk.pos.y + chunk.size.y

func _find_non_overlapping_position(start_pos: Vector2i, size: Vector2i) -> Vector2i:
	if editor.map_data == null:
		return start_pos
	if not _chunk_overlaps(start_pos, size, null):
		return start_pos
	var radius := 1
	while radius < 32:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var candidate := start_pos + Vector2i(dx, dy)
				if not _chunk_overlaps(candidate, size, null):
					return candidate
		radius += 1
	return start_pos
