extends Node


var money: int = 0
var day: int = 1
var current_phase: String = "SHOP"


var xp: int = 0
var level: int = 1
const XP_PER_LEVEL: int = 50


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


var health: int = 100
var max_health: int = 100


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
		"weapon_scene": "res://Scenes/BobaDartGun.tscn",
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
		"weapon_scene": "res://Scenes/TapiocaLauncher.tscn",
		"tuning": {
			"projectile_speed": 680.0, "projectile_size": 15.0, "projectile_lifetime": 2.8,
			"spread_deg": 2.2, "projectile_color": Color(0.42, 0.27, 0.64),
			"recoil_distance": 10.0, "kick_rotation": 0.13, "kick_duration": 0.07, "recover_duration": 0.14,
			"flash_scale": Vector2(28, 16), "flash_color": Color(1.0, 0.75, 0.95, 0.95), "flash_duration": 0.11,
			"camera_shake": 4.0, "burst_color": Color(0.79, 0.64, 1.0), "sparkle_amount": 28,
			"cluster_count": 12, "cluster_spread_deg": 14.0
		}
	},
	"Poison Straw": {
		"damage": 8, "fire_rate": 0.6, "unlock_level": 4, "cost": 250, "type": "ranged",
		"weapon_scene": "res://Scenes/PoisonStraw.tscn",
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


var active_abilities: Dictionary = {
	"Shadow Dash": {
		"desc": "Dash forward at lightning speed",
		"cost": 0, "cooldown": 2.0,
		"color": Color(0.5, 0.8, 1.0)
	},
	"Smoke Bomb": {
		"desc": "Drop a smoke cloud that slows nearby enemies for 3s",
		"cost": 150, "cooldown": 5.0,
		"color": Color(0.6, 0.6, 0.7)
	},
	"Shuriken Burst": {
		"desc": "Fire 8 projectiles in a ring around you",
		"cost": 250, "cooldown": 4.0,
		"color": Color(0.9, 0.4, 0.4)
	},
	"Poison Cloud": {
		"desc": "Leave a poison zone that damages enemies over time",
		"cost": 400, "cooldown": 6.0,
		"color": Color(0.35, 0.95, 0.45)
	}
}

var passive_upgrades: Dictionary = {
	"Health Upgrade": {
		"desc": "Increases max health",
		"per_tier": "+25 HP",
		"costs": [75, 150, 300],
		"max_tier": 3,
		"color": Color(1.0, 0.7, 0.3)
	},
	"Speed Upgrade": {
		"desc": "Increases movement speed",
		"per_tier": "+30 speed",
		"costs": [75, 150, 300],
		"max_tier": 3,
		"color": Color(0.45, 0.72, 1.0)
	},
	"Damage Upgrade": {
		"desc": "Increases all damage dealt",
		"per_tier": "+0.25x damage",
		"costs": [100, 200, 400],
		"max_tier": 3,
		"color": Color(1.0, 0.35, 0.35)
	},
	"Cooldown Upgrade": {
		"desc": "Reduces ability cooldowns",
		"per_tier": "-0.3s cooldown",
		"costs": [100, 200, 400],
		"max_tier": 3,
		"color": Color(0.8, 0.5, 1.0)
	}
}

var owned_active_abilities: Array = ["Shadow Dash"]
var active_ability: String = "Shadow Dash"
var passive_tiers: Dictionary = {
	"Health Upgrade": 0,
	"Speed Upgrade": 0,
	"Damage Upgrade": 0,
	"Cooldown Upgrade": 0
}

var speed_bonus: float = 0.0
var max_health_bonus: int = 0
var cooldown_reduction: float = 0.0


var target_order_received: bool = false
var current_contract: Dictionary = {}
var contracts_completed: int = 0
var missions_completed: int = 0
var daily_earnings: int = 0
var customers_served_today: int = 0


var mission_profile: Dictionary = {}


var daily_quests: Array = []
var quest_progress: Dictionary = {}

var master_volume: float = 80.0
var sfx_volume: float = 80.0
var _sfx_bus_idx: int = -1

func _ready():
	print("GameManager initialized")
	_setup_audio_buses()
	setup_inputs()
	generate_daily_quests()

func _setup_audio_buses():
	_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if _sfx_bus_idx == -1:
		AudioServer.add_bus()
		_sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus_idx, "SFX")
		AudioServer.set_bus_send(_sfx_bus_idx, "Master")
	set_master_volume(master_volume)
	set_sfx_volume(sfx_volume)

