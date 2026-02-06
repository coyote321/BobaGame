extends Node2D

var enemies_container
var mission_complete = false
var target_enemy = null

# UI Elements
var lbl_objective: Label
var lbl_status: Label
var btn_return: Button
var btn_abort: Button
var stealth_rating: float = 100.0

func _ready():
	if GameManager.current_phase != "MISSION":
		GameManager.start_mission()
	setup_ui()
	enemies_container = get_node_or_null("Enemies")
	
	if enemies_container:
		# Only mark a special target when a contract is active.
		if GameManager.current_contract.size() > 0:
			setup_target()

func setup_ui():
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)
	
	# Mission HUD background
	var hud_bg = ColorRect.new()
	hud_bg.color = Color(0.05, 0.05, 0.1, 0.8)
	hud_bg.position = Vector2(0, 0)
	hud_bg.size = Vector2(350, 150)
	canvas_layer.add_child(hud_bg)
	
	# Objective Label
	lbl_objective = Label.new()
	lbl_objective.position = Vector2(20, 15)
	lbl_objective.add_theme_font_size_override("font_size", 18)
	lbl_objective.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	canvas_layer.add_child(lbl_objective)
	
	if GameManager.current_contract.size() > 0:
		lbl_objective.text = "🎯 TARGET: " + GameManager.current_contract["target"]
	else:
		lbl_objective.text = "🎯 ELIMINATE ALL ENEMIES"
	
	# Status Label
	lbl_status = Label.new()
	lbl_status.text = "STEALTH: ████████████"
	lbl_status.position = Vector2(20, 45)
	lbl_status.add_theme_font_size_override("font_size", 14)
	lbl_status.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	canvas_layer.add_child(lbl_status)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "[CTRL] Crouch | [1/2] Weapons | [B] Abort Mission"
	instructions.position = Vector2(20, 70)
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	canvas_layer.add_child(instructions)
	
	# ABORT MISSION Button - Always visible, LARGE and clickable
	btn_abort = Button.new()
	btn_abort.text = "✖ ABORT MISSION"
	btn_abort.position = Vector2(20, 100)
	btn_abort.custom_minimum_size = Vector2(180, 45)
	btn_abort.add_theme_font_size_override("font_size", 16)
	btn_abort.modulate = Color(1, 0.5, 0.5)
	btn_abort.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_abort.pressed.connect(_on_abort_pressed)
	canvas_layer.add_child(btn_abort)
	
	# Return Button (shown after completion)
	btn_return = Button.new()
	btn_return.text = "✓ RETURN TO SHOP"
	btn_return.position = Vector2(220, 100)
	btn_return.custom_minimum_size = Vector2(180, 45)
	btn_return.add_theme_font_size_override("font_size", 16)
	btn_return.visible = false
	btn_return.modulate = Color(0.5, 1, 0.5)
	btn_return.mouse_filter = Control.MOUSE_FILTER_STOP
	btn_return.pressed.connect(_on_return_pressed)
	canvas_layer.add_child(btn_return)
	
	# Money display
	var money_label = Label.new()
	money_label.text = "$" + str(GameManager.money)
	money_label.position = Vector2(1100, 20)
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	canvas_layer.add_child(money_label)

func setup_target():
	if enemies_container.get_child_count() > 0:
		var enemies = enemies_container.get_children()
		target_enemy = enemies.pick_random()
		target_enemy.is_target = true
		target_enemy.setup_visuals()

func _process(delta):
	if not mission_complete:
		update_stealth_display(delta)
		check_mission_status()

# Handle keyboard abort with 'B' key
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			_on_abort_pressed()

func update_stealth_display(delta: float):
	var spotted = false
	if enemies_container:
		for enemy in enemies_container.get_children():
			if enemy.state == enemy.State.CHASE or enemy.state == enemy.State.ALERT:
				spotted = true
				# Drain per second while spotted (frame-rate independent)
				stealth_rating = max(0.0, stealth_rating - (20.0 * delta))
				break
	
	if not spotted and stealth_rating < 100:
		# Recover slowly when hidden again
		stealth_rating = min(100.0, stealth_rating + (10.0 * delta))
	
	var bars = int(stealth_rating / 10.0)
	var bar_str = ""
	for i in range(10):
		bar_str += "█" if i < bars else "░"
	
	lbl_status.text = "STEALTH: " + bar_str
	
	if stealth_rating > 70:
		lbl_status.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
	elif stealth_rating > 30:
		lbl_status.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	else:
		lbl_status.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

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
	
	lbl_objective.text = "✓ MISSION COMPLETE"
	lbl_objective.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	
	# Award XP for mission completion
	GameManager.add_xp(50)
	GameManager.update_quest_progress("complete_mission", 1)
	
	# Bonus for stealth
	var stealth_bonus = int(stealth_rating / 10) * 10
	if stealth_bonus > 0:
		GameManager.add_money(stealth_bonus)
		lbl_status.text = "STEALTH BONUS: +$" + str(stealth_bonus) + " | +50 XP"
	else:
		lbl_status.text = "+50 XP"
	
	btn_abort.visible = false
	btn_return.visible = true

func _on_abort_pressed():
	# Abort without rewards
	GameManager.target_order_received = false
	GameManager.current_contract = {}
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")

func _on_return_pressed():
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")
