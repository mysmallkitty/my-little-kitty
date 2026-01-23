class_name Player
extends CharacterBody2D

@export var move_speed := 50.0
@export var jump_speed := 130.0
@export var gravity := 340.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.12
@export var dash_speed := 120.0
@export var dash_time := 0.25
@export var dash_gravity_scale := 0.2
@export var dash_lift_accel := 80.0
@export var editor_mode: bool = false
@export var jump_sfx: AudioStream = preload("res://audio/jump.wav")
@export var dash_sfx: AudioStream = preload("res://audio/dash.wav")

signal signal_damaged
signal signal_grounded
signal signal_respawn

var _vel: Vector2
var _on_floor_timer := 0.0
var _jump_buffer_timer := 0.0
var _has_air_jump := true
var _is_dashing := false
var _dash_timer := 0.0
var _dash_momentum: Vector2 = Vector2.ZERO
var _can_dash_jump_boost := false
var _can_dash := false
var dir_look := 1.0
@warning_ignore("unused_private_class_variable")
var _checkpoint_pos: Vector2 = Vector2.ZERO
var _jump_player: AudioStreamPlayer
var _dash_player: AudioStreamPlayer
var _death_pixels: CPUParticles2D

@export var collision_shape: CollisionShape2D
@export var hazard_mask: int = 1 << 1

func _is_overlapping_hazard() -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return false

	var space_state := get_world_2d().direct_space_state

	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = collision_shape.shape
	params.transform = collision_shape.global_transform
	params.collision_mask = hazard_mask
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.exclude = [self]

	var hits := space_state.intersect_shape(params, 1)
	return hits.size() > 0

func _ready() -> void:
	_setup_sfx()
	_setup_death_pixels()

func _setup_sfx() -> void:
	if jump_sfx != null:
		_jump_player = AudioStreamPlayer.new()
		_jump_player.bus = "sfx"
		_jump_player.stream = jump_sfx
		add_child(_jump_player)
	if dash_sfx != null:
		_dash_player = AudioStreamPlayer.new()
		_dash_player.bus = "sfx"
		_dash_player.stream = dash_sfx
		add_child(_dash_player)

func _setup_death_pixels() -> void:
	_death_pixels = get_node_or_null("DeathPixels") as CPUParticles2D
	if _death_pixels == null:
		return
	if _death_pixels.texture != null:
		return
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_death_pixels.texture = ImageTexture.create_from_image(image)

func _die() -> void:
	signal_damaged.emit()

func _respawn() -> void:
	signal_respawn.emit()

func _physics_process(delta):
	if editor_mode:
		return
	var _dir = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
	if _dir < 0:
		dir_look = -1.0
	if _dir > 0:
		dir_look = 1.0
	$Kitty.scale.x = dir_look * 1
	_handle_timers(delta)
	if _is_dashing:
		_dash_step(delta)
	else:
		_air_ground_step(delta)
	_apply_move()
	if _is_overlapping_hazard():
		_die()

func _handle_timers(delta: float) -> void:
	if is_on_floor():
		signal_grounded.emit()
		_can_dash = true
		_on_floor_timer = coyote_time
		_has_air_jump = true
		_can_dash_jump_boost = false
	else:
		_on_floor_timer = max(0.0, _on_floor_timer - delta)
	_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_end_dash()

func _input(event):
	if editor_mode:
		return
	if event.is_action_pressed("player_jump"):
		_jump_buffer_timer = jump_buffer
	if _can_dash:
		if event.is_action_pressed("player_dash") and not _is_dashing:
			_start_dash(scale.x)
			_can_dash = false

func _air_ground_step(delta: float) -> void:
	_vel.y += gravity * delta
	var dir = Input.get_action_strength("player_right") - Input.get_action_strength("player_left")
	_vel.x = move_speed * dir

	if _jump_buffer_timer > 0.0:
		if _on_floor_timer > 0.0:
			_jump_buffer_timer = 0.0
			_jump(false)
		elif _has_air_jump:
			_jump_buffer_timer = 0.0
			_jump(true)

func _start_dash(_dir) -> void:
	_is_dashing = true
	_dash_timer = dash_time
	_vel = Vector2(dash_speed * dir_look, 0)
	_can_dash_jump_boost = true
	velocity = _vel
	_play_dash_sfx()

func _dash_step(_delta: float) -> void:
	_vel.x = dash_speed * dir_look
	_vel.y += (gravity * dash_gravity_scale - dash_lift_accel) * _delta

func _end_dash() -> void:
	_is_dashing = false
	_dash_timer = 0.0
	_dash_momentum = _vel

func _jump(is_air_jump: bool) -> void:
	if _is_dashing:
		_end_dash()
		_dash_momentum = Vector2.ZERO
	if is_air_jump:
		_has_air_jump = false
	_vel.y = -jump_speed
	_play_jump_sfx()
	if _can_dash_jump_boost:
		_vel.x += _dash_momentum.x * 0.5
	_can_dash_jump_boost = false
	_dash_momentum = Vector2.ZERO

func _unhandled_input(event):
	if editor_mode:
		return
	if event.is_action_released("player_jump") and _vel.y < 0:
		_vel.y *= 0.55

func _apply_move() -> void:
	velocity = _vel
	move_and_slide()
	_vel = velocity

func _play_jump_sfx() -> void:
	if _jump_player != null:
		_jump_player.play()

func _play_dash_sfx() -> void:
	if _dash_player != null:
		_dash_player.play()
