extends "res://Scripts/EnemyBase.gd"

const SLIME_SCENE: PackedScene = preload("res://Scenes/SlimeEnemy.tscn")

var _phase: int = 0
var _special_cooldown: float = 2.4
var _slime_spawn_cooldown: float = 4.0

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
	_body_size = Vector2(164, 164)
	_body_offset = Vector2(-82, -82)
	_patrol_extent = Vector2(240, 140)
	_idle_wait_range = Vector2(0.2, 0.8)
	_alert_icon_text = "!!!"
	_alert_font_size = 24
	_alert_offset = Vector2(-22, -118)
	_alert_blink_multiplier = 8.0
	_xp_reward_target = 500

	super._ready()

func setup_visuals():
	super.setup_visuals()
	if body_rect:
		body_rect.position = _body_offset
		body_rect.size = _body_size
		body_rect.color = Color(0.75, 0.95, 0.12, 1) if is_target else _body_color
	if health_bar:
		health_bar.position = Vector2(-95, -118)
		health_bar.size = Vector2(190, 12)
		health_bar.max_value = max_health
		health_bar.value = health

func _physics_process(delta):
	super._physics_process(delta)
	if is_dead:
		return
	_special_cooldown -= delta
	if player and is_instance_valid(player) and _special_cooldown <= 0.0:
		_reactor_pulse()
		_special_cooldown = randf_range(2.6, 4.2)
	_slime_spawn_cooldown -= delta
	if player and is_instance_valid(player) and _slime_spawn_cooldown <= 0.0:
		_try_periodic_slime_spawn()
		_slime_spawn_cooldown = randf_range(5.5, 8.0)

func take_damage(amount: float):
	super.take_damage(amount)
	if is_dead:
		return
	_update_phase()

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
	for i in range(count):
		var slime = SLIME_SCENE.instantiate()
		var angle: float = (TAU / float(max(count, 1))) * float(i)
		slime.global_position = global_position + Vector2(cos(angle), sin(angle)) * randf_range(180.0, 280.0)
		holder.add_child(slime)
		var mission = get_tree().current_scene
		if mission and mission.has_method("_connect_enemy"):
			mission._connect_enemy(slime)

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
