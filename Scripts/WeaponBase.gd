extends Node2D


var player: CharacterBody2D = null
var weapon_name: String = ""


var _weapon_muzzle_flash: Polygon2D
var _muzzle_flash_inner: Polygon2D
var _shot_anim_tween: Tween


static var _muzzle_burst_scale_curve: Curve
static var _trail_scale_tex: CurveTexture
static var _shared_fx_built: bool = false

static func _ensure_shared_fx() -> void:
	if _shared_fx_built:
		return
	_shared_fx_built = true

	_muzzle_burst_scale_curve = Curve.new()
	_muzzle_burst_scale_curve.add_point(Vector2(0.0, 1.0))
	_muzzle_burst_scale_curve.add_point(Vector2(0.3, 0.7))
	_muzzle_burst_scale_curve.add_point(Vector2(1.0, 0.0))

	var trail_curve := Curve.new()
	trail_curve.add_point(Vector2(0.0, 1.0))
	trail_curve.add_point(Vector2(0.5, 0.6))
	trail_curve.add_point(Vector2(1.0, 0.0))
	_trail_scale_tex = CurveTexture.new()
	_trail_scale_tex.curve = trail_curve

const DEFAULT_WEAPON_TUNING := {
	"projectile_speed": 800.0,
	"projectile_size": 10.0,
	"projectile_lifetime": 2.4,
	"spread_deg": 0.0,
	"projectile_color": Color(0.85, 0.2, 0.15),
	"recoil_distance": 5.0,
	"kick_rotation": 0.06,
	"kick_duration": 0.05,
	"recover_duration": 0.08,
	"flash_scale": Vector2(16, 8),
	"flash_color": Color(1.0, 0.9, 0.7, 0.9),
	"flash_duration": 0.05,
	"camera_shake": 2.0,
	"melee_range": 80.0,
	"melee_arc_dot": 0.5,
	"lunge_distance": 8.0,
	"swing_rotation": 0.3,
	"flame_speed": 300.0,
	"flame_lifetime": 0.4,
	"flame_spread_deg": 15.0
}

func init_weapon(p_player: CharacterBody2D, p_weapon_name: String) -> void:
	player = p_player
	weapon_name = p_weapon_name
	_ensure_shared_fx()
	_ensure_weapon_vfx_nodes()


func attack() -> void:
	pass


func _get_tuning() -> Dictionary:
	var tuning := DEFAULT_WEAPON_TUNING.duplicate(true)
	var weapon_data = GameManager.weapons.get(weapon_name, {})
	var weapon_tuning = weapon_data.get("tuning", {})
	for key in weapon_tuning:
		tuning[key] = weapon_tuning[key]
	return tuning

func _get_fire_rate() -> float:
	return float(GameManager.weapons.get(weapon_name, {}).get("fire_rate", 0.5))

func _get_damage() -> float:
	return GameManager.get_weapon_damage(weapon_name)


func _get_facing_direction() -> Vector2:
	if player and player.has_node("Visuals"):
		return Vector2.RIGHT.rotated(player.get_node("Visuals").rotation)
	return Vector2.RIGHT

func _get_muzzle_global_position() -> Vector2:
	var muzzle = get_node_or_null("Muzzle")
	if muzzle:
		return muzzle.global_position

	if player:
		return player.global_position + _get_facing_direction() * 34.0
	return global_position

func _get_muzzle_local_position() -> Vector2:
	var muzzle = get_node_or_null("Muzzle")
	if muzzle:
		return position + muzzle.position
	return Vector2(34, 0)


