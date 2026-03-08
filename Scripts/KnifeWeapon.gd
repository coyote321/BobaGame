extends "res://Scripts/WeaponBase.gd"
## Kitchen Knife / melee weapon — swing attack with slash arc VFX.

func attack() -> void:
	if weapon_name == "":
		return
	var damage = _get_damage()
	var tuning := _get_tuning()
	var facing_dir := _get_facing_direction()
	var melee_anim_tuning := tuning.duplicate(true)
	melee_anim_tuning["kick_rotation"] = float(tuning.get("swing_rotation", 0.3))

	_play_shot_animation(facing_dir, melee_anim_tuning)
	_play_melee_swing(tuning)
	player.global_position += facing_dir * float(tuning.get("lunge_distance", 8.0))

	var melee_range = float(tuning.get("melee_range", 80.0))
	var burst_color: Color = tuning.get("burst_color", Color(1.0, 0.85, 0.96))
	_spawn_slash_arc(facing_dir, melee_range, burst_color, tuning)

	var enemies_node = player.get_parent().get_node_or_null("Enemies")
	if enemies_node:
		for enemy in enemies_node.get_children():
			if enemy.has_method("take_damage"):
				var dist = player.global_position.distance_to(enemy.global_position)
				if dist < melee_range:
					var dir_to_enemy = player.global_position.direction_to(enemy.global_position)
					if facing_dir.dot(dir_to_enemy) > float(tuning.get("melee_arc_dot", 0.5)):
						enemy.take_damage(damage)
						_spawn_melee_hit_effect(enemy.global_position, burst_color)

	player.fire_cooldown = _get_fire_rate()

# ---------------------------------------------------------------------------
#  Melee swing animation
# ---------------------------------------------------------------------------

func _play_melee_swing(tuning: Dictionary) -> void:
	var swing_duration = (float(tuning.get("kick_duration", 0.06)) + float(tuning.get("recover_duration", 0.09))) * 2.5
	var swing_angle = float(tuning.get("swing_rotation", 0.35))

	var start_rot = rotation
	var start_scale = scale

	var tween = player.create_tween()
	# Wind up (rotate back, scale up)
	tween.tween_property(self, "rotation", start_rot - swing_angle * 2.5, swing_duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", start_scale * 1.3, swing_duration * 0.15)
	# Slash forward (fast, big arc)
	tween.tween_property(self, "rotation", start_rot + swing_angle * 5.0, swing_duration * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Recover
	tween.tween_property(self, "rotation", start_rot, swing_duration * 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", start_scale, swing_duration * 0.4).set_trans(Tween.TRANS_SINE)

# ---------------------------------------------------------------------------
#  Slash arc VFX
# ---------------------------------------------------------------------------

func _spawn_slash_arc(direction: Vector2, radius: float, color: Color, tuning: Dictionary) -> void:
	var arc = Polygon2D.new()
	var arc_points := PackedVector2Array()
	var arc_dot = float(tuning.get("melee_arc_dot", 0.5))
	var half_angle = acos(clamp(arc_dot, -1.0, 1.0))
	var base_angle = direction.angle()
	var segments = 14

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = base_angle - half_angle + t * half_angle * 2.0
		arc_points.append(Vector2(cos(angle), sin(angle)) * radius)

	for i in range(segments, -1, -1):
		var t = float(i) / float(segments)
		var angle = base_angle - half_angle + t * half_angle * 2.0
		arc_points.append(Vector2(cos(angle), sin(angle)) * (radius * 0.3))

	arc.polygon = arc_points
	arc.color = Color(color.r, color.g, color.b, 0.45)
	arc.global_position = player.global_position
	arc.z_index = 105
	player.get_parent().add_child(arc)

	var tween = player.create_tween().set_parallel(true)
	tween.tween_property(arc, "modulate:a", 0.0, 0.18).from(1.0).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(arc, "scale", Vector2(1.15, 1.15), 0.18).from(Vector2(0.7, 0.7))
	tween.chain().tween_callback(arc.queue_free)

	var slash_particles = CPUParticles2D.new()
	slash_particles.emitting = true
	slash_particles.one_shot = true
	slash_particles.amount = 10
	slash_particles.lifetime = 0.2
	slash_particles.explosiveness = 0.9
	slash_particles.direction = Vector2(direction.x, direction.y)
	slash_particles.spread = rad_to_deg(half_angle)
	slash_particles.initial_velocity_min = 100.0
	slash_particles.initial_velocity_max = 200.0
	slash_particles.gravity = Vector2.ZERO
	slash_particles.damping_min = 80.0
	slash_particles.damping_max = 150.0
	slash_particles.scale_amount_min = 1.5
	slash_particles.scale_amount_max = 3.0

	var grad = Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
	grad.add_point(0.3, Color(color.r, color.g, color.b, 0.7))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	slash_particles.color_ramp = grad

	slash_particles.global_position = player.global_position + direction * 15.0
	slash_particles.z_index = 106
	player.get_parent().add_child(slash_particles)
	_auto_free_after(slash_particles, 0.5)

# ---------------------------------------------------------------------------
#  Hit effect
# ---------------------------------------------------------------------------

func _spawn_melee_hit_effect(pos: Vector2, color: Color) -> void:
	var hit = CPUParticles2D.new()
	hit.emitting = true
	hit.one_shot = true
	hit.amount = 10
	hit.lifetime = 0.22
	hit.explosiveness = 0.95
	hit.spread = 180.0
	hit.initial_velocity_min = 40.0
	hit.initial_velocity_max = 120.0
	hit.gravity = Vector2(0, 80)
	hit.damping_min = 30.0
	hit.damping_max = 80.0
	hit.scale_amount_min = 2.0
	hit.scale_amount_max = 4.0

	var grad = Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.2, color)
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	hit.color_ramp = grad

	hit.global_position = pos
	hit.z_index = 110
	player.get_parent().add_child(hit)
	_auto_free_after(hit, 0.5)
