extends CharacterBody2D

var speed = 200
var sprint_speed = 350
var crouch_speed = 100
var aim_speed_penalty = 0.5
var health = 100

var is_crouching = false
var is_aiming = false

# Reference to external HUD
var hud_node = null

# Weapon State
var current_weapon_idx = 1 # 1 = Main, 2 = Melee

var fire_cooldown = 0.0
var ability_cooldown = 0.0

@export var projectile_scene: PackedScene

const BOBA_PROJECTILE_SCRIPT := preload("res://Scripts/BobaProjectile.gd")
const FLAME_PROJECTILE_SCRIPT := preload("res://Scripts/FlameProjectile.gd")

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

var _weapon_muzzle_flash: Polygon2D
var _shot_anim_tween: Tween
var _muzzle_flash_inner: Polygon2D
var _current_weapon_node: Node2D = null

func _ready():
	health = GameManager.max_health
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	await get_tree().process_frame
	hud_node = get_tree().current_scene.find_child("HUD", true, false)
	_ensure_weapon_vfx_nodes()
	_update_weapon_scene()

func _physics_process(delta):
	if fire_cooldown > 0:
		fire_cooldown -= delta
	if ability_cooldown > 0:
		ability_cooldown -= delta
	
	update_trail()
	
	if has_node("Visuals"):
		$Visuals.look_at(get_global_mouse_position())
	
	handle_state_inputs()
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed = speed
	
	if is_crouching:
		current_speed = crouch_speed
	elif Input.is_action_pressed("sprint") and not is_aiming:
		current_speed = sprint_speed
		
	if is_aiming:
		current_speed *= aim_speed_penalty
		
	velocity = direction * current_speed
	
	# Animations
	if velocity.length() > 0:
		if has_node("AnimationPlayer"):
			$AnimationPlayer.play("walk")
	else:
		if has_node("AnimationPlayer"):
			$AnimationPlayer.stop()
			if has_node("Visuals"):
				$Visuals.scale = Vector2(1, 1) if not is_crouching else Vector2(0.8, 0.8)
			
	move_and_slide()
	
	if GameManager.current_phase == "MISSION":
		# Attack (left click). Using the "aim" mouse button to steady aim only.
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if fire_cooldown <= 0.0:
				attack()
		
		# Ability
		if Input.is_action_just_pressed("ability"):
			if ability_cooldown <= 0.0:
				use_ability()

func update_trail():
	if has_node("Trail"):
		var trail = $Trail
		trail.add_point(global_position)
		if trail.points.size() > 15:
			trail.remove_point(0)

