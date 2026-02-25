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

func _ready():
	health = GameManager.max_health
	add_to_group("player")
	# Allow _input to fire even while tree is paused (for game-over screen)
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Find the HUD in the scene tree (instanced in MissionScene)
	await get_tree().process_frame
	hud_node = get_tree().current_scene.find_child("HUD", true, false)

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

func attack():
	if current_weapon_idx == 1 or current_weapon_idx == 3:
		shoot()
	else:
		melee_attack()

func melee_attack():
	var weapon_name = GameManager.equipped_melee
	var damage = GameManager.get_weapon_damage(weapon_name)
	
	print("Melee Attack with ", weapon_name)
	
	# Find enemies in range
	var enemies_node = get_parent().get_node_or_null("Enemies")
	if enemies_node:
		for enemy in enemies_node.get_children():
			if enemy.has_method("take_damage"):
				var dist = global_position.distance_to(enemy.global_position)
				if dist < 80:
					var dir_to_enemy = global_position.direction_to(enemy.global_position)
					var facing_dir = Vector2.RIGHT
					if has_node("Visuals"):
						facing_dir = Vector2.RIGHT.rotated($Visuals.rotation)
					if facing_dir.dot(dir_to_enemy) > 0.5:
						enemy.take_damage(damage)
						print("Hit enemy with ", weapon_name, "!")
	
	fire_cooldown = GameManager.weapons.get(weapon_name, {}).get("fire_rate", 0.5)

func shoot():
	var weapon_name = GameManager.equipped_main
	if current_weapon_idx == 3:
		weapon_name = GameManager.equipped_special
		if weapon_name == "":
			return

	var weapon_data = GameManager.weapons.get(weapon_name, {})
	fire_cooldown = float(weapon_data.get("fire_rate", 0.5))
	
	# Flamethrower uses its own spawning logic
	if weapon_name == "Flamethrower":
		_shoot_flame(weapon_data)
		return
	
	var damage = GameManager.get_weapon_damage(weapon_name)
	var direction = Vector2.RIGHT
	if has_node("Visuals"):
		direction = Vector2.RIGHT.rotated($Visuals.rotation)
	
	# Create projectile
	var projectile = Area2D.new()
	projectile.name = "Proj_" + str(randi())
	projectile.collision_layer = 8
	projectile.collision_mask = 1 | 4
	projectile.z_index = 100
	
	# SET SCRIPT FIRST
	projectile.set_script(BOBA_PROJECTILE_SCRIPT)
	
	# SET PROPERTIES
	projectile.direction = direction
	projectile.damage = damage
	projectile.speed = 800.0
	
	# Visual - plain red square (gray-box prototype)
	var rect = ColorRect.new()
	rect.color = Color(0.85, 0.2, 0.15)
	rect.size = Vector2(10, 10)
	rect.position = Vector2(-5, -5)  # Center it
	projectile.add_child(rect)
	
	# Collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	projectile.add_child(shape)
	
	# Set position
	projectile.global_position = global_position + direction * 30
	
	# ADD TO SCENE
	get_parent().add_child(projectile)
	
	# Connect signal AFTER adding to tree
	projectile.body_entered.connect(projectile._on_body_entered)
	
	# Start lifetime countdown
	projectile.start_lifetime()

