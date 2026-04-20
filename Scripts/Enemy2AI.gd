extends "res://Scripts/EnemyBase.gd"
## Ranged tank enemy (purple). Shoots projectiles instead of lunging.

const PROJECTILE_SCRIPT = preload("res://Scripts/EnemyProjectile.gd")

func _ready():
	# ── Stat overrides ──
	max_health = 200.0
	speed = 40.0
	chase_speed = 55.0
	attack_damage = 25.0
	detection_range = 400.0
	attack_range = 300.0
	_body_color = Color(0.6, 0.2, 0.7, 1)
	_body_size = Vector2(60, 60)
	_body_offset = Vector2(-30, -30)
	_patrol_extent = Vector2(150, 100)
	_idle_wait_range = Vector2(0.5, 1.5)
	_alert_icon_text = "!"
	_alert_font_size = 28
	_alert_offset = Vector2(-5, -80)
	_alert_blink_multiplier = 6.0
	_xp_reward = 40
	_xp_reward_target = 150
	_money_reward = 15

	# Call the shared base _ready
	super._ready()

# ── Override: different disengage threshold ──────────────────────────────
func _get_attack_disengage_mult() -> float:
	return 1.2

# ── Override: slowly approach during attack ──────────────────────────────
func _attack_movement(_delta: float) -> void:
	if player and is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed * 0.5
		move_and_slide()

# ── Override: ranged projectile attack ───────────────────────────────────
func perform_attack():
	if not player:
		return

	var projectile = Area2D.new()
	projectile.name = "EnemyProj_" + str(randi())

	projectile.collision_layer = 16
	projectile.collision_mask = 1 | 2

	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.direction = (player.global_position - global_position).normalized()
	projectile.damage = attack_damage
	projectile.speed = 350.0

	var p_rect = ColorRect.new()
	p_rect.color = Color(0.7, 0.15, 0.1)
	p_rect.size = Vector2(12, 12)
	p_rect.position = Vector2(-6, -6)
	projectile.add_child(p_rect)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	projectile.add_child(shape)

	projectile.global_position = global_position

	get_tree().current_scene.add_child(projectile)
	projectile.body_entered.connect(projectile._on_body_entered)
