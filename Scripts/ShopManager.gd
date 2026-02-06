extends Node2D

# Config
const SHIFT_DURATION: float = 120.0 # 2 minutes per day
const MAX_CUSTOMERS: int = 5
const CUSTOMER_SLOTS_Y: float = 350.0
const SLOT_SPACING: float = 120.0
const SLOT_START_X: float = 400.0

# State
var time_remaining: float = SHIFT_DURATION
var shift_active: bool = true
var active_customers: Array = []
var customer_slots_taken: Array = [false, false, false, false, false]
var current_mix: Array = []
var active_zone = null
var customers_spawned: int = 0

# UI References
@onready var ui_interaction = $UI_Layer/InteractionLabel
@onready var ui_boba_panel = $UI_Layer/BobaPanel
@onready var player = $Player
@onready var spawn_point = $CustomerSpawnPoint

# HUD Elements (created dynamically)
var hud_container: Control
var lbl_day: Label
var lbl_time: Label
var lbl_money: Label
var lbl_customers: Label
var lbl_xp: ProgressBar
var lbl_contract: Label

# Preload
var customer_scene = preload("res://Scenes/Customer.tscn")

func _ready():
	print("Shop Manager Started - Day ", GameManager.day)
	GameManager.current_phase = "SHOP"
	time_remaining = SHIFT_DURATION
	
	setup_hud()
	setup_zones()
	setup_boba_ui()
	
	start_spawning()

func _process(delta):
	if shift_active:
		time_remaining -= delta
		update_hud()
		
		if time_remaining <= 0:
			end_day()
			
	if active_zone and Input.is_action_just_pressed("interact"):
		interact_with_zone(active_zone)

# ============ HUD SYSTEM ============

func setup_hud():
	# Create HUD container
	hud_container = Control.new()
	hud_container.name = "HUD"
	hud_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	$UI_Layer.add_child(hud_container)
	
	# Background panel
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.06, 0.85)
	bg.position = Vector2(0, 0)
	bg.size = Vector2(1280, 70)
	hud_container.add_child(bg)
	
	# Day Label
	lbl_day = Label.new()
	lbl_day.position = Vector2(20, 10)
	lbl_day.add_theme_font_size_override("font_size", 28)
	lbl_day.add_theme_color_override("font_color", Color(0.95, 0.85, 0.7))
	hud_container.add_child(lbl_day)
	
	# Time Label
	lbl_time = Label.new()
	lbl_time.position = Vector2(20, 40)
	lbl_time.add_theme_font_size_override("font_size", 18)
	lbl_time.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hud_container.add_child(lbl_time)
	
	# Money Label
	lbl_money = Label.new()
	lbl_money.position = Vector2(250, 15)
	lbl_money.add_theme_font_size_override("font_size", 24)
	lbl_money.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	hud_container.add_child(lbl_money)
	
	# Customers served
	lbl_customers = Label.new()
	lbl_customers.position = Vector2(250, 42)
	lbl_customers.add_theme_font_size_override("font_size", 16)
	lbl_customers.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	hud_container.add_child(lbl_customers)
	
	# XP Progress Bar
	var xp_label = Label.new()
	xp_label.text = "LVL"
	xp_label.position = Vector2(500, 20)
	xp_label.add_theme_font_size_override("font_size", 14)
	hud_container.add_child(xp_label)
	
	lbl_xp = ProgressBar.new()
	lbl_xp.position = Vector2(540, 18)
	lbl_xp.size = Vector2(150, 25)
	lbl_xp.show_percentage = false
	hud_container.add_child(lbl_xp)
	
	# Contract indicator
	lbl_contract = Label.new()
	lbl_contract.position = Vector2(750, 20)
	lbl_contract.add_theme_font_size_override("font_size", 18)
	lbl_contract.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	lbl_contract.visible = false
	hud_container.add_child(lbl_contract)

func update_hud():
	if lbl_day:
		lbl_day.text = "DAY " + str(GameManager.day)
	if lbl_time:
		var mins = int(time_remaining / 60)
		var secs = int(time_remaining) % 60
		lbl_time.text = "Time: %02d:%02d" % [mins, secs]
		# Change color when low on time
		if time_remaining < 30:
			lbl_time.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		elif time_remaining < 60:
			lbl_time.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	if lbl_money:
		lbl_money.text = "$" + str(GameManager.money) + " (+$" + str(GameManager.daily_earnings) + " today)"
	if lbl_customers:
		lbl_customers.text = "Customers: " + str(GameManager.customers_served_today)
	if lbl_xp:
		lbl_xp.value = GameManager.get_xp_progress() * 100
	if lbl_contract:
		if GameManager.target_order_received:
			lbl_contract.visible = true
			lbl_contract.text = "🎯 CONTRACT AVAILABLE"
		else:
			lbl_contract.visible = false

