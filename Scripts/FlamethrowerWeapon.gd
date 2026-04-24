extends "res://Scripts/WeaponBase.gd"
## Flamethrower — continuous stream of short-lived flame projectiles.

const FLAME_PROJECTILE_SCRIPT := preload("res://Scripts/FlameProjectile.gd")

var _flame_sfx: AudioStreamPlayer = null
var fuel: float = 7.5
const MAX_FUEL: float = 7.5
var _out_of_fuel: bool = false

static var _fire_grad_tex: GradientTexture1D
static var _ember_grad_tex: GradientTexture1D
static var _smoke_grad_tex: GradientTexture1D
static var _fire_scale_curve_tex: CurveTexture
static var _light_tex: GradientTexture2D
static var _shared_flame_fx_built: bool = false

static func _ensure_shared_flame_fx() -> void:
	if _shared_flame_fx_built:
		return
	_shared_flame_fx_built = true

	var fire_grad = Gradient.new()
	fire_grad.set_offset(0, 0.0)
	fire_grad.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
	fire_grad.add_point(0.1, Color(1.0, 0.98, 0.5, 1.0))
	fire_grad.add_point(0.3, Color(1.0, 0.7, 0.1, 0.95))
	fire_grad.add_point(0.55, Color(1.0, 0.4, 0.02, 0.85))
	fire_grad.add_point(0.75, Color(0.8, 0.12, 0.01, 0.6))
	fire_grad.set_offset(1, 1.0)
	fire_grad.set_color(1, Color(0.15, 0.02, 0.0, 0.0))
	_fire_grad_tex = GradientTexture1D.new()
	_fire_grad_tex.gradient = fire_grad

	var ember_grad = Gradient.new()
	ember_grad.set_offset(0, 0.0)
	ember_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	ember_grad.add_point(0.3, Color(1.0, 0.6, 0.1, 0.9))
	ember_grad.add_point(0.6, Color(1.0, 0.3, 0.05, 0.7))
	ember_grad.set_offset(1, 1.0)
	ember_grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	_ember_grad_tex = GradientTexture1D.new()
	_ember_grad_tex.gradient = ember_grad

	var smoke_grad = Gradient.new()
	smoke_grad.set_offset(0, 0.0)
	smoke_grad.set_color(0, Color(0.35, 0.28, 0.22, 0.35))
	smoke_grad.add_point(0.4, Color(0.25, 0.2, 0.16, 0.2))
	smoke_grad.set_offset(1, 1.0)
	smoke_grad.set_color(1, Color(0.12, 0.1, 0.08, 0.0))
	_smoke_grad_tex = GradientTexture1D.new()
	_smoke_grad_tex.gradient = smoke_grad

	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.2))
	scale_curve.add_point(Vector2(0.15, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.85))
	scale_curve.add_point(Vector2(0.8, 0.4))
	scale_curve.add_point(Vector2(1.0, 0.05))
	_fire_scale_curve_tex = CurveTexture.new()
	_fire_scale_curve_tex.curve = scale_curve

	_light_tex = GradientTexture2D.new()
	_light_tex.gradient = Gradient.new()
	_light_tex.gradient.set_color(0, Color.WHITE)
	_light_tex.gradient.set_color(1, Color.TRANSPARENT)
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(0.5, 0.0)
	_light_tex.width = 128
	_light_tex.height = 128

func _ready() -> void:
	_ensure_shared_flame_fx()
	_flame_sfx = AudioStreamPlayer.new()
	_flame_sfx.stream = preload("res://Assets/Audio/sfx/sfx_flamethrower.wav")
	_flame_sfx.volume_db = -5.0
	_flame_sfx.bus = &"SFX"
	add_child(_flame_sfx)

func attack() -> void:
	if weapon_name == "":
		return
	if _out_of_fuel:
		stop_sound()
		return

	var tuning := _get_tuning()
	
	# Drain fuel based on fire rate
	fuel -= _get_fire_rate()
	if fuel <= 0.0:
		fuel = 0.0
		_out_of_fuel = true
		stop_sound()
		return

	_shoot_flame(tuning)
	_play_shot_animation(_get_facing_direction(), tuning)
	
	# Play flamethrower sound
	if _flame_sfx and not _flame_sfx.playing:
		_flame_sfx.play()
	
	player.fire_cooldown = _get_fire_rate()

