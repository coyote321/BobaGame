extends Area2D
class_name Hazard

enum Mode { RADIATION, WASTE }

@export var mode: Mode = Mode.RADIATION
@export var damage_per_tick: float = 8.0
@export var tick_interval: float = 1.0

var _bodies: Array = []
var _tick_timer: Timer

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_tick_timer = Timer.new()
	_tick_timer.one_shot = false
	_tick_timer.wait_time = tick_interval
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	if mode == Mode.RADIATION:
		_tick_timer.start()

func _on_body_entered(body: Node) -> void:
	if mode == Mode.WASTE:
		_apply_sludge_melt(body)
		return
	if body not in _bodies:
		_bodies.append(body)

func _on_body_exited(body: Node) -> void:
	_bodies.erase(body)

func _on_tick() -> void:
	for body in _bodies.duplicate():
		if not is_instance_valid(body):
			_bodies.erase(body)
			continue
		_apply_damage(body, damage_per_tick)

func _apply_damage(body: Node, amount: float) -> void:
	if body.has_method("take_damage"):
		body.take_damage(amount)

func _apply_sludge_melt(body: Node) -> void:
	if _is_protected_boss_target(body):
		return
	if body.has_method("melt_die"):
		body.melt_die()
	else:
		_apply_damage(body, 9999.0)

func _is_protected_boss_target(body: Node) -> bool:
	if body == null:
		return false
	if body.has_method("is_reactor_overlord"):
		return true
	if "is_target" in body and body.is_target:
		return true
	return false