# ============ CUSTOMER SYSTEM ============

func start_spawning():
	while shift_active:
		await get_tree().create_timer(randf_range(3.0, 8.0)).timeout
		if not shift_active: break
		
		if active_customers.size() < MAX_CUSTOMERS:
			spawn_customer()

func get_free_slot() -> int:
	for i in range(MAX_CUSTOMERS):
		if not customer_slots_taken[i]:
			return i
	return -1

func spawn_customer():
	if not spawn_point:
		print("No Spawn Point!")
		return
		
	var slot_index = get_free_slot()
	if slot_index == -1:
		return
		
	customer_slots_taken[slot_index] = true
	
	var cust = customer_scene.instantiate()
	var slot_x = SLOT_START_X + (slot_index * SLOT_SPACING)
	cust.position = Vector2(slot_x, CUSTOMER_SLOTS_Y)
	cust.set_meta("slot_index", slot_index)
	
	# FIRST customer is ALWAYS a secret agent, then 50% chance
	var is_first_customer = customers_spawned == 0
	if (is_first_customer or randf() < 0.5) and not GameManager.target_order_received:
		cust.is_secret_agent = true
		cust.set_meta("is_contract", true)
		print("SECRET AGENT SPAWNED!")
	
	customers_spawned += 1

	# Connect signals before adding to tree so we don't miss signals
	# emitted from the customer's `_ready()`.
	cust.customer_left.connect(_on_customer_left)
	cust.order_ready.connect(_on_customer_order)
	
	add_child(cust)
	active_customers.append(cust)

func _on_customer_left(customer):
	if customer in active_customers:
		active_customers.erase(customer)
		
		if customer.has_meta("slot_index"):
			var idx = customer.get_meta("slot_index")
			if idx >= 0 and idx < MAX_CUSTOMERS:
				customer_slots_taken[idx] = false
		
		if customer.satisfaction_score > 0:
			GameManager.add_reputation(customer.satisfaction_score * 10)
			GameManager.customers_served_today += 1
			GameManager.update_quest_progress("serve_customers", 1)
			
			# XP based on satisfaction (5-25 XP)
			var xp_reward = customer.satisfaction_score * 5
			GameManager.add_xp(xp_reward)
			
			var tip = customer.satisfaction_score * 2
			GameManager.add_money(tip)
			GameManager.update_quest_progress("earn_tips", tip)

func _on_customer_order(customer):
	print("Customer ordered: ", customer.order)
	
	# Handle secret agent order
	if customer.has_meta("is_contract") and customer.get_meta("is_contract"):
		show_contract_notification(customer)

func show_contract_notification(customer):
	var target_names = ["The Businessman", "The Senator", "The Dealer", "The Kingpin", "The Traitor"]
	var target = target_names.pick_random()
	var reward = randi_range(100, 250)
	
	GameManager.receive_contract(target, reward)
	
	# Flash notification
	var notif = Label.new()
	notif.text = "🦉 \"The owl flies at midnight...\"\nTarget: " + target
	notif.position = Vector2(400, 300)
	notif.add_theme_font_size_override("font_size", 24)
	notif.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	notif.z_index = 100
	add_child(notif)
	
	var tween = create_tween()
	tween.tween_property(notif, "modulate:a", 0.0, 3.0)
	tween.tween_callback(notif.queue_free)

# ============ ZONE INTERACTIONS ============

func interact_with_zone(zone_name):
	if zone_name == "counter":
		ui_boba_panel.visible = !ui_boba_panel.visible
		update_mix_label()
	elif zone_name == "upgrade":
		show_upgrade_panel()
	elif zone_name == "mission":
		show_mission_panel()

func setup_zones():
	if has_node("CounterZone"):
		$CounterZone.area_entered.connect(func(area): _set_zone("counter"))
		$CounterZone.area_exited.connect(func(area): _clear_zone())
	if has_node("UpgradeZone"):
		$UpgradeZone.area_entered.connect(func(area): _set_zone("upgrade"))
		$UpgradeZone.area_exited.connect(func(area): _clear_zone())
	if has_node("MissionZone"):
		$MissionZone.area_entered.connect(func(area): _set_zone("mission"))
		$MissionZone.area_exited.connect(func(area): _clear_zone())

