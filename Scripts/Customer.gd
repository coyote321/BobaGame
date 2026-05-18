extends CharacterBody2D

signal customer_left(customer)
signal order_ready(customer)

const CUSTOMER_FRAME_COUNT: int = 4
const CUSTOMER_IDLE_FPS: float = 6.0
const CUSTOMER_WALK_FPS: float = 10.0
const LEAVE_SHOP_DURATION: float = 0.8
const CUSTOMER_SHEETS := [
	preload("res://Assets/Sprites/customer 1.png"),
	preload("res://Assets/Sprites/customer 2 (1).png"),
	preload("res://Assets/Sprites/customer 3.png"),
]

var patience: float = 100.0
var max_patience: float = 100.0
var decay_rate: float = 5.0
var order: Dictionary = {}
var is_waiting: bool = false
var has_ordered: bool = false
var satisfaction_score: int = 0
var is_secret_agent: bool = false
var exit_position: Vector2 = Vector2.ZERO

var _queue_move_tween: Tween
var _leaving_shop: bool = false

@onready var patience_bar = $Control/ProgressBar
@onready var order_label = $Control/OrderLabel
@onready var body_sprite = $Body

func _ready():
	_setup_customer_animation()

	# Secret agents look identical to regular customers — no visual hints
	body_sprite.modulate = Color.WHITE
	
	max_patience = 60.0 - (GameManager.day * 2) 
	if max_patience < 20: max_patience = 20
	patience = max_patience
	decay_rate = 100.0 / max_patience
	
	patience_bar.show_percentage = false
	patience_bar.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	patience_bar.add_theme_font_size_override("font_size", 0)
	
	generate_order()
	update_ui()

func _setup_customer_animation() -> void:
	if not body_sprite is AnimatedSprite2D:
		return

	var sheet_index: int = randi() % CUSTOMER_SHEETS.size()
	var sheet: Texture2D = CUSTOMER_SHEETS[sheet_index]
	var frame_width: int = int(sheet.get_width() / CUSTOMER_FRAME_COUNT)
	var frame_height: int = sheet.get_height()
	var frames := SpriteFrames.new()
	for anim_name in [&"idle", &"walk"]:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		if anim_name == &"idle":
			frames.set_animation_speed(anim_name, CUSTOMER_IDLE_FPS)
		else:
			frames.set_animation_speed(anim_name, CUSTOMER_WALK_FPS)
		for frame_idx in range(CUSTOMER_FRAME_COUNT):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(frame_idx * frame_width, 0, frame_width, frame_height)
			frames.add_frame(anim_name, atlas)

	body_sprite.sprite_frames = frames
	body_sprite.play(&"idle")

func move_to_queue_slot(target_pos: Vector2, duration: float = 0.4) -> void:
	if _leaving_shop:
		return
	if (position - target_pos).length() <= 1.0:
		return
	if _queue_move_tween != null and is_instance_valid(_queue_move_tween):
		_queue_move_tween.kill()
	_queue_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if body_sprite is AnimatedSprite2D and body_sprite.sprite_frames != null:
		if body_sprite.sprite_frames.has_animation(&"walk"):
			body_sprite.play(&"walk")
	_queue_move_tween.tween_property(self, "position", target_pos, duration)
	_queue_move_tween.finished.connect(_on_queue_move_finished, CONNECT_ONE_SHOT)

func set_exit_position(target_pos: Vector2) -> void:
	exit_position = target_pos

func _on_queue_move_finished() -> void:
	_queue_move_tween = null
	if not is_instance_valid(self):
		return
	if body_sprite is AnimatedSprite2D and body_sprite.sprite_frames != null:
		if body_sprite.sprite_frames.has_animation(&"idle"):
			body_sprite.play(&"idle")

func _process(delta):
	if is_waiting:
		patience -= decay_rate * delta
		patience_bar.value = (patience / max_patience) * 100
		
		if patience_bar.value > 50:
			patience_bar.modulate = Color.GREEN
		elif patience_bar.value > 20:
			patience_bar.modulate = Color.YELLOW
		else:
			patience_bar.modulate = Color.RED
			
		if patience <= 0:
			leave_angry()