func handle_state_inputs():
	# Crouch
	if Input.is_action_pressed("crouch"):
		is_crouching = true
		if has_node("Visuals"):
			$Visuals.scale = Vector2(0.8, 0.8)
	else:
		is_crouching = false
		if has_node("Visuals") and not (has_node("AnimationPlayer") and $AnimationPlayer.is_playing()):
			$Visuals.scale = Vector2(1, 1)

	# Aim
	is_aiming = Input.is_action_pressed("aim")

	# Weapon Switching
	if Input.is_action_just_pressed("weapon_1"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("weapon_2"):
		switch_weapon(2)
	elif Input.is_action_just_pressed("weapon_3"):
		switch_weapon(3)

func is_crouching_state() -> bool:
	return is_crouching

func switch_weapon(idx):
	current_weapon_idx = idx
	var weapon_name = ""
	if idx == 1:
		weapon_name = GameManager.equipped_main
	elif idx == 2:
		weapon_name = GameManager.equipped_melee
	elif idx == 3:
		weapon_name = GameManager.equipped_special
	
	# Update HUD
	if hud_node and hud_node.has_method("update_weapon"):
		hud_node.update_weapon(idx, weapon_name)
	_update_weapon_scene()

func _update_weapon_scene() -> void:
	if not has_node("Visuals"):
		return
	# Remove old weapon scene
	if _current_weapon_node and is_instance_valid(_current_weapon_node):
		_current_weapon_node.queue_free()
		_current_weapon_node = null
	# No weapons in shop phase
	if GameManager.current_phase == "SHOP":
		return
	# Get weapon scene path
	var weapon_name = _get_current_weapon_name()
	var weapon_data = GameManager.weapons.get(weapon_name, {})
	var scene_path = weapon_data.get("weapon_scene", "")
	if scene_path == "":
		return
	var scene = load(scene_path)
	if scene:
		_current_weapon_node = scene.instantiate()
		var offset = weapon_data.get("hold_offset", Vector2(32, 8))
		_current_weapon_node.position = offset
		$Visuals.add_child(_current_weapon_node)

func _get_muzzle_global_position() -> Vector2:
	if _current_weapon_node and is_instance_valid(_current_weapon_node):
		var muzzle = _current_weapon_node.get_node_or_null("Muzzle")
		if muzzle:
			return muzzle.global_position
	# Fallback: offset from player center
	return global_position + _get_facing_direction() * 34.0

func _get_muzzle_local_position() -> Vector2:
	if _current_weapon_node and is_instance_valid(_current_weapon_node):
		var muzzle = _current_weapon_node.get_node_or_null("Muzzle")
		if muzzle:
			return _current_weapon_node.position + muzzle.position
	return Vector2(34, 0)

func _ensure_weapon_vfx_nodes() -> void:
	if not has_node("Visuals"):
		return
	if _weapon_muzzle_flash and is_instance_valid(_weapon_muzzle_flash):
		return

	_weapon_muzzle_flash = Polygon2D.new()
	_weapon_muzzle_flash.name = "MuzzleFlash"
	_weapon_muzzle_flash.color = Color(1.0, 0.9, 0.7, 0.0)
	_weapon_muzzle_flash.polygon = _make_star_polygon(22.0, 8.0, 6)
	_weapon_muzzle_flash.position = _get_muzzle_local_position()
	_weapon_muzzle_flash.z_index = 120
	$Visuals.add_child(_weapon_muzzle_flash)

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

func _get_weapon_tuning(weapon_name: String) -> Dictionary:
	var tuning := DEFAULT_WEAPON_TUNING.duplicate(true)
	var weapon_data = GameManager.weapons.get(weapon_name, {})
	var weapon_tuning = weapon_data.get("tuning", {})
	for key in weapon_tuning:
		tuning[key] = weapon_tuning[key]
	return tuning

func _get_facing_direction() -> Vector2:
	if has_node("Visuals"):
		return Vector2.RIGHT.rotated($Visuals.rotation)
	return Vector2.RIGHT

func _play_shot_animation(direction: Vector2, tuning: Dictionary) -> void:
	if not has_node("Visuals"):
		return

	if _shot_anim_tween and _shot_anim_tween.is_running():
		_shot_anim_tween.kill()

	var kick_distance = float(tuning.get("recoil_distance", 5.0))
	var kick_rotation = float(tuning.get("kick_rotation", 0.06))
	var kick_duration = float(tuning.get("kick_duration", 0.05))
	var recover_duration = float(tuning.get("recover_duration", 0.08))
	var flash_duration = float(tuning.get("flash_duration", 0.05))

	var visuals: Node2D = $Visuals
	var start_pos := visuals.position
	var start_rot := visuals.rotation
	var kick_sign = -1.0 if randf() > 0.5 else 1.0

	_shot_anim_tween = create_tween().set_parallel(false).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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

		var flash_tween = create_tween().set_parallel(true)
		flash_tween.tween_property(_weapon_muzzle_flash, "scale", Vector2(1.3, 1.3), flash_duration * 0.3).from(Vector2(0.4, 0.4))
		flash_tween.tween_property(_weapon_muzzle_flash, "modulate:a", 0.0, flash_duration).from(1.0).set_trans(Tween.TRANS_EXPO)
		if _muzzle_flash_inner and is_instance_valid(_muzzle_flash_inner):
			flash_tween.tween_property(_muzzle_flash_inner, "modulate:a", 0.0, flash_duration * 0.7).from(1.0)

	_spawn_muzzle_burst_particles(direction, tuning)
	_apply_shot_camera_shake(float(tuning.get("camera_shake", 2.0)))

func _spawn_muzzle_burst_particles(direction: Vector2, tuning: Dictionary) -> void:
	var burst_color: Color = tuning.get("burst_color", tuning.get("flash_color", Color(1.0, 0.9, 0.7)))
	var amount: int = int(tuning.get("sparkle_amount", 18))

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

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.3, 0.7))
	scale_curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = scale_curve

	particles.global_position = _get_muzzle_global_position()
	particles.z_index = 115
	get_parent().add_child(particles)

	_auto_free_after(particles, 0.6)

