extends "res://Scripts/WeaponBase.gd"


const FLAME_PROJECTILE_SCRIPT := preload("res://Scripts/FlameProjectile.gd")


static var _fire_mat: ParticleProcessMaterial
static var _ember_mat: ParticleProcessMaterial
static var _smoke_mat: ParticleProcessMaterial
static var _light_tex: GradientTexture2D
static var _resources_built: bool = false

static func _build_shared_resources() -> void:
	if _resources_built:
		return
	_resources_built = true


	_fire_mat = ParticleProcessMaterial.new()
	_fire_mat.direction = Vector3(1, 0, 0)
	_fire_mat.spread = 22.0
	_fire_mat.initial_velocity_min = 40.0
	_fire_mat.initial_velocity_max = 100.0
	_fire_mat.gravity = Vector3(0, -70, 0)
	_fire_mat.damping_min = 10.0
	_fire_mat.damping_max = 30.0
	_fire_mat.scale_min = 4.0
	_fire_mat.scale_max = 12.0
	_fire_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_fire_mat.emission_sphere_radius = 8.0

	var fire_grad = Gradient.new()
	fire_grad.set_offset(0, 0.0)
	fire_grad.set_color(0, Color(1.0, 1.0, 0.92, 1.0))
	fire_grad.add_point(0.1, Color(1.0, 0.98, 0.5, 1.0))
	fire_grad.add_point(0.3, Color(1.0, 0.7, 0.1, 0.95))
	fire_grad.add_point(0.55, Color(1.0, 0.4, 0.02, 0.85))
	fire_grad.add_point(0.75, Color(0.8, 0.12, 0.01, 0.6))
	fire_grad.set_offset(1, 1.0)
	fire_grad.set_color(1, Color(0.15, 0.02, 0.0, 0.0))
	var fire_grad_tex = GradientTexture1D.new()
	fire_grad_tex.gradient = fire_grad
	_fire_mat.color_ramp = fire_grad_tex

	var fire_scale_curve = Curve.new()
	fire_scale_curve.add_point(Vector2(0.0, 0.2))
	fire_scale_curve.add_point(Vector2(0.15, 1.0))
	fire_scale_curve.add_point(Vector2(0.5, 0.85))
	fire_scale_curve.add_point(Vector2(0.8, 0.4))
	fire_scale_curve.add_point(Vector2(1.0, 0.05))
	var fire_scale_tex = CurveTexture.new()
	fire_scale_tex.curve = fire_scale_curve
	_fire_mat.scale_curve = fire_scale_tex


	_ember_mat = ParticleProcessMaterial.new()
	_ember_mat.direction = Vector3(0.5, -1.0, 0)
	_ember_mat.spread = 50.0
	_ember_mat.initial_velocity_min = 40.0
	_ember_mat.initial_velocity_max = 120.0
	_ember_mat.gravity = Vector3(0, -90, 0)
	_ember_mat.damping_min = 15.0
	_ember_mat.damping_max = 40.0
	_ember_mat.scale_min = 1.5
	_ember_mat.scale_max = 3.0

	var ember_grad = Gradient.new()
	ember_grad.set_offset(0, 0.0)
	ember_grad.set_color(0, Color(1.0, 0.95, 0.4, 1.0))
	ember_grad.add_point(0.3, Color(1.0, 0.6, 0.1, 0.9))
	ember_grad.add_point(0.6, Color(1.0, 0.3, 0.05, 0.7))
	ember_grad.set_offset(1, 1.0)
	ember_grad.set_color(1, Color(0.5, 0.1, 0.0, 0.0))
	var ember_grad_tex = GradientTexture1D.new()
	ember_grad_tex.gradient = ember_grad
	_ember_mat.color_ramp = ember_grad_tex


	_smoke_mat = ParticleProcessMaterial.new()
	_smoke_mat.direction = Vector3(0.3, -1, 0)
	_smoke_mat.spread = 45.0
	_smoke_mat.initial_velocity_min = 10.0
	_smoke_mat.initial_velocity_max = 35.0
	_smoke_mat.gravity = Vector3(0, -35, 0)
	_smoke_mat.scale_min = 6.0
	_smoke_mat.scale_max = 16.0
	_smoke_mat.damping_min = 5.0
	_smoke_mat.damping_max = 15.0

	var smoke_grad = Gradient.new()
	smoke_grad.set_offset(0, 0.0)
	smoke_grad.set_color(0, Color(0.35, 0.28, 0.22, 0.35))
	smoke_grad.add_point(0.4, Color(0.25, 0.2, 0.16, 0.2))
	smoke_grad.set_offset(1, 1.0)
	smoke_grad.set_color(1, Color(0.12, 0.1, 0.08, 0.0))
	var smoke_grad_tex = GradientTexture1D.new()
	smoke_grad_tex.gradient = smoke_grad
	_smoke_mat.color_ramp = smoke_grad_tex


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
	_build_shared_resources()

func attack() -> void:
	if weapon_name == "":
		return
	var tuning := _get_tuning()
	_shoot_flame(tuning)
	_play_shot_animation(_get_facing_direction(), tuning)
	player.fire_cooldown = _get_fire_rate()

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

	flame.rotation = direction.angle()

	flame.set_script(FLAME_PROJECTILE_SCRIPT)
	flame.direction = direction
	flame.damage = damage
	flame.speed = float(tuning.get("flame_speed", 300.0))
	flame.lifetime = float(tuning.get("flame_lifetime", 0.4))


	var fire = GPUParticles2D.new()
	fire.emitting = true
	fire.one_shot = false
	fire.amount = 40
	fire.lifetime = 0.5
	fire.speed_scale = 2.2
	fire.explosiveness = 0.1
	fire.randomness = 0.5
	fire.process_material = _fire_mat
	flame.add_child(fire)


	if randi() % 3 == 0:
		var embers = GPUParticles2D.new()
		embers.emitting = true
		embers.one_shot = false
		embers.amount = 10
		embers.lifetime = 0.6
		embers.speed_scale = 1.5
		embers.explosiveness = 0.3
		embers.randomness = 0.9
		embers.process_material = _ember_mat
		flame.add_child(embers)

		var smoke = GPUParticles2D.new()
		smoke.emitting = true
		smoke.one_shot = false
		smoke.amount = 10
		smoke.lifetime = 0.7
		smoke.speed_scale = 0.8
		smoke.explosiveness = 0.05
		smoke.randomness = 0.8
		smoke.process_material = _smoke_mat
		flame.add_child(smoke)


	var glow = PointLight2D.new()
	glow.color = Color(1.0, 0.5, 0.1, 1.0)
	glow.energy = 1.8 + randf_range(-0.3, 0.3)
	glow.texture_scale = 0.5
	glow.texture = _light_tex
	flame.add_child(glow)


	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	flame.add_child(shape)

	flame.global_position = _get_muzzle_global_position()
	player.get_parent().add_child(flame)

	flame.body_entered.connect(flame._on_body_entered)
	flame.start_lifetime()
