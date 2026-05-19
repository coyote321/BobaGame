extends Area2D

## Boba Healing Potion pickup.
## Player must press E while nearby to heal.
## Restores 30 HP (capped at max_health), then disappears.

@export var heal_amount: int = 30

var _player_in_range: Node2D = null
var _picked_up: bool = false
var _prompt_label: Label = null
var _bob_offset: float = 0.0
var _visual_base_position := Vector2.ZERO
var _pickup_sfx: AudioStreamPlayer = null
@onready var _visual_root := get_node_or_null("VisualRoot") as Node2D
@onready var _shadow := get_node_or_null("VisualRoot/Shadow") as Polygon2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _visual_root:
		_visual_base_position = _visual_root.position
	
	# Heal potion sound effect
	_pickup_sfx = AudioStreamPlayer.new()
	_pickup_sfx.stream = preload("res://Assets/Audio/sfx/sfx_healpotion.wav")
	_pickup_sfx.volume_db = 0.0
	_pickup_sfx.bus = &"SFX"
	add_child(_pickup_sfx)

	# Create the "Press E to heal" prompt (hidden by default)
	_prompt_label = Label.new()
	_prompt_label.text = "Press E to heal"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-50, 35)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 0.9))
	_prompt_label.visible = false
	add_child(_prompt_label)

func _process(delta: float) -> void:
	if _picked_up:
		return
	# Keep collision steady while the potion itself floats.
	_bob_offset += delta * 2.6
	var lift := sin(_bob_offset)
	if _visual_root:
		_visual_root.position = _visual_base_position + Vector2(0.0, lift * 7.0)
		_visual_root.rotation = sin(_bob_offset * 0.65) * 0.06
	if _shadow:
		var squash := 1.0 - (lift * 0.08)
		_shadow.scale = Vector2(1.0 + lift * 0.08, squash)
		_shadow.modulate.a = 0.65 - lift * 0.18

func _unhandled_input(event: InputEvent) -> void:
	if _picked_up or _player_in_range == null:
		return
	if event.is_action_pressed("interact"):
		_pick_up()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		_player_in_range = body
		if _prompt_label:
			_prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_in_range:
		_player_in_range = null
		if _prompt_label:
			_prompt_label.visible = false

func _pick_up() -> void:
	if _player_in_range == null:
		return

	# Check if player is already at full health
	if _player_in_range.health >= GameManager.max_health:
		if _prompt_label:
			_prompt_label.text = "Health is full!"
			_prompt_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3, 0.9))
		var flash_tween = create_tween()
		flash_tween.tween_property(_prompt_label, "modulate:a", 0.0, 0.8).from(1.0)
		flash_tween.tween_callback(func():
			if _prompt_label:
				_prompt_label.text = "Press E to heal"
				_prompt_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 0.9))
				_prompt_label.modulate.a = 1.0
				_prompt_label.visible = _player_in_range != null
		)
		return

	_picked_up = true

	# Play pickup sound
	if _pickup_sfx:
		_pickup_sfx.play()

	# Heal the player
	if _player_in_range.has_method("heal"):
		_player_in_range.heal(heal_amount)

	print("Healed ", heal_amount, " HP with Boba Potion!")

	# Hide prompt
	if _prompt_label:
		_prompt_label.visible = false

	# Pickup flash effect — green glow, scale up and fade out
	modulate = Color(0.3, 1.0, 0.5, 1.0)
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(2.0, 2.0), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		# Move SFX to scene root so it keeps playing after potion is freed
		if _pickup_sfx and _pickup_sfx.playing:
			remove_child(_pickup_sfx)
			get_tree().current_scene.add_child(_pickup_sfx)
			_pickup_sfx.finished.connect(_pickup_sfx.queue_free)
		queue_free()
	)
