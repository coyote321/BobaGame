extends Node


var money: int = 0
var day: int = 1
var current_phase: String = "SHOP"


var xp: int = 0
var level: int = 1
const XP_BASE: int = 100
const XP_GROWTH: int = 50

func get_xp_for_next_level(lvl: int = level) -> int:
	return XP_BASE + XP_GROWTH * (lvl - 1) * lvl


var reputation: int = 0
var shop_level: int = 1
const STARTING_INGREDIENTS := ["Black Tea", "Green Tea", "Milk", "Tapioca", "Sugar"]
const LEVEL_INGREDIENT_UNLOCKS := {
	2: "Honey",
	3: "Taro",
	4: "Brown Sugar"
}
const ALL_INGREDIENTS := ["Black Tea", "Green Tea", "Milk", "Tapioca", "Sugar", "Honey", "Taro", "Brown Sugar"]
const REMOVED_INGREDIENTS := ["Matcha"]
const STARTING_INVENTORY := {
	"Black Tea": 999,
	"Green Tea": 999,
	"Milk": 999,
	"Tapioca": 100,
	"Sugar": 999
}

var unlocked_ingredients: Array = STARTING_INGREDIENTS.duplicate()
var inventory: Dictionary = STARTING_INVENTORY.duplicate(true)


var health: int = 100
var max_health: int = 100