func _set_zone(name):
	active_zone = name
	ui_interaction.text = "Press 'E' - " + name.capitalize()
	ui_interaction.visible = true

func _clear_zone():
	active_zone = null
	ui_interaction.visible = false
	# Close ALL panels when leaving any zone
	ui_boba_panel.visible = false
	var upgrade_panel = get_node_or_null("UI_Layer/UpgradePanel")
	if upgrade_panel:
		upgrade_panel.visible = false
	var mission_panel = get_node_or_null("UI_Layer/MissionPanel")
	if mission_panel:
		mission_panel.visible = false

# ============ UPGRADE/WEAPON SHOP ============

func show_upgrade_panel(toggle: bool = true):
	var panel = get_node_or_null("UI_Layer/UpgradePanel")
	if not panel:
		return
	if toggle:
		panel.visible = !panel.visible
	else:
		panel.visible = true
	
	# Clear and rebuild
	for child in panel.get_children():
		if child.name != "CloseUpgrade":
			child.queue_free()
	
	var title = Label.new()
	title.text = "WEAPON SHOP - Level " + str(GameManager.level)
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)
	
	var y_offset = 60
	var available_weapons = GameManager.get_available_weapons()
	
	for weapon_name in available_weapons:
		var weapon_data = GameManager.weapons[weapon_name]
		var owned = weapon_name in GameManager.owned_weapons
		var wn = weapon_name
		
		var row = HBoxContainer.new()
		row.position = Vector2(20, y_offset)
		panel.add_child(row)
		
		var lbl = Label.new()
		lbl.text = weapon_name + " (DMG: " + str(weapon_data["damage"]) + ")"
		lbl.custom_minimum_size = Vector2(180, 30)
		row.add_child(lbl)
		
		var btn = Button.new()
		if owned:
			btn.text = "EQUIP"
			btn.pressed.connect(func(weapon_to_equip = wn): GameManager.equip_weapon(weapon_to_equip))
		else:
			btn.text = "$" + str(weapon_data["cost"])
			btn.pressed.connect(func(weapon_to_buy = wn): 
				if GameManager.buy_weapon(weapon_to_buy):
					show_upgrade_panel(false)  # Refresh without closing
			)
		row.add_child(btn)
		
		y_offset += 35

# ============ MISSION PANEL ============

func show_mission_panel():
	var panel = get_node_or_null("UI_Layer/MissionPanel")
	if not panel:
		return
	panel.visible = !panel.visible
	
	for child in panel.get_children():
		if child.name != "CloseMission":
			child.queue_free()
	
	var title = Label.new()
	title.text = "CONTRACTS"
	title.position = Vector2(100, 20)
	title.add_theme_font_size_override("font_size", 22)
	panel.add_child(title)
	
	if GameManager.target_order_received and GameManager.current_contract.size() > 0:
		var contract_lbl = Label.new()
		contract_lbl.text = "Target: " + GameManager.current_contract["target"] + "\nReward: $" + str(GameManager.current_contract["reward"])
		contract_lbl.position = Vector2(40, 60)
		contract_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
		panel.add_child(contract_lbl)
		
		var btn = Button.new()
		btn.text = "START MISSION"
		btn.position = Vector2(80, 120)
		btn.custom_minimum_size = Vector2(140, 40)
		btn.modulate = Color(0.2, 1, 0.2)
		btn.pressed.connect(_on_start_mission)
		panel.add_child(btn)
	else:
		var no_contract = Label.new()
		no_contract.text = "No contract yet.\nServe customers to get one,\nor try Free Play!"
		no_contract.position = Vector2(40, 55)
		no_contract.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		panel.add_child(no_contract)
		
		# Always available: Free Play Mission
		var free_btn = Button.new()
		free_btn.text = "FREE PLAY MISSION"
		free_btn.position = Vector2(60, 120)
		free_btn.custom_minimum_size = Vector2(180, 40)
		free_btn.modulate = Color(0.5, 0.7, 1)
		free_btn.pressed.connect(_on_free_play_mission)
		panel.add_child(free_btn)

func _on_start_mission():
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")

func _on_free_play_mission():
	# Start mission without a contract - just practice
	GameManager.current_contract = {"target": "Practice Target", "reward": 50}
	GameManager.target_order_received = true
	GameManager.start_mission()
	get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")

# ============ BOBA CRAFTING ============

var lbl_mix: Label

