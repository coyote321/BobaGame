extends "res://Scripts/EnemyBase.gd"
## Heavy spear enemy. Tougher and slower than grunts, but still melee-only.

func _ready():
	# ── Stat overrides ──
	max_health = 200.0
	speed = 40.0
	chase_speed = 55.0
	attack_damage = 25.0
	detection_range = 400.0
	attack_range = 105.0
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
	return 1.5

# ── Override: heavy spear jab ────────────────────────────────────────────
func perform_attack():
	if not player or not player.has_method("take_damage"):
		return

	player.take_damage(attack_damage)

	var jab_dir = (player.global_position - global_position).normalized()
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + jab_dir * 18, 0.08)
	tween.tween_property(self, "position", original_pos, 0.12)
