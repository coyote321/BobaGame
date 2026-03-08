extends Node

# Currency & Time
var money: int = 0
var day: int = 1
var current_phase: String = "SHOP" # "SHOP" or "MISSION"

# Progression
var xp: int = 0
var level: int = 1
const XP_PER_LEVEL: int = 50  # XP needed to level up (multiplied by level)

# Shop Progression
var reputation: int = 0
var shop_level: int = 1
var unlocked_ingredients: Array = ["Black Tea", "Green Tea", "Milk", "Tapioca", "Sugar"]
var inventory: Dictionary = {
	"Black Tea": 999,
	"Green Tea": 999,
	"Milk": 999,
	"Tapioca": 100,
	"Sugar": 999
}

# Player stats
var health: int = 100
var max_health: int = 100

# Weapons System
var weapons: Dictionary = {
	"Pistol": {
		"damage": 10, "fire_rate": 0.4, "unlock_level": 1, "cost": 0, "type": "ranged",
		"weapon_scene": "res://Scenes/Pistol.tscn",
		"tuning": {
			"projectile_speed": 850.0, "projectile_size": 10.0, "projectile_lifetime": 2.2,
			"spread_deg": 1.5, "projectile_color": Color(1.0, 0.42, 0.55),
			"recoil_distance": 4.8, "kick_rotation": 0.06, "kick_duration": 0.05, "recover_duration": 0.08,
			"flash_scale": Vector2(18, 10), "flash_color": Color(1.0, 0.93, 0.6, 0.95), "flash_duration": 0.07,
			"camera_shake": 2.0, "burst_color": Color(1.0, 0.68, 0.82), "sparkle_amount": 18
		}
	},
	"Boba Dart Gun": {
		"damage": 10, "fire_rate": 0.8, "unlock_level": 2, "cost": 75, "type": "ranged",
		"tuning": {
			"projectile_speed": 950.0, "projectile_size": 8.0, "projectile_lifetime": 2.0,
			"spread_deg": 0.8, "projectile_color": Color(0.45, 0.98, 0.98),
			"recoil_distance": 3.0, "kick_rotation": 0.04, "kick_duration": 0.04, "recover_duration": 0.07,
			"flash_scale": Vector2(16, 8), "flash_color": Color(0.68, 1.0, 0.98, 0.95), "flash_duration": 0.06,
			"camera_shake": 1.4, "burst_color": Color(0.55, 1.0, 0.92), "sparkle_amount": 20,
			"poison_tick_damage": 1.0, "poison_ticks": 10, "poison_interval": 1.0
		}
	},
	"Kitchen Knife": {
		"damage": 25, "fire_rate": 0.5, "unlock_level": 1, "cost": 0, "type": "melee",
		"weapon_scene": "res://Scenes/KitchenKnife.tscn",
		"hold_offset": Vector2(40, 6),
		"tuning": {
			"melee_range": 120.0, "melee_arc_dot": 0.4, "lunge_distance": 10.0,
			"swing_rotation": 0.35, "kick_duration": 0.06, "recover_duration": 0.09,
			"flash_scale": Vector2(14, 7), "flash_color": Color(1.0, 0.95, 1.0, 0.75), "flash_duration": 0.06,
			"camera_shake": 1.8, "burst_color": Color(1.0, 0.85, 0.96), "sparkle_amount": 16
		}
	},
	"Tapioca Launcher": {
		"damage": 6, "fire_rate": 1.2, "unlock_level": 3, "cost": 150, "type": "special",
		"tuning": {
			"projectile_speed": 680.0, "projectile_size": 15.0, "projectile_lifetime": 2.8,
			"spread_deg": 2.2, "projectile_color": Color(0.42, 0.27, 0.64),
			"recoil_distance": 10.0, "kick_rotation": 0.13, "kick_duration": 0.07, "recover_duration": 0.14,
			"flash_scale": Vector2(28, 16), "flash_color": Color(1.0, 0.75, 0.95, 0.95), "flash_duration": 0.11,
			"camera_shake": 4.0, "burst_color": Color(0.79, 0.64, 1.0), "sparkle_amount": 28,
			"cluster_count": 5, "cluster_spread_deg": 8.0
		}
	},
	"Poison Straw": {
		"damage": 8, "fire_rate": 0.6, "unlock_level": 4, "cost": 250, "type": "ranged",
		"tuning": {
			"projectile_speed": 1000.0, "projectile_size": 7.0, "projectile_lifetime": 2.2,
			"spread_deg": 0.5, "projectile_color": Color(0.35, 0.95, 0.45),
			"recoil_distance": 2.5, "kick_rotation": 0.03, "kick_duration": 0.04, "recover_duration": 0.07,
			"flash_scale": Vector2(14, 7), "flash_color": Color(0.67, 1.0, 0.58, 0.85), "flash_duration": 0.06,
			"camera_shake": 1.2, "burst_color": Color(0.74, 1.0, 0.67), "sparkle_amount": 16,
			"poison_tick_damage": 3.0, "poison_ticks": 5, "poison_interval": 0.8
		}
	},
	"Flamethrower": {
		"damage": 5, "fire_rate": 0.05, "unlock_level": 1, "cost": 200, "type": "special",
		"weapon_scene": "res://Scenes/Flamethrower.tscn",
		"tuning": {
			"flame_speed": 320.0, "flame_lifetime": 0.45, "flame_spread_deg": 18.0,
			"recoil_distance": 2.0, "kick_rotation": 0.025, "kick_duration": 0.03, "recover_duration": 0.05,
			"flash_scale": Vector2(20, 12), "flash_color": Color(1.0, 0.66, 0.35, 0.85), "flash_duration": 0.05,
			"camera_shake": 1.0, "burst_color": Color(1.0, 0.74, 0.44), "sparkle_amount": 14
		}
	}
}
var owned_weapons: Array = ["Pistol", "Kitchen Knife", "Tapioca Launcher"]
var equipped_main: String = "Pistol"
var equipped_melee: String = "Kitchen Knife"
var equipped_special: String = "Tapioca Launcher"
var player_damage_multiplier: float = 1.0