func _ensure_weapon_vfx_nodes() -> void:
	if _weapon_muzzle_flash and is_instance_valid(_weapon_muzzle_flash):
		return

	_weapon_muzzle_flash = Polygon2D.new()
	_weapon_muzzle_flash.name = "MuzzleFlash"
	_weapon_muzzle_flash.color = Color(1.0, 0.9, 0.7, 0.0)
	_weapon_muzzle_flash.polygon = _make_star_polygon(22.0, 8.0, 6)
	_weapon_muzzle_flash.position = _get_muzzle_local_position()
	_weapon_muzzle_flash.z_index = 120
	var visuals = player.get_node_or_null("Visuals") if player else null
	if visuals:
		visuals.add_child(_weapon_muzzle_flash)
	else:
		add_child(_weapon_muzzle_flash)

	_muzzle_flash_inner = Polygon2D.new()
	_muzzle_flash_inner.name = "MuzzleFlashInner"
	_muzzle_flash_inner.color = Color(1.0, 1.0, 1.0, 0.0)
	_muzzle_flash_inner.polygon = _make_star_polygon(12.0, 5.0, 6)
	_muzzle_flash_inner.z_index = 121
	_weapon_muzzle_flash.add_child(_muzzle_flash_inner)

func _make_star_polygon(outer_r: float, inner_r: float, points: int) -> PackedVector2Array:
	var verts := PackedVector2Array()
	for i in range(points * 2):
		var angle = TAU * (float(i) / float(points * 2)) - PI / 2.0
		var r = outer_r if i % 2 == 0 else inner_r
		verts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return verts


func _play_shot_animation(direction: Vector2, tuning: Dictionary) -> void:
	if not player or not player.has_node("Visuals"):
		return

	if _shot_anim_tween and _shot_anim_tween.is_running():
		_shot_anim_tween.kill()

	var kick_distance = float(tuning.get("recoil_distance", 5.0))
	var kick_rotation = float(tuning.get("kick_rotation", 0.06))
	var kick_duration = float(tuning.get("kick_duration", 0.05))
	var recover_duration = float(tuning.get("recover_duration", 0.08))
	var flash_duration = float(tuning.get("flash_duration", 0.05))

	var visuals: Node2D = player.get_node("Visuals")
	var start_pos := visuals.position
	var start_rot := visuals.rotation
	var kick_sign = -1.0 if randf() > 0.5 else 1.0

	_shot_anim_tween = player.create_tween().set_parallel(false).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shot_anim_tween.tween_property(visuals, "position", start_pos - direction * kick_distance, kick_duration)
	_shot_anim_tween.parallel().tween_property(visuals, "rotation", start_rot + (kick_rotation * kick_sign), kick_duration)

	var overshoot_pos = start_pos + direction * (kick_distance * 0.15)
	_shot_anim_tween.tween_property(visuals, "position", overshoot_pos, recover_duration * 0.6)
	_shot_anim_tween.parallel().tween_property(visuals, "rotation", start_rot - (kick_rotation * kick_sign * 0.15), recover_duration * 0.6)
	_shot_anim_tween.tween_property(visuals, "position", start_pos, recover_duration * 0.4).set_trans(Tween.TRANS_SINE)
	_shot_anim_tween.parallel().tween_property(visuals, "rotation", start_rot, recover_duration * 0.4).set_trans(Tween.TRANS_SINE)

	var flash_color: Color = tuning.get("flash_color", Color(1.0, 0.9, 0.7, 0.9))
	var flash_size: Vector2 = tuning.get("flash_scale", Vector2(16, 8))

	if _weapon_muzzle_flash and is_instance_valid(_weapon_muzzle_flash):
		var random_rot = randf_range(-0.3, 0.3)
		_weapon_muzzle_flash.color = flash_color
		_weapon_muzzle_flash.polygon = _make_star_polygon(flash_size.x, flash_size.y * 0.6, 5 + randi() % 3)
		_weapon_muzzle_flash.position = _get_muzzle_local_position()
		_weapon_muzzle_flash.rotation = random_rot
		_weapon_muzzle_flash.scale = Vector2(0.6, 0.6)
		_weapon_muzzle_flash.modulate.a = 1.0

		if _muzzle_flash_inner and is_instance_valid(_muzzle_flash_inner):
			_muzzle_flash_inner.color = Color(1.0, 1.0, 1.0, 0.95)
			_muzzle_flash_inner.modulate.a = 1.0

		var flash_tween = player.create_tween().set_parallel(true)
		flash_tween.tween_property(_weapon_muzzle_flash, "scale", Vector2(1.3, 1.3), flash_duration * 0.3).from(Vector2(0.4, 0.4))
		flash_tween.tween_property(_weapon_muzzle_flash, "modulate:a", 0.0, flash_duration).from(1.0).set_trans(Tween.TRANS_EXPO)
		if _muzzle_flash_inner and is_instance_valid(_muzzle_flash_inner):
			flash_tween.tween_property(_muzzle_flash_inner, "modulate:a", 0.0, flash_duration * 0.7).from(1.0)

	_spawn_muzzle_burst_particles(direction, tuning)
	_apply_shot_camera_shake(float(tuning.get("camera_shake", 2.0)))


