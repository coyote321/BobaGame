extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 400.0
var damage: float = 10.0

func _ready():

	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):


	if body.name == "Player" or body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
	elif body.has_method("take_damage") and not body.is_in_group("enemy"):

		body.take_damage(damage)
		queue_free()
	else:

		queue_free()
