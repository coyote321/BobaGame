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