func _shoot_flame(_weapon_data: Dictionary) -> void:
	var damage = GameManager.get_weapon_damage("Flamethrower")
	var base_dir = Vector2.RIGHT
	if has_node("Visuals"):
		base_dir = Vector2.RIGHT.rotated($Visuals.rotation)
	
	# Wide cone spread for flamethrower feel
	var spread = deg_to_rad(randf_range(-15.0, 15.0))
	var direction = base_dir.rotated(spread)
	
	# Create flame projectile node
	var flame = Area2D.new()
	flame.name = "Flame_" + str(randi())
	flame.collision_layer = 8
	flame.collision_mask = 1 | 4
	flame.z_index = 100
	
	flame.set_script(FLAME_PROJECTILE_SCRIPT)
	flame.direction = direction
	flame.damage = damage
	flame.speed = 300.0
	
	# ===== MAIN FIRE PARTICLES =====
	var fire = GPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = false
	fire.amount = 50
	fire.lifetime = 0.5
	fire.speed_scale = 2.0
	fire.explosiveness = 0.1
	fire.randomness = 0.5
	
	var fire_mat = ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(direction.x, direction.y, 0)
	fire_mat.spread = 20.0
	fire_mat.initial_velocity_min = 30.0
	fire_mat.initial_velocity_max = 80.0
	fire_mat.gravity = Vector3(0, -60, 0)  # flames rise
	fire_mat.damping_min = 10.0
	fire_mat.damping_max = 30.0
	fire_mat.scale_min = 4.0
	fire_mat.scale_max = 10.0
	fire_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_mat.emission_sphere_radius = 6.0
	
	# Fire color: white-hot core -> bright yellow -> orange -> red -> fade
	var fire_grad = Gradient.new()
	fire_grad.set_offset(0, 0.0)
	fire_grad.set_color(0, Color(1.0, 1.0, 0.85, 1.0))      # white-hot
	fire_grad.add_point(0.15, Color(1.0, 0.95, 0.3, 1.0))    # bright yellow
	fire_grad.add_point(0.4, Color(1.0, 0.55, 0.05, 0.95))   # orange
	fire_grad.add_point(0.7, Color(0.85, 0.15, 0.02, 0.7))   # deep red
	fire_grad.set_offset(1, 1.0)
	fire_grad.set_color(1, Color(0.2, 0.02, 0.0, 0.0))       # fade out
	var fire_grad_tex = GradientTexture1D.new()
	fire_grad_tex.gradient = fire_grad
	fire_mat.color_ramp = fire_grad_tex
	
	# Scale curve: grow then shrink
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(0.2, 1.0))
	scale_curve.add_point(Vector2(0.6, 0.8))
	scale_curve.add_point(Vector2(1.0, 0.1))
	var scale_curve_tex = CurveTexture.new()
	scale_curve_tex.curve = scale_curve
	fire_mat.scale_curve = scale_curve_tex
	
	fire.process_material = fire_mat
	flame.add_child(fire)
	
	# ===== SMOKE TRAIL =====
	var smoke = GPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = false
	smoke.amount = 20
	smoke.lifetime = 0.6
	smoke.speed_scale = 1.0
	smoke.explosiveness = 0.05
	smoke.randomness = 0.8
	
	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, -1, 0)  # drift upward
	smoke_mat.spread = 40.0
	smoke_mat.initial_velocity_min = 15.0
	smoke_mat.initial_velocity_max = 40.0
	smoke_mat.gravity = Vector3(0, -30, 0)
	smoke_mat.scale_min = 6.0
	smoke_mat.scale_max = 14.0
	smoke_mat.damping_min = 5.0
	smoke_mat.damping_max = 15.0
	
	# Smoke color: dark gray, fading out
	var smoke_grad = Gradient.new()
	smoke_grad.set_offset(0, 0.0)
	smoke_grad.set_color(0, Color(0.3, 0.25, 0.2, 0.4))
	smoke_grad.set_offset(1, 1.0)
	smoke_grad.set_color(1, Color(0.15, 0.12, 0.1, 0.0))
	var smoke_grad_tex = GradientTexture1D.new()
	smoke_grad_tex.gradient = smoke_grad
	smoke_mat.color_ramp = smoke_grad_tex
	
	smoke.process_material = smoke_mat
	flame.add_child(smoke)
	
	# ===== GLOW / LIGHT EFFECT =====
	var glow = PointLight2D.new()
	glow.color = Color(1.0, 0.5, 0.1, 1.0)
	glow.energy = 1.5
	glow.texture_scale = 0.4
	# Use a simple white gradient texture for the light
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
	
	# Larger collision for the flame area
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 20.0
	shape.shape = circle
	flame.add_child(shape)
	
	# Position and add to scene
	flame.global_position = global_position + base_dir * 25
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
