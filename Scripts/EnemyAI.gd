extends "res://Scripts/EnemyBase.gd"
## Standard melee grunt enemy (blue). Overrides only the stats that differ
## from EnemyBase defaults.

func _ready():
	# ── Stat overrides ──
	max_health = 60.0
	speed = 180.0
	chase_speed = 280.0
	attack_damage = 5.0
	detection_range = 250.0
	attack_range = 80.0
	_body_color = Color(0.2, 0.5, 0.9, 1)
	_body_size = Vector2(50, 50)
	_body_offset = Vector2(-25, -25)
	_patrol_extent = Vector2(100, 50)
	_idle_wait_range = Vector2(1.0, 3.0)
	_alert_icon_text = "❗"
	_alert_font_size = 24
	_alert_offset = Vector2(-10, -70)
	_alert_blink_multiplier = 4.0
	_xp_reward = 25
	_xp_reward_target = 100
	_money_reward = 10

	# Call the shared base _ready
	super._ready()