var weapons: Dictionary = {
	"Boba Gun": {
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
	"Whisk": {
		"damage": 25, "fire_rate": 0.5, "unlock_level": 1, "cost": 0, "type": "melee",
		"weapon_scene": "res://Scenes/KitchenKnife.tscn",
		"hold_offset": Vector2(40, 6),
		"tuning": {
			"melee_range": 120.0, "melee_arc_dot": 0.4, "lunge_distance": 10.0,
			"swing_rotation": 0.35, "kick_duration": 0.06, "recover_duration": 0.09,
			"flash_scale": Vector2(14, 7), "flash_color": Color(0.95, 0.9, 0.75, 0.75), "flash_duration": 0.06,
			"camera_shake": 1.8, "burst_color": Color(0.95, 0.86, 0.68), "sparkle_amount": 16
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
var owned_weapons: Array = ["Boba Gun", "Whisk", "Tapioca Launcher"]
var equipped_main: String = "Boba Gun"
var equipped_melee: String = "Whisk"
var equipped_special: String = "Tapioca Launcher"
var player_damage_multiplier: float = 1.0


var active_abilities: Dictionary = {
	"Shadow Dash": {
		"desc": "Dash forward at lightning speed",
		"cost": 0, "cooldown": 2.0, "unlock_level": 1,
		"color": Color(0.5, 0.8, 1.0)
	},
	"Smoke Bomb": {
		"desc": "Drop a smoke cloud that slows nearby enemies for 3s",
		"cost": 150, "cooldown": 5.0, "unlock_level": 2,
		"color": Color(0.6, 0.6, 0.7)
	},
	"Shuriken Burst": {
		"desc": "Fire 8 projectiles in a ring around you",
		"cost": 250, "cooldown": 4.0, "unlock_level": 3,
		"color": Color(0.9, 0.4, 0.4)
	},
	"Poison Cloud": {
		"desc": "Leave a poison zone that damages enemies over time",
		"cost": 400, "cooldown": 6.0, "unlock_level": 5,
		"color": Color(0.35, 0.95, 0.45)
	}
}

var passive_upgrades: Dictionary = {
	"Health Upgrade": {
		"desc": "Increases max health",
		"per_tier": "+25 HP",
		"costs": [75, 150, 300],
		"max_tier": 3,
		"unlock_level": 1,
		"color": Color(1.0, 0.7, 0.3)
	},
	"Speed Upgrade": {
		"desc": "Increases movement speed",
		"per_tier": "+30 speed",
		"costs": [75, 150, 300],
		"max_tier": 3,
		"unlock_level": 2,
		"color": Color(0.45, 0.72, 1.0)
	},
	"Damage Upgrade": {
		"desc": "Increases all damage dealt",
		"per_tier": "+0.25x damage",
		"costs": [100, 200, 400],
		"max_tier": 3,
		"unlock_level": 3,
		"color": Color(1.0, 0.35, 0.35)
	},
	"Cooldown Upgrade": {
		"desc": "Reduces ability cooldowns",
		"per_tier": "-0.3s cooldown",
		"costs": [100, 200, 400],
		"max_tier": 3,
		"unlock_level": 4,
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
## Live seconds remaining for timed missions; MissionManager writes, HUD reads. < 0 means no timer.
var mission_countdown_seconds: float = -1.0
var mission_aborting: bool = false


var daily_quests: Array = []
var quest_progress: Dictionary = {}

var master_volume: float = 80.0
var sfx_volume: float = 80.0
var _sfx_bus_idx: int = -1

# True after the player has dismissed the first-time kitchen tutorial overlay.
# Persists for the play session so the tutorial only shows once.
var tutorial_seen: bool = false


const ADMIN_TARGET_LEVEL: int = 99
const ADMIN_MONEY_GRANT: int = 999999
var admin_mode: bool = false
var _admin_snapshot: Dictionary = {}

const _AGENT_DEBUG_LOG_REL := "res://.cursor/debug-6f1b6e.log"
const _AGENT_DEBUG_INGEST := "http://127.0.0.1:7813/ingest/0aca1ad4-5c0c-40c7-aa6a-dc265157d894"

func _ready():
	print("GameManager initialized")
	remove_retired_ingredients()
	_setup_audio_buses()
	generate_daily_quests()
	#region agent log
	agent_debug_log("Scripts/GameManager.gd:_ready", "GameManager ready", {
		"current_phase": current_phase,
		"weapon_count": weapons.size(),
		"mission_count": MISSION_CATALOG.size(),
	}, "H6")
	#endregion

#region agent log
func agent_debug_log(location: String, message: String, data: Dictionary, hypothesis_id: String, run_id: String = "initial") -> void:
	var payload := {
		"sessionId": "6f1b6e",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var line := JSON.stringify(payload)
	# Godot nuance: `WRITE_READ` truncates existing files per open; use WRITE for create, READ_WRITE + seek_end to append.
	var attempted: Array[String] = []
	var ok_any := false
	var paths: PackedStringArray = PackedStringArray([
		ProjectSettings.globalize_path(_AGENT_DEBUG_LOG_REL),
		ProjectSettings.globalize_path("user://cursor_debug/debug-6f1b6e.log"),
	])
	for p in paths:
		attempted.append(p)
		var parent := p.get_base_dir()
		if parent.length() > 0:
			DirAccess.make_dir_recursive_absolute(parent)
		var f: FileAccess
		if FileAccess.file_exists(p):
			f = FileAccess.open(p, FileAccess.READ_WRITE)
			if f:
				f.seek_end()
		else:


			f = FileAccess.open(p, FileAccess.WRITE)
		if f:
			f.store_line(line)
			f.flush()
			f.close()
			ok_any = true
			break


	if not ok_any:
		push_error("agent_debug_log: file write FAILED; attempted=" + str(attempted) + "; err=" + str(FileAccess.get_open_error()))

	_agent_debug_notify_ingest(line)

func _agent_debug_notify_ingest(json_line: String) -> void:
	var http := HTTPRequest.new()
	http.timeout = 3
	add_child(http)
	http.request_completed.connect(func(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		http.queue_free()
	)
	var err := http.request(
		_AGENT_DEBUG_INGEST,
		PackedStringArray(["Content-Type: application/json", "X-Debug-Session-Id: 6f1b6e"]),
		HTTPClient.METHOD_POST,
		json_line
	)
	if err != OK:
		http.queue_free()
#endregion

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_A:
			toggle_admin()
			get_viewport().set_input_as_handled()

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

func add_xp(amount: int):
	xp += amount
	print("XP gained: ", amount, " | Total: ", xp)
	check_level_up()

func check_level_up():
	var xp_needed = get_xp_for_next_level()
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		print("LEVEL UP! Now level ", level)
		on_level_up()
		xp_needed = get_xp_for_next_level()

func on_level_up():
	if level in LEVEL_INGREDIENT_UNLOCKS and LEVEL_INGREDIENT_UNLOCKS[level] not in unlocked_ingredients:
		var ingredient = LEVEL_INGREDIENT_UNLOCKS[level]
		unlocked_ingredients.append(ingredient)
		inventory[ingredient] = 50
		print("Unlocked ingredient: ", ingredient)

func remove_retired_ingredients() -> void:
	for ing in REMOVED_INGREDIENTS:
		unlocked_ingredients.erase(ing)
		inventory.erase(ing)

func get_level_available_ingredients(lvl: int = level) -> Array:
	var available := STARTING_INGREDIENTS.duplicate()
	var unlock_levels := LEVEL_INGREDIENT_UNLOCKS.keys()
	unlock_levels.sort()
	for unlock_level in unlock_levels:
		if lvl < int(unlock_level):
			continue
		var ingredient: String = LEVEL_INGREDIENT_UNLOCKS[unlock_level]
		if ingredient not in available and ingredient not in REMOVED_INGREDIENTS:
			available.append(ingredient)
	return available

func get_orderable_ingredients() -> Array:
	var level_available := get_level_available_ingredients()
	var orderable := []
	for ingredient in unlocked_ingredients:
		if ingredient in level_available and ingredient not in REMOVED_INGREDIENTS:
			orderable.append(ingredient)
	return orderable if not orderable.is_empty() else STARTING_INGREDIENTS.duplicate()

func unlock_all_ingredients(amount: int = 999) -> void:
	remove_retired_ingredients()
	for ing in ALL_INGREDIENTS:
		if ing not in unlocked_ingredients:
			unlocked_ingredients.append(ing)
		inventory[ing] = amount

func get_xp_progress() -> float:
	var xp_needed = get_xp_for_next_level()
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


const CONTRACT_POOL := [
	{
		"target": "The Businessman",
		"desc": "Back-alley hit on a corrupt exec.",
		"scene": "res://Scenes/MissionScene.tscn",
		"mission_type": "extermination",
		"reward_min": 120, "reward_max": 180,
		"time_limit": 0.0, "waves": 0,
	},
	{
		"target": "The Senator",
		"desc": "Storm the warehouse before his detail arrives.",
		"scene": "res://Scenes/MissionScene2.tscn",
		"mission_type": "timed_hunt",
		"reward_min": 160, "reward_max": 240,
		"time_limit": 90.0, "waves": 0,
	},
	{
		"target": "The Kingpin",
		"desc": "Crime lord holed up in his blood arena.",
		"scene": "res://Scenes/MissionScene3.tscn",
		"mission_type": "boss_hunt",
		"reward_min": 220, "reward_max": 320,
		"time_limit": 0.0, "waves": 0,
	},
	{
		"target": "The Traitor",
		"desc": "Hold the compound until the defector is caught.",
		"scene": "res://Scenes/MissionScene4.tscn",
		"mission_type": "survival",
		"reward_min": 200, "reward_max": 280,
		"time_limit": 120.0, "waves": 3,
	},
]

func generate_random_contract() -> Dictionary:
	var template: Dictionary = CONTRACT_POOL.pick_random()
	var reward: int = randi_range(
		int(template.get("reward_min", 100)),
		int(template.get("reward_max", 200))
	)
	return {
		"target": template["target"],
		"desc": template.get("desc", ""),
		"scene": template["scene"],
		"mission_type": template["mission_type"],
		"time_limit": float(template.get("time_limit", 0.0)),
		"waves": int(template.get("waves", 0)),
		"reward": reward,
		"completed": false,
	}

func receive_contract(data) -> void:
	# Accept either a full contract dictionary (new flow) or a
	# target_name/reward pair (legacy). When called with a String,
	# build a minimal contract that falls back to the first mission.
	if data is Dictionary:
		current_contract = (data as Dictionary).duplicate()
	else:
		var target_name: String = str(data)
		current_contract = {
			"target": target_name,
			"desc": "Eliminate the target.",
			"scene": "res://Scenes/MissionScene.tscn",
			"mission_type": "extermination",
			"time_limit": 0.0,
			"waves": 0,
			"reward": 100,
			"completed": false,
		}
	current_contract["completed"] = false
	target_order_received = true
	print("Contract received: Eliminate ",
		current_contract.get("target", "?"),
		" for $", current_contract.get("reward", 0))

func complete_contract():
	if current_contract.size() > 0:
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
	{"type": "boss_hunt", "label": "Reactor Breach", "desc": "Eliminate the rogue Chief Engineer and avoid radioactive sludge.",
	 "scene": "res://Scenes/MissionScene5.tscn",
	 "reward_money": 500, "reward_xp": 360, "unlock_missions": 4, "tier": 3,
	 "is_final_mission": true,
	 "story_pages": [
		{"title": "THE WASTELAND GATE", "body": "Every contract points to the same dead horizon: the abandoned nuclear plant beyond town. The air glows. The ground has split. Nothing grows there except fear."},
		{"title": "THE REACTOR OVERLORD", "body": "The Chief Engineer was never just a rogue worker. He became a giant reactor-fed tyrant, using the plant to power every gang, every bribe, every weapon pointed at your town."},
		{"title": "RESTORE THE TOWN", "body": "Cut through the wasteland, breach the reactor yard, and defeat him. If the Overlord falls, the city can breathe again."},
	 ],
	 "color": Color(0.55, 0.95, 0.35)},
]

func get_available_missions() -> Array:
	var result := []
	var total_done := contracts_completed + missions_completed
	for entry in MISSION_CATALOG:
		if total_done < entry.get("unlock_missions", 0):
			continue
		var card = entry.duplicate()
		card["tier"] = int(entry.get("tier", 1))
		result.append(card)
	return result

## Returns the scene path for the current mission profile.
func get_mission_scene() -> String:
	var scene = mission_profile.get("scene", "")
	if scene != "":
		return scene
	# Fallback for contract missions — use the first available scene
	return "res://Scenes/MissionScene.tscn"

func build_mission_profile(type: String, tier: int, reward_money: int, reward_xp: int, time_limit: float = 0.0, contract_target: String = "", waves: int = 0, scene: String = "") -> Dictionary:
	var profile := {
		"type": type,
		"tier": tier,
		"time_limit": time_limit,
		"reward_money": reward_money,
		"reward_xp": reward_xp,
		"contract_target_name": contract_target,
		"waves": waves,
		"scene": scene,
	}
	#region agent log
	agent_debug_log("Scripts/GameManager.gd:build_mission_profile", "Mission profile built", profile.duplicate(), "H2,H3")
	#endregion
	return profile



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
	mission_aborting = false
	current_phase = "MISSION"
	print("Starting Mission Phase...")

func start_shop(clear_abort_state: bool = true):
	current_phase = "SHOP"
	day += 1
	daily_earnings = 0
	customers_served_today = 0
	mission_profile = {}
	mission_countdown_seconds = -1.0
	generate_daily_quests()
	if clear_abort_state:
		mission_aborting = false
	print("Starting Shop Phase - Day ", day)

func abort_mission_to_shop() -> void:
	mission_aborting = true
	target_order_received = false
	current_contract = {}
	mission_profile = {}
	start_shop(false)
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")

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


func get_available_abilities() -> Array:
	var available := []
	for ability_name in active_abilities:
		if int(active_abilities[ability_name].get("unlock_level", 1)) <= level:
			available.append(ability_name)
	return available

func is_ability_unlocked(ability_name: String) -> bool:
	if ability_name not in active_abilities:
		return false
	return int(active_abilities[ability_name].get("unlock_level", 1)) <= level

func buy_ability(ability_name: String) -> bool:
	if ability_name in active_abilities and ability_name not in owned_active_abilities:
		if not is_ability_unlocked(ability_name):
			print("Ability locked: ", ability_name)
			return false
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

func get_available_passives() -> Array:
	var available := []
	for passive_name in passive_upgrades:
		if int(passive_upgrades[passive_name].get("unlock_level", 1)) <= level:
			available.append(passive_name)
	return available

func is_passive_unlocked(passive_name: String) -> bool:
	if passive_name not in passive_upgrades:
		return false
	return int(passive_upgrades[passive_name].get("unlock_level", 1)) <= level

func upgrade_passive(passive_name: String) -> bool:
	if passive_name not in passive_upgrades:
		return false
	if not is_passive_unlocked(passive_name):
		print("Passive locked: ", passive_name)
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
	mission_aborting = false
	target_order_received = false
	current_contract = {}
	contracts_completed = 0
	missions_completed = 0
	daily_earnings = 0
	customers_served_today = 0
	mission_profile = {}
	mission_countdown_seconds = -1.0
	reputation = 0
	shop_level = 1
	unlocked_ingredients = STARTING_INGREDIENTS.duplicate()
	inventory = STARTING_INVENTORY.duplicate(true)
	remove_retired_ingredients()
	owned_weapons = ["Boba Gun", "Whisk", "Tapioca Launcher"]
	equipped_main = "Boba Gun"
	equipped_melee = "Whisk"
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
	tutorial_seen = false
	generate_daily_quests()
	print("Game state fully reset")


func toggle_admin() -> void:
	if admin_mode:
		revoke_admin()
	else:
		grant_admin()

func grant_admin() -> void:
	if admin_mode:
		print("[ADMIN] Already active")
		return

	_admin_snapshot = {
		"level": level,
		"xp": xp,
		"money": money,
		"reputation": reputation,
		"shop_level": shop_level,
		"unlocked_ingredients": unlocked_ingredients.duplicate(true),
		"inventory": inventory.duplicate(true),
		"owned_weapons": owned_weapons.duplicate(true),
		"equipped_main": equipped_main,
		"equipped_melee": equipped_melee,
		"equipped_special": equipped_special,
		"owned_active_abilities": owned_active_abilities.duplicate(true),
		"active_ability": active_ability,
		"passive_tiers": passive_tiers.duplicate(true),
		"health": health,
		"max_health": max_health,
		"player_damage_multiplier": player_damage_multiplier,
		"speed_bonus": speed_bonus,
		"max_health_bonus": max_health_bonus,
		"cooldown_reduction": cooldown_reduction,
	}

	level = ADMIN_TARGET_LEVEL
	xp = 0
	money = ADMIN_MONEY_GRANT

	unlock_all_ingredients()

	for weapon_name in weapons.keys():
		if weapon_name not in owned_weapons:
			owned_weapons.append(weapon_name)

	for ability_name in active_abilities.keys():
		if ability_name not in owned_active_abilities:
			owned_active_abilities.append(ability_name)

	for passive_name in passive_upgrades.keys():
		passive_tiers[passive_name] = passive_upgrades[passive_name]["max_tier"]
	_recalculate_passive_bonuses()
	health = max_health

	admin_mode = true
	print("[ADMIN] Enabled — level ", level, ", $", money, ", all weapons/abilities/ingredients unlocked, passives maxed. Press Ctrl+Shift+A again to revoke.")

func revoke_admin() -> void:
	if not admin_mode:
		print("[ADMIN] Not active")
		return
	if _admin_snapshot.is_empty():
		admin_mode = false
		print("[ADMIN] No snapshot to restore; flag cleared")
		return

	level = _admin_snapshot["level"]
	xp = _admin_snapshot["xp"]
	money = _admin_snapshot["money"]
	reputation = _admin_snapshot["reputation"]
	shop_level = _admin_snapshot["shop_level"]
	unlocked_ingredients = _admin_snapshot["unlocked_ingredients"].duplicate(true)
	inventory = _admin_snapshot["inventory"].duplicate(true)
	remove_retired_ingredients()
	owned_weapons = _admin_snapshot["owned_weapons"].duplicate(true)
	equipped_main = _admin_snapshot["equipped_main"]
	equipped_melee = _admin_snapshot["equipped_melee"]
	equipped_special = _admin_snapshot["equipped_special"]
	owned_active_abilities = _admin_snapshot["owned_active_abilities"].duplicate(true)
	active_ability = _admin_snapshot["active_ability"]
	passive_tiers = _admin_snapshot["passive_tiers"].duplicate(true)
	_recalculate_passive_bonuses()
	max_health = _admin_snapshot["max_health"]
	health = mini(_admin_snapshot["health"], max_health)
	player_damage_multiplier = _admin_snapshot["player_damage_multiplier"]
	speed_bonus = _admin_snapshot["speed_bonus"]
	max_health_bonus = _admin_snapshot["max_health_bonus"]
	cooldown_reduction = _admin_snapshot["cooldown_reduction"]

	_admin_snapshot.clear()
	admin_mode = false
	print("[ADMIN] Revoked — previous progress restored")
