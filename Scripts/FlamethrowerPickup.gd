extends Area2D

## Flamethrower world pickup. Place this scene anywhere in a mission level.
## Player must press E while nearby to pick it up.
## - If an inventory slot is empty, the weapon fills the next open slot.
## - If all slots are full, it replaces the weapon in the currently selected slot.

@export var weapon_name: String = "Flamethrower"

var _player_in_range: Node2D = null
var _picked_up: bool = false
var _prompt_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create the "Press E" prompt (hidden by default)
	_prompt_label = Label.new()
	_prompt_label.text = "Press E to pick up"
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-55, 25)
	_prompt_label.add_theme_font_size_override("font_size", 14)
	_prompt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_prompt_label.visible = false
	add_child(_prompt_label)

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
	_picked_up = true
	
	# Determine which slot to place the weapon in
	var slot_main = GameManager.equipped_main
	var slot_melee = GameManager.equipped_melee
	var slot_special = GameManager.equipped_special
	
	# Check for empty slots first (empty string = open slot)
	if slot_main == "":
		GameManager.equipped_main = weapon_name
	elif slot_melee == "":
		GameManager.equipped_melee = weapon_name
	elif slot_special == "":
		GameManager.equipped_special = weapon_name
	else:
		# All slots full — replace the currently selected slot
		var idx = 1
		if _player_in_range and "current_weapon_idx" in _player_in_range:
			idx = _player_in_range.current_weapon_idx
		
		match idx:
			1:
				GameManager.equipped_main = weapon_name
			2:
				GameManager.equipped_melee = weapon_name
			3:
				GameManager.equipped_special = weapon_name
	
	# Make sure the weapon is in owned_weapons
	if weapon_name not in GameManager.owned_weapons:
		GameManager.owned_weapons.append(weapon_name)
	
	print("Picked up ", weapon_name, "!")
	
	# Refresh the HUD hotbar so the new weapon name shows up
	var hud = get_tree().current_scene.find_child("HUD", true, false)
	if hud and hud.has_method("_refresh_hotbar"):
		hud._refresh_hotbar()
		if _player_in_range and "current_weapon_idx" in _player_in_range:
			var idx = _player_in_range.current_weapon_idx
			var wn = ""
			match idx:
				1: wn = GameManager.equipped_main
				2: wn = GameManager.equipped_melee
				3: wn = GameManager.equipped_special
			if hud.has_method("update_weapon"):
				hud.update_weapon(idx, wn)
	
	# Pickup flash effect — scale up and fade out
	if _prompt_label:
		_prompt_label.visible = false
	var tween = create_tween()
	tween.parallel().tween_property(self, "scale", Vector2(2.0, 2.0), 0.25)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
