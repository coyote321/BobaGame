extends Area2D

const POISON_DOT_SCRIPT := preload("res://Scripts/PoisonDoT.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: float = 15.0
var lifetime: float = 3.0

var poison_tick_damage: float = 0.0
var poison_ticks: int = 0
var poison_interval: float = 1.0

var _age: float = 0.0


static var _hit_scale_curve: Curve
static var _hit_flash_tex: GradientTexture2D
static var _shared_built: bool = false

static func _build_shared() -> void:
	if _shared_built:
		return
	_shared_built = true

	_hit_scale_curve = Curve.new()
	_hit_scale_curve.add_point(Vector2(0.0, 0.5))
	_hit_scale_curve.add_point(Vector2(0.15, 1.0))
	_hit_scale_curve.add_point(Vector2(1.0, 0.0))

	_hit_flash_tex = GradientTexture2D.new()
	_hit_flash_tex.gradient = Gradient.new()
	_hit_flash_tex.gradient.set_color(0, Color.WHITE)
	_hit_flash_tex.gradient.set_color(1, Color.TRANSPARENT)
	_hit_flash_tex.fill = GradientTexture2D.FILL_RADIAL
	_hit_flash_tex.fill_from = Vector2(0.5, 0.5)
	_hit_flash_tex.fill_to = Vector2(0.5, 0.0)
	_hit_flash_tex.width = 64
	_hit_flash_tex.height = 64

func _ready() -> void:
	_build_shared()

func _physics_process(delta):
	position += direction * speed * delta
	_age += delta

	if has_node("Bubble"):
		var pulse = 1.0 + sin(_age * 14.0) * 0.06
		$Bubble.scale = Vector2(pulse, pulse)
	if has_node("Highlight"):
		$Highlight.rotation += delta * 3.0

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		return

	var hit_pos = global_position
	var hit_color = Color(0.85, 0.2, 0.15)
	if has_node("Bubble"):
		hit_color = $Bubble.color

	if body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_hit_particles(hit_pos, hit_color, true)
		if poison_ticks > 0 and poison_tick_damage > 0.0:
			_apply_poison(body, hit_color)
	else:
		_spawn_hit_particles(hit_pos, hit_color, false)

	queue_free()

func _apply_poison(target: Node, color: Color) -> void:
	var poison_node = Node2D.new()
	poison_node.name = "PoisonDoT_" + str(randi())
	poison_node.set_script(POISON_DOT_SCRIPT)
	target.add_child(poison_node)
	poison_node.start(target, poison_tick_damage, poison_ticks, poison_interval, color)

func _spawn_hit_particles(pos: Vector2, color: Color, is_enemy: bool) -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12 if is_enemy else 6
	particles.lifetime = 0.3
	particles.explosiveness = 0.92
	particles.randomness = 0.5
	particles.direction = Vector2(-direction.x, -direction.y)
	particles.spread = 65.0 if is_enemy else 45.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 160.0
	particles.gravity = Vector2(0, 120)
	particles.damping_min = 40.0
	particles.damping_max = 100.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0


	var grad = Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.15, color)
	if is_enemy:
		grad.add_point(0.5, Color(color.r * 0.8, color.g * 0.6, color.b * 0.6, 0.8))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = grad
	particles.scale_amount_curve = _hit_scale_curve

	particles.global_position = pos
	particles.z_index = 110
	get_tree().current_scene.add_child(particles)

	if is_enemy:
		var flash = PointLight2D.new()
		flash.color = color
		flash.energy = 1.2
		flash.texture_scale = 0.2
		flash.texture = _hit_flash_tex
		flash.global_position = pos
		get_tree().current_scene.add_child(flash)

		var tween = get_tree().create_tween()
		tween.tween_property(flash, "energy", 0.0, 0.15)
		tween.tween_callback(flash.queue_free)

	_auto_free_node(particles, 0.6)

func _auto_free_node(node: Node, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(node):
		node.queue_free()

func start_lifetime():
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()
