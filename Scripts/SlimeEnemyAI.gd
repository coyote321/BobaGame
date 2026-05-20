extends "res://Scripts/EnemyBase.gd"
## Reactor slime minion. Uses a 6x4 directional sprite sheet:
## front, back, left, right.

const SLIME_TEXTURE: Texture2D = preload("res://Assets/Sprites/slime-enemy-reactor.png")
const SLIME_FRONT_ROW: int = 0
const SLIME_BACK_ROW: int = 1
const SLIME_LEFT_ROW: int = 2
const SLIME_RIGHT_ROW: int = 3
const SLIME_FRAME_COUNT: int = 6
const SLIME_WALK_FPS: float = 8.0

var _slime_sprite: Sprite2D
var _slime_row: int = SLIME_FRONT_ROW
var _slime_frame: int = 0
var _slime_timer: float = 0.0

func is_reactor_slime() -> bool:
	return true

func _ready():
	max_health = 42.0
	speed = 135.0
	chase_speed = 235.0
	attack_damage = 7.0
	detection_range = 520.0
	attack_range = 58.0
	_body_color = Color(0.2, 0.9, 0.72, 1)
	_body_size = Vector2(38, 32)
	_body_offset = Vector2(-19, -16)
	_patrol_extent = Vector2(120, 70)
	_idle_wait_range = Vector2(0.35, 1.1)
	_alert_icon_text = "!"
	_alert_font_size = 20
	_alert_offset = Vector2(-5, -56)
	_alert_blink_multiplier = 6.0
	_xp_reward = 15
	_money_reward = 5

	super._ready()

func uses_hazmat_visual() -> bool:
	return false

func setup_visuals():
	super.setup_visuals()
	_setup_slime_visual()
	if body_rect:
		body_rect.visible = false
	if health_bar:
		health_bar.position = Vector2(-24, -36)
		health_bar.size = Vector2(48, 7)
		health_bar.max_value = max_health
		health_bar.value = health

func _physics_process(delta):
	super._physics_process(delta)
	_update_slime_animation(delta)

func _setup_slime_visual() -> void:
	if has_node("SlimeSprite") and $SlimeSprite is Sprite2D:
		_slime_sprite = $SlimeSprite
	else:
		_slime_sprite = Sprite2D.new()
		_slime_sprite.name = "SlimeSprite"
		add_child(_slime_sprite)
		move_child(_slime_sprite, 0)

	_slime_sprite.texture = SLIME_TEXTURE
	_slime_sprite.hframes = SLIME_FRAME_COUNT
	_slime_sprite.vframes = 4
	_slime_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slime_sprite.position = Vector2(0, -6)
	_slime_sprite.scale = Vector2(1.45, 1.45)
	_set_slime_frame(0, SLIME_FRONT_ROW)

func _update_slime_animation(delta: float) -> void:
	if not _slime_sprite:
		return

	var face_vector := velocity
	if state == State.ATTACK and player and is_instance_valid(player):
		face_vector = player.global_position - global_position

	var next_row := _slime_row
	if absf(face_vector.x) > absf(face_vector.y):
		next_row = SLIME_RIGHT_ROW if face_vector.x > 0.0 else SLIME_LEFT_ROW
	elif absf(face_vector.y) > 0.1:
		next_row = SLIME_FRONT_ROW if face_vector.y > 0.0 else SLIME_BACK_ROW

	if next_row != _slime_row:
		_set_slime_frame(0, next_row)
		_slime_timer = 0.0

	if velocity.length_squared() <= 1.0 and state != State.ATTACK:
		_set_slime_frame(0, _slime_row)
		return

	_slime_timer += delta
	var frame_time := 1.0 / SLIME_WALK_FPS
	while _slime_timer >= frame_time:
		_slime_timer -= frame_time
		_set_slime_frame((_slime_frame + 1) % SLIME_FRAME_COUNT, _slime_row)

func _set_slime_frame(frame_index: int, row: int) -> void:
	_slime_frame = clampi(frame_index, 0, SLIME_FRAME_COUNT - 1)
	_slime_row = clampi(row, 0, 3)
	if _slime_sprite:
		_slime_sprite.frame_coords = Vector2i(_slime_frame, _slime_row)
