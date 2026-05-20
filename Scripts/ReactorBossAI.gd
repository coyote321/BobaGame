extends "res://Scripts/EnemyBase.gd"

const SLIME_SCENE: PackedScene = preload("res://Scenes/SlimeEnemy.tscn")
const SUMMON_TEXTURE: Texture2D = preload("res://Assets/Sprites/reactor_boss_summon.png")
const BOSS_FRAME_COUNT: int = 10
const BOSS_ROW_COUNT: int = 3
const WALK_ROW: int = 0
const SUMMON_ROW: int = 1
const HURT_DEATH_ROW: int = 2
const WALK_FIRST_FRAME: int = 0
const WALK_LAST_FRAME: int = 9
const SUMMON_FIRST_FRAME: int = 0
const SUMMON_LAST_FRAME: int = 2
const HURT_FRAME: int = 0
const DEATH_FIRST_FRAME: int = 1
const DEATH_LAST_FRAME: int = 8
const WALK_FPS: float = 10.0
const SUMMON_FPS: float = 10.0
const DEATH_FPS: float = 8.0
const SUMMON_ANIMATION_TIME: float = 0.75

var _phase: int = 0
var _special_cooldown: float = 2.4
var _slime_spawn_cooldown: float = 2.0
var _boss_sprite: Sprite2D
var _boss_row: int = WALK_ROW
var _boss_frame: int = 0
var _boss_animation_timer: float = 0.0
var _summon_visual_timer: float = 0.0
var _boss_faces_left: bool = false

func is_reactor_overlord() -> bool:
	return true

func _ready():
	max_health = 900.0
	speed = 105.0
	chase_speed = 190.0
	attack_damage = 24.0
	detection_range = 1100.0
	attack_range = 150.0
	_body_color = Color(0.28, 0.85, 0.18, 1)
	_body_size = Vector2(112, 112)
	_body_offset = Vector2(-56, -56)
	_patrol_extent = Vector2(240, 140)
	_idle_wait_range = Vector2(0.2, 0.8)
	_alert_icon_text = "!!!"
	_alert_font_size = 24
	_alert_offset = Vector2(-22, -92)
	_alert_blink_multiplier = 8.0
	_xp_reward_target = 500

	super._ready()

func setup_visuals():
	super.setup_visuals()
	_setup_boss_sprite()
	if body_rect:
		body_rect.position = _body_offset
		body_rect.size = _body_size
		body_rect.color = Color(0.75, 0.95, 0.12, 1) if is_target else _body_color
		body_rect.visible = false
	if has_node("CoreGlow"):
		$CoreGlow.visible = false
	if health_bar:
		health_bar.position = Vector2(-60, -92)
		health_bar.size = Vector2(120, 10)
		health_bar.max_value = max_health
		health_bar.value = health

func _physics_process(delta):
	super._physics_process(delta)
	_update_boss_sprite(delta)
	if is_dead:
		return
	_special_cooldown -= delta
	if player and is_instance_valid(player) and _special_cooldown <= 0.0:
		_reactor_pulse()
		_special_cooldown = randf_range(2.6, 4.2)
	_slime_spawn_cooldown -= delta
	if player and is_instance_valid(player) and _slime_spawn_cooldown <= 0.0:
		_try_periodic_slime_spawn()
		_slime_spawn_cooldown = randf_range(2.6, 4.0)

func take_damage(amount: float):
	if is_dead:
		return

	health -= amount
	if health_bar:
		health_bar.value = health
	_update_health_bar_color()
	show_damage_number(amount)

	if health <= 0:
		die()
		return

	hurt_timer = 0.2
	state = State.HURT
	_start_boss_animation(HURT_DEATH_ROW, HURT_FRAME)
	_update_phase()

func die():
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	velocity = Vector2.ZERO

	if not GameManager.mission_aborting:
		if is_target:
			GameManager.add_xp(_xp_reward_target)
		else:
			GameManager.add_xp(_xp_reward)
		GameManager.update_quest_progress("kill_enemies", 1)

	died.emit(self)
	remove_from_group("enemy")

	if health_bar:
		health_bar.visible = false
	if alert_indicator:
		alert_indicator.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	_start_boss_animation(HURT_DEATH_ROW, DEATH_FIRST_FRAME)
	await get_tree().create_timer(float(DEATH_LAST_FRAME - DEATH_FIRST_FRAME + 1) / DEATH_FPS).timeout
	queue_free()

func perform_attack():
	if not player or not player.has_method("take_damage"):
		return

	var lunge_dir = (player.global_position - global_position).normalized()
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + lunge_dir * 44, 0.12)
	tween.tween_property(self, "position", original_pos, 0.16)

	if global_position.distance_to(player.global_position) <= attack_range + 70.0:
		player.take_damage(attack_damage)
	_spawn_shockwave(attack_range + 90.0)

func _get_attack_disengage_mult() -> float:
	return 2.0

func _update_phase() -> void:
	var ratio := health / max_health
	if _phase == 0 and ratio <= 0.66:
		_phase = 1
		chase_speed += 35.0
		attack_damage += 5.0
		_summon_slimes(3)
	elif _phase == 1 and ratio <= 0.33:
		_phase = 2
		chase_speed += 45.0
		attack_damage += 7.0
		_special_cooldown = 0.4
		_summon_slimes(5)

func _summon_slimes(count: int) -> void:
	var holder := get_parent()
	if holder == null:
		return
	_play_summon_animation()
	for i in range(count):
		var slime = SLIME_SCENE.instantiate()
		var angle: float = (TAU / float(max(count, 1))) * float(i)
		slime.global_position = global_position + Vector2(cos(angle), sin(angle)) * randf_range(180.0, 280.0)
		holder.add_child(slime)
		var mission = get_tree().current_scene
		if mission and mission.has_method("_connect_enemy"):
			mission._connect_enemy(slime)

