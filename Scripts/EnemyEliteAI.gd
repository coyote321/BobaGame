extends "res://Scripts/EnemyBase.gd"
## Elite melee enemy (red) — faster, stronger, and more aggressive than the
## standard grunt. Used in Level 2+ missions.

func _ready():
	# ── Stat overrides ──
	max_health = 120.0
	speed = 220.0
	chase_speed = 340.0
	attack_damage = 12.0
	detection_range = 320.0
	attack_range = 90.0
	_body_color = Color(0.85, 0.18, 0.18, 1)
	_body_size = Vector2(46, 46)
	_body_offset = Vector2(-23, -23)
	_patrol_extent = Vector2(140, 70)
	_idle_wait_range = Vector2(0.5, 1.5)
	_alert_icon_text = "⚠"
	_alert_font_size = 22
	_alert_offset = Vector2(-10, -65)
	_alert_blink_multiplier = 6.0
	_xp_reward = 50
	_xp_reward_target = 200
	_money_reward = 20

	# Call the shared base _ready
	super._ready()

# ── Override: double-lunge attack for extra aggression ───────────────────
func perform_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

		var lunge_dir = (player.global_position - global_position).normalized()
		var original_pos = position
		var tween = create_tween()
		tween.tween_property(self, "position", original_pos + lunge_dir * 30, 0.06)
		tween.tween_property(self, "position", original_pos + lunge_dir * 10, 0.04)
		tween.tween_property(self, "position", original_pos + lunge_dir * 25, 0.05)
		tween.tween_property(self, "position", original_pos, 0.07)