func _spawn_shell_casing(direction: Vector2, tuning: Dictionary) -> void:
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
	get_parent().add_child(shell)
	_auto_free_after(shell, 0.8)

func _apply_shot_camera_shake(intensity: float) -> void:
	if intensity <= 0.0 or not has_node("Camera2D"):
		return
	var cam: Camera2D = $Camera2D
	var tween = create_tween()
	var shake1 = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	var shake2 = Vector2(randf_range(-intensity * 0.5, intensity * 0.5), randf_range(-intensity * 0.5, intensity * 0.5))
	tween.tween_property(cam, "offset", shake1, 0.025)
	tween.tween_property(cam, "offset", shake2 * -0.6, 0.03)
	tween.tween_property(cam, "offset", shake1 * 0.2, 0.025)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.04).set_trans(Tween.TRANS_SINE)

func _auto_free_after(node: Node, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(node):
		node.queue_free()

func use_ability():
	print("Ability Used! (Dash)")
	ability_cooldown = 2.0
	
	var dash_dir = velocity.normalized()
	if dash_dir == Vector2.ZERO:
		if has_node("Visuals"):
			dash_dir = Vector2.RIGHT.rotated($Visuals.rotation)
		else:
			dash_dir = Vector2.RIGHT
	
	# Dash with a minimal safety clamp; avoid clipping too far through walls.
	global_position += dash_dir * 120.0
	
	# Visual effect
	modulate = Color(0.5, 0.8, 1, 0.7)
	var t := get_tree().create_timer(0.2)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func _get_current_weapon_name() -> String:
	match current_weapon_idx:
		1: return GameManager.equipped_main
		2: return GameManager.equipped_melee
		3: return GameManager.equipped_special
	return ""

func _get_current_weapon_type() -> String:
	var wname = _get_current_weapon_name()
	if wname == "":
		return ""
	return GameManager.weapons.get(wname, {}).get("type", "ranged")

func attack():
	var wtype = _get_current_weapon_type()
	if wtype == "melee":
		melee_attack()
	else:
		shoot()

func melee_attack():
	var weapon_name = _get_current_weapon_name()
	if weapon_name == "":
		return
	var damage = GameManager.get_weapon_damage(weapon_name)
	var tuning := _get_weapon_tuning(weapon_name)
	var facing_dir := _get_facing_direction()
	var melee_anim_tuning := tuning.duplicate(true)
	melee_anim_tuning["kick_rotation"] = float(tuning.get("swing_rotation", 0.3))

	_play_shot_animation(facing_dir, melee_anim_tuning)
	_play_melee_swing(tuning)
	global_position += facing_dir * float(tuning.get("lunge_distance", 8.0))

	var melee_range = float(tuning.get("melee_range", 80.0))
	var burst_color: Color = tuning.get("burst_color", Color(1.0, 0.85, 0.96))
	_spawn_slash_arc(facing_dir, melee_range, burst_color, tuning)

	var enemies_node = get_parent().get_node_or_null("Enemies")
	if enemies_node:
		var attack_origin = _get_muzzle_global_position()
		for enemy in enemies_node.get_children():
			if enemy.has_method("take_damage"):
				var dist = global_position.distance_to(enemy.global_position)
				if dist < melee_range:
					var dir_to_enemy = global_position.direction_to(enemy.global_position)
					if facing_dir.dot(dir_to_enemy) > float(tuning.get("melee_arc_dot", 0.5)):
						enemy.take_damage(damage)
						_spawn_melee_hit_effect(enemy.global_position, burst_color)

	fire_cooldown = GameManager.weapons.get(weapon_name, {}).get("fire_rate", 0.5)

func _play_melee_swing(tuning: Dictionary) -> void:
	if not _current_weapon_node or not is_instance_valid(_current_weapon_node):
		return
	var swing_duration = (float(tuning.get("kick_duration", 0.06)) + float(tuning.get("recover_duration", 0.09))) * 2.5
	var swing_angle = float(tuning.get("swing_rotation", 0.35))

	var weapon = _current_weapon_node
	var start_rot = weapon.rotation
	var start_scale = weapon.scale

	var tween = create_tween()
	# Wind up (rotate back, scale up)
	tween.tween_property(weapon, "rotation", start_rot - swing_angle * 2.5, swing_duration * 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(weapon, "scale", start_scale * 1.3, swing_duration * 0.15)
	# Slash forward (fast, big arc)
	tween.tween_property(weapon, "rotation", start_rot + swing_angle * 5.0, swing_duration * 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Recover
	tween.tween_property(weapon, "rotation", start_rot, swing_duration * 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(weapon, "scale", start_scale, swing_duration * 0.4).set_trans(Tween.TRANS_SINE)

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
	arc.global_position = global_position
	arc.z_index = 105
	get_parent().add_child(arc)

	var tween = create_tween().set_parallel(true)
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

	slash_particles.global_position = global_position + direction * 15.0
	slash_particles.z_index = 106
	get_parent().add_child(slash_particles)
	_auto_free_after(slash_particles, 0.5)

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
	get_parent().add_child(hit)
	_auto_free_after(hit, 0.5)

func shoot():
	var weapon_name = _get_current_weapon_name()
	if weapon_name == "":
		return

	var weapon_data = GameManager.weapons.get(weapon_name, {})
	var tuning := _get_weapon_tuning(weapon_name)
	fire_cooldown = float(weapon_data.get("fire_rate", 0.5))
	var direction = _get_facing_direction()
	var spread_deg = float(tuning.get("spread_deg", 0.0))
	if spread_deg > 0.0:
		direction = direction.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))

	if weapon_name == "Flamethrower":
		_shoot_flame(tuning)
		_play_shot_animation(_get_facing_direction(), tuning)
		return

	var damage = GameManager.get_weapon_damage(weapon_name)
	_play_shot_animation(_get_facing_direction(), tuning)
	_spawn_shell_casing(direction, tuning)

	var cluster_count = int(tuning.get("cluster_count", 1))
	if cluster_count > 1:
		var cluster_spread = float(tuning.get("cluster_spread_deg", 8.0))
		for i in range(cluster_count):
			var offset_angle = deg_to_rad(randf_range(-cluster_spread, cluster_spread))
			var proj_dir = direction.rotated(offset_angle)
			var speed_variance = randf_range(0.85, 1.1)
			var size_variance = randf_range(0.7, 1.0)
			_spawn_boba_projectile(proj_dir, damage, tuning, speed_variance, size_variance)
		return

	_spawn_boba_projectile(direction, damage, tuning)

func _spawn_boba_projectile(direction: Vector2, damage: float, tuning: Dictionary, speed_mult: float = 1.0, size_mult: float = 1.0) -> void:
	var projectile = Area2D.new()
	projectile.name = "Proj_" + str(randi())
	projectile.collision_layer = 8
	projectile.collision_mask = 1 | 4
	projectile.z_index = 100

	projectile.set_script(BOBA_PROJECTILE_SCRIPT)

	projectile.direction = direction
	projectile.damage = damage
	projectile.speed = float(tuning.get("projectile_speed", 800.0)) * speed_mult
	projectile.lifetime = float(tuning.get("projectile_lifetime", 2.4))
	projectile.poison_tick_damage = float(tuning.get("poison_tick_damage", 0.0))
	projectile.poison_ticks = int(tuning.get("poison_ticks", 0))
	projectile.poison_interval = float(tuning.get("poison_interval", 1.0))

	var projectile_size = float(tuning.get("projectile_size", 10.0)) * size_mult
	var projectile_color: Color = tuning.get("projectile_color", Color(0.85, 0.2, 0.15))

	var bubble = Polygon2D.new()
	bubble.name = "Bubble"
	bubble.color = projectile_color
	var points := PackedVector2Array()
	for i in range(12):
		var a = TAU * (float(i) / 12.0)
		points.append(Vector2(cos(a), sin(a)) * (projectile_size * 0.52))
	bubble.polygon = points
	projectile.add_child(bubble)

	var highlight = Polygon2D.new()
	highlight.name = "Highlight"
	highlight.color = Color(1.0, 1.0, 1.0, 0.5)
	var hl_points := PackedVector2Array()
	for i in range(8):
		var a = TAU * (float(i) / 8.0)
		hl_points.append(Vector2(cos(a), sin(a)) * (projectile_size * 0.28) + Vector2(-projectile_size * 0.12, -projectile_size * 0.12))
	highlight.polygon = hl_points
	projectile.add_child(highlight)

	var sparkle = Polygon2D.new()
	sparkle.color = Color(1.0, 1.0, 1.0, 0.75)
	sparkle.polygon = PackedVector2Array([
		Vector2(-projectile_size * 0.12, -projectile_size * 0.28),
		Vector2(projectile_size * 0.06, -projectile_size * 0.34),
		Vector2(projectile_size * 0.24, -projectile_size * 0.18),
		Vector2(projectile_size * 0.02, -projectile_size * 0.10)
	])
	projectile.add_child(sparkle)

	var trail = _create_projectile_trail(projectile_color, projectile_size)
	projectile.add_child(trail)

	var glow = PointLight2D.new()
	glow.color = projectile_color
	glow.energy = 0.6
	glow.texture_scale = 0.15 + (projectile_size / 60.0)
	var light_tex = GradientTexture2D.new()
	light_tex.gradient = Gradient.new()
	light_tex.gradient.set_color(0, Color.WHITE)
	light_tex.gradient.set_color(1, Color.TRANSPARENT)
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 64
	light_tex.height = 64
	glow.texture = light_tex
	projectile.add_child(glow)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = max(5.0, projectile_size * 0.65)
	shape.shape = circle
	projectile.add_child(shape)

	projectile.global_position = _get_muzzle_global_position()

	get_parent().add_child(projectile)
	projectile.body_entered.connect(projectile._on_body_entered)
	projectile.start_lifetime()

func _create_projectile_trail(color: Color, size: float) -> GPUParticles2D:
	var trail = GPUParticles2D.new()
	trail.name = "Trail"
	trail.emitting = true
	trail.amount = 16
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

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex = CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex

	trail.process_material = mat
	return trail

func _shoot_flame(tuning: Dictionary) -> void:
	var damage = GameManager.get_weapon_damage("Flamethrower")
	var base_dir = Vector2.RIGHT
	if has_node("Visuals"):
		base_dir = Vector2.RIGHT.rotated($Visuals.rotation)

	var spread = deg_to_rad(randf_range(-float(tuning.get("flame_spread_deg", 15.0)), float(tuning.get("flame_spread_deg", 15.0))))
	var direction = base_dir.rotated(spread)

	var flame = Area2D.new()
	flame.name = "Flame_" + str(randi())
	flame.collision_layer = 8
	flame.collision_mask = 1 | 4
	flame.z_index = 100

	flame.set_script(FLAME_PROJECTILE_SCRIPT)
	flame.direction = direction
	flame.damage = damage
	flame.speed = float(tuning.get("flame_speed", 300.0))
	flame.lifetime = float(tuning.get("flame_lifetime", 0.4))

	var fire = GPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = false
	fire.amount = 60
	fire.lifetime = 0.5
	fire.speed_scale = 2.2
	fire.explosiveness = 0.1
	fire.randomness = 0.5

	var fire_mat = ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(direction.x, direction.y, 0)
	fire_mat.spread = 22.0
	fire_mat.initial_velocity_min = 40.0
	fire_mat.initial_velocity_max = 100.0
	fire_mat.gravity = Vector3(0, -70, 0)
	fire_mat.damping_min = 10.0
	fire_mat.damping_max = 30.0
	fire_mat.scale_min = 4.0
	fire_mat.scale_max = 12.0
	fire_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_mat.emission_sphere_radius = 8.0

	var fire_grad = Gradient.new()
	fire_grad.set_offset(0, 0.0)
	fire_grad.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
	fire_grad.add_point(0.1, Color(1.0, 0.98, 0.5, 1.0))
	fire_grad.add_point(0.3, Color(1.0, 0.7, 0.1, 0.95))
	fire_grad.add_point(0.55, Color(1.0, 0.4, 0.02, 0.85))
	fire_grad.add_point(0.75, Color(0.8, 0.12, 0.01, 0.6))
	fire_grad.set_offset(1, 1.0)
	fire_grad.set_color(1, Color(0.15, 0.02, 0.0, 0.0))
	var fire_grad_tex = GradientTexture1D.new()
	fire_grad_tex.gradient = fire_grad
	fire_mat.color_ramp = fire_grad_tex

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.85))
	scale_curve.add_point(Vector2(0.8, 0.4))
	scale_curve.add_point(Vector2(1.0, 0.05))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	fire_mat.scale_curve = scale_curve_tex

	fire.process_material = fire_mat
	flame.add_child(fire)

	var embers = GPUParticles2D.new()
	embers.emitting = true
	embers.one_shot = false
	embers.amount = 12
	embers.lifetime = 0.6
	embers.speed_scale = 1.5
	embers.explosiveness = 0.3
	embers.randomness = 0.9

	var ember_mat = ParticleProcessMaterial.new()
	ember_mat.direction = Vector3(direction.x * 0.5, direction.y * 0.5 - 1.0, 0)
	ember_mat.spread = 50.0
	ember_mat.initial_velocity_min = 40.0
	ember_mat.initial_velocity_max = 120.0
	ember_mat.gravity = Vector3(0, -90, 0)
	ember_mat.damping_min = 15.0
	ember_mat.damping_max = 40.0
	ember_mat.scale_min = 1.5
	ember_mat.scale_max = 3.0

	var ember_grad = Gradient.new()
	ember_grad.set_offset(0, 0.0)
	ember_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	ember_grad.add_point(0.3, Color(1.0, 0.6, 0.1, 0.9))
	ember_grad.add_point(0.6, Color(1.0, 0.3, 0.05, 0.7))
	ember_grad.set_offset(1, 1.0)
	ember_grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	var ember_grad_tex = GradientTexture1D.new()
	ember_grad_tex.gradient = ember_grad
	ember_mat.color_ramp = ember_grad_tex

	embers.process_material = ember_mat
	flame.add_child(embers)

	var smoke = GPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = false
	smoke.amount = 14
	smoke.lifetime = 0.7
	smoke.speed_scale = 0.8
	smoke.explosiveness = 0.05
	smoke.randomness = 0.8

	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(direction.x * 0.3, -1, 0)
	smoke_mat.spread = 45.0
	smoke_mat.initial_velocity_min = 10.0
	smoke_mat.initial_velocity_max = 35.0
	smoke_mat.gravity = Vector3(0, -35, 0)
	smoke_mat.scale_min = 6.0
	smoke_mat.scale_max = 16.0
	smoke_mat.damping_min = 5.0
	smoke_mat.damping_max = 15.0

	var smoke_grad = Gradient.new()
	smoke_grad.set_offset(0, 0.0)
	smoke_grad.set_color(0, Color(0.35, 0.28, 0.22, 0.35))
	smoke_grad.add_point(0.4, Color(0.25, 0.2, 0.16, 0.2))
	smoke_grad.set_offset(1, 1.0)
	smoke_grad.set_color(1, Color(0.12, 0.1, 0.08, 0.0))
	var smoke_grad_tex = GradientTexture1D.new()
	smoke_grad_tex.gradient = smoke_grad
	smoke_mat.color_ramp = smoke_grad_tex

	smoke.process_material = smoke_mat
	flame.add_child(smoke)

	var glow = PointLight2D.new()
	glow.color = Color(1.0, 0.5, 0.1, 1.0)
	glow.energy = 1.8 + randf_range(-0.3, 0.3)
	glow.texture_scale = 0.5
	var light_tex = GradientTexture2D.new()
	light_tex.gradient = Gradient.new()
	light_tex.gradient.set_color(0, Color.WHITE)
	light_tex.gradient.set_color(1, Color.TRANSPARENT)
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 128
	light_tex.height = 128
	glow.texture = light_tex
	flame.add_child(glow)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	flame.add_child(shape)

	flame.global_position = _get_muzzle_global_position()
	get_parent().add_child(flame)

	flame.body_entered.connect(flame._on_body_entered)
	flame.start_lifetime()

func take_damage(amount):
	health -= amount
	if health < 0:
		health = 0
	
	# Flash red
	modulate = Color(1, 0.3, 0.3)
	var t := get_tree().create_timer(0.1)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE
	
	# Update HUD
	if hud_node and hud_node.has_method("update_health"):
		hud_node.update_health(health, GameManager.max_health)
	
	# Screen shake
	if has_node("Camera2D"):
		var cam = $Camera2D
		var shake_tween = create_tween()
		shake_tween.tween_property(cam, "offset", Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
		shake_tween.tween_property(cam, "offset", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
		shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)
	
	if health <= 0:
		die()

var is_game_over: bool = false

func die():
	if is_game_over:
		return
	is_game_over = true
	set_physics_process(false)
	
	# Hide the HUD
	if hud_node and hud_node.has_method("hide_hud"):
		hud_node.hide_hud()
	
	# Brief red flash before transition
	modulate = Color(1, 0.2, 0.2)
	
	# Short delay for impact
	await get_tree().create_timer(0.8).timeout
	
	# Transition to the end screen
	GameManager.health = GameManager.max_health
	get_tree().change_scene_to_file("res://Scenes/EndScreen.tscn")