func _setup_boss_sprite() -> void:
	if has_node("BossSprite") and $BossSprite is Sprite2D:
		_boss_sprite = $BossSprite
	else:
		_boss_sprite = Sprite2D.new()
		_boss_sprite.name = "BossSprite"
		add_child(_boss_sprite)
		move_child(_boss_sprite, 0)

	_boss_sprite.texture = SUMMON_TEXTURE
	_boss_sprite.hframes = BOSS_FRAME_COUNT
	_boss_sprite.vframes = BOSS_ROW_COUNT
	_boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_boss_sprite.position = Vector2(0, -14)
	_boss_sprite.scale = Vector2(1.35, 1.35)
	_boss_sprite.z_index = 1
	_boss_sprite.modulate = Color(1.12, 1.08, 1.0, 1) if is_target else Color.WHITE
	_set_boss_frame(WALK_FIRST_FRAME, WALK_ROW)

func _play_summon_animation() -> void:
	_summon_visual_timer = SUMMON_ANIMATION_TIME
	_boss_animation_timer = 0.0
	_start_boss_animation(SUMMON_ROW, SUMMON_FIRST_FRAME)

func _update_boss_sprite(delta: float) -> void:
	if not _boss_sprite:
		return

	_update_boss_facing()

	if is_dead:
		_advance_boss_animation(delta, DEATH_FPS, false, DEATH_FIRST_FRAME, DEATH_LAST_FRAME)
		return

	if state == State.HURT:
		_start_boss_animation(HURT_DEATH_ROW, HURT_FRAME)
		return

	if _summon_visual_timer > 0.0:
		_summon_visual_timer -= delta
		_start_boss_animation(SUMMON_ROW, SUMMON_FIRST_FRAME)
		_advance_boss_animation(delta, SUMMON_FPS, true, SUMMON_FIRST_FRAME, SUMMON_LAST_FRAME)
		return

	if velocity.length_squared() > 1.0:
		_start_boss_animation(WALK_ROW, WALK_FIRST_FRAME)
		_advance_boss_animation(delta, WALK_FPS, true, WALK_FIRST_FRAME, WALK_LAST_FRAME)
	else:
		_start_boss_animation(WALK_ROW, WALK_FIRST_FRAME)

func _update_boss_facing() -> void:
	if not _boss_sprite:
		return

	var face_vector := velocity
	if state == State.ATTACK and player and is_instance_valid(player):
		face_vector = player.global_position - global_position
	if absf(face_vector.x) > 0.1:
		_boss_faces_left = face_vector.x < 0.0
		_apply_boss_flip()

func _start_boss_animation(row: int, frame_index: int = 0) -> void:
	if _boss_row == row:
		return
	_boss_row = row
	_boss_frame = frame_index
	_boss_animation_timer = 0.0
	_set_boss_frame(_boss_frame, _boss_row)

func _advance_boss_animation(delta: float, fps: float, loops: bool, first_frame: int, last_frame: int) -> void:
	_boss_animation_timer += delta
	var frame_time := 1.0 / fps
	while _boss_animation_timer >= frame_time:
		_boss_animation_timer -= frame_time
		if _boss_frame >= last_frame:
			if not loops:
				_set_boss_frame(last_frame, _boss_row)
				return
			_boss_frame = first_frame
		else:
			_boss_frame += 1
		_set_boss_frame(_boss_frame, _boss_row)

func _set_boss_frame(frame_index: int, row: int) -> void:
	_boss_frame = clampi(frame_index, 0, BOSS_FRAME_COUNT - 1)
	_boss_row = clampi(row, 0, BOSS_ROW_COUNT - 1)
	if _boss_sprite:
		_boss_sprite.frame_coords = Vector2i(_boss_frame, _boss_row)
		_apply_boss_flip()

func _apply_boss_flip() -> void:
	if not _boss_sprite:
		return
	var uses_reversed_hit_frame := _boss_row == HURT_DEATH_ROW and _boss_frame == HURT_FRAME
	_boss_sprite.flip_h = not _boss_faces_left if uses_reversed_hit_frame else _boss_faces_left

func _try_periodic_slime_spawn() -> void:
	var holder := get_parent()
	if holder == null:
		return
	var slime_cap := 4 + (_phase * 2)
	var available_slots: int = slime_cap - _active_slime_count(holder)
	if available_slots <= 0:
		return
	_summon_slimes(mini(available_slots, 1 + _phase))

func _active_slime_count(holder: Node) -> int:
	var count := 0
	for child in holder.get_children():
		if child and child.has_method("is_reactor_slime") and child.is_reactor_slime():
			count += 1
	return count

func _reactor_pulse() -> void:
	_spawn_shockwave(260.0 + (_phase * 70.0))
	if player and is_instance_valid(player):
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= 260.0 + (_phase * 70.0) and player.has_method("take_damage"):
			player.take_damage(10.0 + (_phase * 5.0))

func _spawn_shockwave(radius: float) -> void:
	var ring := Polygon2D.new()
	ring.name = "ReactorShockwave"
	ring.color = Color(0.55, 1.0, 0.16, 0.28)
	var points := PackedVector2Array()
	for i in range(32):
		var a: float = (TAU / 32.0) * float(i)
		points.append(Vector2(cos(a), sin(a)) * radius)
	ring.polygon = points
	ring.z_index = 25
	add_child(ring)

	var tween := create_tween().set_parallel(true)
	ring.scale = Vector2(0.25, 0.25)
	tween.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.35)
	tween.tween_property(ring, "modulate:a", 0.0, 0.45)
	tween.chain().tween_callback(ring.queue_free)
