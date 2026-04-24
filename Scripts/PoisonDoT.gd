extends Node2D

var _target: Node
var _tick_damage: float
var _ticks_remaining: int
var _interval: float
var _color: Color
var _timer: float = 0.0
var _particles: CPUParticles2D
var _is_finishing: bool = false

func start(target: Node, tick_dmg: float, ticks: int, interval: float, color: Color) -> void:
	_target = target
	_tick_damage = tick_dmg
	_ticks_remaining = ticks
	_interval = interval
	_color = color
	_timer = interval
	_setup_particles()

func _setup_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting = true
	_particles.amount = 4
	_particles.lifetime = 0.6
	_particles.explosiveness = 0.0
	_particles.randomness = 0.6
	_particles.direction = Vector2(0, -1)
	_particles.spread = 60.0
	_particles.initial_velocity_min = 10.0
	_particles.initial_velocity_max = 30.0
	_particles.gravity = Vector2(0, -20)
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 2.5

	var grad := Gradient.new()
	grad.set_offset(0, 0.0)
	grad.set_color(0, Color(0.3, 1.0, 0.5, 0.8))
	grad.set_offset(1, 1.0)
	grad.set_color(1, Color(0.1, 0.6, 0.2, 0.0))
	_particles.color_ramp = grad
	_particles.z_index = 105
	add_child(_particles)

func _process(delta: float) -> void:
	if _is_finishing:
		return
	if not is_instance_valid(_target) or _ticks_remaining <= 0:
		_finish()
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = _interval
		_ticks_remaining -= 1
		if _target.has_method("take_damage"):
			_target.take_damage(_tick_damage)
		_show_poison_number()

func _finish() -> void:
	_is_finishing = true
	if _particles:
		_particles.emitting = false
	await get_tree().create_timer(0.6).timeout
	queue_free()

func _show_poison_number() -> void:
	var lbl := Label.new()
	lbl.text = "-" + str(int(_tick_damage))
	lbl.position = Vector2(randf_range(-20, 20), -60)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	_target.add_child(lbl)

	var tween := get_tree().create_tween()
	tween.parallel().tween_property(lbl, "position:y", lbl.position.y - 20, 0.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)