func stop_sound() -> void:
	if _flame_sfx and _flame_sfx.playing:
		var tween = create_tween()
		tween.tween_property(_flame_sfx, "volume_db", -40.0, 0.3)
		tween.tween_callback(func():
			_flame_sfx.stop()
			_flame_sfx.volume_db = -5.0
		)

func _shoot_flame(tuning: Dictionary) -> void:
	var damage = _get_damage()
	var base_dir = _get_facing_direction()

	var spread = deg_to_rad(randf_range(-float(tuning.get("flame_spread_deg", 15.0)), float(tuning.get("flame_spread_deg", 15.0))))
	var direction = base_dir.rotated(spread)

	var flame = Area2D.new()
	flame.name = "Flame_" + str(randi())
	flame.collision_layer = 8
	flame.collision_mask = 1 | 4
	flame.z_index = 100

	flame.set_script(FLAME_PROJECTILE_SCRIPT)
	flame.direction = direction
	flame.damage = damage
	flame.speed = float(tuning.get("flame_speed", 300.0))
	flame.lifetime = float(tuning.get("flame_lifetime", 0.4))

	# ---- Fire particles ----
	var fire = GPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = false
	fire.amount = 30
	fire.lifetime = 0.5
	fire.speed_scale = 2.2
	fire.explosiveness = 0.1
	fire.randomness = 0.5

	var fire_mat = ParticleProcessMaterial.new()
	fire_mat.direction = Vector3(direction.x, direction.y, 0)
	fire_mat.spread = 22.0
	fire_mat.initial_velocity_min = 40.0
	fire_mat.initial_velocity_max = 100.0
	fire_mat.gravity = Vector3(0, -70, 0)
	fire_mat.damping_min = 10.0
	fire_mat.damping_max = 30.0
	fire_mat.scale_min = 4.0
	fire_mat.scale_max = 12.0
	fire_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_mat.emission_sphere_radius = 8.0

	fire_mat.color_ramp = _fire_grad_tex
	fire_mat.scale_curve = _fire_scale_curve_tex

	fire.process_material = fire_mat
	flame.add_child(fire)

	# ---- Ember particles ----
	var embers = GPUParticles2D.new()
	embers.emitting = true
	embers.one_shot = false
	embers.amount = 6
	embers.lifetime = 0.6
	embers.speed_scale = 1.5
	embers.explosiveness = 0.3
	embers.randomness = 0.9

	var ember_mat = ParticleProcessMaterial.new()
	ember_mat.direction = Vector3(direction.x * 0.5, direction.y * 0.5 - 1.0, 0)
	ember_mat.spread = 50.0
	ember_mat.initial_velocity_min = 40.0
	ember_mat.initial_velocity_max = 120.0
	ember_mat.gravity = Vector3(0, -90, 0)
	ember_mat.damping_min = 15.0
	ember_mat.damping_max = 40.0
	ember_mat.scale_min = 1.5
	ember_mat.scale_max = 3.0

	ember_mat.color_ramp = _ember_grad_tex

	embers.process_material = ember_mat
	flame.add_child(embers)

	# ---- Smoke particles ----
	var smoke = GPUParticles2D.new()
	smoke.emitting = true
	smoke.one_shot = false
	smoke.amount = 6
	smoke.lifetime = 0.7
	smoke.speed_scale = 0.8
	smoke.explosiveness = 0.05
	smoke.randomness = 0.8

	var smoke_mat = ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(direction.x * 0.3, -1, 0)
	smoke_mat.spread = 45.0
	smoke_mat.initial_velocity_min = 10.0
	smoke_mat.initial_velocity_max = 35.0
	smoke_mat.gravity = Vector3(0, -35, 0)
	smoke_mat.scale_min = 6.0
	smoke_mat.scale_max = 16.0
	smoke_mat.damping_min = 5.0
	smoke_mat.damping_max = 15.0

	smoke_mat.color_ramp = _smoke_grad_tex

	smoke.process_material = smoke_mat
	flame.add_child(smoke)

	# ---- Glow light ----
	var glow = PointLight2D.new()
	glow.color = Color(1.0, 0.5, 0.1, 1.0)
	glow.energy = 1.8 + randf_range(-0.3, 0.3)
	glow.texture_scale = 0.5
	glow.texture = _light_tex
	flame.add_child(glow)

	# ---- Collision ----
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	flame.add_child(shape)

	flame.global_position = _get_muzzle_global_position()
	player.get_parent().add_child(flame)

	flame.body_entered.connect(flame._on_body_entered)
	flame.start_lifetime()
