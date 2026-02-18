extends CharacterBody2D

# == Combat Stats ==
@export var max_health: float = 50.0
var health: float = 50.0
var is_dead: bool = false

# == State Machine ==
enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL

# == Movement ==
var speed: float = 120.0
var chase_speed: float = 180.0
var patrol_points: Array = []
var patrol_index: int = 0
var patrol_wait_timer: float = 0.0

# == Detection ==
var detection_range: float = 400.0
var attack_range: float = 300.0
var player: CharacterBody2D = null

# == Combat ==
var attack_damage: float = 10.0
var attack_cooldown: float = 0.0
const ATTACK_RATE: float = 1.5
var hurt_timer: float = 0.0

# == Alert ==
var alert_timer: float = 0.0
const ALERT_DURATION: float = 1.0

# == Target for contract missions ==
var is_target: bool = false

# == Visuals ==
var sprite: Sprite2D
var health_bar: ProgressBar
var alert_indicator: Label

# == Projectile ==
const PROJECTILE_SCRIPT = preload("res://Scripts/EnemyProjectile.gd")
const PROJECTILE_TEXTURE = preload("res://Assets/Sprites/projectile.svg")

func _ready():
	health = max_health
	setup_visuals()
	
	# Find player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	
	# Setup patrol points around spawn
	setup_patrol_points()

func setup_visuals():
	# Get or create sprite
	if has_node("Sprite2D"):
		sprite = $Sprite2D
	else:
		sprite = Sprite2D.new()
		sprite.modulate = Color.BLUE # Blue for Enemy 2
		add_child(sprite)
	
	# Target enemies are gold colored
	if is_target:
		sprite.modulate = Color(1, 0.85, 0)
	
	# Health bar (use existing one if present in the scene)
	if has_node("HealthBar") and $HealthBar is ProgressBar:
		health_bar = $HealthBar
		health_bar.show_percentage = false
	else:
		health_bar = ProgressBar.new()
		health_bar.position = Vector2(-25, -50)
		health_bar.size = Vector2(50, 8)
		health_bar.value = 100
		health_bar.show_percentage = false
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2)
		health_bar.add_theme_stylebox_override("background", style)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color(0.8, 0.2, 0.2)
		health_bar.add_theme_stylebox_override("fill", fill)
		add_child(health_bar)
	
	# Drive the bar in "HP units" so scene defaults don't matter.
	health_bar.max_value = max_health
	health_bar.value = health
	
	# Alert indicator
	alert_indicator = Label.new()
	alert_indicator.text = "!"
	alert_indicator.position = Vector2(-5, -80)
	alert_indicator.add_theme_font_size_override("font_size", 28)
	alert_indicator.add_theme_color_override("font_color", Color.YELLOW)
	alert_indicator.visible = false
	add_child(alert_indicator)

func setup_patrol_points():
	var origin = global_position
	patrol_points = [
		origin + Vector2(150, 0),
		origin + Vector2(150, 100),
		origin + Vector2(0, 100),
		origin
	]