func set_master_volume(value: float):
	master_volume = value
	_set_bus_volume("Master", value)

func set_sfx_volume(value: float):
	sfx_volume = value
	if _sfx_bus_idx == -1:
		_sfx_bus_idx = AudioServer.get_bus_index("SFX")
	if _sfx_bus_idx == -1:
		return
	_set_bus_volume("SFX", value)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

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
			

	if not InputMap.has_action("aim"):
		InputMap.add_action("aim")
		var ev_aim = InputEventMouseButton.new()
		ev_aim.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("aim", ev_aim)


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


func add_money(amount: int):
	money += amount
	daily_earnings += amount
	print("Money added: ", amount, " | Total: ", money)

func spend_money(amount: int) -> bool:
	if money >= amount:
		money -= amount
		update_quest_progress("spend_money", amount)
		return true
	return false


func add_reputation(amount: int):
	reputation += amount
	if reputation > shop_level * 100:
		shop_level += 1
		print("SHOP LEVEL UP! Level: ", shop_level)


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


func generate_daily_quests():
	var pool := QUEST_POOL.duplicate()
	pool.shuffle()
	daily_quests = []
	quest_progress = {}
	var count: int = mini(3, pool.size())
	for i in range(count):
		var q = pool[i].duplicate()
		q["completed"] = false
		q["desc"] = q["desc"] % q["target"]
		daily_quests.append(q)
		quest_progress[q["id"]] = 0

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


const MISSION_CATALOG := [
	{"type": "extermination", "label": "Street Sweep", "desc": "Clear out a back-alley hideout.",
	 "scene": "res://Scenes/MissionScene.tscn",
	 "reward_money": 60, "reward_xp": 40, "unlock_missions": 0,
	 "color": Color(0.45, 0.72, 1.0)},
	{"type": "timed_hunt", "label": "Warehouse Raid", "desc": "Storm the warehouse before reinforcements arrive.",
	 "scene": "res://Scenes/MissionScene2.tscn",
	 "reward_money": 100, "reward_xp": 70, "time_limit": 60.0, "unlock_missions": 1,
	 "color": Color(1.0, 0.7, 0.3)},
	{"type": "boss_hunt", "label": "Boss Takedown", "desc": "Infiltrate the arena and eliminate the boss.",
	 "scene": "res://Scenes/MissionScene3.tscn",
	 "reward_money": 160, "reward_xp": 110, "unlock_missions": 2,
	 "color": Color(1.0, 0.3, 0.4)},
	{"type": "survival", "label": "Last Stand", "desc": "Hold out against 3 waves in the compound.",
	 "scene": "res://Scenes/MissionScene4.tscn",
	 "reward_money": 200, "reward_xp": 140, "waves": 3, "time_limit": 120.0, "unlock_missions": 3,
	 "color": Color(0.7, 0.45, 1.0)},
]

func get_available_missions() -> Array:
	var result := []
	var total_done := contracts_completed + missions_completed
	for entry in MISSION_CATALOG:
		if total_done < entry.get("unlock_missions", 0):
			continue
		var card = entry.duplicate()
		card["tier"] = 1
		result.append(card)
	return result

## Returns the scene path for the current mission profile.
func get_mission_scene() -> String:
	var scene = mission_profile.get("scene", "")
	if scene != "":
		return scene
	# Fallback for contract missions — use the first available scene
	return "res://Scenes/MissionScene.tscn"

func build_mission_profile(type: String, tier: int, reward_money: int, reward_xp: int, time_limit: float = 0.0, contract_target: String = "", waves: int = 0) -> Dictionary:
	return {
		"type": type,
		"tier": tier,
		"time_limit": time_limit,
		"reward_money": reward_money,
		"reward_xp": reward_xp,
		"contract_target_name": contract_target,
		"waves": waves,
	}



func tier_difficulty_scale(tier: int) -> float:

	return 1.0 + (tier - 1) * 0.4

func tier_enemy_bonus_count(tier: int) -> int:

	return max(0, tier - 1) * 2


