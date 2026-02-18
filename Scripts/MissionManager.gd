extends Node2D

var enemies_container
var mission_complete = false
var target_enemy = null
var stealth_rating: float = 100.0

# Reference to HUD (found in scene tree)
var hud = null

func _ready():
	if GameManager.current_phase != "MISSION":
		GameManager.start_mission()
	
	enemies_container = get_node_or_null("Enemies")
	
	# Find the HUD and wire up buttons
	await get_tree().process_frame
	hud = find_child("HUD", true, false)
	if hud:
		hud.connect_buttons(_on_abort_pressed, _on_return_pressed)
	
	if enemies_container:
		if GameManager.current_contract.size() > 0:
			setup_target()

func setup_target():
	if enemies_container.get_child_count() > 0:
		var enemies = enemies_container.get_children()
		target_enemy = enemies.pick_random()
		target_enemy.is_target = true
		target_enemy.setup_visuals()

func _process(delta):
	if not mission_complete:
		update_stealth(delta)
		check_mission_status()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			_on_abort_pressed()

func update_stealth(delta: float):
	var spotted = false
	if enemies_container:
		for enemy in enemies_container.get_children():
			if not "state" in enemy:
				continue
			if enemy.state == enemy.State.CHASE or enemy.state == enemy.State.ALERT:
				spotted = true
				stealth_rating = max(0.0, stealth_rating - (20.0 * delta))
				break
	
	if not spotted and stealth_rating < 100:
		stealth_rating = min(100.0, stealth_rating + (10.0 * delta))
	
	# Update the HUD stealth display
	if hud and hud.has_method("update_stealth"):
		hud.update_stealth(stealth_rating)

func check_mission_status():
	if not enemies_container:
		return
	
	if target_enemy and not is_instance_valid(target_enemy):
		on_mission_complete()
		return
	
	if enemies_container.get_child_count() == 0:
		on_mission_complete()

func on_mission_complete():
	if mission_complete:
		return
	
	mission_complete = true
	
	GameManager.add_xp(50)
	GameManager.update_quest_progress("complete_mission", 1)
	
	var stealth_bonus = int(stealth_rating / 10) * 10
	if stealth_bonus > 0:
		GameManager.add_money(stealth_bonus)
	
	# Update HUD to show completion
	if hud and hud.has_method("show_mission_complete"):
		hud.show_mission_complete(stealth_bonus)

func _on_abort_pressed():
	GameManager.target_order_received = false
	GameManager.current_contract = {}
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")

func _on_return_pressed():
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")
