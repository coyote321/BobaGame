extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0

func _ready():
	# Auto-destroy after 5 seconds to prevent memory leaks
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	# Collision masks should handle most filtering (hitting walls/player)
	# But we double check to be safe
	
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body.has_method("take_damage") and not body.is_in_group("enemy"):
		# Hit something destructible that isn't an enemy
		body.take_damage(damage)
		queue_free()
	else:
		# Hit wall or obstacle
		queue_free()
