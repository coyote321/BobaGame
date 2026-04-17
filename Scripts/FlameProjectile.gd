extends Area2D


var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 5.0
var lifetime: float = 0.4


var _hit_cooldowns: Dictionary = {}
const HIT_INTERVAL: float = 0.15

func _physics_process(delta: float) -> void:
	position += direction * speed * delta


	var to_erase: Array = []
	for key in _hit_cooldowns:
		_hit_cooldowns[key] -= delta
		if _hit_cooldowns[key] <= 0.0:
			to_erase.append(key)
	for key in to_erase:
		_hit_cooldowns.erase(key)

func _on_body_entered(body: Node2D) -> void:
	_try_damage(body)

func _try_damage(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		return


	if not body.has_method("take_damage"):
		return

	var id = body.get_instance_id()
	if id in _hit_cooldowns:
		return

	body.take_damage(damage)
	_hit_cooldowns[id] = HIT_INTERVAL

func start_lifetime() -> void:
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()
