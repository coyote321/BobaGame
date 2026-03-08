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
var current_weapon_idx = 1 # 1 = Main, 2 = Melee, 3 = Special

var fire_cooldown = 0.0
var ability_cooldown = 0.0

@export var projectile_scene: PackedScene

var _current_weapon_node: Node2D = null

func _ready():
	health = GameManager.max_health
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	await get_tree().process_frame
	hud_node = get_tree().current_scene.find_child("HUD", true, false)
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
		# Initialize the weapon script
		if _current_weapon_node.has_method("init_weapon"):
			_current_weapon_node.init_weapon(self, weapon_name)

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
	if _current_weapon_node and _current_weapon_node.has_method("attack"):
		_current_weapon_node.attack()

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