# Mission/Contract System
var target_order_received: bool = false
var current_contract: Dictionary = {}
var contracts_completed: int = 0
var daily_earnings: int = 0
var customers_served_today: int = 0

# Daily Quests
var daily_quests: Array = []
var quest_progress: Dictionary = {}

func _ready():
	print("GameManager initialized")
	setup_inputs()
	generate_daily_quests()

func setup_inputs():
	var actions = {
		"move_up": KEY_W,
		"move_down": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"sprint": KEY_SHIFT,
		"crouch": KEY_CTRL,
		"pause": KEY_ESCAPE,
		"weapon_1": KEY_1,
		"weapon_2": KEY_2,
		"weapon_3": KEY_3,
		"ability": KEY_G,
		"interact": KEY_E
	}
	
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev = InputEventKey.new()
			ev.physical_keycode = actions[action]
			InputMap.action_add_event(action, ev)
			
	# Mouse inputs
	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var ev_aim = InputEventMouseButton.new()
		ev_aim.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", ev_aim)

# XP & Leveling
func add_xp(amount: int):
	xp += amount
	print("XP gained: ", amount, " | Total: ", xp)
	check_level_up()

func check_level_up():
	var xp_needed = level * XP_PER_LEVEL
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		print("LEVEL UP! Now level ", level)
		on_level_up()
		xp_needed = level * XP_PER_LEVEL

func on_level_up():
	# Unlock new ingredients based on level
	var level_unlocks = {
		2: "Honey",
		3: "Matcha",
		4: "Taro",
		5: "Brown Sugar"
	}
	if level in level_unlocks and level_unlocks[level] not in unlocked_ingredients:
		unlocked_ingredients.append(level_unlocks[level])
		inventory[level_unlocks[level]] = 50
		print("Unlocked ingredient: ", level_unlocks[level])

func get_xp_progress() -> float:
	var xp_needed = level * XP_PER_LEVEL
	return float(xp) / float(xp_needed)