func generate_order():
	# Snapshot the currently-orderable ingredients at the moment of order
	# creation. Customers must NEVER request anything outside this list
	# (e.g. Honey before the level-2 unlock).
	var orderable_ingredients := GameManager.get_orderable_ingredients()

	var available_bases = []
	if "Black Tea" in orderable_ingredients:
		available_bases.append("Black Tea")
	if "Green Tea" in orderable_ingredients:
		available_bases.append("Green Tea")
	if available_bases.is_empty():
		available_bases = ["Black Tea"]

	var use_milk = "Milk" in orderable_ingredients and randf() > 0.5

	# Only toppings that CraftingSystem.validate_mix can resolve are eligible
	# here. Adding new toppings (e.g. Taro) requires teaching the crafter
	# about them first, otherwise the player would not be able to serve.
	var available_toppings = []
	for topping in ["Tapioca", "Sugar", "Honey"]:
		if topping in orderable_ingredients:
			available_toppings.append(topping)

	var chosen_topping := "None"
	if available_toppings.size() > 0 and randf() > 0.3:
		chosen_topping = available_toppings.pick_random()

	# Final defensive check: never let a locked ingredient through, even if
	# something upstream produced an inconsistent orderable list.
	if chosen_topping != "None" and chosen_topping not in orderable_ingredients:
		chosen_topping = "None"

	order = {
		"base": available_bases.pick_random(),
		"milk": "Milk" if use_milk else "No Milk",
		"topping": chosen_topping
	}

	update_order_display()
	has_ordered = true
	is_waiting = true
	emit_signal("order_ready", self)

func update_order_display():
	var text = ""

	text += order["base"]
	if order["milk"] == "Milk":
		text += " + Milk"
	if order["topping"] != "None":
		text += " + " + order["topping"]
	

	order_label.text = text

func update_ui():
	patience_bar.value = 100

func receive_item(item_data: Dictionary) -> bool:
	if not has_ordered: return false
	
	var accuracy = calculate_accuracy(item_data)
	
	if accuracy < 3:
		order_label.text = "Wrong order!"
		order_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		_reset_order_label_after_delay()
		return false
	
	var speed_bonus = (patience / max_patience) * 2
	
	satisfaction_score = int(accuracy + speed_bonus)
	satisfaction_score = clampi(satisfaction_score, 1, 5)
	
	serve_complete()
	return true

func _reset_order_label_after_delay() -> void:
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self) and is_waiting:
		update_order_display()

func calculate_accuracy(item: Dictionary) -> int:
	var matches = 0
	if item.get("base") == order["base"]:
		matches += 1
	if item.get("milk") == order["milk"]:
		matches += 1
	if item.get("topping") == order["topping"]:
		matches += 1
	
	if matches == 3:
		return 3
	if matches == 2:
		return 2
	return 1

func serve_complete():
	is_waiting = false
	
	# Secret agents show the same feedback as regular customers
	if satisfaction_score >= 4:
		order_label.text = "5/5 Amazing!"
	elif satisfaction_score >= 3:
		order_label.text = "3/5 Thanks!"
	else:
		order_label.text = "1/5 Meh."
	
	await get_tree().create_timer(0.4).timeout
	leave_shop()

func leave_angry():
	is_waiting = false
	satisfaction_score = 0
	order_label.text = "Too slow!"
	await get_tree().create_timer(0.6).timeout
	leave_shop()

func leave_shop():
	if _leaving_shop:
		return
	_leaving_shop = true
	is_waiting = false
	emit_signal("customer_left", self)

	if _queue_move_tween != null and is_instance_valid(_queue_move_tween):
		_queue_move_tween.kill()

	if exit_position == Vector2.ZERO:
		queue_free()
		return

	if body_sprite is AnimatedSprite2D and body_sprite.sprite_frames != null:
		if body_sprite.sprite_frames.has_animation(&"walk"):
			body_sprite.play(&"walk")

	_queue_move_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_queue_move_tween.set_parallel(true)
	_queue_move_tween.tween_property(self, "position", exit_position, LEAVE_SHOP_DURATION)
	_queue_move_tween.tween_property(self, "modulate:a", 0.0, LEAVE_SHOP_DURATION)
	_queue_move_tween.chain().tween_callback(queue_free)
