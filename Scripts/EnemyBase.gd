extends CharacterBody2D
## Base class for all enemy types. Holds shared state‑machine, visuals,
## detection, damage, death, and damage‑number logic.

signal died(enemy)

# ─── Health ─────────────────────────────────────────────────────────────
@export var max_health: float = 60.0
var health: float = 60.0
var is_dead: bool = false

# ─── State Machine ──────────────────────────────────────────────────────
enum State { IDLE, PATROL, ALERT, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL

# ─── Movement ───────────────────────────────────────────────────────────
var speed: float = 180.0
var chase_speed: float = 280.0
var patrol_points: Array = []
var patrol_index: int = 0
var patrol_wait_timer: float = 0.0

# ─── Detection ──────────────────────────────────────────────────────────
var detection_range: float = 250.0
var attack_range: float = 80.0
var player: CharacterBody2D = null

# ─── Attack ─────────────────────────────────────────────────────────────
var attack_damage: float = 5.0
var attack_cooldown: float = 0.0
const ATTACK_RATE: float = 0.3
var hurt_timer: float = 0.0

# ─── Alert ──────────────────────────────────────────────────────────────
var alert_timer: float = 0.0
const ALERT_DURATION: float = 1.5

# ─── Contract Target ───────────────────────────────────────────────────
var is_target: bool = false

# ─── Visuals (created in setup_visuals) ─────────────────────────────────
var body_rect: ColorRect
var health_bar: ProgressBar
var alert_indicator: Label
var _health_fill_style: StyleBoxFlat
var _health_color_key: String = ""

# ─── Configurable overrides for subclasses ──────────────────────────────
var _body_size: Vector2 = Vector2(50, 50)
var _body_offset: Vector2 = Vector2(-25, -25)
var _body_color: Color = Color(0.2, 0.5, 0.9, 1)
var _alert_icon_text: String = "❗"
var _alert_font_size: int = 24
var _alert_offset: Vector2 = Vector2(-10, -70)
var _alert_blink_multiplier: float = 4.0
var _patrol_extent: Vector2 = Vector2(100, 50)
var _idle_wait_range: Vector2 = Vector2(1.0, 3.0)
var _xp_reward: int = 25
var _xp_reward_target: int = 100
var _money_reward: int = 10

# ─── Lifecycle ──────────────────────────────────────────────────────────

func _ready():
	add_to_group("enemy")
	health = max_health
	setup_visuals()

	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	setup_patrol_points()

# ─── Visuals ────────────────────────────────────────────────────────────

func setup_visuals():
	# Body rect
	if has_node("Body") and $Body is ColorRect:
		body_rect = $Body
	else:
		body_rect = ColorRect.new()
		body_rect.name = "Body"
		body_rect.position = _body_offset
		body_rect.size = _body_size
		body_rect.color = _body_color
		add_child(body_rect)

	if is_target:
		body_rect.color = Color(1, 0.85, 0)

	# Health bar
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
		add_child(health_bar)
	_health_fill_style = StyleBoxFlat.new()
	_health_fill_style.bg_color = Color(0.2, 0.8, 0.2)
	health_bar.add_theme_stylebox_override("fill", _health_fill_style)

	health_bar.max_value = max_health
	health_bar.value = health
	_update_health_bar_color()

	# Alert indicator
	alert_indicator = Label.new()
	alert_indicator.text = _alert_icon_text
	alert_indicator.position = _alert_offset
	alert_indicator.add_theme_font_size_override("font_size", _alert_font_size)
	alert_indicator.visible = false
	add_child(alert_indicator)

# ─── Patrol ─────────────────────────────────────────────────────────────

func setup_patrol_points():
	var origin = global_position
	patrol_points = [
		origin + Vector2(_patrol_extent.x, 0),
		origin + Vector2(_patrol_extent.x, _patrol_extent.y),
		origin + Vector2(0, _patrol_extent.y),
		origin
	]

# ─── State Machine ──────────────────────────────────────────────────────

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

	if global_position.distance_to(target) < 10:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		state = State.IDLE
		patrol_wait_timer = randf_range(_idle_wait_range.x, _idle_wait_range.y)

	check_player_detection()

func process_alert(delta):
	alert_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()

	alert_indicator.visible = int(alert_timer * _alert_blink_multiplier) % 2 == 0

	if alert_timer <= 0:
		alert_indicator.visible = false
		state = State.CHASE

func process_chase(delta):
	if not player or not is_instance_valid(player):
		state = State.PATROL
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > detection_range * 1.5:
		state = State.PATROL
		return

	if distance < attack_range:
		state = State.ATTACK
		return

	var dir = (player.global_position - global_position).normalized()
	velocity = dir * chase_speed
	move_and_slide()

func process_attack(delta):
	if not player or not is_instance_valid(player):
		state = State.PATROL
		return

	var distance = global_position.distance_to(player.global_position)

	if distance > attack_range * _get_attack_disengage_mult():
		state = State.CHASE
		return

	_attack_movement(delta)

	if attack_cooldown <= 0:
		perform_attack()
		attack_cooldown = ATTACK_RATE

## Override in subclasses for different disengage thresholds.
func _get_attack_disengage_mult() -> float:
	return 1.5

## Override in subclasses for movement during attack (e.g. ranged enemies).
func _attack_movement(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

func process_hurt(delta):
	velocity = Vector2.ZERO
	move_and_slide()
	hurt_timer -= delta
	if hurt_timer <= 0 and health > 0:
		state = State.CHASE

# ─── Attack (override in subclass) ──────────────────────────────────────

func perform_attack():
	if player and player.has_method("take_damage"):
		player.take_damage(attack_damage)

		var lunge_dir = (player.global_position - global_position).normalized()
		var original_pos = position
		var tween = create_tween()
		tween.tween_property(self, "position", original_pos + lunge_dir * 20, 0.08)
		tween.tween_property(self, "position", original_pos, 0.08)

# ─── Detection ──────────────────────────────────────────────────────────

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

# ─── Damage ─────────────────────────────────────────────────────────────

func take_damage(amount: float):
	if is_dead:
		return

	health -= amount
	health_bar.value = health
	_update_health_bar_color()

	# Flash body white
	if body_rect:
		var orig_color = body_rect.color
		body_rect.color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		body_rect.color = orig_color

	show_damage_number(amount)

	if health <= 0:
		die()
	else:
		hurt_timer = 0.2
		state = State.HURT

func _update_health_bar_color() -> void:
	if not _health_fill_style:
		return
	var color_key := "danger"
	var fill_color := Color(0.8, 0.2, 0.2)
	if health > max_health * 0.5:
		color_key = "healthy"
		fill_color = Color(0.2, 0.8, 0.2)
	elif health > max_health * 0.25:
		color_key = "warning"
		fill_color = Color(0.8, 0.8, 0.2)
	if color_key != _health_color_key:
		_health_fill_style.bg_color = fill_color
		_health_color_key = color_key

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

# ─── Death ──────────────────────────────────────────────────────────────

func die():
	if is_dead:
		return
	is_dead = true
	state = State.DEAD

	if is_target:
		GameManager.complete_contract()
		GameManager.add_xp(_xp_reward_target)
	else:
		GameManager.add_xp(_xp_reward)

	GameManager.add_money(_money_reward)
	GameManager.update_quest_progress("kill_enemies", 1)

	died.emit(self)
	remove_from_group("enemy")

	if body_rect:
		var tween = create_tween()
		tween.tween_property(body_rect, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(self, "scale", Vector2(1.2, 0.3), 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()
