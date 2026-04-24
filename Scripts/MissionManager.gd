extends Node2D

var enemies_container: Node2D
var mission_complete: bool = false
var mission_failed: bool = false
var target_enemy: Node = null
var stealth_rating: float = 100.0
var initial_enemy_count: int = 0
var spawn_bounds: Rect2 = Rect2(150, 120, 950, 480)
var live_enemy_count: int = 0
var _tracked_enemies: Dictionary = {}


var mission_type: String = "extermination"
var mission_tier: int = 1
var time_remaining: float = -1.0
var waves_total: int = 0
var waves_spawned: int = 0
var wave_spawn_timer: float = 0.0
var reward_money: int = 60
var reward_xp: int = 40


var hud = null


var _enemy_scene: PackedScene = preload("res://Scenes/Enemy.tscn")
var _tank_scene: PackedScene = preload("res://Scenes/Enemy2.tscn")
var _elite_scene: PackedScene = preload("res://Scenes/EnemyElite.tscn")

func _ready():
	if GameManager.current_phase != "MISSION":
		GameManager.start_mission()

	enemies_container = get_node_or_null("Enemies")


	var profile: Dictionary = GameManager.mission_profile
	if profile.size() > 0:
		mission_type = profile.get("type", "extermination")
		mission_tier = int(profile.get("tier", 1))
		time_remaining = float(profile.get("time_limit", 0.0))
		if time_remaining <= 0.0:
			time_remaining = -1.0
		waves_total = int(profile.get("waves", 0))
		reward_money = int(profile.get("reward_money", 60))
		reward_xp = int(profile.get("reward_xp", 40))

	await get_tree().process_frame
	hud = find_child("HUD", true, false)
	if hud:
		hud.connect_buttons(_on_abort_pressed, _on_return_pressed)

	_apply_mission_setup()

	if hud and hud.has_method("update_objective"):
		hud.update_objective(_objective_text())

func _apply_mission_setup() -> void:
	if not enemies_container:
		return

	_compute_spawn_bounds()

	var extras := GameManager.tier_enemy_bonus_count(mission_tier)
	for i in range(extras):
		_spawn_extra_enemy(false)


	var scale := GameManager.tier_difficulty_scale(mission_tier)
	for enemy in enemies_container.get_children():
		_apply_difficulty_scale(enemy, scale)

	match mission_type:
		"extermination":
			if GameManager.current_contract.size() > 0:
				setup_target()
		"timed_hunt":
			if GameManager.current_contract.size() > 0:
				setup_target()
		"boss_hunt":
			_setup_boss()
		"survival":

			for enemy in enemies_container.get_children():
				enemy.queue_free()
			await get_tree().process_frame
			_reset_enemy_tracking()
			_spawn_wave()

	for enemy in enemies_container.get_children():
		_connect_enemy(enemy)
	initial_enemy_count = live_enemy_count

func _apply_difficulty_scale(enemy: Node, scale: float) -> void:
	if not enemy:
		return
	if "max_health" in enemy:
		enemy.max_health = enemy.max_health * scale
	if "health" in enemy:
		enemy.health = enemy.health * scale
	if "attack_damage" in enemy:
		enemy.attack_damage = enemy.attack_damage * scale
	if enemy.has_method("setup_visuals"):
		enemy.setup_visuals()

func _spawn_extra_enemy(is_tank: bool) -> void:
	var scene: PackedScene
	if is_tank:
		scene = _tank_scene
	elif mission_tier >= 2 and randf() < 0.5:
		scene = _elite_scene
	else:
		scene = _enemy_scene
	var e = scene.instantiate()
	e.position = _random_spawn_point()
	enemies_container.add_child(e)

	_apply_difficulty_scale(e, GameManager.tier_difficulty_scale(mission_tier))
	_connect_enemy(e)

func _connect_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	if enemy.has_meta("mission_tracked"):
		return
	enemy.set_meta("mission_tracked", true)
	if _is_living_enemy(enemy):
		live_enemy_count += 1
		_tracked_enemies[enemy.get_instance_id()] = true
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)
	enemy.tree_exited.connect(_on_enemy_tree_exited.bind(enemy))

func _on_enemy_died(enemy) -> void:
	_untrack_enemy(enemy)
	call_deferred("check_mission_status")

func _on_enemy_tree_exited(enemy) -> void:
	_untrack_enemy(enemy)
	call_deferred("check_mission_status")

func _untrack_enemy(enemy) -> void:
	if not enemy:
		return
	var id: int = enemy.get_instance_id()
	if not _tracked_enemies.has(id):
		return
	_tracked_enemies.erase(id)
	live_enemy_count = maxi(live_enemy_count - 1, 0)

func _reset_enemy_tracking() -> void:
	live_enemy_count = 0
	_tracked_enemies.clear()

func _compute_spawn_bounds() -> void:
	# Auto-fit spawn bounds to the scene's starting enemies so larger maps
	# populate waves across the whole playable area instead of a fixed box.
	if not enemies_container or enemies_container.get_child_count() == 0:
		return
	var bb := Rect2()
	var first := true
	for child in enemies_container.get_children():
		if not child is Node2D:
			continue
		var p: Vector2 = child.position
		if first:
			bb = Rect2(p, Vector2.ZERO)
			first = false
		else:
			bb = bb.expand(p)
	if first:
		return
	bb = bb.grow(180.0)
	spawn_bounds = bb

func _random_spawn_point() -> Vector2:
	var r := spawn_bounds
	return Vector2(
		randf_range(r.position.x, r.position.x + r.size.x),
		randf_range(r.position.y, r.position.y + r.size.y)
	)