func setup_boba_ui():
	var p = ui_boba_panel
	for c in p.get_children():
		# Godot 4: `name` is a StringName; convert before string ops.
		if str(c.name).begins_with("Close"):
			continue
		c.queue_free()
		
	var header = Label.new()
	header.text = "🧋 BOBA STATION"
	header.position = Vector2(130, 15)
	header.add_theme_font_size_override("font_size", 20)
	p.add_child(header)
	
	lbl_mix = Label.new()
	lbl_mix.position = Vector2(20, 60)
	lbl_mix.add_theme_color_override("font_color", Color(0.5, 0.8, 1))
	p.add_child(lbl_mix)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(30, 100)
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 8)
	p.add_child(grid)
	
	for ing in GameManager.unlocked_ingredients:
		var btn = Button.new()
		btn.text = "+ " + ing
		btn.custom_minimum_size = Vector2(160, 35)
		btn.pressed.connect(_add_to_mix.bind(ing))
		grid.add_child(btn)
		
	var serve_btn = Button.new()
	serve_btn.text = "SERVE"
	serve_btn.position = Vector2(40, 300)
	serve_btn.custom_minimum_size = Vector2(130, 50)
	serve_btn.modulate = Color.GREEN
	serve_btn.pressed.connect(_on_serve_drink)
	p.add_child(serve_btn)
	
	var clear_btn = Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.position = Vector2(220, 300)
	clear_btn.custom_minimum_size = Vector2(130, 50)
	clear_btn.modulate = Color.RED
	clear_btn.pressed.connect(func(): 
		current_mix = []
		update_mix_label()
	)
	p.add_child(clear_btn)

func _add_to_mix(ing):
	if current_mix.size() < 4:
		current_mix.append(ing)
		update_mix_label()

func update_mix_label():
	if lbl_mix:
		lbl_mix.text = "Mix: " + CraftingSystem.get_mix_description(current_mix)

func _on_serve_drink():
	var target_customer = null
	for c in active_customers:
		if c.is_waiting:
			target_customer = c
			break
	
	if target_customer:
		var created_drink = CraftingSystem.validate_mix(current_mix, target_customer.order)
		var success = target_customer.receive_item(created_drink)
		
		if success:
			current_mix = []
			update_mix_label()
			ui_boba_panel.visible = false
			GameManager.add_money(10)
			GameManager.add_xp(10)  # Base XP for serving

# ============ DAY END ============

func end_day():
	shift_active = false
	GameManager.end_day()
	show_day_summary()

func show_day_summary():
	var summary = Control.new()
	summary.set_anchors_preset(Control.PRESET_FULL_RECT)
	$UI_Layer.add_child(summary)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary.add_child(bg)
	
	var panel = VBoxContainer.new()
	panel.position = Vector2(440, 150)
	panel.add_theme_constant_override("separation", 15)
	summary.add_child(panel)
	
	var title = Label.new()
	title.text = "DAY " + str(GameManager.day) + " COMPLETE!"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	panel.add_child(title)
	
	var earnings = Label.new()
	earnings.text = "Earnings: $" + str(GameManager.daily_earnings)
	earnings.add_theme_font_size_override("font_size", 24)
	panel.add_child(earnings)
	
	var customers = Label.new()
	customers.text = "Customers Served: " + str(GameManager.customers_served_today)
	customers.add_theme_font_size_override("font_size", 20)
	panel.add_child(customers)
	
	var level = Label.new()
	level.text = "Level: " + str(GameManager.level) + " (XP: " + str(GameManager.xp) + "/" + str(GameManager.level * GameManager.XP_PER_LEVEL) + ")"
	level.add_theme_font_size_override("font_size", 20)
	panel.add_child(level)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	panel.add_child(spacer)
	
	var btn_container = HBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 30)
	panel.add_child(btn_container)
	
	if GameManager.target_order_received:
		var mission_btn = Button.new()
		mission_btn.text = "GO ON MISSION"
		mission_btn.custom_minimum_size = Vector2(180, 50)
		mission_btn.modulate = Color(1, 0.3, 0.3)
		mission_btn.pressed.connect(func(): 
			GameManager.start_mission()
			get_tree().change_scene_to_file("res://Scenes/MissionScene.tscn")
		)
		btn_container.add_child(mission_btn)
	
	var continue_btn = Button.new()
	continue_btn.text = "NEXT DAY"
	continue_btn.custom_minimum_size = Vector2(180, 50)
	continue_btn.pressed.connect(func():
		GameManager.start_shop()
		get_tree().reload_current_scene()
	)
	btn_container.add_child(continue_btn)
