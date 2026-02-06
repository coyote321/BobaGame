extends CharacterBody2D

var speed = 200
var sprint_speed = 350
var crouch_speed = 100
var aim_speed_penalty = 0.5
var health = 100

var is_crouching = false
var is_aiming = false

# Weapon State
var current_weapon_idx = 1 # 1 = Main, 2 = Melee

var fire_cooldown = 0.0
var ability_cooldown = 0.0

@export var projectile_scene: PackedScene

const BOBA_PROJECTILE_SCRIPT := preload("res://Scripts/BobaProjectile.gd")
const PROJECTILE_TEXTURE := preload("res://Assets/Sprites/projectile.svg")

func _ready():
	health = GameManager.max_health
	add_to_group("player")

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

func is_crouching_state() -> bool:
	return is_crouching

func switch_weapon(idx):
	current_weapon_idx = idx
	var weapon_name = GameManager.equipped_main if idx == 1 else GameManager.equipped_melee
	print("Switched to: ", weapon_name)
	update_hotbar_ui()

func update_hotbar_ui():
	var hotbar = get_tree().current_scene.find_child("Hotbar", true, false)
	if hotbar:
		var hbox = hotbar.get_node_or_null("HBox")
		if hbox:
			for i in range(hbox.get_child_count()):
				var slot = hbox.get_child(i)
				var style = slot.get_theme_stylebox("panel")
				if style:
					style = style.duplicate()
					if i + 1 == current_weapon_idx:
						style.bg_color = Color(0.4, 0.7, 1, 0.5)
						style.border_color = Color(0.4, 0.7, 1, 1)
					else:
						style.bg_color = Color(0, 0, 0, 0.5)
						style.border_color = Color(0, 0, 0, 0)
					slot.add_theme_stylebox_override("panel", style)

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
	if current_weapon_idx == 1:
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
	print("=== SHOOT CALLED ===")
	
	var weapon_name = GameManager.equipped_main
	var weapon_data = GameManager.weapons.get(weapon_name, {})
	# Respect weapon fire rate (seconds between shots)
	fire_cooldown = float(weapon_data.get("fire_rate", 0.5))
	var damage = GameManager.get_weapon_damage(weapon_name)
	var direction = Vector2.RIGHT
	if has_node("Visuals"):
		direction = Vector2.RIGHT.rotated($Visuals.rotation)
	
	print("Weapon:", weapon_name, "Damage:", damage)
	
	# Create projectile
	var projectile = Area2D.new()
	projectile.name = "Boba_" + str(randi())
	# Layer/mask: detect walls (1) + enemies (4), but not the player.
	projectile.collision_layer = 8
	projectile.collision_mask = 1 | 4
	projectile.z_index = 100
	
	# SET SCRIPT FIRST
	projectile.set_script(BOBA_PROJECTILE_SCRIPT)
	
	# SET PROPERTIES - FAST speed!
	projectile.direction = direction
	projectile.damage = damage
	projectile.speed = 800.0  # FAST!
	
	# Visual - load the original boba image
	var sprite = Sprite2D.new()
	sprite.texture = PROJECTILE_TEXTURE
	sprite.scale = Vector2(0.4, 0.4)  # Scale down the boba cup
	sprite.rotation = direction.angle() + PI/2  # Point in direction
	projectile.add_child(sprite)
	
	# Collision shape
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	projectile.add_child(shape)
	
	# Set position
	projectile.global_position = global_position + direction * 30  # Offset in front
	
	# ADD TO SCENE
	get_parent().add_child(projectile)
	
	# Connect signal AFTER adding to tree
	projectile.body_entered.connect(projectile._on_body_entered)
	
	# Start lifetime countdown
	projectile.start_lifetime()
	
	print("BOBA FIRED! Damage:", damage)

func take_damage(amount):
	health -= amount
	
	# Flash red
	modulate = Color(1, 0.3, 0.3)
	var t := get_tree().create_timer(0.1)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE
	
	if has_node("HealthBar"):
		$HealthBar.value = (float(health) / float(GameManager.max_health)) * 100
	
	print("Player Health: ", health)
	
	if health <= 0:
		die()

func die():
	print("GAME OVER")
	set_physics_process(false)  # Stop player processing
	
	# Show game over screen
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	get_tree().current_scene.add_child(canvas)
	
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0, 0, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	
	var label = Label.new()
	label.text = "MISSION FAILED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	canvas.add_child(label)
	
	var btn = Button.new()
	btn.text = "RETURN TO SHOP"
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-100, 60)
	btn.custom_minimum_size = Vector2(200, 50)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS  # Works while paused
	btn.pressed.connect(func():
		get_tree().paused = false  # UNPAUSE FIRST!
		GameManager.health = GameManager.max_health
		GameManager.start_shop()
		get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")
	)
	canvas.add_child(btn)
	
	get_tree().paused = true
