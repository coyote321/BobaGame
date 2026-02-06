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
	"Pistol": {"damage": 10, "fire_rate": 1.0, "unlock_level": 1, "cost": 0, "type": "ranged"},
	"Boba Dart Gun": {"damage": 15, "fire_rate": 0.8, "unlock_level": 2, "cost": 75, "type": "ranged"},
	"Kitchen Knife": {"damage": 25, "fire_rate": 0.5, "unlock_level": 1, "cost": 0, "type": "melee"},
	"Tapioca Launcher": {"damage": 20, "fire_rate": 1.2, "unlock_level": 3, "cost": 150, "type": "ranged"},
	"Poison Straw": {"damage": 40, "fire_rate": 2.0, "unlock_level": 4, "cost": 250, "type": "melee"}
}
var owned_weapons: Array = ["Pistol", "Kitchen Knife"]
var equipped_main: String = "Pistol"
var equipped_melee: String = "Kitchen Knife"
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
		else:
			equipped_melee = weapon_name
		print("Equipped: ", weapon_name)

func get_weapon_damage(weapon_name: String) -> float:
	if weapon_name in weapons:
		return weapons[weapon_name]["damage"] * player_damage_multiplier
	return 10.0