func _spawn_muzzle_burst_particles(direction: Vector2, tuning: Dictionary) -> void:
	var burst_color: Color = tuning.get("burst_color", tuning.get("flash_color", Color(1.0, 0.9, 0.7)))
	var amount: int = mini(int(tuning.get("sparkle_amount", 18)), 12)

	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.25
	particles.explosiveness = 0.95
	particles.randomness = 0.4
	particles.direction = Vector2(direction.x, direction.y)
	particles.spread = 35.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 60)
	particles.damping_min = 60.0
	particles.damping_max = 120.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5

	var grad = Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.2, burst_color)
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(burst_color.r, burst_color.g, burst_color.b, 0.0))
	particles.color_ramp = grad
	particles.scale_amount_curve = _muzzle_burst_scale_curve

	particles.global_position = _get_muzzle_global_position()
	particles.z_index = 115
	player.get_parent().add_child(particles)

	_auto_free_after(particles, 0.6)

func _spawn_shell_casing(direction: Vector2, _tuning: Dictionary) -> void:
	var shell = CPUParticles2D.new()
	shell.emitting = true
	shell.one_shot = true
	shell.amount = 1
	shell.lifetime = 0.45
	shell.explosiveness = 1.0

	var eject_dir = direction.rotated(PI / 2.0 * (1.0 if randf() > 0.5 else -1.0))
	shell.direction = Vector2(eject_dir.x, eject_dir.y)
	shell.spread = 15.0
	shell.initial_velocity_min = 50.0
	shell.initial_velocity_max = 90.0
	shell.gravity = Vector2(0, 350)
	shell.scale_amount_min = 2.0
	shell.scale_amount_max = 2.5
	shell.angular_velocity_min = -720.0
	shell.angular_velocity_max = 720.0
	shell.color = Color(0.85, 0.72, 0.35)

	var fade = Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(0.85, 0.72, 0.35, 1.0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(0.65, 0.52, 0.25, 0.0))
	shell.color_ramp = fade

	shell.global_position = _get_muzzle_global_position()
	shell.z_index = 90
	player.get_parent().add_child(shell)
	_auto_free_after(shell, 0.8)

func _apply_shot_camera_shake(intensity: float) -> void:
	if intensity <= 0.0 or not player or not player.has_node("Camera2D"):
		return
	var cam: Camera2D = player.get_node("Camera2D")
	var tween = player.create_tween()
	var shake1 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var shake2 = Vector2(randf_range(-intensity * 0.5, intensity * 0.5), randf_range(-intensity * 0.5, intensity * 0.5))
	tween.tween_property(cam, "offset", shake1, 0.025)
	tween.tween_property(cam, "offset", shake2 * -0.6, 0.03)
	tween.tween_property(cam, "offset", shake1 * 0.2, 0.025)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.04).set_trans(Tween.TRANS_SINE)


func _create_projectile_trail(color: Color, size: float) -> GPUParticles2D:
	var trail = GPUParticles2D.new()
	trail.name = "Trail"
	trail.emitting = true
	trail.amount = 8
	trail.lifetime = 0.2
	trail.speed_scale = 1.0
	trail.explosiveness = 0.0
	trail.randomness = 0.2
	trail.z_index = -1

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 5.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = max(2.0, size * 0.3)
	mat.scale_max = max(3.0, size * 0.5)
	mat.damping_min = 10.0
	mat.damping_max = 20.0

	var grad = Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(color.r, color.g, color.b, 0.7))
	grad.add_point(0.4, Color(color.r, color.g, color.b, 0.4))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex
	mat.scale_curve = _trail_scale_tex

	trail.process_material = mat
	return trail


func _auto_free_after(node: Node, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(node):
		node.queue_free()