# Money
func add_money(amount: int):
	money += amount
	daily_earnings += amount
	print("Money added: ", amount, " | Total: ", money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false

# Reputation
func add_reputation(amount: int):
	reputation += amount
	if reputation > shop_level * 100:
		shop_level += 1
		print("SHOP LEVEL UP! Level: ", shop_level)

# Contracts
func receive_contract(target_name: String, reward: int):
	current_contract = {
		"target": target_name,
		"reward": reward,
		"completed": false
	}
	target_order_received = true
	print("Contract received: Eliminate ", target_name, " for $", reward)

func complete_contract():
	if current_contract.size() > 0:
		add_money(current_contract.get("reward", 100))
		add_xp(50)
		contracts_completed += 1
		current_contract = {}
		target_order_received = false
		print("Contract completed! Total contracts: ", contracts_completed)

# Daily Quests
func generate_daily_quests():
	daily_quests = [
		{"id": "serve_customers", "desc": "Serve 5 customers", "target": 5, "reward_xp": 25, "reward_money": 20, "completed": false},
		{"id": "earn_tips", "desc": "Earn $50 in tips", "target": 50, "reward_xp": 30, "reward_money": 25, "completed": false},
		{"id": "complete_mission", "desc": "Complete a mission", "target": 1, "reward_xp": 50, "reward_money": 50, "completed": false}
	]
	quest_progress = {
		"serve_customers": 0,
		"earn_tips": 0,
		"complete_mission": 0
	}

func update_quest_progress(quest_id: String, amount: int):
	if quest_id in quest_progress:
		quest_progress[quest_id] += amount
		check_quest_completion(quest_id)

func check_quest_completion(quest_id: String):
	for quest in daily_quests:
		if quest["id"] == quest_id:
			if quest.get("completed", false):
				return
			if quest_progress[quest_id] >= quest["target"]:
				add_xp(quest["reward_xp"])
				add_money(quest["reward_money"])
				quest["completed"] = true
				print("Quest completed: ", quest["desc"])

# Phase transitions
func start_mission():
	current_phase = "MISSION"
	print("Starting Mission Phase...")

func start_shop():
	current_phase = "SHOP"
	day += 1
	daily_earnings = 0
	customers_served_today = 0
	generate_daily_quests()
	print("Starting Shop Phase - Day ", day)

func end_day():
	print("Day ", day, " ended. Earnings: $", daily_earnings)
	# XP bonus based on performance
	var performance_xp = (customers_served_today * 5) + (daily_earnings / 10)
	add_xp(performance_xp)

# Weapon Management
func get_available_weapons() -> Array:
	var available = []
	for weapon_name in weapons:
		if weapons[weapon_name]["unlock_level"] <= level:
			available.append(weapon_name)
	return available

func buy_weapon(weapon_name: String) -> bool:
	if weapon_name in weapons and weapon_name not in owned_weapons:
		var cost = weapons[weapon_name]["cost"]
		if spend_money(cost):
			owned_weapons.append(weapon_name)
			print("Purchased weapon: ", weapon_name)
			return true
	return false

func equip_weapon(weapon_name: String):
	if weapon_name in owned_weapons:
		var weapon_type = weapons[weapon_name]["type"]
		if weapon_type == "ranged":
			equipped_main = weapon_name
		elif weapon_type == "melee":
			equipped_melee = weapon_name
		elif weapon_type == "special":
			equipped_special = weapon_name
		print("Equipped: ", weapon_name)

func get_weapon_damage(weapon_name: String) -> float:
	if weapon_name in weapons:
		return weapons[weapon_name]["damage"] * player_damage_multiplier
	return 10.0

func reset_game():
	# Reset all game state for a fresh start
	health = max_health
	money = 0
	day = 1
	xp = 0
	level = 1
	current_phase = "SHOP"
	target_order_received = false
	current_contract = {}
	contracts_completed = 0
	daily_earnings = 0
	customers_served_today = 0
	reputation = 0
	shop_level = 1
	owned_weapons = ["Pistol", "Kitchen Knife", "Tapioca Launcher"]
	equipped_main = "Pistol"
	equipped_melee = "Kitchen Knife"
	equipped_special = "Tapioca Launcher"
	player_damage_multiplier = 1.0
	generate_daily_quests()
	print("Game state fully reset")