func _setup_boss() -> void:
	var children := enemies_container.get_children()
	if children.size() == 0:
		_spawn_extra_enemy(true)
		children = enemies_container.get_children()
	var boss = children[0]
	boss.is_target = true
	if "max_health" in boss:
		boss.max_health = boss.max_health * 3.5
	if "health" in boss:
		boss.health = boss.max_health if "max_health" in boss else boss.health * 3.5
	if "attack_damage" in boss:
		boss.attack_damage = boss.attack_damage * 1.8
	if "scale" in boss:
		boss.scale = Vector2(1.5, 1.5)
	if boss.has_method("setup_visuals"):
		boss.setup_visuals()
	target_enemy = boss

func _spawn_wave() -> void:
	waves_spawned += 1
	var tanks: int = 0 if waves_spawned == 1 else mini(2, waves_spawned - 1)
	var grunts: int = 3 + waves_spawned
	var elites: int = 0
	if mission_tier >= 2:
		elites = mini(waves_spawned, 3)
		grunts = maxi(grunts - elites, 2)
	for i in range(grunts):
		_spawn_extra_enemy(false)
	for i in range(elites):
		var e = _elite_scene.instantiate()
		e.position = _random_spawn_point()
		enemies_container.add_child(e)
		_apply_difficulty_scale(e, GameManager.tier_difficulty_scale(mission_tier))
		_connect_enemy(e)
	for i in range(tanks):
		_spawn_extra_enemy(true)

func setup_target():
	if enemies_container.get_child_count() > 0:
		var enemies = enemies_container.get_children()
		target_enemy = enemies.pick_random()
		target_enemy.is_target = true
		if target_enemy.has_method("setup_visuals"):
			target_enemy.setup_visuals()

func _objective_text() -> String:
	match mission_type:
		"extermination":
			return "ELIMINATE ALL ENEMIES"
		"timed_hunt":
			return "CLEAR ALL ENEMIES — BEAT THE CLOCK"
		"boss_hunt":
			return "DEFEAT THE BOSS"
		"survival":
			return "SURVIVE %d WAVES" % waves_total
	return "ELIMINATE ALL ENEMIES"

func _process(delta):
	if mission_complete or mission_failed:
		return

	update_stealth(delta)
	update_timer(delta)
	_tick_survival(delta)
	check_mission_status()
	_update_hud_counters()

func update_timer(delta: float) -> void:
	if time_remaining < 0.0:
		if hud and hud.has_method("update_timer"):
			hud.update_timer(-1.0)
		return
	time_remaining -= delta
	if hud and hud.has_method("update_timer"):
		hud.update_timer(time_remaining)
	if time_remaining <= 0.0:
		time_remaining = 0.0
		if mission_type == "survival":

			on_mission_complete()
		else:
			on_mission_failed("TIME UP")

func _tick_survival(delta: float) -> void:
	if mission_type != "survival":
		return
	wave_spawn_timer -= delta
	var living := _living_enemy_count()
	if living == 0 and waves_spawned < waves_total:
		wave_spawn_timer = 2.0
		_spawn_wave()
	elif waves_spawned < waves_total and wave_spawn_timer <= 0.0:

		if living < 3:
			wave_spawn_timer = 30.0
			_spawn_wave()

func _update_hud_counters() -> void:
	if not hud or not hud.has_method("update_enemy_count"):
		return
	if enemies_container:
		var remaining := _living_enemy_count()
		var total := initial_enemy_count
		if mission_type == "survival":
			total = max(total, remaining + (waves_total - waves_spawned) * 4)
		hud.update_enemy_count(remaining, max(total, remaining))

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

	if hud and hud.has_method("update_stealth"):
		hud.update_stealth(stealth_rating)

func check_mission_status():
	if mission_complete or mission_failed:
		return

	var living := _living_enemy_count()

	match mission_type:
		"boss_hunt":
			if _is_target_defeated():
				on_mission_complete()
				return
			if living == 0:
				on_mission_complete()
		"extermination", "timed_hunt":
			if _is_target_defeated():
				on_mission_complete()
				return
			if living == 0:
				on_mission_complete()
		"survival":
			if waves_spawned >= waves_total and living == 0:
				on_mission_complete()

func _is_target_defeated() -> bool:
	if target_enemy == null:
		return false
	if not is_instance_valid(target_enemy):
		return true
	if "is_dead" in target_enemy and target_enemy.is_dead:
		return true
	return false

func _living_enemy_count() -> int:
	return live_enemy_count

func _is_living_enemy(enemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy.is_queued_for_deletion():
		return false
	if "is_dead" in enemy and enemy.is_dead:
		return false
	return true

func on_mission_complete():
	if mission_complete or mission_failed:
		return

	mission_complete = true


	GameManager.add_xp(reward_xp)
	GameManager.add_money(reward_money)
	GameManager.missions_completed += 1
	GameManager.update_quest_progress("complete_mission", 1)
	if mission_type == "boss_hunt":
		GameManager.update_quest_progress("boss_hunt", 1)

	var stealth_bonus = int(stealth_rating / 10) * 10
	if stealth_bonus > 0:
		GameManager.add_money(stealth_bonus)

	if GameManager.current_contract.size() > 0:
		GameManager.complete_contract()

	if hud and hud.has_method("show_mission_complete"):
		hud.show_mission_complete(stealth_bonus)

func on_mission_failed(reason: String):
	if mission_complete or mission_failed:
		return
	mission_failed = true
	if hud and hud.has_method("show_mission_failed"):
		hud.show_mission_failed(reason)

func _on_abort_pressed():
	GameManager.target_order_received = false
	GameManager.current_contract = {}
	GameManager.mission_profile = {}
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")

func _on_return_pressed():
	GameManager.start_shop()
	get_tree().change_scene_to_file("res://Scenes/ShopScene.tscn")
