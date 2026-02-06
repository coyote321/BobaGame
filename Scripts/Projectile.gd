extends Area2D

var speed = 600
var direction = Vector2.ZERO
var damage = 10.0  # Set by weapon

func _ready():
	# Auto-destroy after 3 seconds
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
		spawn_hit_effect()
		queue_free()
	elif body.name != "Player":
		spawn_hit_effect()
		queue_free()

func spawn_hit_effect():
	# Simple hit particles
	var particles = CPUParticles2D.new()
	particles.position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.3
	particles.speed_scale = 2.0
	particles.direction = -direction
	particles.spread = 45.0
	particles.initial_velocity_min = 100
	particles.initial_velocity_max = 200
	particles.color = Color(1, 0.8, 0.3)
	get_tree().current_scene.add_child(particles)
	
	# Auto cleanup
	particles.finished.connect(particles.queue_free)
