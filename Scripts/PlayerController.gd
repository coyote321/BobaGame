extends CharacterBody2D

var speed = 200
var sprint_speed = 350
var crouch_speed = 100
var aim_speed_penalty = 0.5
var health = 100

var is_crouching = false
var is_aiming = false

const WALK_FRAME_RATE := 10.0
## Target drawn height (px) for one sprite cell; scales sheet rows of different resolutions consistently.
const CHARACTER_TARGET_HEIGHT_PX := 240.0
const CHARACTER_CROUCH_MULTIPLIER := 0.8

# Reference to external HUD
var hud_node = null

# Weapon State
var current_weapon_idx = 1 # 1 = Main, 2 = Melee, 3 = Special

var fire_cooldown = 0.0
var ability_cooldown = 0.0

@export var projectile_scene: PackedScene

var _damage_sfx: AudioStreamPlayer = null
var _heartbeat_sfx: AudioStreamPlayer = null
var _death_sfx: AudioStreamPlayer = null

var _current_weapon_node: Node2D = null
var _weapon_scene_cache: Dictionary = {}
var _crosshair: Node2D = null
var _walk_frame_time := 0.0
var _character_base_scale := Vector2(0.11, 0.11)

var _agent_physics_logged := false

@onready var _character_root := get_node_or_null("Character") as Node2D
@onready var _character_sprite := get_node_or_null("Character/CharacterSprite") as Sprite2D

#region agent log
const _AGENT_LOG_PATH := "/Users/s/Documents/GitHub/BobaGame/.cursor/debug-2bc24f.log"

