extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: float = 15.0

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		return
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	queue_free()

func start_lifetime():
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()