func _physics_process(delta):
	if is_dead:
		return
	
	attack_cooldown -= delta
	
	match state:
		State.IDLE:
			process_idle(delta)
		State.PATROL:
			process_patrol(delta)
		State.ALERT:
			process_alert(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
		State.HURT:
			process_hurt(delta)

func process_idle(delta):
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		state = State.PATROL
	check_player_detection()

func process_patrol(delta):
	if patrol_points.size() == 0:
		return
	
	var target = patrol_points[patrol_index]
	var dir = (target - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	
	# Flip sprite
	if dir.x != 0 and sprite:
		sprite.flip_h = dir.x < 0
	
	if global_position.distance_to(target) < 10:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		state = State.IDLE
		patrol_wait_timer = randf_range(0.5, 1.5)
	
	check_player_detection()

func process_alert(delta):
	alert_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	
	# Flash alert indicator
	alert_indicator.visible = int(alert_timer * 6) % 2 == 0
	
	if alert_timer <= 0:
		alert_indicator.visible = false
		state = State.CHASE

func process_chase(delta):
	if not player or not is_instance_valid(player):
		state = State.PATROL
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Lost sight?
	if distance > detection_range * 1.5:
		state = State.PATROL
		return
	
	# In attack range?
	if distance < attack_range:
		state = State.ATTACK
		return
	
	# Chase
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * chase_speed
	move_and_slide()
	
	if sprite:
		sprite.flip_h = dir.x < 0

func process_attack(delta):
	if not player or not is_instance_valid(player):
		state = State.PATROL
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# If player moves out of range, chase again
	if distance > attack_range * 1.2:
		state = State.CHASE
		return
	
	# Stop to shoot
	velocity = Vector2.ZERO
	move_and_slide()
	
	# Face player
	var dir = (player.global_position - global_position).normalized()
	if sprite:
		sprite.flip_h = dir.x < 0
	
	if attack_cooldown <= 0:
		perform_attack()
		attack_cooldown = ATTACK_RATE

func process_hurt(delta):
	# Brief stun
	velocity = Vector2.ZERO
	move_and_slide()
	hurt_timer -= delta
	if hurt_timer <= 0 and health > 0:
		state = State.CHASE

func perform_attack():
	if not player:
		return
		
	# Spawn Projectile
	var projectile = Area2D.new()
	projectile.name = "EnemyProj_" + str(randi())
	
	# Collision: Layer 5 (16) for Enemy Projectile
	# Mask: Player (2) + Wall (1) -> 3
	projectile.collision_layer = 16 
	projectile.collision_mask = 1 | 2
	
	projectile.set_script(PROJECTILE_SCRIPT)
	projectile.direction = (player.global_position - global_position).normalized()
	projectile.damage = attack_damage
	
	# Visual
	var p_sprite = Sprite2D.new()
	p_sprite.texture = PROJECTILE_TEXTURE
	p_sprite.scale = Vector2(0.5, 0.5)
	p_sprite.modulate = Color(1, 0.2, 0.2) # Red projectile
	projectile.add_child(p_sprite)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	projectile.add_child(shape)
	
	projectile.global_position = global_position
	
	get_parent().add_child(projectile)
	projectile.body_entered.connect(projectile._on_body_entered)


func check_player_detection():
	if not player or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	var effective_range = detection_range
	
	var player_crouching = false
	if player.has_method("is_crouching_state"):
		player_crouching = player.is_crouching_state()
	
	if player_crouching:
		effective_range *= 0.5
	
	if distance < effective_range:
		state = State.ALERT
		alert_timer = ALERT_DURATION
		alert_indicator.visible = true

func take_damage(amount: float):
	if is_dead:
		return
	
	health -= amount
	health_bar.value = health
	
	# Update health bar color
	var fill = StyleBoxFlat.new()
	if health > max_health * 0.5:
		fill.bg_color = Color(0.2, 0.8, 0.2)
	elif health > max_health * 0.25:
		fill.bg_color = Color(0.8, 0.8, 0.2)
	else:
		fill.bg_color = Color(0.8, 0.2, 0.2)
	health_bar.add_theme_stylebox_override("fill", fill)
	
	# Flash red
	if sprite:
		var orig_color = sprite.modulate
		sprite.modulate = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		sprite.modulate = orig_color
	
	# Show damage number
	show_damage_number(amount)
	
	if health <= 0:
		die()
	else:
		hurt_timer = 0.2
		state = State.HURT

func show_damage_number(amount: float):
	var dmg_label = Label.new()
	dmg_label.text = "-" + str(int(amount))
	dmg_label.position = Vector2(-15, -80)
	dmg_label.add_theme_font_size_override("font_size", 20)
	dmg_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	add_child(dmg_label)
	
	var tween = create_tween()
	tween.parallel().tween_property(dmg_label, "position:y", dmg_label.position.y - 30, 0.5)
	tween.parallel().tween_property(dmg_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(dmg_label.queue_free)

func die():
	is_dead = true
	state = State.DEAD
	
	# Complete contract if this was the target
	if is_target:
		GameManager.complete_contract()
		GameManager.add_xp(150)
	else:
		GameManager.add_xp(40)
	
	GameManager.add_money(15)
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 0.3), 0.5)
	tween.tween_callback(queue_free)
