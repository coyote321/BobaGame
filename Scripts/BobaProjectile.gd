extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 800.0
var damage: float = 15.0

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body):
	if body.name == "Player":
		return
	
	print("BOBA HIT:", body.name, "for", damage, "damage!")
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
		show_damage_popup(body)
	
	queue_free()

func show_damage_popup(target):
	var label = Label.new()
	label.text = "-" + str(int(damage))
	label.global_position = target.global_position + Vector2(-15, -50)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	
	var tween = get_tree().create_tween()
	tween.tween_property(label, "position:y", label.position.y - 40, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)

func start_lifetime():
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		queue_free()
