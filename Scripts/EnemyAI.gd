extends CharacterBody2D

# == Combat Stats ==
@export var max_health: float = 100.0
var health: float = 100.0
var is_dead: bool = false

# == State Machine ==
enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL

# == Movement ==
var speed: float = 80.0
var chase_speed: float = 120.0
var patrol_points: Array = []
var patrol_index: int = 0
var patrol_wait_timer: float = 0.0

# == Detection ==
var detection_range: float = 200.0
var attack_range: float = 50.0
var player: CharacterBody2D = null

# == Combat ==
var attack_damage: float = 15.0
var attack_cooldown: float = 0.0
const ATTACK_RATE: float = 1.0
var hurt_timer: float = 0.0

# == Alert ==
var alert_timer: float = 0.0
const ALERT_DURATION: float = 1.5

# == Target for contract missions ==
var is_target: bool = false

# == Visuals ==
var sprite: Sprite2D
var health_bar: ProgressBar
var alert_indicator: Label

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
		sprite.modulate = Color.RED
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
	alert_indicator.text = "❗"
	alert_indicator.position = Vector2(-10, -70)
	alert_indicator.add_theme_font_size_override("font_size", 24)
	alert_indicator.visible = false
	add_child(alert_indicator)

func setup_patrol_points():
	var origin = global_position
	patrol_points = [
		origin + Vector2(100, 0),
		origin + Vector2(100, 50),
		origin + Vector2(0, 50),
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
		patrol_wait_timer = randf_range(1.0, 3.0)
	
	check_player_detection()

func process_alert(delta):
	alert_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	
	# Flash alert indicator
	alert_indicator.visible = int(alert_timer * 4) % 2 == 0
	
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
	
	if distance > attack_range * 1.5:
		state = State.CHASE
		return
	
	velocity = Vector2.ZERO
	move_and_slide()
	
	if attack_cooldown <= 0:
		perform_attack()
		attack_cooldown = ATTACK_RATE

func process_hurt(delta):
	# Brief stun after being hit without spawning new timers each frame
	velocity = Vector2.ZERO
	move_and_slide()
	hurt_timer -= delta
	if hurt_timer <= 0 and health > 0:
		state = State.CHASE

func perform_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)
		# Visual attack effect
		var tween = create_tween()
		tween.tween_property(self, "position", global_position + (player.global_position - global_position).normalized() * 20, 0.1)
		tween.tween_property(self, "position", global_position, 0.1)

func check_player_detection():
	if not player or not is_instance_valid(player):
		return
	
	var distance = global_position.distance_to(player.global_position)
	var effective_range = detection_range
	
	# Harder to detect crouching player
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
		GameManager.add_xp(100)
	else:
		GameManager.add_xp(25)
	
	GameManager.add_money(10)
	
	# Death animation
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(self, "scale", Vector2(1.2, 0.3), 0.5)
	tween.tween_callback(queue_free)