func _agent_log(hypothesis_id: String, location: String, message: String, data: Dictionary, run_id: String = "pre-fix") -> void:
	var line := {
		"sessionId": "2bc24f",
		"timestamp": Time.get_ticks_msec(),
		"location": location,
		"message": message,
		"data": data,
		"hypothesisId": hypothesis_id,
		"runId": run_id,
	}
	var json_str := JSON.stringify(line)
	var f: FileAccess = FileAccess.open(_AGENT_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(_AGENT_LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(json_str)
		f.close()

#endregion

func _make_sfx(stream: AudioStream, volume: float = 0.0) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume
	sfx.bus = &"SFX"
	add_child(sfx)
	return sfx

func _ready():
	health = GameManager.max_health
	speed += int(GameManager.speed_bonus)
	sprint_speed += int(GameManager.speed_bonus)
	crouch_speed += int(GameManager.speed_bonus * 0.5)
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_damage_sfx = _make_sfx(preload("res://Assets/Audio/sfx/sfx_playerdamage.wav"), -5.0)
	_heartbeat_sfx = _make_sfx(preload("res://Assets/Audio/sfx/sfx_heartbeat(single).wav"))
	_heartbeat_sfx.finished.connect(_on_heartbeat_finished)
	_death_sfx = _make_sfx(preload("res://Assets/Audio/sfx/sfx_playerdeath.wav"))
	
	await get_tree().process_frame
	hud_node = get_tree().current_scene.find_child("HUD", true, false)
	_create_crosshair()
	_update_weapon_scene()
	_recompute_character_base_scale_from_sprite()
	_update_character_scale()
	_agent_log("H1", "PlayerController.gd:_ready", "sprite_nodes", {
		"root_null": _character_root == null,
		"sprite_null": _character_sprite == null,
		"has_path": has_node("Character/CharacterSprite"),
	}, "pre-fix")
	if _character_sprite:
		var t: Texture2D = _character_sprite.texture
		_agent_log("H2", "PlayerController.gd:_ready", "texture", {
			"tex_null": t == null,
			"tex_size": t.get_size() if t else Vector2.ZERO,
			"hframes": _character_sprite.hframes,
			"vframes": _character_sprite.vframes,
			"base_scale": [_character_base_scale.x, _character_base_scale.y],
		}, "pre-fix")
	if _character_root and _character_sprite:
		_agent_log("H5", "PlayerController.gd:_ready", "visibility", {
			"root_vis": _character_root.visible,
			"sprite_vis": _character_sprite.visible,
			"self_mod": [modulate.r, modulate.g, modulate.b, modulate.a],
		}, "pre-fix")

func _physics_process(delta):
	if fire_cooldown > 0:
		fire_cooldown -= delta
	if ability_cooldown > 0:
		ability_cooldown -= delta
	
	_update_aim()
	
	var menu_active := JoystickCursor.is_menu_active()
	if menu_active:
		is_aiming = false
	else:
		handle_state_inputs()
	
	var direction := Vector2.ZERO
	if menu_active:
		if _allows_keyboard_movement_while_ui_active():
			direction = _get_keyboard_movement_vector()
	else:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var current_speed = speed
	
	if is_crouching:
		current_speed = crouch_speed
	elif Input.is_action_pressed("sprint") and not is_aiming:
		current_speed = sprint_speed
		
	if is_aiming:
		current_speed *= aim_speed_penalty
		
	velocity = direction * current_speed
	
	_update_character_animation(delta, velocity.length_squared() > 0.0)
			
	move_and_slide()
	if not _agent_physics_logged and Engine.get_physics_frames() >= 90:
		_agent_physics_logged = true
		var nframes := _get_walk_frame_count()
		_agent_log("H3", "PlayerController.gd:_physics_process", "animation_tick", {
			"frame": _character_sprite.frame if _character_sprite else -1,
			"walk_frames": nframes,
			"vel_sq": velocity.length_squared(),
			"scaled_h": (_character_sprite.texture.get_height() / float(maxi(_character_sprite.vframes, 1)) * _character_root.scale.y) if _character_sprite and _character_sprite.texture and _character_root else -1.0,
		}, "pre-fix")
	
	if GameManager.current_phase == "MISSION" and not menu_active:
		# Attack action covers LMB and the right trigger on Xbox.
		if Input.is_action_pressed("attack"):
			if fire_cooldown <= 0.0:
				attack()
		else:
			# Stop flamethrower sound when not holding attack
			if _current_weapon_node and _current_weapon_node.has_method("stop_sound"):
				_current_weapon_node.stop_sound()
		
		# Ability
		if Input.is_action_just_pressed("ability"):
			if ability_cooldown <= 0.0:
				use_ability()

func _allows_keyboard_movement_while_ui_active() -> bool:
	var tree := get_tree()
	if tree == null or tree.paused:
		return false
	var scene := tree.current_scene
	return scene and scene.has_method("_allows_keyboard_movement_while_ui_active") and scene._allows_keyboard_movement_while_ui_active()

func _get_keyboard_movement_vector() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.y += 1.0
	return direction.normalized() if direction.length_squared() > 1.0 else direction

func _update_aim() -> void:
	# Aim follows the mouse cursor. The right stick is wired to the mouse
	# cursor via the JoystickCursor autoload, so this single path covers
	# both keyboard+mouse and Xbox controller players.
	_update_crosshair()
	if has_node("Visuals"):
		$Visuals.look_at(get_global_mouse_position())

func _create_crosshair() -> void:
	if _crosshair != null:
		return
	_crosshair = Node2D.new()
	_crosshair.name = "Crosshair"
	_crosshair.top_level = true
	_crosshair.z_index = 500
	_crosshair.visible = false
	add_child(_crosshair)

	var col := Color(1.0, 1.0, 1.0, 0.95)
	var segments := [
		[Vector2(-18, 0), Vector2(-6, 0)],
		[Vector2(6, 0), Vector2(18, 0)],
		[Vector2(0, -18), Vector2(0, -6)],
		[Vector2(0, 6), Vector2(0, 18)],
	]
	for segment in segments:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = col
		line.add_point(segment[0])
		line.add_point(segment[1])
		_crosshair.add_child(line)

	var center := Line2D.new()
	center.width = 2.0
	center.default_color = col
	center.add_point(Vector2(-2, 0))
	center.add_point(Vector2(2, 0))
	_crosshair.add_child(center)

func _update_crosshair() -> void:
	if _crosshair == null:
		return
	var menu_active := JoystickCursor.is_menu_active()
	_crosshair.visible = GameManager.current_phase == "MISSION" and not menu_active and not is_game_over
	if _crosshair.visible:
		_crosshair.global_position = get_global_mouse_position()

func handle_state_inputs():
	# Crouch
	if Input.is_action_pressed("crouch"):
		is_crouching = true
	else:
		is_crouching = false
	_update_character_scale()

	# Aim
	is_aiming = Input.is_action_pressed("aim")

	# Weapon Switching: direct (1/2/3) and cycling (LB/RB or Q/R).
	for i in range(1, 4):
		if Input.is_action_just_pressed("weapon_" + str(i)):
			switch_weapon(i)
			break
	if Input.is_action_just_pressed("weapon_next"):
		switch_weapon(_cycled_weapon_idx(1))
	elif Input.is_action_just_pressed("weapon_prev"):
		switch_weapon(_cycled_weapon_idx(-1))

func _cycled_weapon_idx(step: int) -> int:
	# Wrap current_weapon_idx in [1..3].
	return ((current_weapon_idx - 1 + step + 3) % 3) + 1

func is_crouching_state() -> bool:
	return is_crouching

func _get_walk_frame_count() -> int:
	if _character_sprite == null:
		return 8
	return maxi(_character_sprite.hframes * _character_sprite.vframes, 1)

func _update_character_animation(delta: float, is_moving: bool) -> void:
	if _character_sprite == null:
		return
	var nframes := _get_walk_frame_count()
	if is_moving:
		_walk_frame_time += delta * WALK_FRAME_RATE
		_character_sprite.frame = int(_walk_frame_time) % nframes
	else:
		_walk_frame_time = 0.0
		_character_sprite.frame = 0
	_update_character_scale()

func _recompute_character_base_scale_from_sprite() -> void:
	if _character_sprite == null:
		return
	var tex: Texture2D = _character_sprite.texture
	if tex == null:
		return
	var vf := maxi(_character_sprite.vframes, 1)
	var hf := maxi(_character_sprite.hframes, 1)
	var tw := tex.get_width()
	var th := tex.get_height()
	var cell_h := float(th) / float(vf)
	var cell_w := float(tw) / float(hf)
	var s := CHARACTER_TARGET_HEIGHT_PX / cell_h
	_character_base_scale = Vector2(s, s)
	_agent_log("H2", "PlayerController.gd:_recompute_character_base_scale_from_sprite", "cell_scale", {
		"tex_wh": [tw, th],
		"hf_vf": [hf, vf],
		"cell_wh": [cell_w, cell_h],
		"target_h": CHARACTER_TARGET_HEIGHT_PX,
		"uniform_scale": s,
	}, "pre-fix")

func _update_character_scale() -> void:
	if _character_root == null:
		return
	var crouch_scale := CHARACTER_CROUCH_MULTIPLIER if is_crouching else 1.0
	_character_root.scale = _character_base_scale * crouch_scale

func switch_weapon(idx):
	current_weapon_idx = idx
	var weapon_name = _get_current_weapon_name()
	
	# Update HUD
	if hud_node and hud_node.has_method("update_weapon"):
		hud_node.update_weapon(idx, weapon_name)
	_update_weapon_scene()

func _update_weapon_scene() -> void:
	if not has_node("Visuals"):
		return
	# Remove old weapon scene
	if _current_weapon_node and is_instance_valid(_current_weapon_node):
		_current_weapon_node.queue_free()
		_current_weapon_node = null
	# No weapons in shop phase
	if GameManager.current_phase == "SHOP":
		return
	# Get weapon scene path
	var weapon_name = _get_current_weapon_name()
	var weapon_data = GameManager.weapons.get(weapon_name, {})
	var scene_path = weapon_data.get("weapon_scene", "")
	if scene_path == "":
		return
	var scene: PackedScene = _get_weapon_scene(scene_path)
	if scene:
		_current_weapon_node = scene.instantiate()
		var offset = weapon_data.get("hold_offset", Vector2(12, 4))
		_current_weapon_node.position = offset
		$Visuals.add_child(_current_weapon_node)
		# Initialize the weapon script
		if _current_weapon_node.has_method("init_weapon"):
			_current_weapon_node.init_weapon(self, weapon_name)

func _get_weapon_scene(scene_path: String) -> PackedScene:
	if _weapon_scene_cache.has(scene_path):
		return _weapon_scene_cache[scene_path]
	var scene := load(scene_path) as PackedScene
	if scene:
		_weapon_scene_cache[scene_path] = scene
	return scene

func _get_current_weapon_name() -> String:
	match current_weapon_idx:
		1: return GameManager.equipped_main
		2: return GameManager.equipped_melee
		3: return GameManager.equipped_special
	return ""

func _get_current_weapon_type() -> String:
	var wname = _get_current_weapon_name()
	if wname == "":
		return ""
	return GameManager.weapons.get(wname, {}).get("type", "ranged")

func _on_heartbeat_finished() -> void:
	# Double-beat pattern: 1-2 ... 1-2 ...
	if health > 0 and health <= 15 and _heartbeat_sfx:
		if not _heartbeat_sfx.has_meta("is_second_beat") or not _heartbeat_sfx.get_meta("is_second_beat"):
			# Short pause then play second beat
			_heartbeat_sfx.set_meta("is_second_beat", true)
			await get_tree().create_timer(0.3).timeout
			if is_instance_valid(self) and health > 0 and health <= 15:
				_heartbeat_sfx.play()
		else:
			# Long pause before next double-beat
			_heartbeat_sfx.set_meta("is_second_beat", false)
			await get_tree().create_timer(1.5).timeout
			if is_instance_valid(self) and health > 0 and health <= 15:
				_heartbeat_sfx.play()

func attack():
	if _current_weapon_node and _current_weapon_node.has_method("attack"):
		_current_weapon_node.attack()

func use_ability():
	var ability = GameManager.active_ability
	ability_cooldown = GameManager.get_ability_cooldown(ability)
	print("Ability Used! (", ability, ")")
	
	match ability:
		"Shadow Dash":
			_ability_shadow_dash()
		"Smoke Bomb":
			_ability_smoke_bomb()
		"Shuriken Burst":
			_ability_shuriken_burst()
		"Poison Cloud":
			_ability_poison_cloud()

func _ability_shadow_dash():
	var dash_dir = velocity.normalized()
	if dash_dir == Vector2.ZERO:
		if has_node("Visuals"):
			dash_dir = Vector2.RIGHT.rotated($Visuals.rotation)
		else:
			dash_dir = Vector2.RIGHT
	global_position += dash_dir * 120.0
	
	modulate = Color(0.5, 0.8, 1, 0.7)
	var t := get_tree().create_timer(0.2)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func _ability_smoke_bomb():
	var result = _create_aoe_area(global_position, 100.0, Color(0.5, 0.5, 0.6, 0.35))
	var smoke: Area2D = result[0]
	var visual: Polygon2D = result[1]
	
	await get_tree().physics_frame
	
	var affected_enemies: Array = []
	var duration := 3.0
	var elapsed := 0.0
	
	while elapsed < duration and is_instance_valid(smoke):
		var bodies = smoke.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemy") and body not in affected_enemies:
				affected_enemies.append(body)
				if body.has_method("apply_slow"):
					body.apply_slow(0.5, duration - elapsed)
		
		if is_instance_valid(visual):
			visual.color.a = 0.35 * (1.0 - elapsed / duration)
		
		await get_tree().create_timer(0.2).timeout
		elapsed += 0.2
	
	if is_instance_valid(smoke):
		smoke.queue_free()

func _ability_shuriken_burst():
	modulate = Color(0.9, 0.4, 0.4, 0.8)
	
	var base_damage = GameManager.get_weapon_damage("Boba Gun") * 0.6
	var count := 8
	for i in range(count):
		var angle = i * (TAU / count)
		var dir = Vector2.RIGHT.rotated(angle)
		
		var proj = Area2D.new()
		proj.global_position = global_position + dir * 50.0
		proj.collision_layer = 0
		proj.collision_mask = 4
		get_tree().current_scene.add_child(proj)
		
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 6.0
		shape.shape = circle
		proj.add_child(shape)
		
		var visual = ColorRect.new()
		visual.size = Vector2(10, 10)
		visual.position = Vector2(-5, -5)
		visual.color = Color(0.9, 0.4, 0.4)
		proj.add_child(visual)
		
		proj.set_meta("direction", dir)
		proj.set_meta("speed", 600.0)
		proj.set_meta("damage", base_damage)
		proj.set_meta("lifetime", 2.0)
		
		proj.body_entered.connect(_on_shuriken_hit.bind(proj))
		_drive_shuriken(proj)
	
	var t := get_tree().create_timer(0.15)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func _drive_shuriken(proj: Area2D):
	var dir: Vector2 = proj.get_meta("direction")
	var spd: float = proj.get_meta("speed")
	var remaining: float = proj.get_meta("lifetime")
	while remaining > 0.0 and is_instance_valid(proj):
		proj.position += dir * spd * get_process_delta_time()
		remaining -= get_process_delta_time()
		await get_tree().process_frame
	if is_instance_valid(proj):
		proj.queue_free()

func _on_shuriken_hit(body: Node, proj: Area2D):
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(proj.get_meta("damage"))
	if is_instance_valid(proj):
		proj.queue_free()

func _ability_poison_cloud():
	var result = _create_aoe_area(global_position, 80.0, Color(0.3, 0.9, 0.35, 0.3))
	var cloud: Area2D = result[0]
	var visual: Polygon2D = result[1]
	
	await get_tree().physics_frame
	
	var tick_damage = GameManager.get_weapon_damage("Boba Gun") * 0.4
	var ticks := 6
	
	for tick in range(ticks):
		if not is_instance_valid(cloud):
			break
		var bodies = cloud.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemy") and body.has_method("take_damage"):
				body.take_damage(tick_damage)
		
		if is_instance_valid(visual):
			visual.color.a = 0.3 * (1.0 - float(tick) / float(ticks))
			visual.rotation += 0.1
		
		await get_tree().create_timer(0.5).timeout
	
	if is_instance_valid(cloud):
		cloud.queue_free()

func _flash_and_reset(color: Color, duration: float = 0.1) -> void:
	modulate = color
	var t := get_tree().create_timer(duration)
	await t.timeout
	if is_instance_valid(self):
		modulate = Color.WHITE

func _update_hud_health() -> void:
	if hud_node and hud_node.has_method("update_health"):
		hud_node.update_health(health, GameManager.max_health)

func _create_aoe_area(pos: Vector2, radius: float, color: Color) -> Array:
	var area = Area2D.new()
	area.global_position = pos
	area.collision_layer = 0
	area.collision_mask = 4
	area.monitoring = true
	area.monitorable = false
	get_tree().current_scene.add_child(area)
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	
	var visual = Polygon2D.new()
	var pts: PackedVector2Array = []
	var segments = int(max(16, radius * 0.25))
	for i in range(segments):
		var angle = i * (TAU / float(segments))
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	visual.polygon = pts
	visual.color = color
	area.add_child(visual)
	
	return [area, visual]

func take_damage(amount):
	health -= amount
	if health < 0:
		health = 0
	
	# Play damage sound
	if _damage_sfx:
		_damage_sfx.play()
	
	# Start heartbeat loop if health is 15 or below
	if health > 0 and health <= 15:
		if _heartbeat_sfx and not _heartbeat_sfx.playing:
			_heartbeat_sfx.play()
	
	_flash_and_reset(Color(1, 0.3, 0.3), 0.1)
	_update_hud_health()
	
	# Screen shake
	if has_node("Camera2D"):
		var cam = $Camera2D
		var shake_tween = create_tween()
		shake_tween.tween_property(cam, "offset", Vector2(randf_range(-8, 8), randf_range(-8, 8)), 0.05)
		shake_tween.tween_property(cam, "offset", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
		shake_tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)
	
	if health <= 0:
		die()

func melt_die() -> void:
	if is_game_over:
		return
	is_game_over = true
	set_physics_process(false)
	health = 0
	_update_hud_health()
	if _crosshair:
		_crosshair.visible = false
	if _death_sfx:
		_death_sfx.play()
	if hud_node and hud_node.has_method("hide_hud"):
		hud_node.hide_hud()
	var visuals := get_node_or_null("Character") as Node2D
	var tween := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if visuals:
		var melt_scale := visuals.scale * Vector2(1.4, 0.12)
		tween.set_parallel(true)
		tween.tween_property(visuals, "modulate", Color(0.25, 1.0, 0.15, 0.15), 0.7)
		tween.tween_property(visuals, "scale", melt_scale, 0.7)
		tween.tween_property(visuals, "rotation", visuals.rotation + 0.5, 0.7)
	else:
		tween.tween_property(self, "modulate", Color(0.25, 1.0, 0.15, 0.15), 0.7)
	await tween.finished
	await get_tree().create_timer(0.25).timeout
	GameManager.health = GameManager.max_health
	
	# Stop MissionManager processing without spawning a door
	var mission_mgr = get_tree().current_scene
	if mission_mgr and "mission_failed" in mission_mgr:
		mission_mgr.mission_failed = true
	get_tree().change_scene_to_file("res://Scenes/EndScreen.tscn")

func heal(amount: int) -> void:
	health = min(health + amount, GameManager.max_health)
	
	# Stop heartbeat if healed above 15
	if health > 15 and _heartbeat_sfx:
		_heartbeat_sfx.stop()
	
	_flash_and_reset(Color(0.3, 1.0, 0.5), 0.15)
	_update_hud_health()

var is_game_over: bool = false

func die():
	if is_game_over:
		return
	is_game_over = true
	set_physics_process(false)
	if _crosshair:
		_crosshair.visible = false
	
	# Play death sound
	if _death_sfx:
		_death_sfx.play()
	
	# Hide the HUD
	if hud_node and hud_node.has_method("hide_hud"):
		hud_node.hide_hud()
	
	# Stop the MissionManager from processing (don't call on_mission_failed — that spawns a door)
	var mission_mgr = get_tree().current_scene
	if mission_mgr and "mission_failed" in mission_mgr:
		mission_mgr.mission_failed = true
	
	# Brief red flash before transition
	modulate = Color(1, 0.2, 0.2)
	
	# Short delay for impact
	await get_tree().create_timer(0.8).timeout
	
	# Transition to the end screen
	GameManager.health = GameManager.max_health
	get_tree().change_scene_to_file("res://Scenes/EndScreen.tscn")
