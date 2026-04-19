extends "res://Scripts/WeaponBase.gd"
## Pistol / ranged weapon — shoots boba projectiles.

const BOBA_PROJECTILE_SCRIPT := preload("res://Scripts/BobaProjectile.gd")

var _gun_sfx: AudioStreamPlayer = null
var _blowdart_sfx: AudioStreamPlayer = null

func _ready() -> void:
	_gun_sfx = AudioStreamPlayer.new()
	_gun_sfx.stream = preload("res://Assets/Audio/sfx/sfx_boba_gun.mp3")
	_gun_sfx.volume_db = 0.0
	_gun_sfx.bus = &"SFX"
	add_child(_gun_sfx)
	
	_blowdart_sfx = AudioStreamPlayer.new()
	_blowdart_sfx.stream = preload("res://Assets/Audio/sfx/sfx_blowdart_straw.mp3")
	_blowdart_sfx.volume_db = 0.0
	_blowdart_sfx.bus = &"SFX"
	add_child(_blowdart_sfx)

func attack() -> void:
	if weapon_name == "":
		return

	var tuning := _get_tuning()
	var direction = _get_facing_direction()
	var spread_deg = float(tuning.get("spread_deg", 0.0))
	if spread_deg > 0.0:
		direction = direction.rotated(deg_to_rad(randf_range(-spread_deg, spread_deg)))

	var damage = _get_damage()
	_play_shot_animation(_get_facing_direction(), tuning)
	_spawn_shell_casing(direction, tuning)

	# Play appropriate weapon sound
	if weapon_name in ["Boba Dart Gun", "Poison Straw"]:
		if _blowdart_sfx:
			_blowdart_sfx.play()
	else:
		if _gun_sfx:
			_gun_sfx.play()

	# Fire-rate cooldown is set on the player
	player.fire_cooldown = _get_fire_rate()

	var cluster_count = int(tuning.get("cluster_count", 1))
	if cluster_count > 1:
		var cluster_spread = float(tuning.get("cluster_spread_deg", 8.0))
		for i in range(cluster_count):
			var offset_angle = deg_to_rad(randf_range(-cluster_spread, cluster_spread))
			var proj_dir = direction.rotated(offset_angle)
			var speed_variance = randf_range(0.85, 1.1)
			var size_variance = randf_range(0.7, 1.0)
			_spawn_boba_projectile(proj_dir, damage, tuning, speed_variance, size_variance)
		return

	_spawn_boba_projectile(direction, damage, tuning)

func _spawn_boba_projectile(direction: Vector2, damage: float, tuning: Dictionary, speed_mult: float = 1.0, size_mult: float = 1.0) -> void:
	var projectile = Area2D.new()
	projectile.name = "Proj_" + str(randi())
	projectile.collision_layer = 8
	projectile.collision_mask = 1 | 4
	projectile.z_index = 100

	projectile.set_script(BOBA_PROJECTILE_SCRIPT)

	projectile.direction = direction
	projectile.damage = damage
	projectile.speed = float(tuning.get("projectile_speed", 800.0)) * speed_mult
	projectile.lifetime = float(tuning.get("projectile_lifetime", 2.4))
	projectile.poison_tick_damage = float(tuning.get("poison_tick_damage", 0.0))
	projectile.poison_ticks = int(tuning.get("poison_ticks", 0))
	projectile.poison_interval = float(tuning.get("poison_interval", 1.0))

	var projectile_size = float(tuning.get("projectile_size", 10.0)) * size_mult
	var projectile_color: Color = tuning.get("projectile_color", Color(0.85, 0.2, 0.15))

	var bubble = Polygon2D.new()
	bubble.name = "Bubble"
	bubble.color = projectile_color
	var points := PackedVector2Array()
	for i in range(12):
		var a = TAU * (float(i) / 12.0)
		points.append(Vector2(cos(a), sin(a)) * (projectile_size * 0.52))
	bubble.polygon = points
	projectile.add_child(bubble)

	var highlight = Polygon2D.new()
	highlight.name = "Highlight"
	highlight.color = Color(1.0, 1.0, 1.0, 0.5)
	var hl_points := PackedVector2Array()
	for i in range(8):
		var a = TAU * (float(i) / 8.0)
		hl_points.append(Vector2(cos(a), sin(a)) * (projectile_size * 0.28) + Vector2(-projectile_size * 0.12, -projectile_size * 0.12))
	highlight.polygon = hl_points
	projectile.add_child(highlight)

	var sparkle = Polygon2D.new()
	sparkle.color = Color(1.0, 1.0, 1.0, 0.75)
	sparkle.polygon = PackedVector2Array([
		Vector2(-projectile_size * 0.12, -projectile_size * 0.28),
		Vector2(projectile_size * 0.06, -projectile_size * 0.34),
		Vector2(projectile_size * 0.24, -projectile_size * 0.18),
		Vector2(projectile_size * 0.02, -projectile_size * 0.10)
	])
	projectile.add_child(sparkle)

	var trail = _create_projectile_trail(projectile_color, projectile_size)
	projectile.add_child(trail)

	var glow = PointLight2D.new()
	glow.color = projectile_color
	glow.energy = 0.6
	glow.texture_scale = 0.15 + (projectile_size / 60.0)
	var light_tex = GradientTexture2D.new()
	light_tex.gradient = Gradient.new()
	light_tex.gradient.set_color(0, Color.WHITE)
	light_tex.gradient.set_color(1, Color.TRANSPARENT)
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 64
	light_tex.height = 64
	glow.texture = light_tex
	projectile.add_child(glow)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = max(5.0, projectile_size * 0.65)
	shape.shape = circle
	projectile.add_child(shape)

	projectile.global_position = _get_muzzle_global_position()

	player.get_parent().add_child(projectile)
	projectile.body_entered.connect(projectile._on_body_entered)
	projectile.start_lifetime()