const QUEST_POOL := [
	{"id": "serve_customers", "desc": "Serve %d customers", "target": 5, "reward_xp": 25, "reward_money": 20},
	{"id": "earn_tips", "desc": "Earn $%d in tips", "target": 50, "reward_xp": 30, "reward_money": 25},
	{"id": "complete_mission", "desc": "Complete %d mission(s)", "target": 1, "reward_xp": 50, "reward_money": 50},
	{"id": "kill_enemies", "desc": "Defeat %d enemies in missions", "target": 10, "reward_xp": 40, "reward_money": 35},
	{"id": "boss_hunt", "desc": "Clear %d boss contract(s)", "target": 1, "reward_xp": 80, "reward_money": 75},
	{"id": "spend_money", "desc": "Spend $%d on upgrades", "target": 100, "reward_xp": 30, "reward_money": 0},
]


func start_mission():
	current_phase = "MISSION"
	print("Starting Mission Phase...")

func start_shop():
	current_phase = "SHOP"
	day += 1
	daily_earnings = 0
	customers_served_today = 0
	mission_profile = {}
	generate_daily_quests()
	print("Starting Shop Phase - Day ", day)

func end_day():
	print("Day ", day, " ended. Earnings: $", daily_earnings)

	var performance_xp = (customers_served_today * 5) + (daily_earnings / 10)
	add_xp(performance_xp)


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


func buy_ability(ability_name: String) -> bool:
	if ability_name in active_abilities and ability_name not in owned_active_abilities:
		var cost = active_abilities[ability_name]["cost"]
		if spend_money(cost):
			owned_active_abilities.append(ability_name)
			print("Purchased ability: ", ability_name)
			return true
	return false

func equip_ability(ability_name: String):
	if ability_name in owned_active_abilities:
		active_ability = ability_name
		print("Equipped ability: ", ability_name)

func upgrade_passive(passive_name: String) -> bool:
	if passive_name not in passive_upgrades:
		return false
	var current_tier = passive_tiers.get(passive_name, 0)
	var data = passive_upgrades[passive_name]
	if current_tier >= data["max_tier"]:
		return false
	var cost = data["costs"][current_tier]
	if spend_money(cost):
		passive_tiers[passive_name] = current_tier + 1
		_recalculate_passive_bonuses()
		print("Upgraded ", passive_name, " to tier ", current_tier + 1)
		return true
	return false

func _recalculate_passive_bonuses():
	speed_bonus = passive_tiers["Speed Upgrade"] * 30.0
	max_health_bonus = passive_tiers["Health Upgrade"] * 25
	player_damage_multiplier = 1.0 + (passive_tiers["Damage Upgrade"] * 0.25)
	cooldown_reduction = passive_tiers["Cooldown Upgrade"] * 0.3
	max_health = 100 + max_health_bonus
	if health > max_health:
		health = max_health

func get_ability_cooldown(ability_name: String) -> float:
	if ability_name in active_abilities:
		return max(0.5, active_abilities[ability_name]["cooldown"] - cooldown_reduction)
	return 2.0

func get_passive_next_cost(passive_name: String) -> int:
	var current_tier = passive_tiers.get(passive_name, 0)
	var data = passive_upgrades.get(passive_name, {})
	if current_tier >= data.get("max_tier", 3):
		return -1
	return data["costs"][current_tier]

func reset_game():

	health = max_health
	money = 0
	day = 1
	xp = 0
	level = 1
	current_phase = "SHOP"
	target_order_received = false
	current_contract = {}
	contracts_completed = 0
	missions_completed = 0
	daily_earnings = 0
	customers_served_today = 0
	mission_profile = {}
	reputation = 0
	shop_level = 1
	owned_weapons = ["Pistol", "Kitchen Knife", "Tapioca Launcher"]
	equipped_main = "Pistol"
	equipped_melee = "Kitchen Knife"
	equipped_special = "Tapioca Launcher"
	player_damage_multiplier = 1.0
	owned_active_abilities = ["Shadow Dash"]
	active_ability = "Shadow Dash"
	passive_tiers = {
		"Health Upgrade": 0,
		"Speed Upgrade": 0,
		"Damage Upgrade": 0,
		"Cooldown Upgrade": 0
	}
	speed_bonus = 0.0
	max_health_bonus = 0
	cooldown_reduction = 0.0
	max_health = 100
	generate_daily_quests()
	print("Game state fully reset")
